-- Plato-Plató: cuentas locales y privilegios de demostración (apartado 6.8). MariaDB 10.6+.
-- Opcional: se añadió a petición del evaluador de Claude para demostrar cuentas y privilegios de MariaDB.
-- Si se usa, ejecutar una vez con la cuenta instaladora, tras el poblado (02 o 06) y 04 y 05 completos.
-- Las cuentas se crean bloqueadas. Para probarlas, asignar claves distintas fuera del repositorio:
-- ALTER USER 'pp_administrador'@'localhost' IDENTIFIED BY '<clave>' ACCOUNT UNLOCK;
-- Repetir para pp_encargado y pp_empleado. Conectarse por socket con cada cuenta en una copia desechable.
-- Comprobar una vista y una llamada de fachada permitidas según los GRANT; el acceso directo a tablas
-- debe dar ERROR 1142 y la llamada directa a un procedimiento interno debe dar ERROR 1370.
USE plato_plato;

CREATE USER IF NOT EXISTS 'pp_administrador'@'localhost' ACCOUNT LOCK;
CREATE USER IF NOT EXISTS 'pp_encargado'@'localhost' ACCOUNT LOCK;
CREATE USER IF NOT EXISTS 'pp_empleado'@'localhost' ACCOUNT LOCK;

-- Vistas de consulta: no conceden acceso a las tablas subyacentes.
CREATE SQL SECURITY DEFINER VIEW v_operativa_platos AS
    SELECT id_plato, id_receta, nombre, descripcion, categoria, menu_del_dia
    FROM platos
    WHERE estado = 'ACTIVO';

CREATE SQL SECURITY DEFINER VIEW v_operativa_recetas AS
    SELECT
        r.id_receta,
        r.nombre AS receta,
        r.cantidad_rendimiento,
        r.unidad_rendimiento,
        c.id_ingrediente,
        i.nombre AS ingrediente,
        c.id_receta_componente,
        s.nombre AS subreceta,
        c.cantidad,
        c.unidad_medida
    FROM recetas r
    JOIN componentes_receta c ON c.id_receta = r.id_receta
    LEFT JOIN ingredientes i ON i.id_ingrediente = c.id_ingrediente
    LEFT JOIN recetas s ON s.id_receta = c.id_receta_componente
    WHERE r.estado = 'ACTIVO';

CREATE SQL SECURITY DEFINER VIEW v_operativa_lotes AS
    SELECT
        l.id_lote,
        l.identificador_lote,
        i.id_ingrediente,
        i.nombre AS ingrediente,
        i.unidad_medida,
        l.fecha_entrada,
        l.fecha_caducidad,
        l.ubicacion_almacen,
        l.fresco,
        l.apto_para_consumo,
        fn_stock_lote(l.id_lote, CURRENT_TIMESTAMP(6)) AS saldo_registrado
    FROM lotes l
    JOIN ingredientes i ON i.id_ingrediente = l.id_ingrediente;

CREATE SQL SECURITY DEFINER VIEW v_gestion_oferta AS
    SELECT
        p.id_periodo_oferta,
        p.id_plato,
        p.tipo,
        p.fecha_inicio,
        p.fecha_fin,
        a.fecha_autorizacion
    FROM periodos_oferta p
    LEFT JOIN autorizaciones_carta a ON a.id_periodo_oferta = p.id_periodo_oferta;

CREATE SQL SECURITY DEFINER VIEW v_gestion_proveedores AS
    SELECT id_proveedor, nombre, persona_contacto, telefono, correo_contacto, estado
    FROM proveedores;

CREATE SQL SECURITY DEFINER VIEW v_admin_costes AS
    SELECT
        id_plato,
        nombre,
        precio_venta,
        ROUND(fn_coste_plato(id_plato, CURRENT_TIMESTAMP(6)), 4) AS coste_por_racion,
        ROUND(fn_margen_plato(id_plato, CURRENT_TIMESTAMP(6)), 4) AS margen_bruto
    FROM platos;

CREATE SQL SECURITY DEFINER VIEW v_admin_usuarios AS
    SELECT u.id_usuario, u.nombre, u.correo_electronico, r.nombre AS rol, u.estado
    FROM usuarios u
    JOIN roles r ON r.id_rol = u.id_rol;

DELIMITER $$

