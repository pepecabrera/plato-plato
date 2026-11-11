-- Plato-Plató: consultas a tablas (apartado 6.3). MariaDB 10.6+.
-- Ejecutar tras 01_tablas.sql y 02_datos.sql. Solo lee: no crea objetos ni modifica datos, y puede repetirse.
-- No depende de funciones, procedimientos ni triggers: saldos, costes y márgenes se calculan en cada consulta.
-- Cada consulta es autónoma; por eso las que recorren subrecetas repiten su expresión recursiva.
-- Un coste NULL significa «no calculable» y nunca se sustituye por cero (RC-11).
-- Los costes se redondean a 4 decimales; las valoraciones y los porcentajes, a 2.
-- Las etiquetas de los resultados van en mayúsculas y sin tilde, como los dominios del esquema.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
USE plato_plato;

-- Parámetros. @ahora es el instante en que se evalúan vigencias, saldos y plazos, en hora local (S-14).
-- Se fija en una fecha del escenario de 02_datos.sql para que los resultados sean reproducibles;
-- para consultar la situación real basta con sustituirla por NOW(6).
-- Los umbrales de los avisos toman los valores por defecto de S-08.
SET @ahora='2026-11-15 12:00:00';
SET @horas_aviso_caducidad=48;
SET @porcentaje_aviso_precio=10;

-- Acceso: cuentas, roles y permisos efectivos.
-- C-01. Cuentas de usuario con su rol y cuántos permisos reciben por el rol y cuántos a título individual (RF-01, RI-01, D-03).
-- Subconsultas escalares correlacionadas. La contraseña protegida no se consulta (RNF-02).
SELECT u.nombre AS usuario, u.correo_electronico, r.nombre AS rol, u.estado, u.fecha_creacion,
       (SELECT COUNT(*) FROM roles_permisos rp WHERE rp.id_rol=u.id_rol) AS permisos_del_rol,
       (SELECT COUNT(*) FROM permisos_adicionales_usuario pa WHERE pa.id_usuario=u.id_usuario) AS permisos_adicionales
FROM usuarios u
JOIN roles r ON r.id_rol=u.id_rol
ORDER BY FIELD(r.nombre,'ADMINISTRADOR','ENCARGADO','EMPLEADO'), u.nombre;

-- C-02. Permisos efectivos de cada usuario activo: los de su rol más los adicionales, con su origen (RC-10, D-03, RNF-01).
-- UNION ALL de las dos vías y agrupación, para que un permiso concedido por ambas aparezca una sola vez.
SELECT u.nombre AS usuario, r.nombre AS rol, p.nombre AS permiso,
       CASE WHEN MIN(c.origen)<>MAX(c.origen) THEN 'ROL Y ADICIONAL' ELSE MIN(c.origen) END AS origen
FROM (
    SELECT us.id_usuario, rp.id_permiso, 'ROL' AS origen
    FROM usuarios us
    JOIN roles_permisos rp ON rp.id_rol=us.id_rol
    UNION ALL
    SELECT pa.id_usuario, pa.id_permiso, 'ADICIONAL'
    FROM permisos_adicionales_usuario pa
) c
JOIN usuarios u ON u.id_usuario=c.id_usuario
JOIN roles r ON r.id_rol=u.id_rol
JOIN permisos p ON p.id_permiso=c.id_permiso
WHERE u.estado='ACTIVO'
GROUP BY u.id_usuario, u.nombre, r.nombre, p.id_permiso, p.nombre
ORDER BY u.nombre, p.nombre;

-- Compras: proveedores, comparación e histórico de precios.
-- C-03. Proveedores con el número de ingredientes que suministran ahora y cuántos de sus precios se usan para costear (RF-02, RI-02).
-- La vigencia se filtra en el ON del LEFT JOIN para conservar a los proveedores sin precios vigentes.
SELECT pr.nombre AS proveedor, pr.estado, pr.persona_contacto, pr.telefono, pr.correo_contacto, pr.forma_pago,
       COUNT(DISTINCT pc.id_ingrediente) AS ingredientes_con_precio_vigente,
       COALESCE(SUM(pc.seleccionado_para_costeo),0) AS precios_seleccionados
FROM proveedores pr
LEFT JOIN precios_compra pc ON pc.id_proveedor=pr.id_proveedor
    AND pc.fecha_inicio_vigencia<=@ahora AND (pc.fecha_fin_vigencia IS NULL OR pc.fecha_fin_vigencia>@ahora)
GROUP BY pr.id_proveedor, pr.nombre, pr.estado, pr.persona_contacto, pr.telefono, pr.correo_contacto, pr.forma_pago
ORDER BY pr.estado, ingredientes_con_precio_vigente DESC, pr.nombre;

-- C-04. Comparación de proveedores: precios vigentes de cada ingrediente activo, del más barato al más caro (RF-13, D-01).
-- Tabla derivada y funciones de ventana RANK y MIN. Para compararlos, cada precio se convierte a la unidad del ingrediente (RC-15).
SELECT t.ingrediente, t.proveedor, t.precio_compra, t.unidad_precio,
       ROUND(t.precio_comparable,4) AS precio_comparable, t.unidad_medida,
       RANK() OVER (PARTITION BY t.id_ingrediente ORDER BY t.precio_comparable) AS posicion,
       ROUND(100*t.precio_comparable/MIN(t.precio_comparable) OVER (PARTITION BY t.id_ingrediente)-100,2) AS sobreprecio_pct,
       t.seleccionado
