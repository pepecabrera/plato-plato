-- 6.7. Pruebas para la instantánea 3d25a51 de docs/entregable-final.
-- MariaDB 10.6+. Ejecutar en una copia de pruebas con 01 y 02 cargados.
-- No ejecutar dentro de una transacción de trabajo: el DDL hace COMMIT implícito.
-- No prueba rutinas/triggers de negocio: no existen en el ZIP recibido.
USE plato_plato;
SET NAMES utf8mb4;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
-- MEMORY conserva los resultados cuando se revierten las operaciones de prueba.
DROP TEMPORARY TABLE IF EXISTS pp67_resultados;
CREATE TEMPORARY TABLE pp67_resultados (
 id INT AUTO_INCREMENT PRIMARY KEY, prueba VARCHAR(180),
 resultado VARCHAR(10), detalle VARCHAR(1000)
) ENGINE=MEMORY;
DELIMITER $$
DROP PROCEDURE IF EXISTS pp67_caso$$
CREATE PROCEDURE pp67_caso(IN titulo VARCHAR(180), IN sentencia TEXT, IN error_esperado INT)
BEGIN
 DECLARE error_real INT DEFAULT 0;
 DECLARE mensaje TEXT DEFAULT '';
 DECLARE preparada BOOLEAN DEFAULT FALSE;
 SAVEPOINT caso;
 BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
   GET DIAGNOSTICS CONDITION 1 error_real = MYSQL_ERRNO, mensaje = MESSAGE_TEXT;
  END;
  SET @pp67_sql = sentencia;
  PREPARE pp67_stmt FROM @pp67_sql;
  SET preparada = TRUE;
  EXECUTE pp67_stmt;
 END;
 IF preparada THEN DEALLOCATE PREPARE pp67_stmt; END IF;
 ROLLBACK TO SAVEPOINT caso;
 RELEASE SAVEPOINT caso;
 INSERT INTO pp67_resultados(prueba,resultado,detalle)
 VALUES(titulo, IF(error_real=error_esperado,'OK','FALLO'),
 CONCAT('Error esperado: ',error_esperado,'; recibido: ',error_real,'. ',mensaje));
END$$
DROP PROCEDURE IF EXISTS pp67_comprobar$$
CREATE PROCEDURE pp67_comprobar(IN titulo VARCHAR(180), IN correcto BOOLEAN, IN detalle VARCHAR(1000))
BEGIN
 INSERT INTO pp67_resultados(prueba,resultado,detalle)
 VALUES(titulo,IF(COALESCE(correcto,FALSE),'OK','FALLO'),detalle);
