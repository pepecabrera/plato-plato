-- 6.5. Triggers asociados a RN-01, RN-02, RN-03 y RN-04.
-- Requiere 01_tablas.sql y 04_funciones_procedimientos.sql.
USE plato_plato;
SET NAMES utf8mb4;
DELIMITER $$

-- RN-01 y RN-03 se evalúan en la fecha de la salida, no en la fecha actual.
-- Una salida por merma no es una elaboración: puede retirar un lote caducado.
CREATE OR REPLACE TRIGGER trg_movimiento_bi_negocio
BEFORE INSERT ON movimientos_stock FOR EACH ROW
BEGIN
    DECLARE v_entrada DATETIME(6);
    DECLARE v_caducidad DATETIME(6);
    DECLARE v_fresco BOOLEAN;
    DECLARE v_apto BOOLEAN;
    DECLARE v_menu BOOLEAN;
    IF NEW.tipo='SALIDA' AND NEW.finalidad_salida='ELABORACION' THEN
        SELECT fecha_entrada,fecha_caducidad,fresco,apto_para_consumo
        INTO v_entrada,v_caducidad,v_fresco,v_apto
        FROM lotes WHERE id_lote=NEW.id_lote;
        SELECT menu_del_dia INTO v_menu FROM platos WHERE id_plato=NEW.id_plato_destino;
        IF v_entrada IS NULL OR v_menu IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-01: lote o plato inexistente';
        END IF;
        IF NEW.fecha_movimiento<v_entrada THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La elaboracion no puede preceder a la recepcion del lote';
        END IF;
        IF v_apto=0 OR (v_caducidad IS NOT NULL AND NEW.fecha_movimiento>=v_caducidad) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-01: no se puede elaborar con un lote caducado o no apto';
        END IF;
        -- RN-01: menos de 48 horas; este IF solo comprueba el menu del dia.
        IF v_caducidad IS NOT NULL
           AND NEW.fecha_movimiento > v_caducidad - INTERVAL 48 HOUR
           AND v_menu = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-01: con menos de 48 horas restantes solo se admite menu del dia';
        END IF;

        -- RN-03 permanece dentro del bloque de salidas para elaboracion.
        IF v_fresco = 1
           AND NEW.fecha_movimiento >= v_entrada + INTERVAL 72 HOUR THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-03: el lote fresco ha alcanzado las 72 horas desde su recepcion';
        END IF;
    END IF; -- Fin del bloque SALIDA con finalidad ELABORACION.
END$$

-- Evita eludir las comprobaciones convirtiendo una entrada en salida por UPDATE.
-- Coincide con S-07: los movimientos registrados se corrigen mediante ajustes.
CREATE OR REPLACE TRIGGER trg_movimiento_bu_historico
BEFORE UPDATE ON movimientos_stock FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Movimiento historico: registrar un ajuste, no modificar';
END$$
CREATE OR REPLACE TRIGGER trg_movimiento_bd_historico
BEFORE DELETE ON movimientos_stock FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Movimiento historico: registrar un ajuste, no eliminar';
END$$

