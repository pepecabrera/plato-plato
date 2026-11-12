-- 6.7. Archivo autonomo: no necesita Python ni archivos auxiliares.
-- SOLO sobre una copia desechable con 01 y UNO de los poblados: 02 o 06.
-- Primera ejecucion: sin 04/05, ejecuta 66 comprobaciones del esquema.
-- Segunda ejecucion: instalar 04 y 05 completos y ejecutar de nuevo;
-- realiza 88 comprobaciones de negocio y cuatro entradas PENDIENTE.
-- Detecta el modo por la presencia de triggers. Rechaza instalaciones parciales.
-- Las pruebas de negocio CONFIRMAN escrituras: recrear la copia antes de repetirlas.
-- Si esta instalado 06, anade 12 comprobaciones de su procedimiento de movimientos.
-- No usar --force. No ejecutar dentro de una transaccion de trabajo.
USE plato_plato;
-- Auxiliares: los resultados sobreviven al ROLLBACK de cada caso.
SET NAMES utf8mb4;
SET autocommit=1;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
DROP TEMPORARY TABLE IF EXISTS pp67_resultados;
CREATE TEMPORARY TABLE pp67_resultados (
 id INT AUTO_INCREMENT PRIMARY KEY, prueba VARCHAR(180), resultado VARCHAR(10), detalle VARCHAR(1000)
) ENGINE=MEMORY;
DELIMITER $$
DROP PROCEDURE IF EXISTS pp67_comprobar$$
CREATE PROCEDURE pp67_comprobar(IN titulo VARCHAR(180), IN correcto BOOLEAN, IN detalle VARCHAR(1000))
BEGIN
 INSERT INTO pp67_resultados(prueba,resultado,detalle)
 VALUES(titulo,IF(COALESCE(correcto,FALSE),'OK','FALLO'),detalle);
END$$
-- FALSE: aislar la sentencia con una transaccion que se revierte.
-- TRUE: CALL autonomo, sin SAVEPOINT ni transaccion exterior; puede dejar cambios.
DROP PROCEDURE IF EXISTS pp67_caso$$
CREATE PROCEDURE pp67_caso(IN titulo VARCHAR(180), IN sentencia TEXT,
 IN error_esperado INT, IN prefijo VARCHAR(255), IN autonomo BOOLEAN)
BEGIN
 DECLARE error_real INT DEFAULT 0;
 DECLARE mensaje TEXT DEFAULT '';
 DECLARE preparada BOOLEAN DEFAULT FALSE;
 IF NOT autonomo THEN START TRANSACTION; END IF;
 BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
   GET DIAGNOSTICS CONDITION 1 error_real=MYSQL_ERRNO,mensaje=MESSAGE_TEXT;
  END;
  SET @pp67_sql=sentencia;
  PREPARE pp67_stmt FROM @pp67_sql;
  SET preparada=TRUE;
  EXECUTE pp67_stmt;
 END;
 IF preparada THEN DEALLOCATE PREPARE pp67_stmt; END IF;
 IF NOT autonomo THEN ROLLBACK; END IF;
 CALL pp67_comprobar(titulo,
  error_real=error_esperado AND (prefijo IS NULL OR LEFT(mensaje,CHAR_LENGTH(prefijo))=prefijo),
  CONCAT('Esperado: ',error_esperado,'; recibido: ',error_real,'; mensaje: ',mensaje));
END$$
DROP PROCEDURE IF EXISTS pp67_finalizar$$
CREATE PROCEDURE pp67_finalizar()
BEGIN
 SELECT id,prueba,resultado,detalle FROM pp67_resultados ORDER BY id;
 SELECT resultado,COUNT(*) AS total FROM pp67_resultados GROUP BY resultado;
 IF EXISTS(SELECT 1 FROM pp67_resultados WHERE resultado='FALLO') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='6.7: hay pruebas fallidas; revisar el detalle';
 END IF;
END$$
DELIMITER ;

DELIMITER $$
DROP PROCEDURE IF EXISTS pp67_ejecutar$$
CREATE PROCEDURE pp67_ejecutar()
BEGIN
 DECLARE v_triggers INT;
 DECLARE v_rutinas INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 IF @@foreign_key_checks<>1 OR @@check_constraint_checks<>1 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Activar las comprobaciones de integridad antes de ejecutar';
 END IF;
 SELECT COUNT(*) INTO v_triggers FROM information_schema.triggers
 WHERE trigger_schema=DATABASE();
 IF v_triggers=0 THEN
  SELECT 'ESQUEMA: 66 comprobaciones; no hay triggers instalados' AS bloque;