FROM (
    SELECT i.id_ingrediente, i.nombre AS ingrediente, pr.nombre AS proveedor, pc.precio_compra, pc.unidad_precio, i.unidad_medida,
           pc.precio_compra*ui.factor_a_base/up.factor_a_base AS precio_comparable,
           CASE WHEN pc.seleccionado_para_costeo=1 THEN 'SI' ELSE 'NO' END AS seleccionado
    FROM precios_compra pc
    JOIN ingredientes i ON i.id_ingrediente=pc.id_ingrediente
    JOIN proveedores pr ON pr.id_proveedor=pc.id_proveedor
    JOIN unidades_medida up ON up.codigo=pc.unidad_precio
    JOIN unidades_medida ui ON ui.codigo=i.unidad_medida AND ui.magnitud=up.magnitud
    WHERE i.estado='ACTIVO' AND pr.estado='ACTIVO'
        AND pc.fecha_inicio_vigencia<=@ahora AND (pc.fecha_fin_vigencia IS NULL OR pc.fecha_fin_vigencia>@ahora)
) t
ORDER BY t.ingrediente, posicion, t.proveedor;

-- C-05. Histórico de precios de cada ingrediente y proveedor, con su situación y la variación respecto al precio anterior (RF-04, RI-04, RC-04).
-- Función de ventana LAG. La variación se calcula sobre el precio comparable, de modo que admite un cambio de unidad entre dos vigencias.
SELECT i.nombre AS ingrediente, pr.nombre AS proveedor, pc.fecha_inicio_vigencia, pc.fecha_fin_vigencia,
       CASE WHEN pc.fecha_inicio_vigencia>@ahora THEN 'FUTURO' WHEN pc.fecha_fin_vigencia<=@ahora THEN 'CERRADO' ELSE 'VIGENTE' END AS situacion,
       pc.precio_compra, pc.unidad_precio,
       ROUND(100*(pc.precio_compra*ui.factor_a_base/up.factor_a_base)/LAG(pc.precio_compra*ui.factor_a_base/up.factor_a_base) OVER w-100,2) AS variacion_pct,
       CASE WHEN pc.seleccionado_para_costeo=1 THEN 'SI' ELSE 'NO' END AS seleccionado
FROM precios_compra pc
JOIN ingredientes i ON i.id_ingrediente=pc.id_ingrediente
JOIN proveedores pr ON pr.id_proveedor=pc.id_proveedor
JOIN unidades_medida up ON up.codigo=pc.unidad_precio
LEFT JOIN unidades_medida ui ON ui.codigo=i.unidad_medida AND ui.magnitud=up.magnitud
WINDOW w AS (PARTITION BY pc.id_ingrediente,pc.id_proveedor ORDER BY pc.fecha_inicio_vigencia)
ORDER BY i.nombre, pr.nombre, pc.fecha_inicio_vigencia;

-- C-06. Avisos de sobrecoste: ingredientes cuyo precio de costeo ha subido al menos @porcentaje_aviso_precio % respecto al anterior
-- del mismo proveedor, con los platos activos afectados (RF-11, RC-06, S-08). La selección de precio no guarda histórico
-- (limitación B.2): solo puede compararse con el precio previo del proveedor seleccionado.
-- CTE recursiva «uso»: ingredientes que utiliza cada receta, directamente o a través de sus subrecetas.
-- UNION descarta las filas repetidas, por lo que la recursión termina aunque los datos contengan un ciclo.
WITH RECURSIVE uso AS (
    SELECT id_receta AS id_receta_raiz, id_ingrediente, id_receta_componente
    FROM componentes_receta
    UNION
    SELECT u.id_receta_raiz, cr.id_ingrediente, cr.id_receta_componente
    FROM uso u
    JOIN componentes_receta cr ON cr.id_receta=u.id_receta_componente
),
evolucion AS (
    SELECT pc.id_ingrediente, pc.id_proveedor, pc.seleccionado_para_costeo, pc.fecha_inicio_vigencia, pc.fecha_fin_vigencia,
           pc.precio_compra*ui.factor_a_base/up.factor_a_base AS precio,
           LAG(pc.precio_compra*ui.factor_a_base/up.factor_a_base)
               OVER (PARTITION BY pc.id_ingrediente,pc.id_proveedor ORDER BY pc.fecha_inicio_vigencia) AS precio_anterior
    FROM precios_compra pc
    JOIN ingredientes i ON i.id_ingrediente=pc.id_ingrediente
    JOIN unidades_medida up ON up.codigo=pc.unidad_precio
    JOIN unidades_medida ui ON ui.codigo=i.unidad_medida AND ui.magnitud=up.magnitud
)
SELECT i.nombre AS ingrediente, pr.nombre AS proveedor, e.fecha_inicio_vigencia AS vigente_desde,
       ROUND(e.precio_anterior,4) AS precio_anterior, ROUND(e.precio,4) AS precio_actual, i.unidad_medida,
       ROUND(100*e.precio/e.precio_anterior-100,2) AS subida_pct,
       COUNT(DISTINCT pl.id_plato) AS platos_afectados,
       GROUP_CONCAT(DISTINCT pl.nombre ORDER BY pl.nombre SEPARATOR ', ') AS platos
FROM evolucion e
JOIN ingredientes i ON i.id_ingrediente=e.id_ingrediente
JOIN proveedores pr ON pr.id_proveedor=e.id_proveedor
JOIN uso u ON u.id_ingrediente=e.id_ingrediente
JOIN platos pl ON pl.id_receta=u.id_receta_raiz AND pl.estado='ACTIVO'
WHERE e.seleccionado_para_costeo=1
    AND e.fecha_inicio_vigencia<=@ahora AND (e.fecha_fin_vigencia IS NULL OR e.fecha_fin_vigencia>@ahora)
    AND e.precio>=e.precio_anterior*(1+@porcentaje_aviso_precio/100)
GROUP BY i.id_ingrediente, i.nombre, pr.nombre, e.fecha_inicio_vigencia, e.precio_anterior, e.precio, i.unidad_medida
ORDER BY subida_pct DESC, i.nombre;