-- USER() identifica la conexión; CURRENT_USER() daría el definidor de la rutina.
-- En la demo local, cada cuenta se vincula a un correo de ambos poblados, no a un ID fijo.
CREATE FUNCTION fn_demo_usuario_sql() RETURNS INT UNSIGNED
READS SQL DATA SQL SECURITY DEFINER
BEGIN
    DECLARE v_login VARCHAR(384) DEFAULT USER();
    DECLARE v_usuario INT UNSIGNED;
    SELECT u.id_usuario INTO v_usuario
    FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
    WHERE u.estado = 'ACTIVO' AND (
        (BINARY v_login = 'pp_administrador@localhost' AND u.correo_electronico = 'ana@plato-plato.example' AND r.nombre = 'ADMINISTRADOR')
        OR (BINARY v_login = 'pp_encargado@localhost' AND u.correo_electronico = 'carlos@plato-plato.example' AND r.nombre = 'ENCARGADO')
        OR (BINARY v_login = 'pp_empleado@localhost' AND u.correo_electronico = 'marta@plato-plato.example' AND r.nombre = 'EMPLEADO')
    );
    IF v_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cuenta SQL sin usuario activo del perfil de demostracion';
    END IF;
    RETURN v_usuario;
END$$

-- Contratos públicos sin parámetro de identidad. Las rutinas de 04 conservan
-- sus comprobaciones de negocio y no se conceden a las cuentas operativas.
CREATE PROCEDURE sp_demo_consultar_escandallo(IN p_plato INT UNSIGNED, IN p_fecha DATETIME(6))
READS SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_consultar_escandallo(fn_demo_usuario_sql(), p_plato, p_fecha);
END$$

CREATE PROCEDURE sp_demo_registrar_movimiento(
    IN p_lote INT UNSIGNED,
    IN p_tipo VARCHAR(7),
    IN p_cantidad DECIMAL(14, 4),
    IN p_fecha DATETIME(6),
    IN p_finalidad VARCHAR(11),
    IN p_plato INT UNSIGNED
)
MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_registrar_movimiento(
        fn_demo_usuario_sql(),
        p_lote,
        p_tipo,
        p_cantidad,
        p_fecha,
        p_finalidad,
        p_plato
    );
END$$

CREATE PROCEDURE sp_demo_registrar_merma(
    IN p_lote INT UNSIGNED,
    IN p_plato INT UNSIGNED,
    IN p_cantidad DECIMAL(14, 4),
    IN p_fecha DATETIME(6),
    IN p_motivo VARCHAR(25),
    IN p_detalle VARCHAR(500),
    IN p_coste DECIMAL(14, 2)
)
MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_registrar_merma(
        fn_demo_usuario_sql(),
        p_lote,
        p_plato,
        p_cantidad,
        p_fecha,
        p_motivo,
        p_detalle,
        p_coste
    );
END$$

CREATE PROCEDURE sp_demo_registrar_receta(
    IN p_nombre VARCHAR(100),
    IN p_rendimiento DECIMAL(14, 4),
    IN p_unidad VARCHAR(10),
    IN p_componentes LONGTEXT
)
MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_registrar_receta(fn_demo_usuario_sql(), p_nombre, p_rendimiento, p_unidad, p_componentes);
END$$

CREATE PROCEDURE sp_demo_registrar_sugerencia(
    IN p_plato INT UNSIGNED,
    IN p_inicio DATETIME(6),
    IN p_fin DATETIME(6)
)
MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_registrar_sugerencia(fn_demo_usuario_sql(), p_plato, p_inicio, p_fin);
END$$

CREATE PROCEDURE sp_demo_cerrar_periodo(IN p_periodo INT UNSIGNED, IN p_fin DATETIME(6))
MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_cerrar_periodo(fn_demo_usuario_sql(), p_periodo, p_fin);
END$$

CREATE PROCEDURE sp_demo_incorporar_carta(
    IN p_plato INT UNSIGNED,
    IN p_inicio DATETIME(6),
    IN p_fin DATETIME(6)
)
MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
    CALL sp_incorporar_carta(fn_demo_usuario_sql(), p_plato, p_inicio, p_fin);
END$$

DELIMITER ;

-- Operativa básica: los tres perfiles de demostración.
GRANT SELECT ON plato_plato.v_operativa_platos TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost', 'pp_empleado'@'localhost';
GRANT SELECT ON plato_plato.v_operativa_recetas TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost', 'pp_empleado'@'localhost';
GRANT SELECT ON plato_plato.v_operativa_lotes TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost', 'pp_empleado'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_registrar_movimiento TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost', 'pp_empleado'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_registrar_merma TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost', 'pp_empleado'@'localhost';

-- Gestión: administrador y encargado.
GRANT SELECT ON plato_plato.v_gestion_oferta TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost';
GRANT SELECT ON plato_plato.v_gestion_proveedores TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_registrar_receta TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_registrar_sugerencia TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_cerrar_periodo TO 'pp_administrador'@'localhost', 'pp_encargado'@'localhost';

-- Administración: solo el perfil administrador.
GRANT SELECT ON plato_plato.v_admin_costes TO 'pp_administrador'@'localhost';
GRANT SELECT ON plato_plato.v_admin_usuarios TO 'pp_administrador'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_consultar_escandallo TO 'pp_administrador'@'localhost';
GRANT EXECUTE ON PROCEDURE plato_plato.sp_demo_incorporar_carta TO 'pp_administrador'@'localhost';
