# 6. Modelo tecnológico

## 6.1. Script de creación de tablas y restricciones

El archivo `sql/01_tablas.sql` crea una base nueva `plato_plato` y sus 17 tablas. No elimina objetos existentes ni incluye datos iniciales. Se ejecuta completo, deteniéndose al primer error. Usa InnoDB, utf8mb4 y modo estricto. El DDL puede realizar commits implícitos; no debe tratarse como una migración reversible mediante ROLLBACK.

### Decisiones físicas

- Identificadores: INT UNSIGNED autogenerados; claves compuestas en las dos concesiones N:M.
- Unidades: código ASCII binario de hasta 10 caracteres, magnitud y factor positivo DECIMAL(18,6). La unidad base de cada magnitud deberá fijarse en los datos iniciales.
- Cantidades y rendimientos: DECIMAL(14,4); precios de compra: DECIMAL(14,4); precios de venta e importes históricos: DECIMAL(14,2). El redondeo económico final corresponde a las rutinas de cálculo.
- Fechas: DATETIME(6) en hora local Europe/Madrid (S-14). DEFAULT CURRENT_TIMESTAMP exige que la conexión tenga la hora local correcta; el script no configura la zona con nombre porque depende de las tablas horarias del servidor. Los cálculos de 48/72 horas siguen la convención local adoptada; si se necesitan horas reales durante cambios de horario, el equipo deberá migrar coherentemente a UTC.
- Nombres únicos según el MR. La colación utf8mb4_unicode_ci compara sin distinguir mayúsculas; deben revisarse sus efectos sobre las denominaciones del catálogo.
- Porcentaje objetivo opcional en [0,100); imágenes y costes desconocidos admiten NULL.
- FK restrictivas, salvo concesiones y composición ON DELETE CASCADE y códigos de unidad ON UPDATE CASCADE, según 5.1.4.
- Columna VIRTUAL única para un único precio seleccionado por ingrediente. La vigencia sigue siendo una comprobación posterior.
- La longitud mínima del hash evita cadenas triviales, pero no demuestra que se haya aplicado un algoritmo seguro. El hash se genera fuera de SQL.

### Cobertura del DDL y trabajo pendiente

| Regla | Garantía declarativa incluida | Pendiente de otros bloques |
|---|---|---|
| RC-01–03 | Cantidades, rendimientos y precios positivos; componentes únicos | — |
| RC-04, D-01 | Fechas ordenadas, inicio único por proveedor/ingrediente y selección única | Solapamientos de vigencias y validación al costear |
| RC-05–08, RC-11 | Objetivo opcional en rango; derivados ausentes de las tablas | Funciones de coste, vista de margen, propagación de NULL y permisos |
| RC-09–10 | FK según política y tablas de permisos | Protección de hechos históricos, autenticación y autorización |
| RC-12 | Impide receta componente igual a receta contenedora | Ciclos indirectos, incluidos UPDATE |
| RC-13 | Signo según tipo de movimiento | Saldos históricos no negativos y concurrencia |
| RC-14 | Merma de lote o plato; movimiento obligatorio solo para lote y único | Crear salida atómica y comparar lote, cantidad, fecha y finalidad; impedir salidas de merma huérfanas |
| RC-15 | FK a unidades y factor positivo | Magnitudes compatibles y rendimiento en raciones; proteger cambios relacionados |
| RC-16 | Inicio único y fin posterior | Solapamientos de oferta |
| RC-17 | Coherencia entre tipo, signo, finalidad y destino | Fecha del lote, primera entrada y unidad implícita del movimiento |
| RN-01–04 | Estructura de lotes, oferta y autorizaciones | Todas las comprobaciones temporales, de aptitud, prueba previa y administrador |
| RNF-02 | Hash de longitud mínima | Algoritmo seguro y verificación externa |