-- Recetas: composición, escandallo y rentabilidad.
-- C-07. Composición directa de cada receta: sus líneas, de ingrediente o de subreceta, y el plato al que pertenece si lo tiene (RF-06, RI-06).
-- La clave ajena exclusiva de cada línea se resuelve con dos LEFT JOIN y COALESCE.
SELECT r.nombre AS receta, p.nombre AS plato, r.cantidad_rendimiento, r.unidad_rendimiento,
       CASE WHEN cr.id_ingrediente IS NOT NULL THEN 'INGREDIENTE' ELSE 'SUBRECETA' END AS tipo_componente,
       COALESCE(i.nombre,sr.nombre) AS componente, cr.cantidad, cr.unidad_medida
FROM recetas r
JOIN componentes_receta cr ON cr.id_receta=r.id_receta
LEFT JOIN platos p ON p.id_receta=r.id_receta
LEFT JOIN ingredientes i ON i.id_ingrediente=cr.id_ingrediente
LEFT JOIN recetas sr ON sr.id_receta=cr.id_receta_componente
ORDER BY r.nombre, tipo_componente, componente;

-- C-08. Recetas que actúan como subreceta: en cuántas recetas se utilizan y si además son la receta de un plato (D-07).
SELECT sr.nombre AS subreceta, sr.estado, p.nombre AS plato_propio, COUNT(*) AS recetas_que_la_usan,
       GROUP_CONCAT(r.nombre ORDER BY r.nombre SEPARATOR ', ') AS utilizada_en
FROM componentes_receta cr
JOIN recetas sr ON sr.id_receta=cr.id_receta_componente
JOIN recetas r ON r.id_receta=cr.id_receta
LEFT JOIN platos p ON p.id_receta=sr.id_receta
GROUP BY sr.id_receta, sr.nombre, sr.estado, p.nombre
ORDER BY recetas_que_la_usan DESC, sr.nombre;

-- C-09. Escandallo detallado de cada plato: ingredientes básicos, bajando por sus subrecetas, con la cantidad y el coste por ración
-- (RF-07, RC-05, RC-15). CTE recursiva «despiece»: «veces» indica cuántas elaboraciones de cada receta hacen falta para una
-- elaboración de la receta raíz. La ruta impide volver a entrar en una receta ya recorrida, de modo que un ciclo no la hace infinita.
WITH RECURSIVE despiece AS (
    SELECT r.id_receta AS id_receta_raiz, r.id_receta, 0 AS nivel, CAST(1 AS DECIMAL(30,12)) AS veces,
           CAST(CONCAT(',',r.id_receta,',') AS CHAR(1000)) AS ruta
    FROM recetas r
    UNION ALL
    SELECT d.id_receta_raiz, sr.id_receta, d.nivel+1,
           CAST(CASE WHEN uc.magnitud=us.magnitud
                     THEN d.veces*cr.cantidad*uc.factor_a_base/(us.factor_a_base*sr.cantidad_rendimiento) END AS DECIMAL(30,12)),
           CONCAT(d.ruta,sr.id_receta,',')
    FROM despiece d
    JOIN componentes_receta cr ON cr.id_receta=d.id_receta
    JOIN recetas sr ON sr.id_receta=cr.id_receta_componente
    JOIN unidades_medida uc ON uc.codigo=cr.unidad_medida
    JOIN unidades_medida us ON us.codigo=sr.unidad_rendimiento
    WHERE LOCATE(CONCAT(',',sr.id_receta,','),d.ruta)=0
)
SELECT p.nombre AS plato, d.nivel, e.nombre AS elaboracion, i.nombre AS ingrediente,
       ROUND(d.veces*cr.cantidad/r.cantidad_rendimiento,4) AS cantidad_por_racion, cr.unidad_medida,
       pc.precio_compra, pc.unidad_precio,
       ROUND(d.veces*cr.cantidad*uc.factor_a_base*pc.precio_compra/(up.factor_a_base*r.cantidad_rendimiento),4) AS coste_por_racion
FROM despiece d
JOIN platos p ON p.id_receta=d.id_receta_raiz
JOIN recetas r ON r.id_receta=d.id_receta_raiz
JOIN recetas e ON e.id_receta=d.id_receta
JOIN componentes_receta cr ON cr.id_receta=d.id_receta
JOIN ingredientes i ON i.id_ingrediente=cr.id_ingrediente
JOIN unidades_medida uc ON uc.codigo=cr.unidad_medida
LEFT JOIN precios_compra pc ON pc.id_ingrediente=cr.id_ingrediente AND pc.seleccionado_para_costeo=1
    AND pc.fecha_inicio_vigencia<=@ahora AND (pc.fecha_fin_vigencia IS NULL OR pc.fecha_fin_vigencia>@ahora)
LEFT JOIN unidades_medida up ON up.codigo=pc.unidad_precio AND up.magnitud=uc.magnitud
ORDER BY p.nombre, d.nivel, e.nombre, i.nombre;

