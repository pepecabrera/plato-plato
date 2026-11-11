-- Plato-Plató: datos ficticios de demostración. MariaDB 10.6+.
-- Ejecutar UNA VEZ tras 01_tablas.sql, con todas las tablas vacías.
-- IDs explícitos para relacionar los ejemplos. No usar sobre datos existentes.
-- Fechas fijas en hora local Europe/Madrid; importes expresados en euros.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
USE plato_plato;
-- El cliente debe detenerse al primer error y hacer ROLLBACK; no usar --force.
START TRANSACTION;

INSERT INTO roles (id_rol,nombre) VALUES
(1,'ADMINISTRADOR'),(2,'ENCARGADO'),(3,'EMPLEADO');

INSERT INTO permisos (id_permiso,nombre) VALUES
(1,'GESTIONAR_USUARIOS'),(2,'GESTIONAR_PROVEEDORES'),
(3,'GESTIONAR_RECETAS'),(4,'GESTIONAR_STOCK'),(5,'REGISTRAR_MERMAS'),
(6,'CONSULTAR_COSTES'),(7,'AUTORIZAR_CARTA');

-- Hashes scrypt generados fuera de SQL; formato y credenciales en el documento.
INSERT INTO usuarios
(id_usuario,nombre,correo_electronico,contrasena_protegida,fecha_creacion,id_rol,estado) VALUES
(1,'Ana Martín','ana@plato-plato.example','scrypt$16384$8$1$6d5ca317a5b20f5036db04fe74a0b44b$2473e88ad74899f9f9416eadbbf1814085962af448af7345ca31a618bbc6df06e32d4ba296116c71a123730c06ca95dd5b1644a54c0011ee0fa90ca695bd2130','2026-09-01 09:00:00',1,'ACTIVO'),
(2,'Carlos López','carlos@plato-plato.example','scrypt$16384$8$1$3cabd10623cd2a7b7b5a9d32e10b7a22$e20233713c3044aa89afd18cf797b42e7332a3ca79b25de5e139ab3f9c82135e93063afee52dc2205d67051574dc6074a0c15e5aca6e8743da271b759bd84d1f','2026-09-01 09:00:00',2,'ACTIVO'),
(3,'Marta Sánchez','marta@plato-plato.example','scrypt$16384$8$1$5e71c14197f4d443c16b1103e36c36e0$fd0858d87254a2ac36b3b52fe54bcb0ac354ac5d6c397306e46d0bfd6fb462c48c3b9f31090d697325ebc3461e66692fc3f5dbf2218c71feec7ed8a3d29c3668','2026-09-01 09:00:00',3,'ACTIVO'),
(4,'Luis García','luis@plato-plato.example','scrypt$16384$8$1$d4e441aed4c865c692eb909616be609e$9c6608326e86dfd227607becfe41c2b1da51f4fbedfb85f270418d53ef3be318b815cb8e96d23660b29bda4ddbafee7e83651319efcd66fa9e1fbb5263130c33','2026-09-01 09:00:00',3,'INACTIVO');

INSERT INTO roles_permisos (id_rol,id_permiso) VALUES
(1,1),(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),
(2,2),(2,3),(2,4),(2,5),(2,6),(3,4),(3,5);

INSERT INTO permisos_adicionales_usuario (id_usuario,id_permiso) VALUES (3,6);

-- Bases: gramo, mililitro, unidad y ración. Solo se convierten magnitudes iguales.
INSERT INTO unidades_medida (codigo,nombre,magnitud,factor_a_base) VALUES
('g','Gramo','MASA',1),('kg','Kilogramo','MASA',1000),
('ml','Mililitro','VOLUMEN',1),('l','Litro','VOLUMEN',1000),
('ud','Unidad','UNIDAD',1),('racion','Ración','RACION',1);

INSERT INTO proveedores
(id_proveedor,nombre,persona_contacto,telefono,correo_contacto,forma_pago,estado) VALUES
(1,'Huerta del Sur','Lucía Pérez',NULL,'pedidos@huertadelsur.example','Transferencia a 30 días','ACTIVO'),
(2,'Despensa Central','Jorge Ruiz',NULL,'ventas@despensacentral.example','Transferencia a 15 días','ACTIVO'),
(3,'Distribuciones Antiguas','Pablo Gil',NULL,'contacto@distribucionesantiguas.example','Transferencia','INACTIVO');

