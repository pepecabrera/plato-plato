-- 6.4. Ejecutar despues de 01_tablas.sql. MariaDB 10.6+.
-- Instalar tambien 05_triggers.sql antes de utilizar los procedimientos.
USE plato_plato;
SET NAMES utf8mb4;
DELIMITER $$

-- NULL significa unidad inexistente o conversion entre magnitudes distintas.
CREATE OR REPLACE FUNCTION fn_convertir(p_cantidad DECIMAL(30,8), p_origen VARCHAR(10), p_destino VARCHAR(10))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    RETURN (SELECT p_cantidad * a.factor_a_base / b.factor_a_base
            FROM unidades_medida a JOIN unidades_medida b ON a.magnitud=b.magnitud
            WHERE a.codigo=p_origen AND b.codigo=p_destino);
END$$

CREATE OR REPLACE FUNCTION fn_coste_ingrediente(p_ingrediente INT UNSIGNED, p_cantidad DECIMAL(30,8), p_unidad VARCHAR(10), p_fecha DATETIME(6))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    RETURN (SELECT fn_convertir(p_cantidad,p_unidad,unidad_precio)*precio_compra
            FROM precios_compra WHERE id_ingrediente=p_ingrediente
              AND seleccionado_para_costeo=1 AND fecha_inicio_vigencia<=p_fecha
              AND (fecha_fin_vigencia IS NULL OR p_fecha<fecha_fin_vigencia));
END$$

-- Expande subrecetas con una CTE: no utiliza funciones almacenadas recursivas.
-- Mismo despiece que C-09/C-10, hasta 64 enlaces. Un fallo en cualquier rama
-- invalida el coste total. El redondeo de presentacion no interviene aqui.
CREATE OR REPLACE FUNCTION fn_coste_receta(p_receta INT UNSIGNED, p_fecha DATETIME(6))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    DECLARE v_coste DECIMAL(30,8);
    WITH RECURSIVE arbol (id_receta,veces,ruta,nivel) AS (
        SELECT id_receta, CAST(1 AS DECIMAL(30,12)),
               CAST(CONCAT(',',id_receta,',') AS CHAR(1000)), 0
        FROM recetas WHERE id_receta=p_receta
        UNION ALL
        SELECT r.id_receta,
               CAST(CASE WHEN uc.magnitud=us.magnitud
                         THEN a.veces*c.cantidad*uc.factor_a_base/(us.factor_a_base*r.cantidad_rendimiento) END AS DECIMAL(30,12)),
               CONCAT(a.ruta,r.id_receta,','), a.nivel+1
        FROM arbol a JOIN componentes_receta c ON c.id_receta=a.id_receta
        JOIN recetas r ON r.id_receta=c.id_receta_componente
        JOIN unidades_medida uc ON uc.codigo=c.unidad_medida
        JOIN unidades_medida us ON us.codigo=r.unidad_rendimiento
        WHERE a.nivel<64 AND LOCATE(CONCAT(',',r.id_receta,','),a.ruta)=0
    ), lineas AS (
        SELECT CASE WHEN a.veces IS NULL THEN NULL
                    WHEN c.id_ingrediente IS NOT NULL THEN a.veces*fn_coste_ingrediente(c.id_ingrediente,c.cantidad,c.unidad_medida,p_fecha)
                    WHEN a.nivel<64 AND LOCATE(CONCAT(',',c.id_receta_componente,','),a.ruta)=0 THEN 0
               END AS coste
        FROM arbol a LEFT JOIN componentes_receta c ON c.id_receta=a.id_receta
    )
    SELECT CASE WHEN COUNT(*)=COUNT(coste)
                THEN SUM(coste)/(SELECT cantidad_rendimiento FROM recetas WHERE id_receta=p_receta) END
    INTO v_coste FROM lineas;
    RETURN v_coste;
END$$

CREATE OR REPLACE FUNCTION fn_coste_plato(p_plato INT UNSIGNED, p_fecha DATETIME(6))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    RETURN (SELECT fn_coste_receta(r.id_receta,p_fecha)
            FROM platos p JOIN recetas r ON r.id_receta=p.id_receta
            JOIN unidades_medida u ON u.codigo=r.unidad_rendimiento
            WHERE p.id_plato=p_plato AND u.codigo='racion' AND u.magnitud='RACION' AND u.factor_a_base=1);