-- C-10. Coste de cada receta y rentabilidad de las que son plato: coste de elaboración, coste unitario (en un plato, su coste de
-- producción), margen bruto, porcentaje de margen y cumplimiento del objetivo (RF-07, RF-08, RC-05 a RC-08, RC-11, D-02, D-06).
-- Misma CTE «despiece» que en C-09. El coste queda en NULL si falta un precio seleccionado y vigente, hay unidades de distinta
-- magnitud, una receta no tiene componentes o existe un ciclo: una línea sin coste anula el total en lugar de sumar cero.
WITH RECURSIVE despiece AS (
    SELECT r.id_receta AS id_receta_raiz, r.id_receta, 0 AS nivel, CAST(1 AS DECIMAL(30,12)) AS veces,
           CAST(CONCAT(',',r.id_receta,',') AS CHAR(1000)) AS ruta
    FROM recetas r
    UNION ALL
    SELECT d.id_receta_raiz, sr.id_receta, d.nivel+1,
           CAST(CASE WHEN uc.magnitud=us.magnitud
                     THEN d.veces*cr.cantidad*uc.factor_a_base/(us.factor_a_base*sr.cantidad_rendimiento) END AS DECIMAL(30,12)),
           CONCAT(d.ruta,sr.id_receta,',')
    FROM despiece d
    JOIN componentes_receta cr ON cr.id_receta=d.id_receta
    JOIN recetas sr ON sr.id_receta=cr.id_receta_componente
    JOIN unidades_medida uc ON uc.codigo=cr.unidad_medida
    JOIN unidades_medida us ON us.codigo=sr.unidad_rendimiento
    WHERE LOCATE(CONCAT(',',sr.id_receta,','),d.ruta)=0
),
lineas AS (
    -- Una fila por línea de cada receta recorrida. La línea de subreceta vale 0 porque su coste lo aportan las líneas de esa subreceta.
    SELECT d.id_receta_raiz,
           CASE WHEN cr.id_ingrediente IS NOT NULL THEN d.veces*cr.cantidad*uc.factor_a_base*pc.precio_compra/up.factor_a_base
                WHEN LOCATE(CONCAT(',',cr.id_receta_componente,','),d.ruta)=0 THEN 0
           END AS coste
    FROM despiece d
    LEFT JOIN componentes_receta cr ON cr.id_receta=d.id_receta
    LEFT JOIN unidades_medida uc ON uc.codigo=cr.unidad_medida
    LEFT JOIN precios_compra pc ON pc.id_ingrediente=cr.id_ingrediente AND pc.seleccionado_para_costeo=1
        AND pc.fecha_inicio_vigencia<=@ahora AND (pc.fecha_fin_vigencia IS NULL OR pc.fecha_fin_vigencia>@ahora)
    LEFT JOIN unidades_medida up ON up.codigo=pc.unidad_precio AND up.magnitud=uc.magnitud
),
costes AS (
    SELECT r.id_receta,
           CASE WHEN COUNT(*)=COUNT(l.coste) THEN ROUND(SUM(l.coste),4) END AS coste_elaboracion,
           CASE WHEN COUNT(*)=COUNT(l.coste) THEN ROUND(SUM(l.coste)/r.cantidad_rendimiento,4) END AS coste_unitario
    FROM recetas r
    JOIN lineas l ON l.id_receta_raiz=r.id_receta
    GROUP BY r.id_receta, r.cantidad_rendimiento
)
SELECT r.nombre AS receta, r.cantidad_rendimiento, r.unidad_rendimiento, c.coste_elaboracion, c.coste_unitario,
       p.nombre AS plato, p.precio_venta,
       p.precio_venta-c.coste_unitario AS margen_bruto,
       ROUND(100*(p.precio_venta-c.coste_unitario)/p.precio_venta,2) AS porcentaje_margen,
       p.porcentaje_margen_objetivo,
       CASE (c.coste_unitario<=p.precio_venta*(1-p.porcentaje_margen_objetivo/100)) WHEN 1 THEN 'SI' WHEN 0 THEN 'NO' END AS cumple_objetivo
FROM recetas r
JOIN costes c ON c.id_receta=r.id_receta
LEFT JOIN platos p ON p.id_receta=r.id_receta
ORDER BY p.id_plato IS NULL, r.nombre;

-- C-11. Ingredientes que impiden costear platos, con el motivo y los platos afectados (RC-11, D-01, S-12).
-- EXISTS y NOT EXISTS correlacionados. La CTE «uso» alcanza también los ingredientes de las subrecetas.
WITH RECURSIVE uso AS (
    SELECT id_receta AS id_receta_raiz, id_ingrediente, id_receta_componente
    FROM componentes_receta
    UNION
    SELECT u.id_receta_raiz, cr.id_ingrediente, cr.id_receta_componente
    FROM uso u
    JOIN componentes_receta cr ON cr.id_receta=u.id_receta_componente
)
SELECT i.nombre AS ingrediente,
       CASE WHEN NOT EXISTS (SELECT 1 FROM precios_compra v WHERE v.id_ingrediente=i.id_ingrediente
                AND v.fecha_inicio_vigencia<=@ahora AND (v.fecha_fin_vigencia IS NULL OR v.fecha_fin_vigencia>@ahora))
            THEN 'SIN PRECIO VIGENTE'
            WHEN EXISTS (SELECT 1 FROM precios_compra s WHERE s.id_ingrediente=i.id_ingrediente AND s.seleccionado_para_costeo=1)
            THEN 'PRECIO SELECCIONADO NO VIGENTE'
            ELSE 'SIN PRECIO SELECCIONADO' END AS motivo,
       COUNT(DISTINCT p.id_plato) AS platos_sin_coste,
       GROUP_CONCAT(DISTINCT p.nombre ORDER BY p.nombre SEPARATOR ', ') AS platos
FROM ingredientes i
JOIN uso u ON u.id_ingrediente=i.id_ingrediente
JOIN platos p ON p.id_receta=u.id_receta_raiz
WHERE NOT EXISTS (SELECT 1 FROM precios_compra pc WHERE pc.id_ingrediente=i.id_ingrediente AND pc.seleccionado_para_costeo=1
        AND pc.fecha_inicio_vigencia<=@ahora AND (pc.fecha_fin_vigencia IS NULL OR pc.fecha_fin_vigencia>@ahora))
GROUP BY i.id_ingrediente, i.nombre
ORDER BY platos_sin_coste DESC, i.nombre;