-- Esquema y datos: ejecutar SOLO con 01 y 02, sin triggers.
-- Cada sentencia negativa comprueba el código exacto, no cualquier error.
-- 4025: CHECK; 1062: duplicado; 1451/1452: integridad referencial; 1048: NOT NULL.
CALL pp67_comprobar('Carga de roles', (SELECT COUNT(*)=3 FROM roles), 'Se esperan 3 filas del poblado original');
CALL pp67_comprobar('Carga de permisos', (SELECT COUNT(*)=7 FROM permisos), 'Se esperan 7 filas del poblado original');
CALL pp67_comprobar('Carga de usuarios', (SELECT COUNT(*)=4 FROM usuarios), 'Se esperan 4 filas del poblado original');
CALL pp67_comprobar('Carga de roles_permisos', (SELECT COUNT(*)=14 FROM roles_permisos), 'Se esperan 14 filas del poblado original');
CALL pp67_comprobar('Carga de permisos_adicionales_usuario', (SELECT COUNT(*)=1 FROM permisos_adicionales_usuario), 'Se esperan 1 filas del poblado original');
CALL pp67_comprobar('Carga de unidades_medida', (SELECT COUNT(*)=6 FROM unidades_medida), 'Se esperan 6 filas del poblado original');
CALL pp67_comprobar('Carga de proveedores', (SELECT COUNT(*)=3 FROM proveedores), 'Se esperan 3 filas del poblado original');
CALL pp67_comprobar('Carga de ingredientes', (SELECT COUNT(*)=8 FROM ingredientes), 'Se esperan 8 filas del poblado original');
CALL pp67_comprobar('Carga de precios_compra', (SELECT COUNT(*)=10 FROM precios_compra), 'Se esperan 10 filas del poblado original');
CALL pp67_comprobar('Carga de recetas', (SELECT COUNT(*)=3 FROM recetas), 'Se esperan 3 filas del poblado original');
CALL pp67_comprobar('Carga de platos', (SELECT COUNT(*)=2 FROM platos), 'Se esperan 2 filas del poblado original');
CALL pp67_comprobar('Carga de componentes_receta', (SELECT COUNT(*)=11 FROM componentes_receta), 'Se esperan 11 filas del poblado original');
CALL pp67_comprobar('Carga de lotes', (SELECT COUNT(*)=8 FROM lotes), 'Se esperan 8 filas del poblado original');
CALL pp67_comprobar('Carga de movimientos_stock', (SELECT COUNT(*)=22 FROM movimientos_stock), 'Se esperan 22 filas del poblado original');
CALL pp67_comprobar('Carga de mermas', (SELECT COUNT(*)=3 FROM mermas), 'Se esperan 3 filas del poblado original');
CALL pp67_comprobar('Carga de periodos_oferta', (SELECT COUNT(*)=4 FROM periodos_oferta), 'Se esperan 4 filas del poblado original');
CALL pp67_comprobar('Carga de autorizaciones_carta', (SELECT COUNT(*)=2 FROM autorizaciones_carta), 'Se esperan 2 filas del poblado original');
CALL pp67_caso('Permiso válido', 'INSERT INTO permisos(nombre) VALUES (''__pp67_permiso__'')', 0, NULL, FALSE);
CALL pp67_caso('Rol fuera de dominio', 'INSERT INTO roles(nombre) VALUES (''INVITADO'')', 4025, NULL, FALSE);
CALL pp67_caso('Permiso vacío', 'INSERT INTO permisos(nombre) VALUES (''   '')', 4025, NULL, FALSE);
CALL pp67_caso('Usuario sin nombre', 'UPDATE usuarios SET nombre=NULL WHERE id_usuario=1', 1048, NULL, FALSE);
CALL pp67_caso('Correo duplicado', 'UPDATE usuarios SET correo_electronico=''ana@plato-plato.example'' WHERE id_usuario=2', 1062, NULL, FALSE);
CALL pp67_caso('Correo inválido', 'UPDATE usuarios SET correo_electronico=''sin_arroba'' WHERE id_usuario=1', 4025, NULL, FALSE);
CALL pp67_caso('Hash demasiado corto', 'UPDATE usuarios SET contrasena_protegida=''corto'' WHERE id_usuario=1', 4025, NULL, FALSE);
CALL pp67_caso('Estado inválido', 'UPDATE usuarios SET estado=''OTRO'' WHERE id_usuario=1', 4025, NULL, FALSE);
CALL pp67_caso('Rol inexistente', 'UPDATE usuarios SET id_rol=4294967295 WHERE id_usuario=1', 1452, NULL, FALSE);
CALL pp67_caso('Rol referenciado no se borra', 'DELETE FROM roles WHERE id_rol=1', 1451, NULL, FALSE);
CALL pp67_caso('Concesión duplicada', 'INSERT INTO roles_permisos VALUES (1,1)', 1062, NULL, FALSE);
CALL pp67_caso('Factor cero', 'UPDATE unidades_medida SET factor_a_base=0 WHERE codigo=''kg''', 4025, NULL, FALSE);
CALL pp67_caso('Magnitud inválida', 'UPDATE unidades_medida SET magnitud=''OTRA'' WHERE codigo=''kg''', 4025, NULL, FALSE);
CALL pp67_caso('Proveedor sin contacto', 'UPDATE proveedores SET telefono=NULL,correo_contacto=NULL WHERE id_proveedor=1', 4025, NULL, FALSE);
CALL pp67_caso('Precio cero', 'UPDATE precios_compra SET precio_compra=0 WHERE id_precio_compra=2', 4025, NULL, FALSE);
CALL pp67_caso('Fin de precio igual al inicio', 'UPDATE precios_compra SET fecha_fin_vigencia=fecha_inicio_vigencia WHERE id_precio_compra=2', 4025, NULL, FALSE);
CALL pp67_caso('Dos precios seleccionados', 'UPDATE precios_compra SET seleccionado_para_costeo=1 WHERE id_precio_compra=3', 1062, NULL, FALSE);
CALL pp67_caso('Rendimiento cero', 'UPDATE recetas SET cantidad_rendimiento=0 WHERE id_receta=1', 4025, NULL, FALSE);
CALL pp67_caso('Precio venta cero', 'UPDATE platos SET precio_venta=0 WHERE id_plato=1', 4025, NULL, FALSE);
CALL pp67_caso('Margen 100 rechazado', 'UPDATE platos SET porcentaje_margen_objetivo=100 WHERE id_plato=1', 4025, NULL, FALSE);
CALL pp67_caso('Margen cero aceptado', 'UPDATE platos SET porcentaje_margen_objetivo=0 WHERE id_plato=1', 0, NULL, FALSE);
CALL pp67_caso('Margen desconocido aceptado', 'UPDATE platos SET porcentaje_margen_objetivo=NULL WHERE id_plato=1', 0, NULL, FALSE);
CALL pp67_caso('Cantidad componente cero', 'UPDATE componentes_receta SET cantidad=0 WHERE id_componente=1', 4025, NULL, FALSE);
CALL pp67_caso('Componente sin origen', 'UPDATE componentes_receta SET id_ingrediente=NULL WHERE id_componente=1', 4025, NULL, FALSE);
CALL pp67_caso('Componente con dos orígenes', 'UPDATE componentes_receta SET id_receta_componente=3 WHERE id_componente=1', 4025, NULL, FALSE);
CALL pp67_caso('Ciclo directo', 'UPDATE componentes_receta SET id_receta_componente=2 WHERE id_componente=6', 4025, NULL, FALSE);
CALL pp67_caso('Ingrediente repetido en receta', 'INSERT INTO componentes_receta(id_receta,cantidad,unidad_medida,id_ingrediente) VALUES (1,1,''g'',1)', 1062, NULL, FALSE);
CALL pp67_caso('Lote duplicado', 'UPDATE lotes SET identificador_lote=''TOM-20261109'' WHERE id_lote=2', 1062, NULL, FALSE);
CALL pp67_caso('Entrada negativa', 'UPDATE movimientos_stock SET cantidad=-1 WHERE id_movimiento=1', 4025, NULL, FALSE);
CALL pp67_caso('Ajuste cero', 'UPDATE movimientos_stock SET cantidad=0 WHERE id_movimiento=21', 4025, NULL, FALSE);
CALL pp67_caso('Entrada con finalidad', 'UPDATE movimientos_stock SET finalidad_salida=''OTRA'' WHERE id_movimiento=1', 4025, NULL, FALSE);
CALL pp67_caso('Elaboración sin plato', 'UPDATE movimientos_stock SET id_plato_destino=NULL WHERE id_movimiento=10', 4025, NULL, FALSE);
CALL pp67_caso('Merma sin movimiento', 'UPDATE mermas SET id_movimiento=NULL WHERE id_merma=1', 4025, NULL, FALSE);
CALL pp67_caso('Merma con dos destinos', 'UPDATE mermas SET id_plato=1 WHERE id_merma=1', 4025, NULL, FALSE);
CALL pp67_caso('Pérdida negativa', 'UPDATE mermas SET coste_perdida=-1 WHERE id_merma=1', 4025, NULL, FALSE);
CALL pp67_caso('Fin de oferta igual al inicio', 'UPDATE periodos_oferta SET fecha_fin=fecha_inicio WHERE id_periodo_oferta=1', 4025, NULL, FALSE);
CALL pp67_caso('Autorización con venta cero', 'UPDATE autorizaciones_carta SET precio_venta_evaluado=0 WHERE id_autorizacion=1', 4025, NULL, FALSE);
CALL pp67_comprobar('Saldo lote 1', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=8.06 FROM movimientos_stock WHERE id_lote=1), 'Saldo esperado: 8.06');
CALL pp67_comprobar('Saldo lote 2', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=4.56 FROM movimientos_stock WHERE id_lote=2), 'Saldo esperado: 4.56');
CALL pp67_comprobar('Saldo lote 3', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=2.84 FROM movimientos_stock WHERE id_lote=3), 'Saldo esperado: 2.84');
CALL pp67_comprobar('Saldo lote 4', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=0.98 FROM movimientos_stock WHERE id_lote=4), 'Saldo esperado: 0.98');
CALL pp67_comprobar('Saldo lote 5', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=4.20 FROM movimientos_stock WHERE id_lote=5), 'Saldo esperado: 4.20');
CALL pp67_comprobar('Saldo lote 6', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=7.00 FROM movimientos_stock WHERE id_lote=6), 'Saldo esperado: 7.00');
CALL pp67_comprobar('Saldo lote 7', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=26 FROM movimientos_stock WHERE id_lote=7), 'Saldo esperado: 26');
CALL pp67_comprobar('Saldo lote 8', (SELECT SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END)=0 FROM movimientos_stock WHERE id_lote=8), 'Saldo esperado: 0');

