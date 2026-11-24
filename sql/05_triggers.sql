-- Plato-Plató: triggers de negocio e integridad (apartado 6.5). MariaDB 10.6+.
-- Requiere 01_tablas.sql y 04_funciones_procedimientos.sql.
USE plato_plato;
SET NAMES utf8mb4;

DELIMITER $$

-- Movimientos de stock: salidas para elaboración y protección del historial

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
    IF NEW.tipo = 'SALIDA' AND NEW.finalidad_salida = 'ELABORACION' THEN
        SELECT fecha_entrada, fecha_caducidad, fresco, apto_para_consumo
        INTO v_entrada, v_caducidad, v_fresco, v_apto
        FROM lotes WHERE id_lote = NEW.id_lote;
        SELECT menu_del_dia INTO v_menu FROM platos WHERE id_plato = NEW.id_plato_destino;
        IF v_entrada IS NULL OR v_menu IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-01: lote o plato inexistente';
        END IF;
        IF NEW.fecha_movimiento < v_entrada THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La elaboracion no puede preceder a la recepcion del lote';
        END IF;
        IF v_apto = 0 OR (v_caducidad IS NOT NULL AND NEW.fecha_movimiento >= v_caducidad) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-01: no se puede elaborar con un lote caducado o no apto';
        END IF;
        -- RN-01: menos de 48 horas; este IF solo comprueba el menú del día.
        IF v_caducidad IS NOT NULL
            AND NEW.fecha_movimiento > v_caducidad - INTERVAL 48 HOUR
            AND v_menu = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-01: con menos de 48 horas restantes solo se admite menu del dia';
        END IF;

        -- RN-03 permanece dentro del bloque de salidas para elaboración.
        IF v_fresco = 1
            AND NEW.fecha_movimiento >= v_entrada + INTERVAL 72 HOUR THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-03: el lote fresco ha alcanzado las 72 horas desde su recepcion';
        END IF;
    END IF;
END$$

-- Evita eludir las comprobaciones convirtiendo una entrada en salida por UPDATE.
-- RC-09: los movimientos registrados se corrigen mediante ajustes.
CREATE OR REPLACE TRIGGER trg_movimiento_bu_historico
BEFORE UPDATE ON movimientos_stock FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimiento historico: registrar un ajuste, no modificar';
END$$

CREATE OR REPLACE TRIGGER trg_movimiento_bd_historico
BEFORE DELETE ON movimientos_stock FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimiento historico: registrar un ajuste, no eliminar';
END$$

-- Periodos de oferta: incorporación a carta, solapes e historial

-- RN-04: solo la primera incorporación requiere la prueba, en un único periodo.
-- La ausencia de solapes permite distinguir etapas reales de la oferta.
CREATE OR REPLACE TRIGGER trg_periodo_bi_negocio
BEFORE INSERT ON periodos_oferta FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM periodos_oferta p WHERE p.id_plato = NEW.id_plato
        AND (NEW.fecha_fin IS NULL OR p.fecha_inicio < NEW.fecha_fin)
        AND (p.fecha_fin IS NULL OR NEW.fecha_inicio < p.fecha_fin)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los periodos de oferta del plato no pueden solaparse';
    END IF;
    IF NEW.tipo = 'CARTA_PERMANENTE' THEN
        IF NOT EXISTS (SELECT 1 FROM periodos_oferta WHERE id_plato = NEW.id_plato
                        AND tipo = 'CARTA_PERMANENTE' AND fecha_inicio < NEW.fecha_inicio)
            AND NOT EXISTS (SELECT 1 FROM periodos_oferta WHERE id_plato = NEW.id_plato
                        AND tipo = 'SUGERENCIA_CHEF' AND fecha_fin IS NOT NULL
                        AND fecha_fin >= fecha_inicio + INTERVAL 14 DAY AND fecha_fin <= NEW.fecha_inicio) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: se requieren 14 dias consecutivos de sugerencia del chef';
        END IF;
    END IF;
END$$