END$$

CREATE OR REPLACE FUNCTION fn_margen_plato(p_plato INT UNSIGNED, p_fecha DATETIME(6))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    RETURN (SELECT precio_venta-fn_coste_plato(id_plato,p_fecha) FROM platos WHERE id_plato=p_plato);
END$$

CREATE OR REPLACE FUNCTION fn_stock_lote(p_lote INT UNSIGNED, p_fecha DATETIME(6))
RETURNS DECIMAL(30,4) READS SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM lotes WHERE id_lote=p_lote) THEN RETURN NULL; END IF;
    RETURN (SELECT COALESCE(SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END),0)
            FROM movimientos_stock WHERE id_lote=p_lote AND fecha_movimiento<=p_fecha);
END$$

-- La aplicacion debe autenticar al usuario: recibir un ID no demuestra identidad.
CREATE OR REPLACE FUNCTION fn_tiene_permiso(p_usuario INT UNSIGNED, p_permiso VARCHAR(100))
RETURNS BOOLEAN READS SQL DATA
BEGIN
    RETURN EXISTS(SELECT 1 FROM usuarios u JOIN roles r ON r.id_rol=u.id_rol
        WHERE u.id_usuario=p_usuario AND u.estado='ACTIVO' AND
        (r.nombre='ADMINISTRADOR' OR EXISTS(
            SELECT 1 FROM permisos p WHERE p.nombre=p_permiso AND
            (EXISTS(SELECT 1 FROM roles_permisos rp WHERE rp.id_rol=u.id_rol AND rp.id_permiso=p.id_permiso)
             OR EXISTS(SELECT 1 FROM permisos_adicionales_usuario pu WHERE pu.id_usuario=u.id_usuario AND pu.id_permiso=p.id_permiso)))));
END$$

-- RN-02 exige una concesion explicita incluso para el administrador.
CREATE OR REPLACE FUNCTION fn_puede_autorizar_carta(p_usuario INT UNSIGNED)
RETURNS BOOLEAN READS SQL DATA
BEGIN
    RETURN EXISTS(
        SELECT 1 FROM usuarios u JOIN permisos p ON p.nombre='AUTORIZAR_CARTA'
        WHERE u.id_usuario=p_usuario AND u.estado='ACTIVO'
          AND (EXISTS(SELECT 1 FROM roles_permisos rp WHERE rp.id_rol=u.id_rol AND rp.id_permiso=p.id_permiso)
               OR EXISTS(SELECT 1 FROM permisos_adicionales_usuario pu WHERE pu.id_usuario=u.id_usuario AND pu.id_permiso=p.id_permiso))
    );
END$$

-- La fecha filtra la vigencia del precio seleccionado ACTUALMENTE; se usa la receta actual.
-- No reconstruye versiones historicas de recetas ni selecciones de precios.
CREATE OR REPLACE PROCEDURE sp_consultar_escandallo(IN p_usuario INT UNSIGNED, IN p_plato INT UNSIGNED, IN p_fecha DATETIME(6))
READS SQL DATA
BEGIN
    IF NOT fn_tiene_permiso(p_usuario,'CONSULTAR_COSTES') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sin permiso CONSULTAR_COSTES';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM platos WHERE id_plato=p_plato) OR p_fecha IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Plato inexistente o fecha ausente';
    END IF;
    SELECT id_plato,nombre,ROUND(fn_coste_plato(id_plato,p_fecha),2) coste_unitario,
           precio_venta,ROUND(fn_margen_plato(id_plato,p_fecha),2) margen_bruto,
           ROUND(100*fn_margen_plato(id_plato,p_fecha)/precio_venta,2) porcentaje_margen
    FROM platos WHERE id_plato=p_plato;
END$$