END$$
DELIMITER ;
START TRANSACTION;
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
CALL pp67_caso('Permiso válido', 'INSERT INTO permisos(nombre) VALUES (''__pp67_permiso__'')', 0);
CALL pp67_caso('Rol fuera de dominio', 'INSERT INTO roles(nombre) VALUES (''INVITADO'')', 4025);
CALL pp67_caso('Permiso vacío', 'INSERT INTO permisos(nombre) VALUES (''   '')', 4025);
CALL pp67_caso('Usuario sin nombre', 'UPDATE usuarios SET nombre=NULL WHERE id_usuario=1', 1048);
CALL pp67_caso('Correo duplicado', 'UPDATE usuarios SET correo_electronico=''ana@plato-plato.example'' WHERE id_usuario=2', 1062);
CALL pp67_caso('Correo inválido', 'UPDATE usuarios SET correo_electronico=''sin_arroba'' WHERE id_usuario=1', 4025);
CALL pp67_caso('Hash demasiado corto', 'UPDATE usuarios SET contrasena_protegida=''corto'' WHERE id_usuario=1', 4025);
CALL pp67_caso('Estado inválido', 'UPDATE usuarios SET estado=''OTRO'' WHERE id_usuario=1', 4025);
CALL pp67_caso('Rol inexistente', 'UPDATE usuarios SET id_rol=4294967295 WHERE id_usuario=1', 1452);
CALL pp67_caso('Rol referenciado no se borra', 'DELETE FROM roles WHERE id_rol=1', 1451);
CALL pp67_caso('Concesión duplicada', 'INSERT INTO roles_permisos VALUES (1,1)', 1062);
CALL pp67_caso('Factor cero', 'UPDATE unidades_medida SET factor_a_base=0 WHERE codigo=''kg''', 4025);
CALL pp67_caso('Magnitud inválida', 'UPDATE unidades_medida SET magnitud=''OTRA'' WHERE codigo=''kg''', 4025);
CALL pp67_caso('Proveedor sin contacto', 'UPDATE proveedores SET telefono=NULL,correo_contacto=NULL WHERE id_proveedor=1', 4025);
CALL pp67_caso('Precio cero', 'UPDATE precios_compra SET precio_compra=0 WHERE id_precio_compra=2', 4025);
CALL pp67_caso('Fin de precio igual al inicio', 'UPDATE precios_compra SET fecha_fin_vigencia=fecha_inicio_vigencia WHERE id_precio_compra=2', 4025);
CALL pp67_caso('Dos precios seleccionados', 'UPDATE precios_compra SET seleccionado_para_costeo=1 WHERE id_precio_compra=3', 1062);
CALL pp67_caso('Rendimiento cero', 'UPDATE recetas SET cantidad_rendimiento=0 WHERE id_receta=1', 4025);
CALL pp67_caso('Precio venta cero', 'UPDATE platos SET precio_venta=0 WHERE id_plato=1', 4025);
CALL pp67_caso('Margen 100 rechazado', 'UPDATE platos SET porcentaje_margen_objetivo=100 WHERE id_plato=1', 4025);
CALL pp67_caso('Margen cero aceptado', 'UPDATE platos SET porcentaje_margen_objetivo=0 WHERE id_plato=1', 0);
CALL pp67_caso('Margen desconocido aceptado', 'UPDATE platos SET porcentaje_margen_objetivo=NULL WHERE id_plato=1', 0);
CALL pp67_caso('Cantidad componente cero', 'UPDATE componentes_receta SET cantidad=0 WHERE id_componente=1', 4025);
CALL pp67_caso('Componente sin origen', 'UPDATE componentes_receta SET id_ingrediente=NULL WHERE id_componente=1', 4025);
CALL pp67_caso('Componente con dos orígenes', 'UPDATE componentes_receta SET id_receta_componente=3 WHERE id_componente=1', 4025);
CALL pp67_caso('Ciclo directo', 'UPDATE componentes_receta SET id_receta_componente=2 WHERE id_componente=6', 4025);
CALL pp67_caso('Ingrediente repetido en receta', 'INSERT INTO componentes_receta(id_receta,cantidad,unidad_medida,id_ingrediente) VALUES (1,1,''g'',1)', 1062);
CALL pp67_caso('Lote duplicado', 'UPDATE lotes SET identificador_lote=''TOM-20261109'' WHERE id_lote=2', 1062);
CALL pp67_caso('Entrada negativa', 'UPDATE movimientos_stock SET cantidad=-1 WHERE id_movimiento=1', 4025);
CALL pp67_caso('Ajuste cero', 'UPDATE movimientos_stock SET cantidad=0 WHERE id_movimiento=21', 4025);
CALL pp67_caso('Entrada con finalidad', 'UPDATE movimientos_stock SET finalidad_salida=''OTRA'' WHERE id_movimiento=1', 4025);
CALL pp67_caso('Elaboración sin plato', 'UPDATE movimientos_stock SET id_plato_destino=NULL WHERE id_movimiento=10', 4025);
CALL pp67_caso('Merma sin movimiento', 'UPDATE mermas SET id_movimiento=NULL WHERE id_merma=1', 4025);
CALL pp67_caso('Merma con dos destinos', 'UPDATE mermas SET id_plato=1 WHERE id_merma=1', 4025);
CALL pp67_caso('Pérdida negativa', 'UPDATE mermas SET coste_perdida=-1 WHERE id_merma=1', 4025);
CALL pp67_caso('Fin de oferta igual al inicio', 'UPDATE periodos_oferta SET fecha_fin=fecha_inicio WHERE id_periodo_oferta=1', 4025);
CALL pp67_caso('Autorización con venta cero', 'UPDATE autorizaciones_carta SET precio_venta_evaluado=0 WHERE id_autorizacion=1', 4025);
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
), 'En el ZIP original FALLA: pasta y tortilla tienen periodos solapados');
CALL pp67_comprobar('RN-04: prueba previa de 14 días', NOT EXISTS (
 SELECT 1 FROM periodos_oferta c WHERE c.tipo='CARTA_PERMANENTE' AND NOT EXISTS (
 SELECT 1 FROM periodos_oferta s WHERE s.id_plato=c.id_plato AND s.tipo='SUGERENCIA_CHEF'
 AND s.fecha_inicio <= c.fecha_inicio - INTERVAL 14 DAY
 AND s.fecha_fin IS NOT NULL AND s.fecha_fin <= c.fecha_inicio
 AND s.fecha_fin >= s.fecha_inicio + INTERVAL 14 DAY)
), 'En el ZIP original FALLA: la carta comienza solo 7 días después del inicio de prueba');
CALL pp67_comprobar('Emisores administradores', NOT EXISTS (
 SELECT 1 FROM autorizaciones_carta a JOIN usuarios u ON u.id_usuario=a.id_emisor
 JOIN roles r ON r.id_rol=u.id_rol WHERE r.nombre<>'ADMINISTRADOR'
), 'Comprueba el rol actual; no demuestra autorización histórica ni bloqueo de otros roles');
ROLLBACK;
INSERT INTO pp67_resultados(prueba,resultado,detalle) VALUES
('Funciones y procedimientos 6.4','PENDIENTE','No incluidos en el ZIP; se necesitan nombres, firmas y comportamiento esperado'),
('Triggers y reglas de negocio 6.5','PENDIENTE','No incluidos: faltan pruebas de ciclos indirectos, saldos negativos, unidades, vigencias, oferta, aptitud y autorización'),
('Concurrencia','PENDIENTE','Requiere pruebas coordinadas en dos conexiones tras disponer de rutinas y bloqueos');
SELECT * FROM pp67_resultados ORDER BY id;
SELECT resultado, COUNT(*) AS total FROM pp67_resultados GROUP BY resultado;
-- Las llamadas anteriores ejecutan las pruebas. No se deja ninguna rutina auxiliar.
DROP PROCEDURE pp67_caso;
DROP PROCEDURE pp67_comprobar;
DROP TEMPORARY TABLE pp67_resultados;
SET @pp67_sql=NULL;