Una receta puede quedar temporalmente sin componentes: el procedimiento que registra la receta completa debe verificar su mínimo 1..*. El DDL no garantiza autorización para cada periodo de carta. El procedimiento de incorporación debe insertar periodo y autorización en una transacción y gestionar el error; los privilegios deben impedir eludirlo mediante escrituras directas.

Para la merma de lote se prevé un trigger BEFORE INSERT que cree el movimiento y asigne NEW.id_movimiento antes de validar la referencia. El bloque de inventario debe probarlo: este DDL no crea el trigger ni acepta una merma de lote sin movimiento. No debe intentarse completar esa referencia mediante un trigger AFTER INSERT que actualice la misma merma.

Toda validación entre filas necesita una estrategia de concurrencia. Comprobar mediante SELECT sin acordar bloqueos no garantiza por sí solo que dos operaciones simultáneas mantengan saldos y periodos válidos.

## 6.2. Poblado de la base de datos mediante sentencias INSERT

El poblado inicial se realiza mediante el archivo `02_datos.sql`, que contiene sentencias `INSERT` con datos ficticios y coherentes para comprobar las relaciones del modelo y disponer de ejemplos para las consultas y los siguientes apartados del proyecto.

### Datos incluidos

| Área | Registros incluidos |
| --- | --- |
| Acceso | 3 roles, 7 permisos, 4 usuarios, 14 asignaciones de permisos a roles y 1 permiso adicional de usuario. |
| Unidades | 6 unidades: gramos, kilogramos, mililitros, litros, unidades y raciones. |
| Compras | 3 proveedores, 8 ingredientes y 10 precios de compra. |
| Cocina | 3 recetas, 2 platos y 11 componentes de receta. |
| Inventario | 8 lotes y 22 movimientos de stock. |
| Mermas | 3 mermas: dos de ingredientes y una de un plato elaborado. |
| Oferta | 4 periodos de oferta y 2 autorizaciones de incorporación a carta. |

Los usuarios representan los perfiles de administrador, encargado y empleado. Uno de los empleados está inactivo y otro dispone del permiso adicional de consultar costes. Estas asignaciones representan permisos de la aplicación; no conceden privilegios del servidor MariaDB.

Los proveedores e ingredientes incluyen registros activos e inactivos. Los precios permiten comparar dos proveedores para el tomate y consultar un precio histórico cerrado. Cada ingrediente activo tiene un único precio seleccionado para costeo; el perejil, inactivo, solo conserva un precio histórico. Los importes se expresan en euros.

Se incluyen las recetas de salsa de tomate, pasta con tomate y tortilla de patatas. La salsa es una subreceta utilizada por la pasta y rinde 1 kg por elaboración, considerando la reducción durante la cocción. Las recetas de pasta y tortilla producen cuatro raciones cada una. Los componentes utilizan gramos y mililitros aunque los ingredientes se valoren por kilogramo o litro, lo que permite probar conversiones dentro de la misma magnitud.

Los platos tienen precio de venta y margen objetivo. La pasta pertenece al menú del día. No se insertan costes calculados ni márgenes reales en la tabla de platos, ya que esos resultados se obtendrán posteriormente.

### Inventario y mermas

Los movimientos incluyen entradas, salidas para elaboración, salidas por merma y ajustes de inventario positivos y negativos. Las cantidades se expresan en la unidad del ingrediente asociado al lote. Las salidas de elaboración corresponden a ocho raciones de pasta y cuatro de tortilla, incluyendo el consumo proporcional de ingredientes de la salsa.

Se registran 2 kg de tomate retirados por caducidad, 0,5 kg retirados por deterioro y una ración de pasta desechada. Las mermas de lote están asociadas a sus movimientos de salida, con la misma cantidad y fecha. La merma de pasta no vuelve a descontar ingredientes, porque su consumo ya se registró durante la elaboración.

El lote caducado queda sin existencias y marcado como no apto para consumo. Ningún lote presenta saldo negativo. Los saldos esperados al terminar el script son:

| Lote | Saldo |
| --- | ---: |
| TOM-20261109 | 8,06 kg |
| CEB-20261109 | 4,56 kg |
| ACE-20261109 | 2,84 l |
| SAL-20261109 | 0,98 kg |
| PAS-20261109 | 4,20 kg |
| PAT-20261109 | 7,00 kg |
| HUE-20261109 | 26 ud |
| TOM-20261101 | 0,00 kg |

El saldo se obtiene sumando entradas y ajustes con su signo y restando las salidas. No se almacena directamente en los lotes. Los ajustes de ejemplo representan diferencias detectadas en el recuento físico; el esquema actual no dispone de un campo para documentar su motivo.

### Oferta y autorizaciones

Cada plato pasa por un periodo de sugerencia del chef antes de incorporarse a la carta permanente. Los intervalos de un mismo plato no se solapan y la incorporación está autorizada por la usuaria administradora después de iniciarse la prueba y antes del inicio de la carta permanente.

Las autorizaciones conservan costes evaluados por ración de 0,72 € para la pasta y 0,84 € para la tortilla, redondeados a dos decimales, junto con sus precios de venta. Son importes históricos del ejemplo, no resultados que el script calcule automáticamente.

### Ejecución y alcance

El archivo se ejecuta una sola vez después de `01_tablas.sql`, sobre las tablas vacías de `plato_plato`. Utiliza identificadores explícitos para que las referencias entre registros sean claras. No elimina datos ni está diseñado para ejecutarse repetidamente: una segunda ejecución produciría conflictos de claves.

Los registros se insertan respetando las dependencias de claves foráneas, dentro de una transacción. El cliente debe detenerse ante el primer error y ejecutar `ROLLBACK` en esa misma conexión; no debe continuar hasta `COMMIT` si una sentencia falla. Un error de sentencia no implica por sí solo que MariaDB revierta toda la transacción.

Las fechas son fijas y representan hora local de Europe/Madrid. El conjunto describe un escenario de demostración de octubre y noviembre de 2026; no pretende mantener vigentes los lotes conforme avance la fecha real.

Las contraseñas se han derivado fuera de SQL mediante scrypt con una sal aleatoria diferente por usuario. El formato almacenado es `scrypt$16384$8$1$sal_hex$hash_hex`, con clave derivada de 64 bytes. La contraseña de prueba de todos los usuarios es `DemoPlato2026!`. Estas credenciales son exclusivamente de demostración; la aplicación deberá implementar la verificación de este formato o sustituir los hashes por los del algoritmo que utilice.

El script aporta ejemplos coherentes para el esquema recibido. No implementa procedimientos ni triggers, ni demuestra que las reglas de negocio se impongan automáticamente. Antes de dar la carga por validada debe ejecutarse en MariaDB 10.6 o superior y comprobarse junto con las reglas de los siguientes apartados.

## 6.3. Script de consultas a tablas en SQL

El archivo `03_consultas.sql` contiene 27 consultas numeradas (C-01 a C-27) que se ejecutan después de `01_tablas.sql` y `02_datos.sql`. Solo lee datos: no crea objetos ni modifica filas, por lo que puede ejecutarse tantas veces como se quiera. No depende de funciones, procedimientos ni triggers; los atributos derivados (saldos, costes y márgenes) se calculan en la propia consulta a partir de las tablas.

### Parámetros

Al principio del script se fijan tres variables. `@ahora` es el instante en que se evalúan vigencias, saldos y plazos; se fija en el 15 de noviembre de 2026 a las 12:00, dentro del escenario de `02_datos.sql`, para que los resultados sean reproducibles, y puede sustituirse por `NOW(6)` para consultar la situación real. `@horas_aviso_caducidad` (48) y `@porcentaje_aviso_precio` (10) son los umbrales por defecto de RF-11 y RF-12 (S-08).

### Consultas incluidas