-- Comprobaciones de coherencia de los datos, NO de protección mediante triggers.
CALL pp67_comprobar('Mermas enlazadas correctamente', NOT EXISTS (
 SELECT 1 FROM mermas m JOIN movimientos_stock s ON s.id_movimiento=m.id_movimiento
 WHERE m.id_lote IS NOT NULL AND (s.id_lote<>m.id_lote OR s.tipo<>'SALIDA'
 OR NOT(s.finalidad_salida <=> 'MERMA') OR s.cantidad<>m.cantidad_desperdiciada OR s.fecha_movimiento<>m.fecha_merma)
), 'Lote, finalidad, cantidad y fecha deben coincidir');
CALL pp67_comprobar('Oferta sin solapamientos', NOT EXISTS (
 SELECT 1 FROM periodos_oferta a JOIN periodos_oferta b
 ON a.id_plato=b.id_plato AND a.id_periodo_oferta<b.id_periodo_oferta
 WHERE (b.fecha_fin IS NULL OR a.fecha_inicio<b.fecha_fin)
 AND (a.fecha_fin IS NULL OR b.fecha_inicio<a.fecha_fin)
), 'Los intervalos actuales no deben solaparse');
CALL pp67_comprobar('RN-04: prueba previa de 14 días', NOT EXISTS (
 SELECT 1 FROM periodos_oferta c WHERE c.tipo='CARTA_PERMANENTE' AND NOT EXISTS (
 SELECT 1 FROM periodos_oferta s WHERE s.id_plato=c.id_plato AND s.tipo='SUGERENCIA_CHEF'
 AND s.fecha_inicio <= c.fecha_inicio - INTERVAL 14 DAY
 AND s.fecha_fin IS NOT NULL AND s.fecha_fin <= c.fecha_inicio
 AND s.fecha_fin >= s.fecha_inicio + INTERVAL 14 DAY)
), 'Se exige una prueba cerrada de al menos 14 días');
CALL pp67_comprobar('Emisores administradores', NOT EXISTS (
 SELECT 1 FROM autorizaciones_carta a JOIN usuarios u ON u.id_usuario=a.id_emisor
 JOIN roles r ON r.id_rol=u.id_rol WHERE r.nombre<>'ADMINISTRADOR'
), 'Comprueba el rol actual; no demuestra autorización histórica ni bloqueo de otros roles');

 ELSE
  IF (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema=DATABASE()
      AND trigger_name IN ('trg_movimiento_bi_negocio','trg_movimiento_bu_historico','trg_movimiento_bd_historico','trg_periodo_bi_negocio','trg_periodo_bu_negocio','trg_periodo_bd_historico','trg_autorizacion_bi_negocio','trg_autorizacion_bu_historico','trg_autorizacion_bd_historico','trg_merma_bu_historico','trg_merma_bd_historico'))<>11 THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Instalacion parcial: ejecutar 05 completo antes de las pruebas de negocio';
  END IF;
  SELECT COUNT(*) INTO v_rutinas FROM information_schema.routines
  WHERE routine_schema=DATABASE() AND routine_name IN ('fn_convertir','fn_coste_ingrediente','fn_coste_receta','fn_coste_plato','fn_margen_plato','fn_stock_lote','fn_tiene_permiso','sp_consultar_escandallo','sp_registrar_movimiento','sp_registrar_sugerencia','sp_incorporar_carta','sp_cerrar_periodo','sp_registrar_merma');
  IF v_rutinas<>13 THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltan rutinas: ejecutar 04 completo antes de las pruebas de negocio';
  END IF;
  IF EXISTS(SELECT 1 FROM recetas WHERE id_receta IN (9001,9002))
     OR EXISTS(SELECT 1 FROM platos WHERE id_plato IN (9001,9002))
     OR EXISTS(SELECT 1 FROM lotes WHERE id_lote BETWEEN 9001 AND 9005)
     OR EXISTS(SELECT 1 FROM periodos_oferta WHERE id_periodo_oferta=9002) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Hay datos de otras pruebas: preparar una copia nueva con 01 y 02';
  END IF;
  SELECT 'NEGOCIO: 88 comprobaciones y cuatro PENDIENTE' AS bloque;
