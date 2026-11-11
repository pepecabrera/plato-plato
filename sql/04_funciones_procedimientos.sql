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
-- Cada rama conserva su factor por unidad de rendimiento. Los ciclos, recetas
-- vacias, unidades incompatibles o precios ausentes producen NULL, nunca cero.
CREATE OR REPLACE FUNCTION fn_coste_receta(p_receta INT UNSIGNED, p_fecha DATETIME(6))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    DECLARE v_coste DECIMAL(30,8);
    WITH RECURSIVE arbol (id_receta,factor,ruta,nivel,ciclo) AS (
        SELECT id_receta, CAST(1/cantidad_rendimiento AS DECIMAL(30,8)),
               CAST(CONCAT('/',id_receta,'/') AS CHAR(2000)), 0, 0
        FROM recetas WHERE id_receta=p_receta
        UNION ALL
        SELECT r.id_receta,
               CAST(a.factor*fn_convertir(c.cantidad,c.unidad_medida,r.unidad_rendimiento)/r.cantidad_rendimiento AS DECIMAL(30,8)),
               CONCAT(a.ruta,r.id_receta,'/'), a.nivel+1,
               LOCATE(CONCAT('/',r.id_receta,'/'),a.ruta)>0
        FROM arbol a JOIN componentes_receta c ON c.id_receta=a.id_receta
        JOIN recetas r ON r.id_receta=c.id_receta_componente
        WHERE a.ciclo=0 AND a.nivel<64
    ), lineas AS (
        SELECT a.*, c.id_componente,c.id_ingrediente,c.id_receta_componente,
               fn_coste_ingrediente(c.id_ingrediente,c.cantidad,c.unidad_medida,p_fecha) coste
        FROM arbol a LEFT JOIN componentes_receta c ON c.id_receta=a.id_receta
    )
    SELECT CASE WHEN COUNT(*)=0 OR
        SUM(ciclo=1 OR factor IS NULL OR id_componente IS NULL
            OR (nivel=64 AND id_receta_componente IS NOT NULL)
            OR (id_ingrediente IS NOT NULL AND coste IS NULL))>0
        THEN NULL ELSE SUM(CASE WHEN id_ingrediente IS NOT NULL THEN factor*coste ELSE 0 END) END
    INTO v_coste FROM lineas;
    RETURN v_coste;
END$$

CREATE OR REPLACE FUNCTION fn_coste_plato(p_plato INT UNSIGNED, p_fecha DATETIME(6))
RETURNS DECIMAL(30,8) READS SQL DATA
BEGIN
    RETURN (SELECT fn_coste_receta(r.id_receta,p_fecha)/u.factor_a_base
            FROM platos p JOIN recetas r ON r.id_receta=p.id_receta
            JOIN unidades_medida u ON u.codigo=r.unidad_rendimiento
            WHERE p.id_plato=p_plato AND u.magnitud='RACION');
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
    IN p_administrador INT UNSIGNED, IN p_plato INT UNSIGNED,
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
        SELECT id_usuario INTO v_usuario FROM usuarios WHERE id_usuario=p_administrador FOR UPDATE;
        SELECT id_plato INTO v_plato FROM platos WHERE id_plato=p_plato FOR UPDATE;
        IF v_usuario IS NULL OR v_plato IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Usuario o plato inexistente'; END IF;
        SET v_fecha=CURRENT_TIMESTAMP(6);
        IF p_inicio IS NULL OR p_inicio<v_fecha THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La incorporacion no puede preceder a la autorizacion actual'; END IF;
        INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio,fecha_fin)
        VALUES(p_plato,'CARTA_PERMANENTE',p_inicio,p_fin);
        SET v_id=LAST_INSERT_ID();
        INSERT INTO autorizaciones_carta(id_periodo_oferta,id_emisor,fecha_autorizacion,coste_evaluado,precio_venta_evaluado)
        VALUES(v_id,p_administrador,v_fecha,0,1);
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

-- RC-14 y S-07: alta definitiva de una merma de lote O de plato.
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
DELIMITER ;