| Bloque | Consultas | Contenido | Requisitos |
| --- | --- | --- | --- |
| Acceso | C-01, C-02 | Cuentas con su rol y permisos efectivos (rol más adicionales), con su origen. | RF-01, RC-10, D-03 |
| Compras | C-03 a C-06 | Proveedores, comparación de precios vigentes, histórico con variación y avisos de sobrecoste con los platos afectados. | RF-02, RF-04, RF-11, RF-13, RC-04 |
| Recetas | C-07 a C-11 | Composición, subrecetas reutilizadas, escandallo detallado, coste y margen de cada plato, e ingredientes que impiden costear. | RF-06 a RF-08, RC-05 a RC-08, RC-11 |
| Inventario | C-12 a C-16 | Saldo por lote, existencias por ingrediente, extracto de movimientos, avisos de caducidad y existencias que ya no pueden usarse. | RF-03, RF-09, RF-12, RC-13, RN-01, RN-03 |
| Mermas | C-17 a C-20 | Detalle de pérdidas, análisis por motivo, evolución mensual con total e ingredientes con más pérdida. | RF-10, RG-02 |
| Oferta | C-21, C-22 | Historial de periodos con su autorización y platos que ya pueden proponerse para la carta. | RI-10, RN-02, RN-04 |
| Control | C-23 a C-27 | Reglas que el DDL no garantiza: recetas sin componentes, periodos de carta sin autorización, solapes, ciclos, saldos negativos, mermas incoherentes y plazos de RN-01 a RN-04. Deben devolver cero filas. | RC-04, RC-12 a RC-14, RC-16, RN-01 a RN-04 |

Cada consulta va precedida de un comentario con su objetivo, las reglas que trata y la técnica empleada. Se usan combinaciones internas y externas, agrupaciones con `HAVING` y `WITH ROLLUP`, subconsultas escalares, correlacionadas y en `FROM`, `EXISTS` y `NOT EXISTS`, `UNION`, funciones de ventana (`RANK`, `LAG` y sumas acumuladas) y expresiones de tabla comunes recursivas. No se usa `SELECT *`.

### Cálculo del coste

El coste recorre las subrecetas con una CTE recursiva. Para cada receta se calcula cuántas elaboraciones de cada subreceta necesita, convirtiendo la cantidad a la unidad de rendimiento mediante `factor_a_base`. Cada ingrediente se valora con su precio seleccionado y vigente en `@ahora`, convertido a la unidad de la línea (RC-05, D-01). Solo se convierten unidades de la misma magnitud (RC-15).

El coste queda en `NULL`, y no en cero, si falta un precio válido, las unidades no son compatibles, una receta no tiene componentes o existe un ciclo (RC-11). La recursión registra las recetas recorridas, de modo que termina aunque los datos contengan un ciclo. Los costes se redondean a cuatro decimales; las valoraciones y los porcentajes, a dos.

Con los datos de `02_datos.sql`, el coste por ración es de 0,7232 € para la pasta con tomate y de 0,8416 € para la tortilla, que coinciden con los importes evaluados de las autorizaciones (0,72 € y 0,84 €).

### Verificación

El script se ha ejecutado en MariaDB 11.8 sobre la base vacía, sobre los datos de `02_datos.sql` y sobre un juego adicional de casos límite que reproduce los escenarios de la sección 4.7. En todos los casos termina sin errores ni avisos, también con `ONLY_FULL_GROUP_BY`, y deja la base sin cambios. Con los casos límite se obtienen los valores de los escenarios: precio de referencia de 1,20 €/kg, coste de la degustación de 0,60 € con un margen del 80 %, saldo de 8 kg tras la merma y rechazo del lote fresco a las 72 horas. Además, las consultas de control detectan cada incumplimiento introducido a propósito.

Con los datos actuales de `02_datos.sql`, las consultas C-24 y C-27 devuelven dos filas cada una: en los dos platos, el periodo de carta permanente empieza antes de que termine su sugerencia del chef. Por ello se incumplen RC-16 y RN-04. Deben corregirse las fechas del poblado o los triggers del apartado 6.5 rechazarán esos datos.