-- Inventario: saldos, existencias, movimientos y avisos.
-- C-12. Saldo de cada lote con existencias: entradas menos salidas más ajustes con su signo (RI-07, RF-03, RC-13).
-- Agregación condicional con GROUP BY y HAVING. Se ordena para consumir antes lo que antes caduca.
SELECT l.identificador_lote, i.nombre AS ingrediente, l.ubicacion_almacen, l.fecha_entrada, l.fecha_caducidad, l.fresco, l.apto_para_consumo,
       SUM(CASE WHEN m.tipo='SALIDA' THEN -m.cantidad ELSE m.cantidad END) AS saldo, i.unidad_medida
FROM lotes l
JOIN ingredientes i ON i.id_ingrediente=l.id_ingrediente
JOIN movimientos_stock m ON m.id_lote=l.id_lote
WHERE m.fecha_movimiento<=@ahora
GROUP BY l.id_lote, l.identificador_lote, i.nombre, l.ubicacion_almacen, l.fecha_entrada, l.fecha_caducidad, l.fresco, l.apto_para_consumo, i.unidad_medida
HAVING saldo>0
ORDER BY i.nombre, l.fecha_caducidad IS NULL, l.fecha_caducidad, l.fecha_entrada;

-- C-13. Existencias de cada ingrediente activo: cantidad total disponible, lotes con existencias y la caducidad más temprana
-- entre ellos (RI-03, RF-03). LEFT JOIN con una tabla derivada, para incluir también los ingredientes sin existencias.
SELECT i.nombre AS ingrediente, i.categoria,
       COALESCE(SUM(s.saldo),0) AS cantidad_total_disponible, i.unidad_medida,
       COUNT(CASE WHEN s.saldo>0 THEN 1 END) AS lotes_con_existencias,
       MIN(CASE WHEN s.saldo>0 THEN s.fecha_caducidad END) AS primera_caducidad
FROM ingredientes i
LEFT JOIN (
    SELECT l.id_lote, l.id_ingrediente, l.fecha_caducidad,
           SUM(CASE WHEN m.tipo='SALIDA' THEN -m.cantidad ELSE m.cantidad END) AS saldo
    FROM lotes l
    JOIN movimientos_stock m ON m.id_lote=l.id_lote
    WHERE m.fecha_movimiento<=@ahora
    GROUP BY l.id_lote, l.id_ingrediente, l.fecha_caducidad
) s ON s.id_ingrediente=i.id_ingrediente
WHERE i.estado='ACTIVO'
GROUP BY i.id_ingrediente, i.nombre, i.categoria, i.unidad_medida
ORDER BY i.categoria, i.nombre;

-- C-14. Extracto de movimientos de cada lote con el saldo tras cada uno (RF-09, RI-08, RC-13, RC-17).
-- Suma acumulada con función de ventana, en el orden del índice ix_mov_lote_fecha.
SELECT l.identificador_lote, i.nombre AS ingrediente, m.fecha_movimiento, m.tipo, m.finalidad_salida, p.nombre AS plato_destino,
       CASE WHEN m.tipo='SALIDA' THEN -m.cantidad ELSE m.cantidad END AS variacion,
       SUM(CASE WHEN m.tipo='SALIDA' THEN -m.cantidad ELSE m.cantidad END)
           OVER (PARTITION BY m.id_lote ORDER BY m.fecha_movimiento,m.id_movimiento ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo,
       i.unidad_medida
FROM movimientos_stock m
JOIN lotes l ON l.id_lote=m.id_lote
JOIN ingredientes i ON i.id_ingrediente=l.id_ingrediente
LEFT JOIN platos p ON p.id_plato=m.id_plato_destino
ORDER BY l.identificador_lote, m.fecha_movimiento, m.id_movimiento;

-- C-15. Avisos de caducidad: lotes con existencias a los que les quedan menos de @horas_aviso_caducidad horas, a qué pueden destinarse
-- y qué platos del menú del día utilizan su ingrediente (RF-12, RN-01, RN-03, S-08).
WITH RECURSIVE uso AS (
    SELECT id_receta AS id_receta_raiz, id_ingrediente, id_receta_componente
    FROM componentes_receta
    UNION
    SELECT u.id_receta_raiz, cr.id_ingrediente, cr.id_receta_componente
    FROM uso u
    JOIN componentes_receta cr ON cr.id_receta=u.id_receta_componente
),
saldos AS (
    SELECT id_lote, SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END) AS saldo
    FROM movimientos_stock
    WHERE fecha_movimiento<=@ahora
    GROUP BY id_lote
)
SELECT l.identificador_lote, i.nombre AS ingrediente, l.ubicacion_almacen, s.saldo, i.unidad_medida, l.fecha_caducidad,
       ROUND(TIMESTAMPDIFF(MINUTE,@ahora,l.fecha_caducidad)/60,1) AS horas_restantes,
       CASE WHEN l.apto_para_consumo=0 OR (l.fresco=1 AND l.fecha_entrada+INTERVAL 72 HOUR<=@ahora) THEN 'NINGUNO'
            WHEN l.fecha_caducidad<@ahora+INTERVAL 48 HOUR THEN 'SOLO MENU DEL DIA'
            ELSE 'CUALQUIER PLATO' END AS destino_permitido,
       GROUP_CONCAT(DISTINCT p.nombre ORDER BY p.nombre SEPARATOR ', ') AS platos_menu_del_dia
FROM lotes l
JOIN ingredientes i ON i.id_ingrediente=l.id_ingrediente
JOIN saldos s ON s.id_lote=l.id_lote AND s.saldo>0
LEFT JOIN uso u ON u.id_ingrediente=l.id_ingrediente
    AND l.apto_para_consumo=1 AND (l.fresco=0 OR l.fecha_entrada+INTERVAL 72 HOUR>@ahora)
LEFT JOIN platos p ON p.id_receta=u.id_receta_raiz AND p.menu_del_dia=1 AND p.estado='ACTIVO'
WHERE l.fecha_caducidad>@ahora AND l.fecha_caducidad<@ahora+INTERVAL @horas_aviso_caducidad HOUR
GROUP BY l.id_lote, l.identificador_lote, i.nombre, l.ubicacion_almacen, s.saldo, i.unidad_medida, l.fecha_caducidad,
         l.apto_para_consumo, l.fresco, l.fecha_entrada