-- Procedimientos de escritura: llamadas autonomas, nunca dentro de otra transaccion.
-- READ COMMITTED + bloqueo del lote serializan los movimientos de ese lote.
CREATE OR REPLACE PROCEDURE sp_registrar_movimiento(
    IN p_usuario INT UNSIGNED, IN p_lote INT UNSIGNED, IN p_tipo VARCHAR(7),
    IN p_cantidad DECIMAL(14,4), IN p_fecha DATETIME(6),
    IN p_finalidad VARCHAR(11), IN p_plato INT UNSIGNED)
MODIFIES SQL DATA
BEGIN
    DECLARE v_lote INT UNSIGNED;
    DECLARE v_entrada DATETIME(6);
    DECLARE v_id INT UNSIGNED;
    IF @@in_transaction THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Llamar fuera de una transaccion'; END IF;
    IF NOT fn_tiene_permiso(p_usuario,'GESTIONAR_STOCK') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sin permiso GESTIONAR_STOCK'; END IF;
    IF p_finalidad='MERMA' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las mermas requieren su flujo especifico; no crear salidas huerfanas'; END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
        START TRANSACTION;
        SELECT id_lote,fecha_entrada INTO v_lote,v_entrada FROM lotes WHERE id_lote=p_lote FOR UPDATE;
        IF v_lote IS NULL OR p_fecha IS NULL OR p_fecha<v_entrada THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote inexistente o movimiento anterior a su recepcion';
        END IF;
        IF NOT EXISTS(SELECT 1 FROM movimientos_stock WHERE id_lote=p_lote) AND p_tipo<>'ENTRADA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El primer movimiento debe ser una entrada';
        END IF;
        IF p_tipo<>'ENTRADA' AND p_fecha<(SELECT MIN(fecha_movimiento) FROM movimientos_stock WHERE id_lote=p_lote) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='No se puede anteponer otro movimiento a la primera entrada';
        END IF;
        INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino)
        VALUES(p_lote,p_tipo,p_cantidad,p_fecha,p_finalidad,p_plato);
        SET v_id=LAST_INSERT_ID();
        IF EXISTS(SELECT 1 FROM (
            SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)
                   OVER(ORDER BY fecha_movimiento,id_movimiento ROWS UNBOUNDED PRECEDING) saldo
            FROM movimientos_stock WHERE id_lote=p_lote
        ) s WHERE saldo<0) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El movimiento deja saldo negativo en el historial';
        END IF;
        COMMIT;
    END;
    SELECT v_id AS id_movimiento;
END$$

-- Registra una prueba ya delimitada; el trigger valida fechas y solapamientos.
CREATE OR REPLACE PROCEDURE sp_registrar_sugerencia(
    IN p_usuario INT UNSIGNED, IN p_plato INT UNSIGNED, IN p_inicio DATETIME(6), IN p_fin DATETIME(6))
MODIFIES SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED;
    DECLARE v_plato INT UNSIGNED;
    IF @@in_transaction THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Llamar fuera de una transaccion'; END IF;
    IF NOT fn_tiene_permiso(p_usuario,'GESTIONAR_PLATOS') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sin permiso GESTIONAR_PLATOS'; END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
        START TRANSACTION;
        SELECT id_plato INTO v_plato FROM platos WHERE id_plato=p_plato FOR UPDATE;
        IF v_plato IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Plato inexistente'; END IF;
        INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio,fecha_fin)
        VALUES(p_plato,'SUGERENCIA_CHEF',p_inicio,p_fin);
        SET v_id=LAST_INSERT_ID();
        COMMIT;
    END;
    SELECT v_id AS id_periodo_oferta;
END$$

-- RN-02: periodo y autorizacion se confirman juntos o se deshacen juntos.
CREATE OR REPLACE PROCEDURE sp_incorporar_carta(
    IN p_autorizador INT UNSIGNED, IN p_plato INT UNSIGNED,
    IN p_inicio DATETIME(6), IN p_fin DATETIME(6))