-- RN-04: solo la primera incorporacion requiere la prueba, en un unico periodo.
-- La ausencia de solapes permite distinguir etapas reales de la oferta.
CREATE OR REPLACE TRIGGER trg_periodo_bi_negocio
BEFORE INSERT ON periodos_oferta FOR EACH ROW
BEGIN
    IF EXISTS(SELECT 1 FROM periodos_oferta p WHERE p.id_plato=NEW.id_plato
        AND (NEW.fecha_fin IS NULL OR p.fecha_inicio<NEW.fecha_fin)
        AND (p.fecha_fin IS NULL OR NEW.fecha_inicio<p.fecha_fin)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Los periodos de oferta del plato no pueden solaparse';
    END IF;
    IF NEW.tipo='CARTA_PERMANENTE' THEN
        IF NOT EXISTS(SELECT 1 FROM periodos_oferta WHERE id_plato=NEW.id_plato
                       AND tipo='CARTA_PERMANENTE' AND fecha_inicio<NEW.fecha_inicio)
           AND NOT EXISTS(SELECT 1 FROM periodos_oferta WHERE id_plato=NEW.id_plato
                       AND tipo='SUGERENCIA_CHEF' AND fecha_fin IS NOT NULL
                       AND fecha_fin>=fecha_inicio+INTERVAL 14 DAY AND fecha_fin<=NEW.fecha_inicio) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-04: se requieren 14 dias consecutivos de sugerencia del chef';
        END IF;
    END IF;
END$$

-- Se permite cerrar un periodo abierto o acortarlo si no invalida una prueba.
-- No se pueden reescribir el plato, el tipo ni la fecha inicial del historial.
CREATE OR REPLACE TRIGGER trg_periodo_bu_negocio
BEFORE UPDATE ON periodos_oferta FOR EACH ROW
BEGIN
    IF NEW.id_periodo_oferta<>OLD.id_periodo_oferta OR NEW.id_plato<>OLD.id_plato
       OR NEW.tipo<>OLD.tipo OR NEW.fecha_inicio<>OLD.fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='No se pueden reescribir los datos iniciales de un periodo';
    END IF;
    IF NOT(NEW.fecha_fin<=>OLD.fecha_fin) THEN
        IF NEW.fecha_fin IS NULL OR (OLD.fecha_fin IS NOT NULL AND NEW.fecha_fin>OLD.fecha_fin) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Solo se permite cerrar o acortar el periodo';
        END IF;
        IF OLD.tipo='SUGERENCIA_CHEF' AND EXISTS(
            SELECT 1 FROM periodos_oferta WHERE id_plato=OLD.id_plato AND tipo='CARTA_PERMANENTE'
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-04: conservar los periodos de prueba tras la incorporacion';
        END IF;
    END IF;
END$$
CREATE OR REPLACE TRIGGER trg_periodo_bd_historico
BEFORE DELETE ON periodos_oferta FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-04: conservar el historial de oferta';
END$$

-- RN-02: exige un administrador activo y guarda la evaluacion economica real.
-- La obligatoriedad de crear esta fila corresponde a sp_incorporar_carta.
CREATE OR REPLACE TRIGGER trg_autorizacion_bi_negocio
BEFORE INSERT ON autorizaciones_carta FOR EACH ROW
BEGIN
    DECLARE v_plato INT UNSIGNED;
    DECLARE v_inicio DATETIME(6);
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_coste DECIMAL(30,8);
    DECLARE v_precio DECIMAL(14,2);
    IF NOT EXISTS(SELECT 1 FROM usuarios u JOIN roles r ON r.id_rol=u.id_rol
                  WHERE u.id_usuario=NEW.id_emisor AND u.estado='ACTIVO' AND r.nombre='ADMINISTRADOR') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: solo puede autorizar un administrador activo';
    END IF;
    SELECT id_plato,fecha_inicio,tipo INTO v_plato,v_inicio,v_tipo
    FROM periodos_oferta WHERE id_periodo_oferta=NEW.id_periodo_oferta;
    IF v_plato IS NULL OR v_tipo<>'CARTA_PERMANENTE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: la autorizacion debe corresponder a una incorporacion a carta';
    END IF;
    IF NEW.fecha_autorizacion IS NULL OR NEW.fecha_autorizacion>v_inicio
       OR NEW.fecha_autorizacion>CURRENT_TIMESTAMP(6) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: autorizacion posterior al inicio o con fecha futura';
    END IF;
    SET v_coste=fn_coste_plato(v_plato,NEW.fecha_autorizacion);
    SELECT precio_venta INTO v_precio FROM platos WHERE id_plato=v_plato;
    IF v_coste IS NULL OR v_precio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: se necesita coste calculable y precio de venta';
    END IF;
    SET NEW.coste_evaluado=ROUND(v_coste,2);
    SET NEW.precio_venta_evaluado=v_precio;
END$$
CREATE OR REPLACE TRIGGER trg_autorizacion_bu_historico
BEFORE UPDATE ON autorizaciones_carta FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: la autorizacion y sus importes son historicos';
END$$
CREATE OR REPLACE TRIGGER trg_autorizacion_bd_historico
BEFORE DELETE ON autorizaciones_carta FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN-02: no se puede eliminar una autorizacion';
END$$
DELIMITER ;
