-- Plato-Plató: 6.6 Poblado de la base de datos mediante procedimientos almacenados (opcional).
-- MariaDB 10.6+. Ejecutar tras 01_tablas.sql (y, si existen, 03-05), con las tablas VACÍAS.
-- ALTERNATIVA a 02_datos.sql: carga el mismo escenario de demostración, pero mediante procedimientos.
-- NO ejecutar 02_datos.sql y este script sobre la misma base: el procedimiento principal lo detecta y se detiene.
-- Los registros se relacionan por clave natural (nombre, correo, identificador de lote), sin IDs fijos.
-- Cliente: usar un cliente que admita DELIMITER (mariadb CLI, DBeaver, Workbench). Sin --force.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
USE plato_plato;

-- Las rutinas llevan el prefijo pob_ para no chocar con las de los apartados 6.4 y 6.5.
-- Se pueden recrear tantas veces como se quiera; solo la carga de datos es de un único uso.
DROP PROCEDURE IF EXISTS pob_poblar_base_datos;
DROP PROCEDURE IF EXISTS pob_bloque_acceso;
DROP PROCEDURE IF EXISTS pob_bloque_unidades;
DROP PROCEDURE IF EXISTS pob_bloque_compras;
DROP PROCEDURE IF EXISTS pob_bloque_cocina;
DROP PROCEDURE IF EXISTS pob_bloque_inventario_y_mermas;
DROP PROCEDURE IF EXISTS pob_bloque_oferta;
DROP PROCEDURE IF EXISTS pob_alta_rol;
DROP PROCEDURE IF EXISTS pob_alta_permiso;
DROP PROCEDURE IF EXISTS pob_alta_usuario;
DROP PROCEDURE IF EXISTS pob_conceder_permiso_rol;
DROP PROCEDURE IF EXISTS pob_conceder_permiso_usuario;
DROP PROCEDURE IF EXISTS pob_alta_unidad;
DROP PROCEDURE IF EXISTS pob_alta_proveedor;
DROP PROCEDURE IF EXISTS pob_alta_ingrediente;
DROP PROCEDURE IF EXISTS pob_alta_precio_compra;
DROP PROCEDURE IF EXISTS pob_alta_receta;
DROP PROCEDURE IF EXISTS pob_alta_plato;
DROP PROCEDURE IF EXISTS pob_alta_componente;
DROP PROCEDURE IF EXISTS pob_alta_lote;
DROP PROCEDURE IF EXISTS pob_registrar_movimiento;
DROP PROCEDURE IF EXISTS pob_registrar_merma_lote;
DROP PROCEDURE IF EXISTS pob_registrar_merma_plato;
DROP PROCEDURE IF EXISTS pob_alta_periodo_oferta;
DROP PROCEDURE IF EXISTS pob_alta_autorizacion_carta;
DROP FUNCTION IF EXISTS pob_id_rol;
DROP FUNCTION IF EXISTS pob_id_permiso;
DROP FUNCTION IF EXISTS pob_id_usuario;
DROP FUNCTION IF EXISTS pob_id_proveedor;
DROP FUNCTION IF EXISTS pob_id_ingrediente;
DROP FUNCTION IF EXISTS pob_id_receta;
DROP FUNCTION IF EXISTS pob_id_plato;
DROP FUNCTION IF EXISTS pob_id_lote;
DROP FUNCTION IF EXISTS pob_saldo_lote;

DELIMITER $$