MODIFIES SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED;
    DECLARE v_plato INT UNSIGNED;
    DECLARE v_usuario INT UNSIGNED;
    DECLARE v_fecha DATETIME(6);
    IF @@in_transaction THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Llamar fuera de una transaccion'; END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
        START TRANSACTION;
        SELECT id_usuario INTO v_usuario FROM usuarios WHERE id_usuario=p_autorizador FOR UPDATE;
        SELECT id_plato INTO v_plato FROM platos WHERE id_plato=p_plato FOR UPDATE;
        IF v_usuario IS NULL OR v_plato IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Usuario o plato inexistente'; END IF;
        IF NOT fn_puede_autorizar_carta(v_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: se requiere un usuario activo con permiso AUTORIZAR_CARTA';
        END IF;
        SET v_fecha=CURRENT_TIMESTAMP(6);
        IF p_inicio IS NULL OR p_inicio<v_fecha THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La incorporacion no puede preceder a la autorizacion actual'; END IF;
        INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio,fecha_fin)
        VALUES(p_plato,'CARTA_PERMANENTE',p_inicio,p_fin);
        SET v_id=LAST_INSERT_ID();
        INSERT INTO autorizaciones_carta(id_periodo_oferta,id_emisor,fecha_autorizacion,coste_evaluado,precio_venta_evaluado)
        VALUES(v_id,v_usuario,v_fecha,0,1);
        -- Los valores provisionales se sustituyen en BEFORE INSERT por los calculados.
        COMMIT;
    END;
    SELECT v_id AS id_periodo_oferta;
END$$
-- Cierra un periodo abierto sin reescribir sus datos iniciales.
CREATE OR REPLACE PROCEDURE sp_cerrar_periodo(
    IN p_usuario INT UNSIGNED, IN p_periodo INT UNSIGNED, IN p_fin DATETIME(6))
MODIFIES SQL DATA
BEGIN
    DECLARE v_plato INT UNSIGNED;
    DECLARE v_bloqueo INT UNSIGNED;
    IF @@in_transaction THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Llamar fuera de una transaccion'; END IF;
    IF NOT fn_tiene_permiso(p_usuario,'GESTIONAR_PLATOS') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sin permiso GESTIONAR_PLATOS'; END IF;
    IF p_fin IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Debe indicar la fecha de cierre'; END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
        START TRANSACTION;
        SELECT id_plato INTO v_plato FROM periodos_oferta WHERE id_periodo_oferta=p_periodo;
        IF v_plato IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Periodo inexistente'; END IF;
        SELECT id_plato INTO v_bloqueo FROM platos WHERE id_plato=v_plato FOR UPDATE;
        UPDATE periodos_oferta SET fecha_fin=p_fin WHERE id_periodo_oferta=p_periodo;
        COMMIT;
    END;
END$$

-- RC-09 y RC-14: alta definitiva de una merma de lote O de plato.
-- El coste es el importe historico total comunicado; NULL significa desconocido.
-- La merma de lote y su salida se confirman juntas; la de plato no descuenta stock.
CREATE OR REPLACE PROCEDURE sp_registrar_merma(
    IN p_usuario INT UNSIGNED, IN p_lote INT UNSIGNED, IN p_plato INT UNSIGNED,
    IN p_cantidad DECIMAL(14,4), IN p_fecha DATETIME(6),
    IN p_motivo VARCHAR(25), IN p_detalle VARCHAR(500), IN p_coste DECIMAL(14,2))