-- Funciones y triggers: 01 + 02 + 04 + 05, sin transaccion exterior.
CALL pp67_comprobar('Conversion kg a g', (fn_convertir(1,'kg','g')=1000), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Conversion ml a l', (fn_convertir(250,'ml','l')=0.25), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Magnitudes incompatibles', (fn_convertir(1,'kg','l') IS NULL), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Unidad inexistente', (fn_convertir(1,'xx','kg') IS NULL), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Coste ingrediente', (ABS(fn_coste_ingrediente(1,100,'g','2026-11-10')-0.24)<0.000001), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Coste salsa', (ABS(fn_coste_receta(1,'2026-11-10')-3.488)<0.000001), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Coste pasta con subreceta', (ABS(fn_coste_plato(1,'2026-11-10')-0.7232)<0.000001), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Coste tortilla', (ABS(fn_coste_plato(2,'2026-11-10')-0.8416)<0.000001), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Margen pasta', (ABS(fn_margen_plato(1,'2026-11-10')-8.7768)<0.000001), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Plato inexistente', (fn_coste_plato(4294967295,'2026-11-10') IS NULL), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Stock historico', (fn_stock_lote(1,'2026-11-09 12:00:00')=10), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Stock final', (fn_stock_lote(1,'2026-11-11')=8.06), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Lote inexistente', (fn_stock_lote(4294967295,'2026-11-11') IS NULL), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Permiso adicional', (fn_tiene_permiso(3,'CONSULTAR_COSTES')=1), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Usuario inactivo', (fn_tiene_permiso(4,'REGISTRAR_MERMAS')=0), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Permiso ausente en encargado', (fn_tiene_permiso(2,'GESTIONAR_USUARIOS')=0), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Integracion: encargado gestiona platos', (fn_tiene_permiso(2,'GESTIONAR_PLATOS')=1), 'Resultado esperado de la regla comprobada');
-- Esta ultima comprobacion expone el permiso ausente; no se parchea el poblado.
START TRANSACTION;
UPDATE precios_compra SET seleccionado_para_costeo=0 WHERE id_ingrediente=1;
CALL pp67_comprobar('Precio ausente propaga NULL', (fn_coste_plato(1,'2026-11-10') IS NULL), 'Resultado esperado de la regla comprobada');
ROLLBACK;
START TRANSACTION;
UPDATE componentes_receta SET unidad_medida='l' WHERE id_componente=1;
CALL pp67_comprobar('Unidad incompatible propaga NULL', (fn_coste_plato(1,'2026-11-10') IS NULL), 'Resultado esperado de la regla comprobada');
ROLLBACK;
START TRANSACTION;
DELETE FROM componentes_receta WHERE id_receta=1;
CALL pp67_comprobar('Subreceta vacia propaga NULL', (fn_coste_plato(1,'2026-11-10') IS NULL), 'Resultado esperado de la regla comprobada');
ROLLBACK;
START TRANSACTION;
INSERT INTO componentes_receta(id_receta,cantidad,unidad_medida,id_receta_componente) VALUES(1,1,'racion',2);
CALL pp67_comprobar('Ciclo indirecto detectado al calcular', (fn_coste_plato(1,'2026-11-10') IS NULL), 'Resultado esperado de la regla comprobada');
ROLLBACK;
CALL pp67_caso('Historial: no modificar movimientos_stock', 'UPDATE movimientos_stock SET id_movimiento=id_movimiento WHERE id_movimiento=1', 1644, 'Movimiento historico:', FALSE);
CALL pp67_caso('Historial: no eliminar movimientos_stock', 'DELETE FROM movimientos_stock WHERE id_movimiento=1', 1644, 'Movimiento historico:', FALSE);
CALL pp67_caso('Historial: no modificar mermas', 'UPDATE mermas SET id_merma=id_merma WHERE id_merma=1', 1644, 'Merma definitiva:', FALSE);
CALL pp67_caso('Historial: no eliminar mermas', 'DELETE FROM mermas WHERE id_merma=1', 1644, 'Merma definitiva:', FALSE);
CALL pp67_caso('Historial: no modificar autorizaciones_carta', 'UPDATE autorizaciones_carta SET id_autorizacion=id_autorizacion WHERE id_autorizacion=1', 1644, 'RN-02:', FALSE);
CALL pp67_caso('Historial: no eliminar autorizaciones_carta', 'DELETE FROM autorizaciones_carta WHERE id_autorizacion=1', 1644, 'RN-02:', FALSE);
CALL pp67_caso('Oferta: no borrar historial', 'DELETE FROM periodos_oferta WHERE id_periodo_oferta=1', 1644, 'RN-04:', FALSE);
CALL pp67_caso('Oferta: no reescribir inicio', 'UPDATE periodos_oferta SET fecha_inicio=''2026-09-30'' WHERE id_periodo_oferta=1', 1644, 'No se pueden reescribir', FALSE);
CALL pp67_caso('Oferta: no invalidar prueba', 'UPDATE periodos_oferta SET fecha_fin=''2026-10-14'' WHERE id_periodo_oferta=1', 1644, 'RN-04: conservar', FALSE);
CALL pp67_caso('Oferta: no solapar', 'INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio,fecha_fin) VALUES(1,''SUGERENCIA_CHEF'',''2026-11-01'',''2026-11-02'')', 1644, 'Los periodos de oferta', FALSE);
-- Fixtures propias, persistentes solo en esta base desechable.
INSERT INTO recetas(id_receta,nombre,cantidad_rendimiento,unidad_rendimiento) VALUES
(9001,'__pp67_receta_1',1,'racion'),(9002,'__pp67_receta_2',1,'racion');
INSERT INTO componentes_receta(id_receta,cantidad,unidad_medida,id_ingrediente) VALUES
(9001,100,'g',1),(9002,100,'g',1);
INSERT INTO platos(id_plato,id_receta,nombre,descripcion,categoria,menu_del_dia,precio_venta) VALUES
(9001,9001,'__pp67_plato_1','Prueba','Prueba',0,5),
(9002,9002,'__pp67_plato_2','Prueba','Prueba',1,5);
INSERT INTO lotes(id_lote,identificador_lote,id_ingrediente,fecha_entrada,fecha_caducidad,ubicacion_almacen,fresco,apto_para_consumo) VALUES
(9001,'__pp67_caducidad',1,'2026-11-09 08:00:00','2026-11-12 08:00:00','Prueba',0,1),
(9002,'__pp67_fresco',1,'2026-11-09 08:00:00','2026-11-20 08:00:00','Prueba',1,1),
(9003,'__pp67_historico',1,'2026-11-01 08:00:00',NULL,'Prueba',0,1),
(9004,'__pp67_sin_entrada',1,'2026-11-09 08:00:00',NULL,'Prueba',0,1),
(9005,'__pp67_no_apto',1,'2026-11-09 08:00:00',NULL,'Prueba',0,0);
INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento) VALUES
(9001,'ENTRADA',10,'2026-11-09 08:00:00'),(9002,'ENTRADA',10,'2026-11-09 08:00:00'),
(9003,'ENTRADA',5,'2026-11-01 08:00:00'),(9003,'ENTRADA',10,'2026-11-03 08:00:00'),
(9005,'ENTRADA',10,'2026-11-09 08:00:00');
INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida)
VALUES(9003,'SALIDA',5,'2026-11-02 08:00:00','OTRA');
CALL pp67_caso('48h exactas: plato ordinario permitido', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9001,''SALIDA'',1,''2026-11-10 08:00:00'',''ELABORACION'',9001)', 0, NULL, FALSE);
CALL pp67_caso('Menos de 48h: ordinario rechazado', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9001,''SALIDA'',1,''2026-11-10 08:00:00.000001'',''ELABORACION'',9001)', 1644, 'RN-01: con menos', FALSE);
CALL pp67_caso('Menos de 48h: menu permitido', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9001,''SALIDA'',1,''2026-11-10 08:00:00.000001'',''ELABORACION'',9002)', 0, NULL, FALSE);
CALL pp67_caso('Caducidad exacta: rechazo', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9001,''SALIDA'',1,''2026-11-12 08:00:00'',''ELABORACION'',9002)', 1644, 'RN-01: no se puede', FALSE);
CALL pp67_caso('Antes de 72h: fresco permitido', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9002,''SALIDA'',1,''2026-11-12 07:59:59.999999'',''ELABORACION'',9001)', 0, NULL, FALSE);
CALL pp67_caso('72h exactas: fresco rechazado', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9002,''SALIDA'',1,''2026-11-12 08:00:00'',''ELABORACION'',9001)', 1644, 'RN-03:', FALSE);
CALL pp67_caso('Lote no apto: rechazo', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9005,''SALIDA'',1,''2026-11-10 08:00:00'',''ELABORACION'',9001)', 1644, 'RN-01: no se puede', FALSE);
CALL pp67_caso('Caducado: retirada por merma permitida', 'INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES(9001,''SALIDA'',1,''2026-11-13'',''MERMA'',NULL)', 0, NULL, FALSE);
CALL pp67_caso('Carta sin prueba: rechazo', 'INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio) VALUES(9002,''CARTA_PERMANENTE'',''2026-11-10'')', 1644, 'RN-04: se requieren', FALSE);
-- Las pruebas directas anteriores se revierten: no dejan salidas huerfanas.
INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio,fecha_fin)
VALUES(9002,'SUGERENCIA_CHEF','2026-10-01','2026-10-15');
CALL pp67_caso('14 dias exactos: carta permitida', 'INSERT INTO periodos_oferta(id_plato,tipo,fecha_inicio) VALUES(9002,''CARTA_PERMANENTE'',''2026-10-15'')', 0, NULL, FALSE);
INSERT INTO periodos_oferta(id_periodo_oferta,id_plato,tipo,fecha_inicio) VALUES(9002,9002,'CARTA_PERMANENTE','2026-10-15');
CALL pp67_caso('Autorizar: encargado rechazado', 'INSERT INTO autorizaciones_carta(id_periodo_oferta,id_emisor,fecha_autorizacion,coste_evaluado,precio_venta_evaluado) VALUES(9002,2,''2026-10-14'',0,1)', 1644, 'RN-02: solo puede', FALSE);
CALL pp67_caso('Autorizar: fecha posterior rechazada', 'INSERT INTO autorizaciones_carta(id_periodo_oferta,id_emisor,fecha_autorizacion,coste_evaluado,precio_venta_evaluado) VALUES(9002,1,''2026-10-16'',0,1)', 1644, 'RN-02: autorizacion posterior', FALSE);