ORDER BY l.fecha_caducidad, l.identificador_lote;

-- C-16. Existencias que ya no pueden destinarse a elaborar platos y su valor al precio de costeo: lotes no aptos, caducados o
-- frescos con 72 horas o más desde su recepción (RN-01, RN-03, D-04, S-05). Son candidatas a registrarse como merma.
SELECT l.identificador_lote, i.nombre AS ingrediente, l.ubicacion_almacen,
       CASE WHEN l.apto_para_consumo=0 THEN 'NO APTO' WHEN l.fecha_caducidad<=@ahora THEN 'CADUCADO' ELSE 'FRESCO FUERA DE PLAZO' END AS motivo,
       s.saldo, i.unidad_medida,
       ROUND(s.saldo*ui.factor_a_base*pc.precio_compra/up.factor_a_base,2) AS valor_estimado
FROM lotes l
JOIN ingredientes i ON i.id_ingrediente=l.id_ingrediente
JOIN unidades_medida ui ON ui.codigo=i.unidad_medida
JOIN (
    SELECT id_lote, SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END) AS saldo
    FROM movimientos_stock
    WHERE fecha_movimiento<=@ahora
    GROUP BY id_lote
) s ON s.id_lote=l.id_lote AND s.saldo>0
LEFT JOIN precios_compra pc ON pc.id_ingrediente=l.id_ingrediente AND pc.seleccionado_para_costeo=1
    AND pc.fecha_inicio_vigencia<=@ahora AND (pc.fecha_fin_vigencia IS NULL OR pc.fecha_fin_vigencia>@ahora)
LEFT JOIN unidades_medida up ON up.codigo=pc.unidad_precio AND up.magnitud=ui.magnitud
WHERE l.apto_para_consumo=0 OR l.fecha_caducidad<=@ahora OR (l.fresco=1 AND l.fecha_entrada+INTERVAL 72 HOUR<=@ahora)
ORDER BY valor_estimado DESC, l.identificador_lote;

-- Mermas: detalle y análisis de las pérdidas.
-- C-17. Detalle de las mermas con el elemento afectado, sea un lote o un plato (RF-10, RI-09, RC-14).
SELECT me.fecha_merma, CASE WHEN me.id_lote IS NOT NULL THEN 'LOTE' ELSE 'PLATO' END AS elemento,
       COALESCE(CONCAT(i.nombre,' (',l.identificador_lote,')'),p.nombre) AS afectado,
       me.cantidad_desperdiciada, COALESCE(i.unidad_medida,r.unidad_rendimiento) AS unidad,
       me.motivo, me.detalle_motivo, me.coste_perdida
FROM mermas me
LEFT JOIN lotes l ON l.id_lote=me.id_lote
LEFT JOIN ingredientes i ON i.id_ingrediente=l.id_ingrediente
LEFT JOIN platos p ON p.id_plato=me.id_plato
LEFT JOIN recetas r ON r.id_receta=p.id_receta
ORDER BY me.fecha_merma DESC, me.id_merma DESC;

-- C-18. Pérdidas por motivo: mermas de lote y de plato, cuántas están sin valorar y su peso en el coste conocido (RF-10, RI-09).
-- El coste desconocido no se cuenta como cero. Subconsulta escalar para el total.
SELECT me.motivo, COUNT(*) AS mermas, COUNT(me.id_lote) AS de_lote, COUNT(me.id_plato) AS de_plato,
       COUNT(*)-COUNT(me.coste_perdida) AS sin_valorar,
       SUM(me.coste_perdida) AS coste_conocido,
       ROUND(100*SUM(me.coste_perdida)/(SELECT NULLIF(SUM(coste_perdida),0) FROM mermas),2) AS porcentaje_del_coste
FROM mermas me
GROUP BY me.motivo
ORDER BY coste_conocido DESC, me.motivo;

-- C-19. Evolución mensual de las pérdidas, separando las de lotes y las de platos, con una fila de total (RF-10).
-- GROUP BY con WITH ROLLUP, que no admite ORDER BY: los meses salen en orden ascendente y el total, al final.
SELECT COALESCE(t.mes,'TOTAL') AS mes, COUNT(*) AS mermas,
       SUM(CASE WHEN t.id_lote IS NOT NULL THEN t.coste_perdida END) AS coste_lotes,
       SUM(CASE WHEN t.id_plato IS NOT NULL THEN t.coste_perdida END) AS coste_platos,
       SUM(t.coste_perdida) AS coste_conocido
FROM (
    SELECT DATE_FORMAT(fecha_merma,'%Y-%m') AS mes, id_lote, id_plato, coste_perdida
    FROM mermas
) t
GROUP BY t.mes WITH ROLLUP;

-- C-20. Ingredientes con más pérdida: cantidad desperdiciada, porcentaje sobre lo recibido en sus lotes y coste (RF-10, RG-02).
SELECT i.nombre AS ingrediente, COUNT(*) AS mermas, SUM(me.cantidad_desperdiciada) AS cantidad_desperdiciada, i.unidad_medida,
       ROUND(100*SUM(me.cantidad_desperdiciada)/e.cantidad_recibida,2) AS porcentaje_sobre_recibido,
       SUM(me.coste_perdida) AS coste_conocido