MODIFIES SQL DATA
BEGIN
    DECLARE v_lote INT UNSIGNED;
    DECLARE v_plato INT UNSIGNED;
    DECLARE v_entrada DATETIME(6);
    DECLARE v_primera DATETIME(6);
    DECLARE v_movimiento INT UNSIGNED DEFAULT NULL;
    DECLARE v_merma INT UNSIGNED;
    IF @@in_transaction THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Llamar fuera de una transaccion'; END IF;
    IF NOT fn_tiene_permiso(p_usuario,'REGISTRAR_MERMAS') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sin permiso REGISTRAR_MERMAS';
    END IF;
    IF (p_lote IS NULL AND p_plato IS NULL) OR (p_lote IS NOT NULL AND p_plato IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La merma debe afectar a un lote o a un plato, exclusivamente';
    END IF;
    IF p_cantidad IS NULL OR p_cantidad<=0 OR p_fecha IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Se requieren cantidad positiva y fecha de merma';
    END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
        START TRANSACTION;
        IF p_lote IS NOT NULL THEN
            SELECT id_lote,fecha_entrada INTO v_lote,v_entrada
            FROM lotes WHERE id_lote=p_lote FOR UPDATE;
            IF v_lote IS NULL OR p_fecha<v_entrada THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote inexistente o merma anterior a su recepcion';
            END IF;
            SELECT MIN(fecha_movimiento) INTO v_primera
            FROM movimientos_stock WHERE id_lote=p_lote;
            IF v_primera IS NULL OR p_fecha<v_primera OR NOT EXISTS(
                SELECT 1 FROM movimientos_stock WHERE id_lote=p_lote
                AND fecha_movimiento=v_primera AND tipo='ENTRADA'
            ) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La merma requiere una entrada previa del lote';
            END IF;
            INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino)
            VALUES(p_lote,'SALIDA',p_cantidad,p_fecha,'MERMA',NULL);
            SET v_movimiento=LAST_INSERT_ID();
            IF EXISTS(SELECT 1 FROM (
                SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)
                       OVER(ORDER BY fecha_movimiento,id_movimiento ROWS UNBOUNDED PRECEDING) saldo
                FROM movimientos_stock WHERE id_lote=p_lote
            ) s WHERE saldo<0) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La merma deja saldo negativo en el historial';
            END IF;
        ELSE
            SELECT id_plato INTO v_plato FROM platos WHERE id_plato=p_plato FOR UPDATE;
            IF v_plato IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Plato inexistente';
            END IF;
        END IF;
        INSERT INTO mermas(cantidad_desperdiciada,fecha_merma,motivo,detalle_motivo,coste_perdida,
                           id_lote,id_plato,id_movimiento)
        VALUES(p_cantidad,p_fecha,p_motivo,p_detalle,p_coste,p_lote,p_plato,v_movimiento);
        SET v_merma=LAST_INSERT_ID();
        COMMIT;
    END;
    SELECT v_merma AS id_merma,v_movimiento AS id_movimiento;
END$$
-- Alta operativa completa. p_componentes es un array JSON no vacio de objetos:
-- {"cantidad":100,"unidad_medida":"g","id_ingrediente":1,"id_receta_componente":null}.
-- Cada objeto utiliza ingrediente O subreceta. Requiere instalar 05 antes de usar.
CREATE OR REPLACE PROCEDURE sp_registrar_receta(
    IN p_usuario INT UNSIGNED, IN p_nombre VARCHAR(100),
    IN p_rendimiento DECIMAL(14,4), IN p_unidad VARCHAR(10),
    IN p_componentes LONGTEXT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_receta INT UNSIGNED;
    IF @@in_transaction THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Llamar fuera de una transaccion'; END IF;
    IF NOT fn_tiene_permiso(p_usuario,'GESTIONAR_RECETAS') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sin permiso GESTIONAR_RECETAS';
    END IF;
    IF p_componentes IS NULL OR NOT JSON_VALID(p_componentes) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RC-12: componentes JSON invalidos';
    END IF;
    IF JSON_TYPE(p_componentes)<>'ARRAY' OR JSON_LENGTH(p_componentes)=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RC-12: la receta requiere al menos un componente';
    END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
        START TRANSACTION;
        INSERT INTO recetas(nombre,cantidad_rendimiento,unidad_rendimiento)
        VALUES(p_nombre,p_rendimiento,p_unidad);
        SET v_receta=LAST_INSERT_ID();
        INSERT INTO componentes_receta(id_receta,cantidad,unidad_medida,id_ingrediente,id_receta_componente)
        SELECT v_receta,j.cantidad,j.unidad_medida,j.id_ingrediente,j.id_receta_componente
        FROM JSON_TABLE(p_componentes,'$[*]' COLUMNS (
            cantidad DECIMAL(14,4) PATH '$.cantidad' ERROR ON EMPTY ERROR ON ERROR,
            unidad_medida VARCHAR(10) PATH '$.unidad_medida' ERROR ON EMPTY ERROR ON ERROR,
            id_ingrediente INT UNSIGNED PATH '$.id_ingrediente' NULL ON EMPTY ERROR ON ERROR,
            id_receta_componente INT UNSIGNED PATH '$.id_receta_componente' NULL ON EMPTY ERROR ON ERROR
        )) AS j;
        COMMIT;
    END;
    SELECT v_receta AS id_receta;
END$$

-- RC-04 y RC-15 (precios). Devuelve NULL si el precio es válido; si no, el mensaje de error.
-- p_excluir es el precio que se está modificando, para no compararlo consigo mismo.
CREATE OR REPLACE FUNCTION fn_validar_precio(
    p_excluir INT UNSIGNED, p_proveedor INT UNSIGNED, p_ingrediente INT UNSIGNED,
    p_unidad VARCHAR(10), p_inicio DATETIME(6), p_fin DATETIME(6))
RETURNS VARCHAR(100) READS SQL DATA
BEGIN
    IF EXISTS(SELECT 1 FROM precios_compra p
              WHERE p.id_proveedor=p_proveedor AND p.id_ingrediente=p_ingrediente
                AND (p_excluir IS NULL OR p.id_precio_compra<>p_excluir)
                AND (p_fin IS NULL OR p.fecha_inicio_vigencia<p_fin)
                AND (p.fecha_fin_vigencia IS NULL OR p_inicio<p.fecha_fin_vigencia)) THEN
        RETURN 'RC-04: vigencias de precio solapadas';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM ingredientes i
                  JOIN unidades_medida ui ON ui.codigo=i.unidad_medida
                  JOIN unidades_medida up ON up.codigo=p_unidad AND up.magnitud=ui.magnitud
                  WHERE i.id_ingrediente=p_ingrediente) THEN
        RETURN 'RC-15: unidad del precio incompatible con la del ingrediente';
    END IF;
    RETURN NULL;