-- Se permite cerrar un periodo abierto o acortarlo si no invalida una prueba.
-- No se pueden reescribir el plato, el tipo ni la fecha inicial del historial.
CREATE OR REPLACE TRIGGER trg_periodo_bu_negocio
BEFORE UPDATE ON periodos_oferta FOR EACH ROW
BEGIN
    DECLARE v_primera_carta DATETIME(6);
    IF NEW.id_periodo_oferta <> OLD.id_periodo_oferta OR NEW.id_plato <> OLD.id_plato
        OR NEW.tipo <> OLD.tipo OR NEW.fecha_inicio <> OLD.fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden reescribir los datos iniciales de un periodo';
    END IF;
    IF NOT (NEW.fecha_fin <=> OLD.fecha_fin) THEN
        IF NEW.fecha_fin IS NULL OR (OLD.fecha_fin IS NOT NULL AND NEW.fecha_fin > OLD.fecha_fin) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se permite cerrar o acortar el periodo';
        END IF;
        IF OLD.tipo = 'SUGERENCIA_CHEF' THEN
            SELECT MIN(fecha_inicio) INTO v_primera_carta FROM periodos_oferta
            WHERE id_plato = OLD.id_plato AND tipo = 'CARTA_PERMANENTE';
            IF OLD.fecha_fin <= v_primera_carta AND OLD.fecha_fin >= OLD.fecha_inicio + INTERVAL 14 DAY
                AND NEW.fecha_fin < OLD.fecha_inicio + INTERVAL 14 DAY AND NOT EXISTS (
                   SELECT 1 FROM periodos_oferta WHERE id_plato = OLD.id_plato AND tipo = 'SUGERENCIA_CHEF'
                    AND id_periodo_oferta <> OLD.id_periodo_oferta AND fecha_fin <= v_primera_carta
                    AND fecha_fin >= fecha_inicio + INTERVAL 14 DAY
               ) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: conservar una prueba valida para la primera incorporacion';
            END IF;
        END IF;
    END IF;
END$$

CREATE OR REPLACE TRIGGER trg_periodo_bd_historico
BEFORE DELETE ON periodos_oferta FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: conservar el historial de oferta';
END$$

-- Autorizaciones de carta: permiso, valoración y protección del historial