FROM mermas me
JOIN lotes l ON l.id_lote=me.id_lote
JOIN ingredientes i ON i.id_ingrediente=l.id_ingrediente
LEFT JOIN (
    SELECT lo.id_ingrediente, SUM(mo.cantidad) AS cantidad_recibida
    FROM movimientos_stock mo
    JOIN lotes lo ON lo.id_lote=mo.id_lote
    WHERE mo.tipo='ENTRADA'
    GROUP BY lo.id_ingrediente
) e ON e.id_ingrediente=i.id_ingrediente
GROUP BY i.id_ingrediente, i.nombre, i.unidad_medida, e.cantidad_recibida
ORDER BY coste_conocido DESC, cantidad_desperdiciada DESC, i.nombre
LIMIT 10;

-- Oferta: periodos y autorizaciones.
-- C-21. Historial de oferta de cada plato: periodos, situación, días ofrecido y, en la carta permanente, la autorización con el
-- margen que se evaluó (RI-10, RN-02, RC-09, RC-16). El periodo incluye su inicio y excluye su fin.
SELECT p.nombre AS plato, po.tipo, po.fecha_inicio, po.fecha_fin,
       CASE WHEN po.fecha_inicio>@ahora THEN 'FUTURO' WHEN po.fecha_fin<=@ahora THEN 'FINALIZADO' ELSE 'VIGENTE' END AS situacion,
       GREATEST(TIMESTAMPDIFF(DAY,po.fecha_inicio,CASE WHEN po.fecha_fin<=@ahora THEN po.fecha_fin ELSE @ahora END),0) AS dias_ofrecido,
       u.nombre AS autorizado_por, a.fecha_autorizacion, a.coste_evaluado, a.precio_venta_evaluado,
       ROUND(100*(a.precio_venta_evaluado-a.coste_evaluado)/a.precio_venta_evaluado,2) AS porcentaje_margen_evaluado
FROM periodos_oferta po
JOIN platos p ON p.id_plato=po.id_plato
LEFT JOIN autorizaciones_carta a ON a.id_periodo_oferta=po.id_periodo_oferta
LEFT JOIN usuarios u ON u.id_usuario=a.id_emisor
ORDER BY p.nombre, po.fecha_inicio;

-- C-22. Platos que ya pueden proponerse para la carta permanente: activos, con precio de venta, que nunca han estado en ella y han
-- completado una prueba cerrada de al menos 14 días como sugerencia del chef (RN-02, RN-04, D-05). NOT EXISTS correlacionado.
-- Antes de autorizar hay que comprobar en C-10 que su coste es calculable.
SELECT p.nombre AS plato, p.categoria, p.precio_venta,
       MAX(po.fecha_fin) AS fin_de_la_prueba,
       MAX(TIMESTAMPDIFF(DAY,po.fecha_inicio,po.fecha_fin)) AS dias_de_prueba
FROM platos p
JOIN periodos_oferta po ON po.id_plato=p.id_plato AND po.tipo='SUGERENCIA_CHEF'
    AND po.fecha_fin<=@ahora AND po.fecha_fin>=po.fecha_inicio+INTERVAL 14 DAY
WHERE p.estado='ACTIVO' AND p.precio_venta IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM periodos_oferta c WHERE c.id_plato=p.id_plato AND c.tipo='CARTA_PERMANENTE')
GROUP BY p.id_plato, p.nombre, p.categoria, p.precio_venta
ORDER BY fin_de_la_prueba, p.nombre;

-- Control: reglas que las claves y los CHECK no garantizan. Los datos de 02_datos.sql se insertan antes de que existan los
-- triggers, de modo que estas consultas comprueban que los cumplen. Cada una debe devolver cero filas.
-- C-23. Multiplicidades mínimas que MariaDB no puede declarar (5.1.5): recetas sin componentes y periodos de carta permanente
-- sin autorización (RN-02). Antijoin: LEFT JOIN y filtro IS NULL.
SELECT 'Receta sin componentes' AS incidencia, r.nombre AS elemento, NULL AS desde
FROM recetas r
LEFT JOIN componentes_receta cr ON cr.id_receta=r.id_receta
WHERE cr.id_componente IS NULL
UNION ALL
SELECT 'Carta permanente sin autorización', p.nombre, po.fecha_inicio
FROM periodos_oferta po
JOIN platos p ON p.id_plato=po.id_plato
LEFT JOIN autorizaciones_carta a ON a.id_periodo_oferta=po.id_periodo_oferta
WHERE po.tipo='CARTA_PERMANENTE' AND a.id_autorizacion IS NULL
ORDER BY incidencia, elemento;

-- C-24. Intervalos solapados: precios de un mismo proveedor e ingrediente (RC-04) y periodos de oferta de un mismo plato (RC-16).
-- Autocombinación: si b empieza después que a, se solapan cuando b empieza antes de que a termine; sin fecha de fin, a sigue abierto.
SELECT 'RC-04' AS regla, CONCAT(pr.nombre,' / ',i.nombre) AS elemento,
       a.fecha_inicio_vigencia AS inicio_a, a.fecha_fin_vigencia AS fin_a, b.fecha_inicio_vigencia AS inicio_b, b.fecha_fin_vigencia AS fin_b
FROM precios_compra a
JOIN precios_compra b ON b.id_proveedor=a.id_proveedor AND b.id_ingrediente=a.id_ingrediente
    AND b.fecha_inicio_vigencia>a.fecha_inicio_vigencia
    AND (a.fecha_fin_vigencia IS NULL OR b.fecha_inicio_vigencia<a.fecha_fin_vigencia)
JOIN proveedores pr ON pr.id_proveedor=a.id_proveedor
JOIN ingredientes i ON i.id_ingrediente=a.id_ingrediente
UNION ALL
SELECT 'RC-16', p.nombre, a.fecha_inicio, a.fecha_fin, b.fecha_inicio, b.fecha_fin
FROM periodos_oferta a
JOIN periodos_oferta b ON b.id_plato=a.id_plato
    AND b.fecha_inicio>a.fecha_inicio
    AND (a.fecha_fin IS NULL OR b.fecha_inicio<a.fecha_fin)