END$$

-- RC-12 y RC-15 (componentes). Valida la magnitud de la línea y que no se cree un ciclo.
-- Ciclo: la receta contenedora no debe ser alcanzable desde la subreceta que se añade.
CREATE OR REPLACE FUNCTION fn_validar_componente(
    p_excluir INT UNSIGNED, p_receta INT UNSIGNED, p_unidad VARCHAR(10),
    p_ingrediente INT UNSIGNED, p_subreceta INT UNSIGNED)
RETURNS VARCHAR(100) READS SQL DATA
BEGIN
    DECLARE v_linea VARCHAR(7) DEFAULT NULL;
    DECLARE v_ref VARCHAR(7) DEFAULT NULL;
    DECLARE v_ciclo INT DEFAULT 0;
    SELECT magnitud INTO v_linea FROM unidades_medida WHERE codigo=p_unidad;
    IF p_ingrediente IS NOT NULL THEN
        SELECT u.magnitud INTO v_ref FROM ingredientes i
        JOIN unidades_medida u ON u.codigo=i.unidad_medida WHERE i.id_ingrediente=p_ingrediente;
    ELSEIF p_subreceta IS NOT NULL THEN
        SELECT u.magnitud INTO v_ref FROM recetas r
        JOIN unidades_medida u ON u.codigo=r.unidad_rendimiento WHERE r.id_receta=p_subreceta;
    END IF;
    IF v_linea IS NULL OR v_ref IS NULL OR v_linea<>v_ref THEN
        RETURN 'RC-15: unidad incompatible o componente inexistente';
    END IF;
    IF p_subreceta IS NOT NULL THEN
        WITH RECURSIVE alcanzadas (id_receta) AS (
            SELECT p_subreceta
            UNION
            SELECT c.id_receta_componente
            FROM alcanzadas a JOIN componentes_receta c ON c.id_receta=a.id_receta
            WHERE c.id_receta_componente IS NOT NULL
              AND (p_excluir IS NULL OR c.id_componente<>p_excluir)
        )
        SELECT COUNT(*) INTO v_ciclo FROM alcanzadas WHERE id_receta=p_receta;
        IF v_ciclo>0 THEN RETURN 'RC-12: la receta quedaria contenida en si misma'; END IF;
    END IF;
    RETURN NULL;
END$$

DELIMITER ;