-- RN-02: exige un usuario activo con AUTORIZAR_CARTA y guarda la evaluación económica real.
-- sp_incorporar_carta se encarga de crear la autorización junto al periodo de carta.
CREATE OR REPLACE TRIGGER trg_autorizacion_bi_negocio
BEFORE INSERT ON autorizaciones_carta FOR EACH ROW
BEGIN
    DECLARE v_plato INT UNSIGNED;
    DECLARE v_inicio DATETIME(6);
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_coste DECIMAL(30, 8);
    DECLARE v_precio DECIMAL(14, 2);
    IF NOT fn_puede_autorizar_carta(NEW.id_emisor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: se requiere un usuario activo con permiso AUTORIZAR_CARTA';
    END IF;
    SELECT id_plato, fecha_inicio, tipo INTO v_plato, v_inicio, v_tipo
    FROM periodos_oferta WHERE id_periodo_oferta = NEW.id_periodo_oferta;
    IF v_plato IS NULL OR v_tipo <> 'CARTA_PERMANENTE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: la autorizacion debe corresponder a una incorporacion a carta';
    END IF;
    IF NEW.fecha_autorizacion IS NULL OR NEW.fecha_autorizacion > v_inicio
        OR NEW.fecha_autorizacion > CURRENT_TIMESTAMP(6) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: autorizacion posterior al inicio o con fecha futura';
    END IF;
    SET v_coste = fn_coste_plato(v_plato, NEW.fecha_autorizacion);
    SELECT precio_venta INTO v_precio FROM platos WHERE id_plato = v_plato;
    IF v_coste IS NULL OR v_precio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: se necesita coste calculable y precio de venta';
    END IF;
    SET NEW.coste_evaluado = ROUND(v_coste, 2);
    SET NEW.precio_venta_evaluado = v_precio;
END$$

CREATE OR REPLACE TRIGGER trg_autorizacion_bu_historico
BEFORE UPDATE ON autorizaciones_carta FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: la autorizacion y sus importes son historicos';
END$$

CREATE OR REPLACE TRIGGER trg_autorizacion_bd_historico
BEFORE DELETE ON autorizaciones_carta FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: no se puede eliminar una autorizacion';
END$$

-- Mermas: protección del historial

-- RC-09: las mermas son definitivas; en esta versión no se pueden corregir ni anular.
CREATE OR REPLACE TRIGGER trg_merma_bu_historico
BEFORE UPDATE ON mermas FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Merma definitiva: no se permite modificar';
END$$

CREATE OR REPLACE TRIGGER trg_merma_bd_historico
BEFORE DELETE ON mermas FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Merma definitiva: no se permite eliminar';
END$$

-- Precios de compra: vigencia y unidades compatibles

-- RC-04 y RC-15: el alta de precios comprueba vigencia y unidades con fn_validar_precio.
CREATE OR REPLACE TRIGGER trg_precio_bi_negocio
BEFORE INSERT ON precios_compra FOR EACH ROW
BEGIN
    DECLARE v_error VARCHAR(100);
    SET v_error = fn_validar_precio(NULL, NEW.id_proveedor, NEW.id_ingrediente, NEW.unidad_precio,
                                  NEW.fecha_inicio_vigencia, NEW.fecha_fin_vigencia);
    IF v_error IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error;
    END IF;
END$$

CREATE OR REPLACE TRIGGER trg_precio_bu_negocio
BEFORE UPDATE ON precios_compra FOR EACH ROW
BEGIN
    DECLARE v_error VARCHAR(100);
    SET v_error = fn_validar_precio(OLD.id_precio_compra, NEW.id_proveedor, NEW.id_ingrediente, NEW.unidad_precio,
                                  NEW.fecha_inicio_vigencia, NEW.fecha_fin_vigencia);
    IF v_error IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error;
    END IF;
END$$

-- Componentes de receta: alta y modificación

-- RC-12 y RC-15 (componentes). Válida la magnitud de la línea y que no se cree un ciclo.
CREATE OR REPLACE TRIGGER trg_componente_bi_negocio
BEFORE INSERT ON componentes_receta FOR EACH ROW
BEGIN
    DECLARE v_error VARCHAR(100);
    SET v_error = fn_validar_componente(NULL, NEW.id_receta, NEW.unidad_medida,
                                      NEW.id_ingrediente, NEW.id_receta_componente);
    IF v_error IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error;
    END IF;
END$$

CREATE OR REPLACE TRIGGER trg_componente_bu_negocio
BEFORE UPDATE ON componentes_receta FOR EACH ROW
BEGIN
    DECLARE v_error VARCHAR(100);
    IF NEW.id_receta <> OLD.id_receta AND NOT EXISTS (
        SELECT 1 FROM componentes_receta WHERE id_receta = OLD.id_receta AND id_componente <> OLD.id_componente
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-12: no se puede dejar una receta sin componentes';
    END IF;
    SET v_error = fn_validar_componente(OLD.id_componente, NEW.id_receta, NEW.unidad_medida,
                                      NEW.id_ingrediente, NEW.id_receta_componente);
    IF v_error IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error;
    END IF;
END$$

-- Unidades, ingredientes y recetas: protección de las medidas en uso

-- RC-15: una unidad en uso no puede cambiar de código, magnitud ni factor, porque
-- reinterpretaría cantidades y precios ya registrados.
CREATE OR REPLACE TRIGGER trg_unidad_bu_negocio
BEFORE UPDATE ON unidades_medida FOR EACH ROW
BEGIN
    IF NEW.codigo <> OLD.codigo OR NEW.magnitud <> OLD.magnitud OR NEW.factor_a_base <> OLD.factor_a_base THEN
        IF EXISTS (SELECT 1 FROM ingredientes WHERE unidad_medida = OLD.codigo)
            OR EXISTS (SELECT 1 FROM precios_compra WHERE unidad_precio = OLD.codigo)
            OR EXISTS (SELECT 1 FROM recetas WHERE unidad_rendimiento = OLD.codigo)
            OR EXISTS (SELECT 1 FROM componentes_receta WHERE unidad_medida = OLD.codigo) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-15: no se puede cambiar una unidad que esta en uso';
        END IF;
    END IF;
END$$

-- RC-15: la unidad de un ingrediente con datos relacionados no puede cambiar.
CREATE OR REPLACE TRIGGER trg_ingrediente_bu_negocio
BEFORE UPDATE ON ingredientes FOR EACH ROW
BEGIN
    IF NEW.unidad_medida <> OLD.unidad_medida THEN
        IF EXISTS (SELECT 1 FROM lotes WHERE id_ingrediente = OLD.id_ingrediente)
            OR EXISTS (SELECT 1 FROM precios_compra WHERE id_ingrediente = OLD.id_ingrediente)
            OR EXISTS (SELECT 1 FROM componentes_receta WHERE id_ingrediente = OLD.id_ingrediente) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-15: no se puede cambiar la unidad de un ingrediente en uso';
        END IF;
    END IF;
END$$

-- RC-15: el rendimiento de una subreceta en uso no puede cambiar.
CREATE OR REPLACE TRIGGER trg_receta_bu_negocio
BEFORE UPDATE ON recetas FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM platos WHERE id_receta = OLD.id_receta)
        AND NOT EXISTS (SELECT 1 FROM unidades_medida WHERE codigo = NEW.unidad_rendimiento
                    AND codigo = 'racion' AND magnitud = 'RACION' AND factor_a_base = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-15: la receta de un plato debe rendir en racion (factor 1)';
    END IF;
    IF NEW.unidad_rendimiento <> OLD.unidad_rendimiento OR NEW.cantidad_rendimiento <> OLD.cantidad_rendimiento THEN
        IF EXISTS (SELECT 1 FROM componentes_receta WHERE id_receta_componente = OLD.id_receta) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-15: no se puede cambiar el rendimiento de una subreceta en uso';
        END IF;
    END IF;
END$$

-- Mermas: coherencia con la salida de stock

-- RC-14: la FK garantiza existencia, este trigger comprueba el hecho enlazado.
-- La asociación única ya está garantizada por UNIQUE(id_movimiento).
CREATE OR REPLACE TRIGGER trg_merma_bi_coherencia
BEFORE INSERT ON mermas FOR EACH ROW
BEGIN
    IF NEW.id_lote IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM movimientos_stock m WHERE m.id_movimiento = NEW.id_movimiento
        AND m.id_lote = NEW.id_lote AND m.cantidad = NEW.cantidad_desperdiciada
        AND m.fecha_movimiento = NEW.fecha_merma AND m.tipo = 'SALIDA' AND m.finalidad_salida = 'MERMA'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-14: la merma no coincide con su salida';
    END IF;
END$$

-- Platos: rendimiento de la receta en raciones

-- RC-15: el rendimiento de la receta principal debe estar en raciones para calcular el coste por ración.
CREATE OR REPLACE TRIGGER trg_plato_bi_raciones
BEFORE INSERT ON platos FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM recetas r JOIN unidades_medida u ON u.codigo = r.unidad_rendimiento
                  WHERE r.id_receta = NEW.id_receta AND u.codigo = 'racion' AND u.magnitud = 'RACION' AND u.factor_a_base = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-15: la receta de un plato debe rendir en racion (factor 1)';
    END IF;
END$$

-- Mantiene la unidad de rendimiento exigida si cambia la receta principal del plato.
CREATE OR REPLACE TRIGGER trg_plato_bu_raciones
BEFORE UPDATE ON platos FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM recetas r JOIN unidades_medida u ON u.codigo = r.unidad_rendimiento
                  WHERE r.id_receta = NEW.id_receta AND u.codigo = 'racion' AND u.magnitud = 'RACION' AND u.factor_a_base = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-15: la receta de un plato debe rendir en racion (factor 1)';
    END IF;
END$$

-- Componentes de receta: borrado del último componente

-- No bloquea el borrado de una receta completa por CASCADE: protege recetas conservadas.
-- Alcance secuencial: no se certifica concurrencia entre conexiones.
CREATE OR REPLACE TRIGGER trg_componente_bd_minimo
BEFORE DELETE ON componentes_receta FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM componentes_receta
                  WHERE id_receta = OLD.id_receta AND id_componente <> OLD.id_componente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-12: no se puede dejar una receta sin componentes';
    END IF;
END$$

-- Lotes: protección de los datos de recepción

-- Protección mínima del lote: no reinterpreta movimientos ya registrados.
CREATE OR REPLACE TRIGGER trg_lote_bu_historico
BEFORE UPDATE ON lotes FOR EACH ROW
BEGIN
    IF (NEW.id_ingrediente <> OLD.id_ingrediente OR NEW.fecha_entrada <> OLD.fecha_entrada)
        AND EXISTS (SELECT 1 FROM movimientos_stock WHERE id_lote = OLD.id_lote) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-17: no cambiar ingrediente ni recepcion de un lote con movimientos';
    END IF;
END$$

DELIMITER ;