INSERT INTO ingredientes (id_ingrediente,nombre,categoria,unidad_medida,estado) VALUES
(1,'Tomate','Hortalizas','kg','ACTIVO'),
(2,'Cebolla','Hortalizas','kg','ACTIVO'),
(3,'Aceite de oliva','Aceites','l','ACTIVO'),
(4,'Sal','Condimentos','kg','ACTIVO'),
(5,'Pasta seca','Cereales','kg','ACTIVO'),
(6,'Patata','Hortalizas','kg','ACTIVO'),
(7,'Huevo','Huevos','ud','ACTIVO'),
(8,'Perejil','Hierbas aromáticas','kg','INACTIVO');

-- Un precio seleccionado por ingrediente activo. El tomate tiene histórico y alternativa.
-- Las vigencias del mismo proveedor e ingrediente no se solapan.
INSERT INTO precios_compra
(id_precio_compra,id_proveedor,id_ingrediente,precio_compra,unidad_precio,fecha_inicio_vigencia,fecha_fin_vigencia,seleccionado_para_costeo) VALUES
(1,1,1,2.0000,'kg','2026-09-01 00:00:00','2026-10-01 00:00:00',0),
(2,1,1,2.4000,'kg','2026-10-01 00:00:00',NULL,1),
(3,2,1,2.7000,'kg','2026-10-01 00:00:00',NULL,0),
(4,1,2,1.5000,'kg','2026-10-01 00:00:00',NULL,1),
(5,2,3,6.0000,'l','2026-10-01 00:00:00',NULL,1),
(6,2,4,0.8000,'kg','2026-10-01 00:00:00',NULL,1),
(7,2,5,2.0000,'kg','2026-10-01 00:00:00',NULL,1),
(8,1,6,1.2000,'kg','2026-10-01 00:00:00',NULL,1),
(9,2,7,0.2500,'ud','2026-10-01 00:00:00',NULL,1),
(10,3,8,8.0000,'kg','2026-09-01 00:00:00','2026-10-01 00:00:00',0);

INSERT INTO recetas
(id_receta,nombre,cantidad_rendimiento,unidad_rendimiento,estado) VALUES
(1,'Salsa de tomate casera',1,'kg','ACTIVO'),
(2,'Pasta con tomate',4,'racion','ACTIVO'),
(3,'Tortilla de patatas',4,'racion','ACTIVO');

INSERT INTO platos
(id_plato,id_receta,nombre,imagen,descripcion,categoria,menu_del_dia,precio_venta,porcentaje_margen_objetivo,estado) VALUES
(1,2,'Pasta con tomate',NULL,'Pasta con salsa de tomate y cebolla casera.','Principal',1,9.50,65,'ACTIVO'),
(2,3,'Tortilla de patatas',NULL,'Tortilla de patatas con cebolla.','Entrante',0,6.00,65,'ACTIVO');

-- La salsa produce 1 kg tras la cocción. La pasta utiliza 600 g de esa subreceta.
-- No hay ciclos. g/kg y ml/l permiten probar conversiones de unidades.
INSERT INTO componentes_receta
(id_componente,id_receta,cantidad,unidad_medida,id_ingrediente,id_receta_componente) VALUES
(1,1,1200,'g',1,NULL),(2,1,200,'g',2,NULL),
(3,1,50,'ml',3,NULL),(4,1,10,'g',4,NULL),
(5,2,400,'g',5,NULL),(6,2,600,'g',NULL,1),
(7,3,800,'g',6,NULL),(8,3,6,'ud',7,NULL),
(9,3,200,'g',2,NULL),(10,3,100,'ml',3,NULL),(11,3,8,'g',4,NULL);

INSERT INTO lotes
(id_lote,identificador_lote,id_ingrediente,fecha_entrada,fecha_caducidad,ubicacion_almacen,fresco,apto_para_consumo) VALUES
(1,'TOM-20261109',1,'2026-11-09 08:00:00','2026-11-16 23:59:59','Cámara de verduras',1,1),
(2,'CEB-20261109',2,'2026-11-09 08:00:00','2026-11-30 23:59:59','Almacén de verduras',1,1),
(3,'ACE-20261109',3,'2026-11-09 08:00:00','2027-05-01 23:59:59','Almacén seco',0,1),
(4,'SAL-20261109',4,'2026-11-09 08:00:00',NULL,'Almacén seco',0,1),
(5,'PAS-20261109',5,'2026-11-09 08:00:00','2027-08-01 23:59:59','Almacén seco',0,1),
(6,'PAT-20261109',6,'2026-11-09 08:00:00','2026-12-01 23:59:59','Almacén de verduras',1,1),
(7,'HUE-20261109',7,'2026-11-09 08:00:00','2026-11-25 23:59:59','Cámara de huevos',1,1),
(8,'TOM-20261101',1,'2026-11-01 08:00:00','2026-11-08 23:59:59','Zona de retirada',0,0);