JOIN platos p ON p.id_plato=a.id_plato
ORDER BY regla, elemento, inicio_a;

-- C-25. Recetas que se contienen a sí mismas a través de una cadena de subrecetas (RC-12).
-- Cierre transitivo con CTE recursiva; UNION descarta las parejas repetidas y garantiza que termina.
WITH RECURSIVE contiene AS (
    SELECT id_receta, id_receta_componente AS id_subreceta
    FROM componentes_receta
    WHERE id_receta_componente IS NOT NULL
    UNION
    SELECT c.id_receta, cr.id_receta_componente
    FROM contiene c
    JOIN componentes_receta cr ON cr.id_receta=c.id_subreceta
    WHERE cr.id_receta_componente IS NOT NULL
)
SELECT r.nombre AS receta_ciclica
FROM contiene c
JOIN recetas r ON r.id_receta=c.id_receta
WHERE c.id_subreceta=c.id_receta
ORDER BY r.nombre;

-- C-26. Coherencia del inventario: lotes cuyo saldo ha sido negativo en algún instante (RC-13), mermas de lote que no coinciden
-- con la salida que originaron y salidas por merma sin merma asociada (RC-14).
-- La ventana ordena solo por fecha: los movimientos simultáneos comparten saldo y UNION los reduce a una fila.
SELECT 'RC-13' AS regla, l.identificador_lote, s.fecha_movimiento AS fecha, CONCAT('Saldo negativo: ',s.saldo) AS detalle
FROM (
    SELECT id_lote, fecha_movimiento,
           SUM(CASE WHEN tipo='SALIDA' THEN -cantidad ELSE cantidad END) OVER (PARTITION BY id_lote ORDER BY fecha_movimiento) AS saldo
    FROM movimientos_stock
) s
JOIN lotes l ON l.id_lote=s.id_lote
WHERE s.saldo<0
UNION
SELECT 'RC-14', l.identificador_lote, me.fecha_merma, 'La merma no coincide con su salida'
FROM mermas me
JOIN lotes l ON l.id_lote=me.id_lote
JOIN movimientos_stock m ON m.id_movimiento=me.id_movimiento
WHERE m.id_lote<>me.id_lote OR m.cantidad<>me.cantidad_desperdiciada OR m.fecha_movimiento<>me.fecha_merma
    OR m.tipo<>'SALIDA' OR NOT (m.finalidad_salida<=>'MERMA')
UNION
SELECT 'RC-14', l.identificador_lote, m.fecha_movimiento, 'Salida por merma sin merma asociada'
FROM movimientos_stock m
JOIN lotes l ON l.id_lote=m.id_lote
LEFT JOIN mermas me ON me.id_movimiento=m.id_movimiento
WHERE m.finalidad_salida='MERMA' AND me.id_merma IS NULL
ORDER BY regla, identificador_lote, fecha;

-- C-27. Hechos registrados que contradicen los plazos de las reglas de negocio: elaboraciones con lotes caducados (RN-01) o con
-- lotes frescos a partir de las 72 horas (RN-03), autorizaciones que no son previas o no corresponden a la carta (RN-02) y
-- primeras incorporaciones a la carta sin una prueba cerrada de 14 días (RN-04). No comprueba el destino al menú del día
-- de RN-01 ni la aptitud del lote, porque el esquema solo guarda su valor actual.
SELECT 'RN-01' AS regla, CONCAT(l.identificador_lote,' -> ',p.nombre) AS elemento, m.fecha_movimiento AS fecha,
       'Elaboración con un lote caducado' AS detalle
FROM movimientos_stock m
JOIN lotes l ON l.id_lote=m.id_lote
JOIN platos p ON p.id_plato=m.id_plato_destino
WHERE m.finalidad_salida='ELABORACION' AND m.fecha_movimiento>=l.fecha_caducidad
UNION ALL
SELECT 'RN-03', CONCAT(l.identificador_lote,' -> ',p.nombre), m.fecha_movimiento, 'Elaboración con un lote fresco transcurridas 72 horas'
FROM movimientos_stock m
JOIN lotes l ON l.id_lote=m.id_lote
JOIN platos p ON p.id_plato=m.id_plato_destino
WHERE m.finalidad_salida='ELABORACION' AND l.fresco=1 AND m.fecha_movimiento>=l.fecha_entrada+INTERVAL 72 HOUR
UNION ALL
SELECT 'RN-02', p.nombre, a.fecha_autorizacion,
       CASE WHEN po.tipo<>'CARTA_PERMANENTE' THEN 'Autorización de un periodo que no es de carta permanente'
            ELSE 'Autorización posterior al inicio del periodo' END
FROM autorizaciones_carta a
JOIN periodos_oferta po ON po.id_periodo_oferta=a.id_periodo_oferta
JOIN platos p ON p.id_plato=po.id_plato
WHERE po.tipo<>'CARTA_PERMANENTE' OR a.fecha_autorizacion>po.fecha_inicio
UNION ALL
SELECT 'RN-04', p.nombre, c.fecha_inicio, 'Primera carta permanente sin prueba previa de 14 días'
FROM periodos_oferta c
JOIN platos p ON p.id_plato=c.id_plato
WHERE c.tipo='CARTA_PERMANENTE'
    AND NOT EXISTS (SELECT 1 FROM periodos_oferta a WHERE a.id_plato=c.id_plato AND a.tipo='CARTA_PERMANENTE' AND a.fecha_inicio<c.fecha_inicio)
    AND NOT EXISTS (SELECT 1 FROM periodos_oferta s WHERE s.id_plato=c.id_plato AND s.tipo='SUGERENCIA_CHEF'
            AND s.fecha_fin<=c.fecha_inicio AND s.fecha_fin>=s.fecha_inicio+INTERVAL 14 DAY)
ORDER BY regla, elemento, fecha;