-- ============================================================
-- 1. Funciones de resolución: clave natural -> identificador.
--    Si la referencia no existe, detienen la carga con un mensaje claro.
-- ============================================================
CREATE FUNCTION pob_id_rol(p_nombre VARCHAR(20)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_rol INTO v_id FROM roles WHERE nombre = p_nombre;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: rol inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_permiso(p_nombre VARCHAR(100)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_permiso INTO v_id FROM permisos WHERE nombre = p_nombre;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: permiso inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_usuario(p_correo VARCHAR(150)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_usuario INTO v_id FROM usuarios WHERE correo_electronico = p_correo;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: usuario inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_proveedor(p_nombre VARCHAR(100)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_proveedor INTO v_id FROM proveedores WHERE nombre = p_nombre;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: proveedor inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_ingrediente(p_nombre VARCHAR(100)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_ingrediente INTO v_id FROM ingredientes WHERE nombre = p_nombre;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: ingrediente inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_receta(p_nombre VARCHAR(100)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_receta INTO v_id FROM recetas WHERE nombre = p_nombre;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: receta inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_plato(p_nombre VARCHAR(100)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_plato INTO v_id FROM platos WHERE nombre = p_nombre;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: plato inexistente';
    END IF;
    RETURN v_id;
END$$

CREATE FUNCTION pob_id_lote(p_identificador VARCHAR(100)) RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    SELECT id_lote INTO v_id FROM lotes WHERE identificador_lote = p_identificador;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: lote inexistente';
    END IF;
    RETURN v_id;
END$$

-- Saldo = entradas + ajustes (con signo) - salidas. Los lotes no almacenan saldo.
CREATE FUNCTION pob_saldo_lote(p_id_lote INT UNSIGNED) RETURNS DECIMAL(14,4)
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(14,4);
    SELECT COALESCE(SUM(CASE tipo WHEN 'SALIDA' THEN -cantidad ELSE cantidad END), 0)
      INTO v_saldo FROM movimientos_stock WHERE id_lote = p_id_lote;
    RETURN v_saldo;
END$$

-- ============================================================
-- 2. Procedimientos de alta: una fila (o un hecho de negocio) por llamada.
-- ============================================================
CREATE PROCEDURE pob_alta_rol(IN p_nombre VARCHAR(20))
BEGIN
    INSERT INTO roles (nombre) VALUES (p_nombre);
END$$

CREATE PROCEDURE pob_alta_permiso(IN p_nombre VARCHAR(100))
BEGIN
    INSERT INTO permisos (nombre) VALUES (p_nombre);
END$$

-- El hash se genera fuera de SQL (scrypt); aquí solo se almacena.
CREATE PROCEDURE pob_alta_usuario(
    IN p_nombre VARCHAR(100), IN p_correo VARCHAR(150), IN p_hash VARCHAR(255),
    IN p_fecha_creacion DATETIME(6), IN p_rol VARCHAR(20), IN p_estado VARCHAR(8))
BEGIN
    INSERT INTO usuarios (nombre, correo_electronico, contrasena_protegida, fecha_creacion, id_rol, estado)
    VALUES (p_nombre, p_correo, p_hash, p_fecha_creacion, pob_id_rol(p_rol), p_estado);
END$$

CREATE PROCEDURE pob_conceder_permiso_rol(IN p_rol VARCHAR(20), IN p_permiso VARCHAR(100))
BEGIN
    INSERT INTO roles_permisos (id_rol, id_permiso)
    VALUES (pob_id_rol(p_rol), pob_id_permiso(p_permiso));
END$$

CREATE PROCEDURE pob_conceder_permiso_usuario(IN p_correo VARCHAR(150), IN p_permiso VARCHAR(100))
BEGIN
    INSERT INTO permisos_adicionales_usuario (id_usuario, id_permiso)
    VALUES (pob_id_usuario(p_correo), pob_id_permiso(p_permiso));
END$$

CREATE PROCEDURE pob_alta_unidad(
    IN p_codigo VARCHAR(10), IN p_nombre VARCHAR(100), IN p_magnitud VARCHAR(7), IN p_factor DECIMAL(18,6))
BEGIN
    INSERT INTO unidades_medida (codigo, nombre, magnitud, factor_a_base)
    VALUES (p_codigo, p_nombre, p_magnitud, p_factor);
END$$

CREATE PROCEDURE pob_alta_proveedor(
    IN p_nombre VARCHAR(100), IN p_contacto VARCHAR(100), IN p_telefono VARCHAR(20),
    IN p_correo VARCHAR(150), IN p_forma_pago VARCHAR(100), IN p_estado VARCHAR(8))
BEGIN
    INSERT INTO proveedores (nombre, persona_contacto, telefono, correo_contacto, forma_pago, estado)
    VALUES (p_nombre, p_contacto, p_telefono, p_correo, p_forma_pago, p_estado);
END$$

CREATE PROCEDURE pob_alta_ingrediente(
    IN p_nombre VARCHAR(100), IN p_categoria VARCHAR(100), IN p_unidad VARCHAR(10), IN p_estado VARCHAR(8))
BEGIN
    INSERT INTO ingredientes (nombre, categoria, unidad_medida, estado)
    VALUES (p_nombre, p_categoria, p_unidad, p_estado);
END$$

-- RC-04: se rechaza una vigencia que solape con otra del mismo proveedor e ingrediente.
CREATE PROCEDURE pob_alta_precio_compra(
    IN p_proveedor VARCHAR(100), IN p_ingrediente VARCHAR(100), IN p_precio DECIMAL(14,4),
    IN p_unidad VARCHAR(10), IN p_inicio DATETIME(6), IN p_fin DATETIME(6), IN p_seleccionado BOOLEAN)
BEGIN
    DECLARE v_proveedor INT UNSIGNED;
    DECLARE v_ingrediente INT UNSIGNED;
    SET v_proveedor = pob_id_proveedor(p_proveedor);
    SET v_ingrediente = pob_id_ingrediente(p_ingrediente);
    IF EXISTS (SELECT 1 FROM precios_compra
               WHERE id_proveedor = v_proveedor AND id_ingrediente = v_ingrediente
                 AND fecha_inicio_vigencia < COALESCE(p_fin, '9999-12-31 23:59:59.999999')
                 AND COALESCE(fecha_fin_vigencia, '9999-12-31 23:59:59.999999') > p_inicio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: vigencias de precio solapadas (RC-04)';
    END IF;
    INSERT INTO precios_compra (id_proveedor, id_ingrediente, precio_compra, unidad_precio,
                                fecha_inicio_vigencia, fecha_fin_vigencia, seleccionado_para_costeo)
    VALUES (v_proveedor, v_ingrediente, p_precio, p_unidad, p_inicio, p_fin, p_seleccionado);
END$$

CREATE PROCEDURE pob_alta_receta(
    IN p_nombre VARCHAR(100), IN p_rendimiento DECIMAL(14,4), IN p_unidad VARCHAR(10), IN p_estado VARCHAR(8))
BEGIN
    INSERT INTO recetas (nombre, cantidad_rendimiento, unidad_rendimiento, estado)
    VALUES (p_nombre, p_rendimiento, p_unidad, p_estado);
END$$

CREATE PROCEDURE pob_alta_plato(
    IN p_receta VARCHAR(100), IN p_nombre VARCHAR(100), IN p_imagen VARCHAR(255),
    IN p_descripcion VARCHAR(500), IN p_categoria VARCHAR(100), IN p_menu_del_dia BOOLEAN,
    IN p_precio_venta DECIMAL(14,2), IN p_margen_objetivo DECIMAL(5,2), IN p_estado VARCHAR(8))
BEGIN
    INSERT INTO platos (id_receta, nombre, imagen, descripcion, categoria, menu_del_dia,
                        precio_venta, porcentaje_margen_objetivo, estado)
    VALUES (pob_id_receta(p_receta), p_nombre, p_imagen, p_descripcion, p_categoria, p_menu_del_dia,
            p_precio_venta, p_margen_objetivo, p_estado);
END$$

-- Una línea de receta usa un ingrediente O una subreceta (se pasa NULL en el otro parámetro).
CREATE PROCEDURE pob_alta_componente(
    IN p_receta VARCHAR(100), IN p_cantidad DECIMAL(14,4), IN p_unidad VARCHAR(10),
    IN p_ingrediente VARCHAR(100), IN p_subreceta VARCHAR(100))
BEGIN
    DECLARE v_ingrediente INT UNSIGNED DEFAULT NULL;
    DECLARE v_subreceta INT UNSIGNED DEFAULT NULL;
    IF p_ingrediente IS NOT NULL THEN SET v_ingrediente = pob_id_ingrediente(p_ingrediente); END IF;
    IF p_subreceta IS NOT NULL THEN SET v_subreceta = pob_id_receta(p_subreceta); END IF;
    INSERT INTO componentes_receta (id_receta, cantidad, unidad_medida, id_ingrediente, id_receta_componente)
    VALUES (pob_id_receta(p_receta), p_cantidad, p_unidad, v_ingrediente, v_subreceta);
END$$

CREATE PROCEDURE pob_alta_lote(
    IN p_identificador VARCHAR(100), IN p_ingrediente VARCHAR(100), IN p_entrada DATETIME(6),
    IN p_caducidad DATETIME(6), IN p_ubicacion VARCHAR(100), IN p_fresco BOOLEAN, IN p_apto BOOLEAN)
BEGIN
    INSERT INTO lotes (identificador_lote, id_ingrediente, fecha_entrada, fecha_caducidad,
                       ubicacion_almacen, fresco, apto_para_consumo)
    VALUES (p_identificador, pob_id_ingrediente(p_ingrediente), p_entrada, p_caducidad,
            p_ubicacion, p_fresco, p_apto);
END$$

-- Registra un movimiento validando RC-13 (sin saldo negativo) y RC-17 (el primero es la entrada y
-- ninguno es anterior a ella). Devuelve el id generado para poder enlazar mermas.
CREATE PROCEDURE pob_registrar_movimiento(
    IN p_identificador_lote VARCHAR(100), IN p_tipo VARCHAR(7), IN p_cantidad DECIMAL(14,4),
    IN p_fecha DATETIME(6), IN p_finalidad VARCHAR(11), IN p_plato_destino VARCHAR(100),
    OUT p_id_movimiento INT UNSIGNED)
BEGIN
    DECLARE v_lote INT UNSIGNED;
    DECLARE v_plato INT UNSIGNED DEFAULT NULL;
    DECLARE v_entrada DATETIME(6);
    SET v_lote = pob_id_lote(p_identificador_lote);
    IF p_plato_destino IS NOT NULL THEN SET v_plato = pob_id_plato(p_plato_destino); END IF;
    SELECT fecha_entrada INTO v_entrada FROM lotes WHERE id_lote = v_lote;
    IF p_fecha < v_entrada THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: movimiento anterior a la entrada del lote (RC-17)';
    END IF;
    IF p_tipo <> 'ENTRADA' AND NOT EXISTS (SELECT 1 FROM movimientos_stock WHERE id_lote = v_lote) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: el primer movimiento de un lote debe ser su entrada (RC-17)';
    END IF;
    IF (p_tipo = 'SALIDA' AND pob_saldo_lote(v_lote) < p_cantidad)
       OR (p_tipo = 'AJUSTE' AND pob_saldo_lote(v_lote) + p_cantidad < 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: el movimiento dejaría saldo negativo (RC-13)';
    END IF;
    INSERT INTO movimientos_stock (id_lote, tipo, cantidad, fecha_movimiento, finalidad_salida, id_plato_destino)
    VALUES (v_lote, p_tipo, p_cantidad, p_fecha, p_finalidad, v_plato);
    SET p_id_movimiento = LAST_INSERT_ID();
END$$

-- RC-14: la merma de un lote crea de forma atómica su salida (finalidad MERMA) y la enlaza.
-- Misma cantidad y fecha en la salida y en la merma.
CREATE PROCEDURE pob_registrar_merma_lote(
    IN p_identificador_lote VARCHAR(100), IN p_cantidad DECIMAL(14,4), IN p_fecha DATETIME(6),
    IN p_motivo VARCHAR(25), IN p_detalle VARCHAR(500), IN p_coste DECIMAL(14,2))
BEGIN
    DECLARE v_movimiento INT UNSIGNED;
    CALL pob_registrar_movimiento(p_identificador_lote, 'SALIDA', p_cantidad, p_fecha, 'MERMA', NULL, v_movimiento);
    INSERT INTO mermas (cantidad_desperdiciada, fecha_merma, motivo, detalle_motivo, coste_perdida,
                        id_lote, id_plato, id_movimiento)
    VALUES (p_cantidad, p_fecha, p_motivo, p_detalle, p_coste,
            pob_id_lote(p_identificador_lote), NULL, v_movimiento);
END$$

-- La merma de un plato elaborado se mide en raciones y no vuelve a descontar ingredientes.
CREATE PROCEDURE pob_registrar_merma_plato(
    IN p_plato VARCHAR(100), IN p_cantidad DECIMAL(14,4), IN p_fecha DATETIME(6),
    IN p_motivo VARCHAR(25), IN p_detalle VARCHAR(500), IN p_coste DECIMAL(14,2))
BEGIN
    INSERT INTO mermas (cantidad_desperdiciada, fecha_merma, motivo, detalle_motivo, coste_perdida,
                        id_lote, id_plato, id_movimiento)
    VALUES (p_cantidad, p_fecha, p_motivo, p_detalle, p_coste, NULL, pob_id_plato(p_plato), NULL);
END$$

-- RC-16: un plato no puede tener dos periodos simultáneos, sean o no del mismo tipo.
-- Intervalos [inicio, fin): el fin no se solapa con un inicio idéntico.
CREATE PROCEDURE pob_alta_periodo_oferta(
    IN p_plato VARCHAR(100), IN p_tipo VARCHAR(20), IN p_inicio DATETIME(6), IN p_fin DATETIME(6))
BEGIN
    DECLARE v_plato INT UNSIGNED;
    SET v_plato = pob_id_plato(p_plato);
    IF EXISTS (SELECT 1 FROM periodos_oferta
               WHERE id_plato = v_plato
                 AND fecha_inicio < COALESCE(p_fin, '9999-12-31 23:59:59.999999')
                 AND COALESCE(fecha_fin, '9999-12-31 23:59:59.999999') > p_inicio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: periodos de oferta solapados (RC-16)';
    END IF;
    INSERT INTO periodos_oferta (id_plato, tipo, fecha_inicio, fecha_fin)
    VALUES (v_plato, p_tipo, p_inicio, p_fin);
END$$

-- RN-02: autoriza la incorporación a carta un administrador con cuenta activa, antes del inicio del periodo.
-- El periodo de carta se localiza por plato y fecha de inicio.
CREATE PROCEDURE pob_alta_autorizacion_carta(
    IN p_plato VARCHAR(100), IN p_inicio_carta DATETIME(6), IN p_correo_emisor VARCHAR(150),
    IN p_fecha_autorizacion DATETIME(6), IN p_coste DECIMAL(14,2), IN p_precio DECIMAL(14,2))
BEGIN
    DECLARE v_periodo INT UNSIGNED DEFAULT NULL;
    DECLARE v_emisor INT UNSIGNED;
    SELECT id_periodo_oferta INTO v_periodo FROM periodos_oferta
     WHERE id_plato = pob_id_plato(p_plato) AND tipo = 'CARTA_PERMANENTE' AND fecha_inicio = p_inicio_carta;
    IF v_periodo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: periodo de carta inexistente';
    END IF;
    SET v_emisor = pob_id_usuario(p_correo_emisor);
    IF NOT EXISTS (SELECT 1 FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
                   WHERE u.id_usuario = v_emisor AND r.nombre = 'ADMINISTRADOR' AND u.estado = 'ACTIVO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: el emisor debe ser un administrador activo (RN-02)';
    END IF;
    IF p_fecha_autorizacion > p_inicio_carta THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: la autorización debe ser previa a la carta (RN-02)';
    END IF;
    INSERT INTO autorizaciones_carta (id_periodo_oferta, id_emisor, fecha_autorizacion,
                                      coste_evaluado, precio_venta_evaluado)
    VALUES (v_periodo, v_emisor, p_fecha_autorizacion, p_coste, p_precio);
END$$

-- ============================================================
-- 3. Bloques de datos: mismo escenario que 02_datos.sql.
-- ============================================================
CREATE PROCEDURE pob_bloque_acceso()
BEGIN
    CALL pob_alta_rol('ADMINISTRADOR');
    CALL pob_alta_rol('ENCARGADO');
    CALL pob_alta_rol('EMPLEADO');

    CALL pob_alta_permiso('GESTIONAR_USUARIOS');
    CALL pob_alta_permiso('GESTIONAR_PROVEEDORES');
    CALL pob_alta_permiso('GESTIONAR_RECETAS');
    CALL pob_alta_permiso('GESTIONAR_STOCK');
    CALL pob_alta_permiso('REGISTRAR_MERMAS');
    CALL pob_alta_permiso('CONSULTAR_COSTES');
    CALL pob_alta_permiso('AUTORIZAR_CARTA');

    -- Contraseña de demostración de todos los usuarios: DemoPlato2026!
    CALL pob_alta_usuario('Ana Martín','ana@plato-plato.example','scrypt$16384$8$1$6d5ca317a5b20f5036db04fe74a0b44b$2473e88ad74899f9f9416eadbbf1814085962af448af7345ca31a618bbc6df06e32d4ba296116c71a123730c06ca95dd5b1644a54c0011ee0fa90ca695bd2130','2026-09-01 09:00:00','ADMINISTRADOR','ACTIVO');
    CALL pob_alta_usuario('Carlos López','carlos@plato-plato.example','scrypt$16384$8$1$3cabd10623cd2a7b7b5a9d32e10b7a22$e20233713c3044aa89afd18cf797b42e7332a3ca79b25de5e139ab3f9c82135e93063afee52dc2205d67051574dc6074a0c15e5aca6e8743da271b759bd84d1f','2026-09-01 09:00:00','ENCARGADO','ACTIVO');
    CALL pob_alta_usuario('Marta Sánchez','marta@plato-plato.example','scrypt$16384$8$1$5e71c14197f4d443c16b1103e36c36e0$fd0858d87254a2ac36b3b52fe54bcb0ac354ac5d6c397306e46d0bfd6fb462c48c3b9f31090d697325ebc3461e66692fc3f5dbf2218c71feec7ed8a3d29c3668','2026-09-01 09:00:00','EMPLEADO','ACTIVO');
    CALL pob_alta_usuario('Luis García','luis@plato-plato.example','scrypt$16384$8$1$d4e441aed4c865c692eb909616be609e$9c6608326e86dfd227607becfe41c2b1da51f4fbedfb85f270418d53ef3be318b815cb8e96d23660b29bda4ddbafee7e83651319efcd66fa9e1fbb5263130c33','2026-09-01 09:00:00','EMPLEADO','INACTIVO');

    CALL pob_conceder_permiso_rol('ADMINISTRADOR','GESTIONAR_USUARIOS');
    CALL pob_conceder_permiso_rol('ADMINISTRADOR','GESTIONAR_PROVEEDORES');
    CALL pob_conceder_permiso_rol('ADMINISTRADOR','GESTIONAR_RECETAS');
    CALL pob_conceder_permiso_rol('ADMINISTRADOR','GESTIONAR_STOCK');
    CALL pob_conceder_permiso_rol('ADMINISTRADOR','REGISTRAR_MERMAS');
    CALL pob_conceder_permiso_rol('ADMINISTRADOR','CONSULTAR_COSTES');
    CALL pob_conceder_permiso_rol('ADMINISTRADOR','AUTORIZAR_CARTA');
    CALL pob_conceder_permiso_rol('ENCARGADO','GESTIONAR_PROVEEDORES');
    CALL pob_conceder_permiso_rol('ENCARGADO','GESTIONAR_RECETAS');
    CALL pob_conceder_permiso_rol('ENCARGADO','GESTIONAR_STOCK');
    CALL pob_conceder_permiso_rol('ENCARGADO','REGISTRAR_MERMAS');
    CALL pob_conceder_permiso_rol('ENCARGADO','CONSULTAR_COSTES');
    CALL pob_conceder_permiso_rol('EMPLEADO','GESTIONAR_STOCK');
    CALL pob_conceder_permiso_rol('EMPLEADO','REGISTRAR_MERMAS');

    CALL pob_conceder_permiso_usuario('marta@plato-plato.example','CONSULTAR_COSTES');
END$$

-- Bases: gramo, mililitro, unidad y ración. Solo se convierten magnitudes iguales.
CREATE PROCEDURE pob_bloque_unidades()
BEGIN
    CALL pob_alta_unidad('g','Gramo','MASA',1);
    CALL pob_alta_unidad('kg','Kilogramo','MASA',1000);
    CALL pob_alta_unidad('ml','Mililitro','VOLUMEN',1);
    CALL pob_alta_unidad('l','Litro','VOLUMEN',1000);
    CALL pob_alta_unidad('ud','Unidad','UNIDAD',1);
    CALL pob_alta_unidad('racion','Ración','RACION',1);
END$$

CREATE PROCEDURE pob_bloque_compras()
BEGIN
    CALL pob_alta_proveedor('Huerta del Sur','Lucía Pérez',NULL,'pedidos@huertadelsur.example','Transferencia a 30 días','ACTIVO');
    CALL pob_alta_proveedor('Despensa Central','Jorge Ruiz',NULL,'ventas@despensacentral.example','Transferencia a 15 días','ACTIVO');
    CALL pob_alta_proveedor('Distribuciones Antiguas','Pablo Gil',NULL,'contacto@distribucionesantiguas.example','Transferencia','INACTIVO');

    CALL pob_alta_ingrediente('Tomate','Hortalizas','kg','ACTIVO');
    CALL pob_alta_ingrediente('Cebolla','Hortalizas','kg','ACTIVO');
    CALL pob_alta_ingrediente('Aceite de oliva','Aceites','l','ACTIVO');
    CALL pob_alta_ingrediente('Sal','Condimentos','kg','ACTIVO');
    CALL pob_alta_ingrediente('Pasta seca','Cereales','kg','ACTIVO');
    CALL pob_alta_ingrediente('Patata','Hortalizas','kg','ACTIVO');
    CALL pob_alta_ingrediente('Huevo','Huevos','ud','ACTIVO');
    CALL pob_alta_ingrediente('Perejil','Hierbas aromáticas','kg','INACTIVO');

    -- Un precio seleccionado por ingrediente activo. El tomate tiene histórico y alternativa.
    CALL pob_alta_precio_compra('Huerta del Sur','Tomate',2.0000,'kg','2026-09-01 00:00:00','2026-10-01 00:00:00',0);
    CALL pob_alta_precio_compra('Huerta del Sur','Tomate',2.4000,'kg','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Despensa Central','Tomate',2.7000,'kg','2026-10-01 00:00:00',NULL,0);
    CALL pob_alta_precio_compra('Huerta del Sur','Cebolla',1.5000,'kg','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Despensa Central','Aceite de oliva',6.0000,'l','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Despensa Central','Sal',0.8000,'kg','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Despensa Central','Pasta seca',2.0000,'kg','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Huerta del Sur','Patata',1.2000,'kg','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Despensa Central','Huevo',0.2500,'ud','2026-10-01 00:00:00',NULL,1);
    CALL pob_alta_precio_compra('Distribuciones Antiguas','Perejil',8.0000,'kg','2026-09-01 00:00:00','2026-10-01 00:00:00',0);
END$$

-- La salsa produce 1 kg tras la cocción. La pasta utiliza 600 g de esa subreceta.
CREATE PROCEDURE pob_bloque_cocina()
BEGIN
    CALL pob_alta_receta('Salsa de tomate casera',1,'kg','ACTIVO');
    CALL pob_alta_receta('Pasta con tomate',4,'racion','ACTIVO');
    CALL pob_alta_receta('Tortilla de patatas',4,'racion','ACTIVO');

    CALL pob_alta_plato('Pasta con tomate','Pasta con tomate',NULL,'Pasta con salsa de tomate y cebolla casera.','Principal',1,9.50,65,'ACTIVO');
    CALL pob_alta_plato('Tortilla de patatas','Tortilla de patatas',NULL,'Tortilla de patatas con cebolla.','Entrante',0,6.00,65,'ACTIVO');

    CALL pob_alta_componente('Salsa de tomate casera',1200,'g','Tomate',NULL);
    CALL pob_alta_componente('Salsa de tomate casera',200,'g','Cebolla',NULL);
    CALL pob_alta_componente('Salsa de tomate casera',50,'ml','Aceite de oliva',NULL);
    CALL pob_alta_componente('Salsa de tomate casera',10,'g','Sal',NULL);
    CALL pob_alta_componente('Pasta con tomate',400,'g','Pasta seca',NULL);
    CALL pob_alta_componente('Pasta con tomate',600,'g',NULL,'Salsa de tomate casera');
    CALL pob_alta_componente('Tortilla de patatas',800,'g','Patata',NULL);
    CALL pob_alta_componente('Tortilla de patatas',6,'ud','Huevo',NULL);
    CALL pob_alta_componente('Tortilla de patatas',200,'g','Cebolla',NULL);
    CALL pob_alta_componente('Tortilla de patatas',100,'ml','Aceite de oliva',NULL);
    CALL pob_alta_componente('Tortilla de patatas',8,'g','Sal',NULL);
END$$

-- Cantidades en la unidad del ingrediente de cada lote. Se insertan en orden cronológico.
CREATE PROCEDURE pob_bloque_inventario_y_mermas()
BEGIN
    DECLARE v_mov INT UNSIGNED;

    CALL pob_alta_lote('TOM-20261109','Tomate','2026-11-09 08:00:00','2026-11-16 23:59:59','Cámara de verduras',1,1);
    CALL pob_alta_lote('CEB-20261109','Cebolla','2026-11-09 08:00:00','2026-11-30 23:59:59','Almacén de verduras',1,1);
    CALL pob_alta_lote('ACE-20261109','Aceite de oliva','2026-11-09 08:00:00','2027-05-01 23:59:59','Almacén seco',0,1);
    CALL pob_alta_lote('SAL-20261109','Sal','2026-11-09 08:00:00',NULL,'Almacén seco',0,1);
    CALL pob_alta_lote('PAS-20261109','Pasta seca','2026-11-09 08:00:00','2027-08-01 23:59:59','Almacén seco',0,1);
    CALL pob_alta_lote('PAT-20261109','Patata','2026-11-09 08:00:00','2026-12-01 23:59:59','Almacén de verduras',1,1);
    CALL pob_alta_lote('HUE-20261109','Huevo','2026-11-09 08:00:00','2026-11-25 23:59:59','Cámara de huevos',1,1);
    CALL pob_alta_lote('TOM-20261101','Tomate','2026-11-01 08:00:00','2026-11-08 23:59:59','Zona de retirada',0,0);

    -- Entradas.
    CALL pob_registrar_movimiento('TOM-20261109','ENTRADA',10,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('CEB-20261109','ENTRADA',5,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('ACE-20261109','ENTRADA',3,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('SAL-20261109','ENTRADA',1,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('PAS-20261109','ENTRADA',5,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('PAT-20261109','ENTRADA',8,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('HUE-20261109','ENTRADA',30,'2026-11-09 08:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('TOM-20261101','ENTRADA',2,'2026-11-01 08:00:00',NULL,NULL,v_mov);

    -- Un lote caducado se retira por completo (merma 1: salida + merma en una sola llamada).
    CALL pob_registrar_merma_lote('TOM-20261101',2,'2026-11-09 09:00:00','CADUCIDAD','Retirada completa del lote caducado.',4.80);

    -- Dos elaboraciones de pasta (8 raciones): necesitan 1,2 kg de salsa.
    CALL pob_registrar_movimiento('TOM-20261109','SALIDA',1.44,'2026-11-10 10:00:00','ELABORACION','Pasta con tomate',v_mov);
    CALL pob_registrar_movimiento('CEB-20261109','SALIDA',0.24,'2026-11-10 10:00:00','ELABORACION','Pasta con tomate',v_mov);
    CALL pob_registrar_movimiento('ACE-20261109','SALIDA',0.06,'2026-11-10 10:00:00','ELABORACION','Pasta con tomate',v_mov);
    CALL pob_registrar_movimiento('SAL-20261109','SALIDA',0.012,'2026-11-10 10:00:00','ELABORACION','Pasta con tomate',v_mov);
    CALL pob_registrar_movimiento('PAS-20261109','SALIDA',0.8,'2026-11-10 10:00:00','ELABORACION','Pasta con tomate',v_mov);

    -- Una elaboración de tortilla (4 raciones).
    CALL pob_registrar_movimiento('PAT-20261109','SALIDA',0.8,'2026-11-10 10:30:00','ELABORACION','Tortilla de patatas',v_mov);
    CALL pob_registrar_movimiento('HUE-20261109','SALIDA',6,'2026-11-10 10:30:00','ELABORACION','Tortilla de patatas',v_mov);
    CALL pob_registrar_movimiento('CEB-20261109','SALIDA',0.2,'2026-11-10 10:30:00','ELABORACION','Tortilla de patatas',v_mov);
    CALL pob_registrar_movimiento('ACE-20261109','SALIDA',0.1,'2026-11-10 10:30:00','ELABORACION','Tortilla de patatas',v_mov);
    CALL pob_registrar_movimiento('SAL-20261109','SALIDA',0.008,'2026-11-10 10:30:00','ELABORACION','Tortilla de patatas',v_mov);

    -- Merma 2: tomates dañados.
    CALL pob_registrar_merma_lote('TOM-20261109',0.5,'2026-11-10 11:00:00','DETERIORO','Tomates dañados detectados al preparar.',1.20);

    -- Ajustes por recuento físico (el esquema no guarda su motivo).
    CALL pob_registrar_movimiento('PAT-20261109','AJUSTE',-0.2,'2026-11-10 12:00:00',NULL,NULL,v_mov);
    CALL pob_registrar_movimiento('HUE-20261109','AJUSTE',2,'2026-11-10 12:00:00',NULL,NULL,v_mov);

    -- Merma 3: una ración de pasta ya elaborada; no genera movimiento.
    CALL pob_registrar_merma_plato('Pasta con tomate',1,'2026-11-10 15:00:00','PLATO_DESECHADO','Una ración de pasta elaborada y no servida.',0.72);
END$$

-- Intervalos [inicio, fin): la sugerencia termina exactamente cuando empieza la carta (RC-16, RN-04).
-- Cada plato pasa 14 días como sugerencia del chef antes de su alta en carta permanente.
CREATE PROCEDURE pob_bloque_oferta()
BEGIN
    CALL pob_alta_periodo_oferta('Pasta con tomate','SUGERENCIA_CHEF','2026-10-01 00:00:00','2026-10-15 00:00:00');
    CALL pob_alta_periodo_oferta('Pasta con tomate','CARTA_PERMANENTE','2026-10-15 00:00:00',NULL);
    CALL pob_alta_periodo_oferta('Tortilla de patatas','SUGERENCIA_CHEF','2026-10-10 00:00:00','2026-10-24 00:00:00');
    CALL pob_alta_periodo_oferta('Tortilla de patatas','CARTA_PERMANENTE','2026-10-24 00:00:00',NULL);

    -- Autoriza la administradora tras iniciarse la prueba y antes del alta en carta.
    -- Costes por ración redondeados: pasta 0,72 EUR; tortilla 0,84 EUR (importes históricos, no calculados).
    CALL pob_alta_autorizacion_carta('Pasta con tomate','2026-10-15 00:00:00','ana@plato-plato.example','2026-10-07 18:00:00',0.72,9.50);
    CALL pob_alta_autorizacion_carta('Tortilla de patatas','2026-10-24 00:00:00','ana@plato-plato.example','2026-10-16 18:00:00',0.84,6.00);
END$$

-- ============================================================
-- 4. Procedimiento principal: todo o nada.
-- ============================================================
CREATE PROCEDURE pob_poblar_base_datos()
BEGIN
    -- Cualquier error revierte toda la carga y se propaga al cliente.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Las tablas padre bastan: el resto depende de ellas mediante claves foráneas.
    IF (SELECT COUNT(*) FROM roles) + (SELECT COUNT(*) FROM permisos) + (SELECT COUNT(*) FROM usuarios)
     + (SELECT COUNT(*) FROM unidades_medida) + (SELECT COUNT(*) FROM proveedores)
     + (SELECT COUNT(*) FROM ingredientes) + (SELECT COUNT(*) FROM recetas) + (SELECT COUNT(*) FROM lotes) > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pob: la base de datos ya contiene datos; la carga exige tablas vacías';
    END IF;

    START TRANSACTION;
    CALL pob_bloque_acceso();
    CALL pob_bloque_unidades();
    CALL pob_bloque_compras();
    CALL pob_bloque_cocina();
    CALL pob_bloque_inventario_y_mermas();
    CALL pob_bloque_oferta();
    COMMIT;

    -- Resumen de filas cargadas por tabla.
    SELECT 'roles' AS tabla, COUNT(*) AS filas FROM roles
    UNION ALL SELECT 'permisos', COUNT(*) FROM permisos
    UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
    UNION ALL SELECT 'roles_permisos', COUNT(*) FROM roles_permisos
    UNION ALL SELECT 'permisos_adicionales_usuario', COUNT(*) FROM permisos_adicionales_usuario
    UNION ALL SELECT 'unidades_medida', COUNT(*) FROM unidades_medida
    UNION ALL SELECT 'proveedores', COUNT(*) FROM proveedores
    UNION ALL SELECT 'ingredientes', COUNT(*) FROM ingredientes
    UNION ALL SELECT 'precios_compra', COUNT(*) FROM precios_compra
    UNION ALL SELECT 'recetas', COUNT(*) FROM recetas
    UNION ALL SELECT 'platos', COUNT(*) FROM platos
    UNION ALL SELECT 'componentes_receta', COUNT(*) FROM componentes_receta
    UNION ALL SELECT 'lotes', COUNT(*) FROM lotes
    UNION ALL SELECT 'movimientos_stock', COUNT(*) FROM movimientos_stock
    UNION ALL SELECT 'mermas', COUNT(*) FROM mermas
    UNION ALL SELECT 'periodos_oferta', COUNT(*) FROM periodos_oferta
    UNION ALL SELECT 'autorizaciones_carta', COUNT(*) FROM autorizaciones_carta;
END$$

DELIMITER ;

-- Ejecución de la carga (una sola vez sobre tablas vacías).
CALL pob_poblar_base_datos();