-- Procedimientos autonomos: sin START TRANSACTION global ni SAVEPOINT.
CALL pp67_caso('Escandallo: acceso con permiso', 'CALL sp_consultar_escandallo(3,1,''2026-11-10'')', 0, NULL, TRUE);
CALL pp67_caso('Escandallo: inactivo rechazado', 'CALL sp_consultar_escandallo(4,1,''2026-11-10'')', 1644, 'Sin permiso CONSULTAR_COSTES', TRUE);
CALL pp67_caso('Escandallo: plato inexistente', 'CALL sp_consultar_escandallo(1,4294967295,''2026-11-10'')', 1644, 'Plato inexistente', TRUE);
-- Retirada temporal en esta base desechable para probar un usuario ACTIVO sin permiso.
DELETE FROM roles_permisos WHERE id_rol=3 AND id_permiso=5;
CALL pp67_caso('Merma: activo sin permiso', 'CALL sp_registrar_merma(3,9001,NULL,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'Sin permiso REGISTRAR_MERMAS', TRUE);
INSERT INTO roles_permisos(id_rol,id_permiso) VALUES(3,5);
SET @nm=(SELECT COUNT(*) FROM movimientos_stock), @nmer=(SELECT COUNT(*) FROM mermas);
CALL pp67_caso('Merma: usuario inactivo', 'CALL sp_registrar_merma(4,9001,NULL,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'Sin permiso REGISTRAR_MERMAS', TRUE);
CALL pp67_caso('Merma: dos destinos', 'CALL sp_registrar_merma(1,9001,9001,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'La merma debe afectar', TRUE);
CALL pp67_caso('Merma: ningun destino', 'CALL sp_registrar_merma(1,NULL,NULL,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'La merma debe afectar', TRUE);
CALL pp67_caso('Merma: cantidad cero', 'CALL sp_registrar_merma(1,9001,NULL,0,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'Se requieren cantidad', TRUE);
CALL pp67_caso('Merma: lote inexistente', 'CALL sp_registrar_merma(1,4294967295,NULL,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'Lote inexistente', TRUE);
CALL pp67_caso('Merma: plato inexistente', 'CALL sp_registrar_merma(1,NULL,4294967295,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'Plato inexistente', TRUE);
CALL pp67_caso('Merma: antes de recepcion', 'CALL sp_registrar_merma(1,9001,NULL,1,''2026-11-08'',''OTRO'',NULL,NULL)', 1644, 'Lote inexistente o merma anterior', TRUE);
CALL pp67_caso('Merma: sin entrada', 'CALL sp_registrar_merma(1,9004,NULL,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'La merma requiere una entrada', TRUE);
CALL pp67_caso('Merma: exceso de stock', 'CALL sp_registrar_merma(1,9001,NULL,11,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'La merma deja saldo negativo', TRUE);
CALL pp67_caso('Merma: saldo historico negativo', 'CALL sp_registrar_merma(1,9003,NULL,1,''2026-11-01 12:00:00'',''OTRO'',NULL,NULL)', 1644, 'La merma deja saldo negativo', TRUE);
CALL pp67_comprobar('Mermas rechazadas: sin escrituras', ((SELECT COUNT(*) FROM movimientos_stock)=@nm AND (SELECT COUNT(*) FROM mermas)=@nmer), 'Resultado esperado de la regla comprobada');
CALL pp67_caso('Merma: fallo tras crear salida', 'CALL sp_registrar_merma(1,9001,NULL,1,''2026-11-10'',''INVALIDO'',''__pp67_fallo'',2.4)', 4025, NULL, TRUE);
CALL pp67_comprobar('Rollback: no queda salida ni merma', ((SELECT COUNT(*) FROM movimientos_stock)=@nm AND (SELECT COUNT(*) FROM mermas)=@nmer AND fn_stock_lote(9001,'2026-11-30')=10), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Rollback: transaccion cerrada', (@@in_transaction=0), 'Resultado esperado de la regla comprobada');
CALL pp67_caso('Merma de lote: alta valida', 'CALL sp_registrar_merma(2,9001,NULL,2,''2026-11-10 09:00:00'',''DETERIORO'',''__pp67_lote'',4.8)', 0, NULL, TRUE);
CALL pp67_comprobar('Merma de lote: una salida y una merma', ((SELECT COUNT(*) FROM movimientos_stock)=@nm+1 AND (SELECT COUNT(*) FROM mermas)=@nmer+1 AND fn_stock_lote(9001,'2026-11-30')=8), 'Resultado esperado de la regla comprobada');
CALL pp67_comprobar('Merma de lote: enlace exacto', ((SELECT COUNT(*) FROM mermas m JOIN movimientos_stock s ON s.id_movimiento=m.id_movimiento WHERE m.detalle_motivo='__pp67_lote' AND s.tipo='SALIDA' AND s.finalidad_salida='MERMA' AND s.id_lote=m.id_lote AND s.cantidad=m.cantidad_desperdiciada AND s.fecha_movimiento=m.fecha_merma AND s.id_plato_destino IS NULL)=1), 'Resultado esperado de la regla comprobada');
SET @nm=(SELECT COUNT(*) FROM movimientos_stock), @nmer=(SELECT COUNT(*) FROM mermas);
CALL pp67_caso('Merma de plato: alta valida y coste desconocido', 'CALL sp_registrar_merma(2,NULL,9001,1,''2026-11-10'',''PLATO_DESECHADO'',''__pp67_plato'',NULL)', 0, NULL, TRUE);
CALL pp67_comprobar('Merma de plato: sin doble descuento', ((SELECT COUNT(*) FROM movimientos_stock)=@nm AND (SELECT COUNT(*) FROM mermas)=@nmer+1 AND (SELECT COUNT(*) FROM mermas WHERE detalle_motivo='__pp67_plato' AND id_plato=9001 AND id_lote IS NULL AND id_movimiento IS NULL AND coste_perdida IS NULL)=1), 'Resultado esperado de la regla comprobada');
CALL pp67_caso('Merma: retirada de lote caducado', 'CALL sp_registrar_merma(2,9001,NULL,1,''2026-11-13'',''CADUCIDAD'',''__pp67_caducado'',2.4)', 0, NULL, TRUE);
CALL pp67_comprobar('Merma caducada: saldo esperado', (fn_stock_lote(9001,'2026-11-30')=7), 'Resultado esperado de la regla comprobada');
START TRANSACTION;
CALL pp67_caso('Merma: rechaza transaccion del llamador', 'CALL sp_registrar_merma(1,9001,NULL,1,''2026-11-10'',''OTRO'',NULL,NULL)', 1644, 'Llamar fuera de una transaccion', TRUE);
CALL pp67_comprobar('Se conserva transaccion del llamador', (@@in_transaction=1), 'Resultado esperado de la regla comprobada');
ROLLBACK;
CALL pp67_caso('Movimiento: usuario inactivo', 'CALL sp_registrar_movimiento(4,9004,''ENTRADA'',10,''2026-11-09 08:00:00'',NULL,NULL)', 1644, 'Sin permiso GESTIONAR_STOCK', TRUE);
CALL pp67_caso('Movimiento: impide salida de merma huerfana', 'CALL sp_registrar_movimiento(1,9001,''SALIDA'',1,''2026-11-10'',''MERMA'',NULL)', 1644, 'Las mermas requieren su flujo', TRUE);
CALL pp67_caso('Movimiento: primera salida rechazada', 'CALL sp_registrar_movimiento(1,9004,''SALIDA'',1,''2026-11-10'',''OTRA'',NULL)', 1644, 'El primer movimiento', TRUE);
CALL pp67_caso('Movimiento: saldo historico negativo', 'CALL sp_registrar_movimiento(1,9003,''SALIDA'',1,''2026-11-01 12:00:00'',''OTRA'',NULL)', 1644, 'El movimiento deja saldo negativo', TRUE);
CALL pp67_caso('Movimiento: entrada valida', 'CALL sp_registrar_movimiento(2,9004,''ENTRADA'',10,''2026-11-09 08:00:00'',NULL,NULL)', 0, NULL, TRUE);
CALL pp67_caso('Movimiento: salida valida', 'CALL sp_registrar_movimiento(2,9004,''SALIDA'',1,''2026-11-10'',''OTRA'',NULL)', 0, NULL, TRUE);
CALL pp67_comprobar('Movimiento: saldo final correcto', (fn_stock_lote(9004,'2026-11-30')=9), 'Resultado esperado de la regla comprobada');
CALL pp67_caso('Sugerencia: inactivo rechazado', 'CALL sp_registrar_sugerencia(4,9001,''2026-10-01'',''2026-10-15'')', 1644, 'Sin permiso GESTIONAR_PLATOS', TRUE);
CALL pp67_caso('Sugerencia: alta por administrador', 'CALL sp_registrar_sugerencia(1,9001,CURRENT_TIMESTAMP(6)-INTERVAL 15 DAY,CURRENT_TIMESTAMP(6))', 0, NULL, TRUE);
SET @np=(SELECT COUNT(*) FROM periodos_oferta), @na=(SELECT COUNT(*) FROM autorizaciones_carta);
-- Forzar fallo de autorizacion DESPUES de crear el periodo: prueba del rollback.
UPDATE precios_compra SET seleccionado_para_costeo=0 WHERE id_precio_compra=2;
CALL pp67_caso('Carta: coste ausente rechaza autorizacion', 'CALL sp_incorporar_carta(1,9001,CURRENT_TIMESTAMP(6)+INTERVAL 1 DAY,NULL)', 1644, 'RN-02: se necesita coste calculable', TRUE);
CALL pp67_comprobar('Carta: rollback de periodo y autorizacion', ((SELECT COUNT(*) FROM periodos_oferta)=@np AND (SELECT COUNT(*) FROM autorizaciones_carta)=@na), 'Resultado esperado de la regla comprobada');
UPDATE precios_compra SET seleccionado_para_costeo=1 WHERE id_precio_compra=2;
CALL pp67_caso('Carta: encargado no puede autorizar', 'CALL sp_incorporar_carta(2,9001,CURRENT_TIMESTAMP(6)+INTERVAL 1 DAY,NULL)', 1644, 'RN-02: solo puede autorizar', TRUE);
CALL pp67_comprobar('Carta: rechazo no deja periodo', ((SELECT COUNT(*) FROM periodos_oferta)=@np AND (SELECT COUNT(*) FROM autorizaciones_carta)=@na), 'Resultado esperado de la regla comprobada');
CALL pp67_caso('Carta: incorporacion valida', 'CALL sp_incorporar_carta(1,9001,CURRENT_TIMESTAMP(6)+INTERVAL 1 DAY,NULL)', 0, NULL, TRUE);
CALL pp67_comprobar('Carta: periodo y autorizacion confirmados', ((SELECT COUNT(*) FROM periodos_oferta)=@np+1 AND (SELECT COUNT(*) FROM autorizaciones_carta)=@na+1 AND (SELECT COUNT(*) FROM autorizaciones_carta a JOIN periodos_oferta p ON p.id_periodo_oferta=a.id_periodo_oferta WHERE p.id_plato=9001 AND p.tipo='CARTA_PERMANENTE' AND a.id_emisor=1 AND a.coste_evaluado=0.24 AND a.precio_venta_evaluado=5 AND a.fecha_autorizacion<=p.fecha_inicio)=1), 'Resultado esperado de la regla comprobada');
SET @periodo=(SELECT id_periodo_oferta FROM periodos_oferta WHERE id_plato=9001 AND tipo='CARTA_PERMANENTE');
CALL pp67_caso('Cerrar periodo: cierre valido', 'CALL sp_cerrar_periodo(1,@periodo,CURRENT_TIMESTAMP(6)+INTERVAL 3 DAY)', 0, NULL, TRUE);
CALL pp67_comprobar('Cerrar periodo: fecha guardada', ((SELECT fecha_fin IS NOT NULL FROM periodos_oferta WHERE id_periodo_oferta=@periodo)), 'Resultado esperado de la regla comprobada');
CALL pp67_caso('Cerrar periodo: no prolongar', 'CALL sp_cerrar_periodo(1,@periodo,CURRENT_TIMESTAMP(6)+INTERVAL 4 DAY)', 1644, 'Solo se permite cerrar o acortar', TRUE);
INSERT INTO pp67_resultados(prueba,resultado,detalle) VALUES
('Concurrencia','PENDIENTE','Esta suite es secuencial; faltan pruebas coordinadas con varias conexiones.'),
('RC-04, RC-12 y RC-15: impedir altas invalidas','PENDIENTE','Falta proteccion completa de vigencias, ciclos indirectos y unidades. Detectar NULL al costear no demuestra impedir el alta.'),
('Privilegios de cuentas operativas','PENDIENTE','Se usa una cuenta de pruebas; no certifica las restricciones de cuentas de aplicacion.'),
('Poblado 06: cobertura adicional','PENDIENTE','Las 12 regresiones de movimientos se ejecutan si 06 esta instalado; faltan pruebas del resto de sus rutinas.');

 END IF;
 IF EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_schema=DATABASE()
           AND routine_name='pob_registrar_movimiento' AND routine_type='PROCEDURE') THEN
  IF NOT EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_schema=DATABASE()
                AND routine_name='pob_saldo_lote' AND routine_type='FUNCTION') THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Falta pob_saldo_lote: instalar 06 completo';
  END IF;
  SELECT 'POBLADO: 12 comprobaciones de saldos historicos y transacciones' AS bloque;
-- Regresion del procedimiento de poblado, sin modificar su escenario original.
-- Fixtures exclusivas de una copia de pruebas. No se eliminan mediante DELETE:
-- los movimientos son historicos y sus triggers pueden estar instalados.
IF EXISTS(SELECT 1 FROM lotes WHERE id_lote BETWEEN 9101 AND 9103) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recrear la copia de pruebas: ya existen fixtures 9101 a 9103';
END IF;
INSERT INTO lotes(id_lote,identificador_lote,id_ingrediente,fecha_entrada,fecha_caducidad,ubicacion_almacen,fresco,apto_para_consumo) VALUES
(9101,'__pp67_pob_hist',1,'2026-11-01 00:00:00',NULL,'Pruebas',0,1),
(9102,'__pp67_pob_primera',1,'2026-11-01 00:00:00',NULL,'Pruebas',0,1),
(9103,'__pp67_pob_vacio',1,'2026-11-01 00:00:00',NULL,'Pruebas',0,1);
INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento) VALUES
(9101,'ENTRADA',5,'2026-11-01 08:00:00'),
(9101,'ENTRADA',10,'2026-11-03 08:00:00'),
(9102,'ENTRADA',5,'2026-11-02 08:00:00');
INSERT INTO movimientos_stock(id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida)
VALUES(9101,'SALIDA',5,'2026-11-02 08:00:00','OTRA');
SET @pob_nmov=(SELECT COUNT(*) FROM movimientos_stock);
CALL pp67_caso('Poblado: salida retroactiva invalida', 'CALL pob_registrar_movimiento(''__pp67_pob_hist'',''SALIDA'',1,''2026-11-01 12:00:00'',''OTRA'',NULL,@pob_id)', 1644, 'pob: el movimiento dejaria saldo negativo en el historial', TRUE);
CALL pp67_caso('Poblado: ajuste retroactivo invalido', 'CALL pob_registrar_movimiento(''__pp67_pob_hist'',''AJUSTE'',-1,''2026-11-01 12:00:00'',NULL,NULL,@pob_id)', 1644, 'pob: el movimiento dejaria saldo negativo en el historial', TRUE);
CALL pp67_caso('Poblado: salida antes de primera entrada', 'CALL pob_registrar_movimiento(''__pp67_pob_primera'',''SALIDA'',1,''2026-11-01 12:00:00'',''OTRA'',NULL,@pob_id)', 1644, 'pob: no se puede anteponer', TRUE);
CALL pp67_caso('Poblado: primer movimiento debe ser entrada', 'CALL pob_registrar_movimiento(''__pp67_pob_vacio'',''SALIDA'',1,''2026-11-01 12:00:00'',''OTRA'',NULL,@pob_id)', 1644, 'pob: el primer movimiento', TRUE);
CALL pp67_comprobar('Poblado: rechazos sin filas residuales', ((SELECT COUNT(*) FROM movimientos_stock)=@pob_nmov AND pob_saldo_lote(9101)=10 AND pob_saldo_lote(9102)=5), 'RC-13/RC-17 y transaccion del llamador');
CALL pp67_caso('Poblado: salida retroactiva valida', 'CALL pob_registrar_movimiento(''__pp67_pob_hist'',''SALIDA'',1,''2026-11-03 12:00:00'',''OTRA'',NULL,@pob_id)', 0, NULL, FALSE);
CALL pp67_caso('Poblado: ajuste retroactivo valido', 'CALL pob_registrar_movimiento(''__pp67_pob_hist'',''AJUSTE'',-1,''2026-11-03 12:00:00'',NULL,NULL,@pob_id)', 0, NULL, FALSE);
CALL pp67_caso('Poblado: entrada retroactiva valida', 'CALL pob_registrar_movimiento(''__pp67_pob_hist'',''ENTRADA'',1,''2026-11-01 06:00:00'',NULL,NULL,@pob_id)', 0, NULL, FALSE);
CALL pp67_caso('Poblado: misma fecha, entrada antes de salida', 'CALL pob_registrar_movimiento(''__pp67_pob_primera'',''SALIDA'',1,''2026-11-02 08:00:00'',''OTRA'',NULL,@pob_id)', 0, NULL, FALSE);
START TRANSACTION;
CALL pp67_caso('Poblado: participa en transaccion exterior', 'CALL pob_registrar_movimiento(''__pp67_pob_hist'',''ENTRADA'',1,''2026-11-04'',NULL,NULL,@pob_id)', 0, NULL, TRUE);
CALL pp67_comprobar('Poblado: no confirma la transaccion', (@@in_transaction=1 AND pob_saldo_lote(9101)=11), 'RC-13/RC-17 y transaccion del llamador');
ROLLBACK;
CALL pp67_comprobar('Poblado: rollback exterior restaura filas', ((SELECT COUNT(*) FROM movimientos_stock)=@pob_nmov AND pob_saldo_lote(9101)=10), 'RC-13/RC-17 y transaccion del llamador');

 END IF;
END$$
DELIMITER ;
CALL pp67_ejecutar();
CALL pp67_finalizar();
DROP PROCEDURE pp67_ejecutar;
DROP PROCEDURE pp67_caso;
DROP PROCEDURE pp67_comprobar;
DROP PROCEDURE pp67_finalizar;
DROP TEMPORARY TABLE pp67_resultados;
SET @pp67_sql=NULL;