-- Cantidades en la unidad del ingrediente de cada lote.
-- Un lote caducado se retira por completo. Las salidas de cocina no superan entradas.
INSERT INTO movimientos_stock
(id_movimiento,id_lote,tipo,cantidad,fecha_movimiento,finalidad_salida,id_plato_destino) VALUES
(1,1,'ENTRADA',10,'2026-11-09 08:00:00',NULL,NULL),
(2,2,'ENTRADA',5,'2026-11-09 08:00:00',NULL,NULL),
(3,3,'ENTRADA',3,'2026-11-09 08:00:00',NULL,NULL),
(4,4,'ENTRADA',1,'2026-11-09 08:00:00',NULL,NULL),
(5,5,'ENTRADA',5,'2026-11-09 08:00:00',NULL,NULL),
(6,6,'ENTRADA',8,'2026-11-09 08:00:00',NULL,NULL),
(7,7,'ENTRADA',30,'2026-11-09 08:00:00',NULL,NULL),
(8,8,'ENTRADA',2,'2026-11-01 08:00:00',NULL,NULL),
(9,8,'SALIDA',2,'2026-11-09 09:00:00','MERMA',NULL),
-- Dos elaboraciones de pasta (8 raciones): necesitan 1,2 kg de salsa.
(10,1,'SALIDA',1.44,'2026-11-10 10:00:00','ELABORACION',1),
(11,2,'SALIDA',0.24,'2026-11-10 10:00:00','ELABORACION',1),
(12,3,'SALIDA',0.06,'2026-11-10 10:00:00','ELABORACION',1),
(13,4,'SALIDA',0.012,'2026-11-10 10:00:00','ELABORACION',1),
(14,5,'SALIDA',0.8,'2026-11-10 10:00:00','ELABORACION',1),
-- Una elaboración de tortilla (4 raciones).
(15,6,'SALIDA',0.8,'2026-11-10 10:30:00','ELABORACION',2),
(16,7,'SALIDA',6,'2026-11-10 10:30:00','ELABORACION',2),
(17,2,'SALIDA',0.2,'2026-11-10 10:30:00','ELABORACION',2),
(18,3,'SALIDA',0.1,'2026-11-10 10:30:00','ELABORACION',2),
(19,4,'SALIDA',0.008,'2026-11-10 10:30:00','ELABORACION',2),
(20,1,'SALIDA',0.5,'2026-11-10 11:00:00','MERMA',NULL),
(21,6,'AJUSTE',-0.2,'2026-11-10 12:00:00',NULL,NULL),
(22,7,'AJUSTE',2,'2026-11-10 12:00:00',NULL,NULL);

-- Las mermas de lote enlazan su salida exacta. Las de plato se miden en raciones.
-- Coste pasta: (0,8*2 + 1,2*3,488)/8 = 0,7232 €/ración.
INSERT INTO mermas
(id_merma,cantidad_desperdiciada,fecha_merma,motivo,detalle_motivo,coste_perdida,id_lote,id_plato,id_movimiento) VALUES
(1,2,'2026-11-09 09:00:00','CADUCIDAD','Retirada completa del lote caducado.',4.80,8,NULL,9),
(2,0.5,'2026-11-10 11:00:00','DETERIORO','Tomates dañados detectados al preparar.',1.20,1,NULL,20),
(3,1,'2026-11-10 15:00:00','PLATO_DESECHADO','Una ración de pasta elaborada y no servida.',0.72,NULL,1,NULL);

-- Intervalos [inicio, fin): una sugerencia termina al incorporarse a carta.
INSERT INTO periodos_oferta (id_periodo_oferta,id_plato,tipo,fecha_inicio,fecha_fin) VALUES
(1,1,'SUGERENCIA_CHEF','2026-10-01 00:00:00','2026-10-15 00:00:00'),
(2,1,'CARTA_PERMANENTE','2026-10-15 00:00:00',NULL),
(3,2,'SUGERENCIA_CHEF','2026-10-10 00:00:00','2026-10-24 00:00:00'),
(4,2,'CARTA_PERMANENTE','2026-10-24 00:00:00',NULL);

-- Autoriza el administrador tras el periodo de prueba y antes del alta en carta.
-- Costes por ración redondeados: pasta 0,72 €; tortilla 0,84 €.
INSERT INTO autorizaciones_carta
(id_autorizacion,id_periodo_oferta,id_emisor,fecha_autorizacion,coste_evaluado,precio_venta_evaluado) VALUES
(1,2,1,'2026-10-07 18:00:00',0.72,9.50),
(2,4,1,'2026-10-16 18:00:00',0.84,6.00);

COMMIT;
