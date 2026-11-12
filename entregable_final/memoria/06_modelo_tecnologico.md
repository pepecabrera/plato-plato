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
- FK restrictivas, salvo concesiones y composición ON DELETE CASCADE y códigos de unidad ON UPDATE CASCADE, según 5.1.4. Como un cambio de código, magnitud o factor de una unidad en uso lo rechaza un trigger de 05, el CASCADE solo actúa sobre unidades sin datos relacionados.
- Columna VIRTUAL única para un único precio seleccionado por ingrediente. La vigencia sigue siendo una comprobación posterior.
- La longitud mínima del hash evita cadenas triviales, pero no demuestra que se haya aplicado un algoritmo seguro. El hash se genera fuera de SQL.

### Cobertura del DDL y trabajo pendiente

| Regla | Garantía declarativa incluida | Pendiente de otros bloques |
|---|---|---|
| RC-01–03 | Cantidades, rendimientos y precios positivos; componentes únicos | — |
| RC-04, D-01 | Fechas ordenadas, inicio único por proveedor/ingrediente y selección única | Validación al costear (funciones de 04). Solapamientos de vigencias: triggers `trg_precio_*` de 05; concurrencia pendiente |
| RC-05–08, RC-11 | Objetivo opcional en rango; derivados ausentes de las tablas | Funciones de coste, margen, propagación de NULL y permisos en 04; consultas en 03 |
| RC-09–10 | FK según política y tablas de permisos | Protección del historial en 05 y permisos de aplicación en 04. Autenticación y privilegios MariaDB fuera del alcance actual |
| RC-12 | Impide receta componente igual a receta contenedora | Ciclos indirectos, incluidos UPDATE: triggers `trg_componente_*` de 05. Alta completa en 04 y protección de la última línea en 05; inserción manual de cabeceras vacías aún posible |
| RC-13 | Signo según tipo de movimiento | Saldos históricos comprobados en sp_registrar_movimiento y sp_registrar_merma; concurrencia general no certificada |
| RC-14 | Merma de lote o plato; movimiento obligatorio solo para lote y único | Alta atómica en 04 y coherencia merma/salida en 05. El procedimiento de movimientos rechaza MERMA; la escritura directa aún puede crear salidas huérfanas |
| RC-15 | FK a unidades y factor positivo | Magnitudes compatibles y cambios en datos relacionados: triggers de 05. Rendimiento en raciones de platos validado en INSERT/UPDATE de platos y cambios de unidad de recetas en 05 |
| RC-16 | Inicio único y fin posterior | Solapamientos comprobados en 05; procedimientos de oferta bloquean el plato |
| RC-17 | Coherencia entre tipo, signo, finalidad y destino | Fecha del lote y primera entrada en procedimientos; 05 bloquea cambios de ingrediente y recepción de lotes con movimientos |
| RN-01–04 | Estructura de lotes, oferta y autorizaciones | Comprobaciones temporales y de aptitud en 05; prueba previa y administrador en 04/05. No se reconstruye aptitud histórica ni se comprueba pertenencia del ingrediente a la receta destino |
| RNF-02 | Hash de longitud mínima | Algoritmo seguro y verificación externa |

sp_registrar_receta registra la receta y sus componentes en una transacción y exige al menos una línea. Los triggers impiden borrar o trasladar la última línea de una receta conservada. Una cabecera insertada manualmente aún puede quedar vacía: no se restringen privilegios MariaDB en esta entrega. El DDL no garantiza autorización para cada periodo de carta. El procedimiento de incorporación debe insertar periodo y autorización en una transacción y gestionar el error; los privilegios deben impedir eludirlo mediante escrituras directas.

Toda validación entre filas necesita una estrategia de concurrencia. Comprobar mediante SELECT sin acordar bloqueos no garantiza por sí solo que dos operaciones simultáneas mantengan saldos y periodos válidos.

## 6.2. Poblado de la base de datos mediante sentencias INSERT

El poblado inicial se realiza mediante el archivo `02_datos.sql`, que contiene sentencias `INSERT` con datos ficticios y coherentes para comprobar las relaciones del modelo y disponer de ejemplos para las consultas y los siguientes apartados del proyecto.

### Datos incluidos

| Área | Registros incluidos |
| --- | --- |
| Acceso | 3 roles, 8 permisos, 4 usuarios, 16 asignaciones de permisos a roles y 1 permiso adicional de usuario. |
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

La fecha de consulta filtra la vigencia del precio seleccionado actualmente. La composición de las recetas y la selección de precios no tienen versionado: consultar una fecha pasada no reconstruye el escandallo de entonces y puede devolver NULL aunque exista otro precio histórico no seleccionado.

El coste recorre las subrecetas con una CTE recursiva. Para cada receta se calcula cuántas elaboraciones de cada subreceta necesita, convirtiendo la cantidad a la unidad de rendimiento mediante `factor_a_base`. Cada ingrediente se valora con su precio seleccionado y vigente en `@ahora`, convertido a la unidad de la línea (RC-05, D-01). Solo se convierten unidades de la misma magnitud (RC-15).

El coste queda en `NULL`, y no en cero, si falta un precio válido, las unidades no son compatibles, una receta no tiene componentes o existe un ciclo (RC-11). La recursión registra las recetas recorridas, de modo que termina aunque los datos contengan un ciclo. Los costes se redondean a cuatro decimales; las valoraciones y los porcentajes, a dos.

Con los datos de `02_datos.sql`, el coste por ración es de 0,7232 € para la pasta con tomate y de 0,8416 € para la tortilla, que coinciden con los importes evaluados de las autorizaciones (0,72 € y 0,84 €).

### Verificación

El script se ha revisado estáticamente; no se dispone de resultados de ejecución de esta versión en MariaDB. Los importes y resultados descritos son los previstos al leer el escenario. Queda pendiente ejecutar las consultas, incluidos los controles C-23 a C-27, conservar la salida con fecha y versión concreta y documentar solo lo observado. No se ha verificado ONLY_FULL_GROUP_BY ni los casos límite en ejecución.

## 6.4. Script de creación de funciones y procedimientos

El archivo `sql/04_funciones_procedimientos.sql` contiene las funciones y los procedimientos necesarios para calcular costes y márgenes, consultar existencias y gestionar movimientos de inventario y periodos de oferta.

### Funciones

| Función | Finalidad |
|---|---|
| `fn_convertir` | Convierte cantidades entre unidades de la misma magnitud, como gramos y kilogramos. |
| `fn_coste_ingrediente` | Calcula el coste de una cantidad de ingrediente utilizando su precio seleccionado y vigente en la fecha indicada. |
| `fn_coste_receta` | Calcula el coste por unidad de rendimiento de una receta, incluyendo sus subrecetas. |
| `fn_coste_plato` | Obtiene el coste de producción de una ración del plato. |
| `fn_margen_plato` | Calcula la diferencia entre el precio de venta y el coste de producción por ración. |
| `fn_stock_lote` | Obtiene el saldo de un lote hasta una fecha, sumando entradas y ajustes y restando salidas. |
| `fn_tiene_permiso` | Comprueba si un usuario activo dispone del permiso requerido mediante su rol o sus permisos adicionales. |

El cálculo de costes utiliza las cantidades de los componentes, las conversiones de unidades, los rendimientos de las recetas y los precios de compra seleccionados y vigentes. Las subrecetas se recorren mediante una expresión común de tabla recursiva (`WITH RECURSIVE`).

Cuando falta un precio válido, existen unidades incompatibles, una receta está vacía o se detecta un ciclo, el coste devuelve `NULL`, en lugar de sustituirse por cero. El recorrido admite hasta 64 enlaces de subrecetas; si necesita superar ese límite, también devuelve `NULL`.

Los costes y márgenes actuales se calculan al consultarlos y no se almacenan en la tabla de platos. De esta forma, reflejan los cambios en los precios aplicables y en la composición de las recetas. Los cálculos intermedios utilizan `DECIMAL(30,8)` y los importes se redondean a dos decimales al presentarlos o guardar una evaluación histórica.

### Procedimientos

| Procedimiento | Finalidad |
|---|---|
| `sp_consultar_escandallo` | Muestra el coste unitario, el precio de venta, el margen bruto y el porcentaje de margen de un plato. |
| `sp_registrar_movimiento` | Registra una entrada, salida o ajuste y comprueba que no provoque saldos negativos en el historial del lote. |
| `sp_registrar_sugerencia` | Registra un periodo de oferta como sugerencia del chef. |
| `sp_incorporar_carta` | Registra conjuntamente un periodo de carta permanente y su autorización. |
| `sp_cerrar_periodo` | Cierra o acorta un periodo de oferta respetando las restricciones del historial. |
| `sp_registrar_merma` | Dar de alta una merma de plato o de lote. |
| `sp_registrar_receta` | Registrar receta y componentes en una transacción, exigiendo GESTIONAR_RECETAS y al menos una línea. |

Los procedimientos de escritura gestionan sus propias transacciones y deben invocarse fuera de una transacción ya abierta. Si una comprobación falla, ejecutan `ROLLBACK` y propagan el error mediante `RESIGNAL`.

El procedimiento de movimientos bloquea el lote durante la operación. Comprueba que ningún movimiento sea anterior a su recepción, que el primero sea una entrada y que todos los saldos acumulados sean no negativos. Esta última comprobación incluye los movimientos posteriores al que se registra, por lo que también permite detectar inconsistencias al introducir movimientos con fecha pasada.

Los procedimientos de oferta bloquean el plato para coordinar las operaciones sobre sus periodos. La incorporación a la carta inserta primero el periodo y después su autorización dentro de una misma transacción. Si la autorización falla, también se deshace la creación del periodo.

Para los usuarios distintos del administrador, se comprueban los permisos `CONSULTAR_COSTES`, `GESTIONAR_STOCK`, `REGISTRAR_MERMAS`, `GESTIONAR_PLATOS` y `GESTIONAR_RECETAS`, según la operación. La incorporación a la carta exige específicamente un administrador activo.

### Alcance

El identificador de usuario recibido por un procedimiento no demuestra su identidad: la autenticación corresponde a la aplicación. Las cuentas operativas deben utilizar los procedimientos autorizados y no disponer de escrituras directas que permitan eludir sus comprobaciones.

sp_registrar_merma exige el permiso REGISTRAR_MERMAS. Para una merma de lote, bloquea el lote, comprueba los saldos históricos y registra conjuntamente la salida y la merma, revirtiendo ambas ante cualquier error. Para una merma de plato no genera movimientos de stock. El coste recibido representa el importe histórico total; admite NULL cuando se desconoce. Las mermas registradas son definitivas: no se permite editarlas, borrarlas ni anularlas en esta versión. Un ajuste de stock no modifica los informes de pérdidas de la merma original.

Los triggers de 05 impiden introducir ciclos al editar recetas y solapamientos de precios. La detección de ciclos durante el cálculo evita devolver un coste válido para una composición cíclica, pero no sustituye la validación de su registro.

### Alta completa de recetas

sp_registrar_receta recibe usuario, nombre, cantidad de rendimiento, unidad de rendimiento y una lista JSON de componentes. Usa JSON_TABLE, disponible en el objetivo MariaDB 10.6+, para insertar las líneas. Cada objeto contiene cantidad, unidad_medida y exactamente uno de id_ingrediente o id_receta_componente. Requiere instalar 05 antes de utilizarse: sus triggers validan magnitudes y ciclos, y el DDL valida cantidades, referencias y exclusividad.

Ejemplo con ingrediente y subreceta:

```sql
CALL sp_registrar_receta(2, 'Pasta de prueba', 4, 'racion',
 '[{"cantidad":800,"unidad_medida":"g","id_ingrediente":5},
   {"cantidad":500,"unidad_medida":"g","id_receta_componente":1}]');
```

La llamada es autónoma, exige GESTIONAR_RECETAS y rechaza una lista vacía o un documento JSON inválido. Un fallo en cualquier línea revierte cabecera y componentes. El procedimiento devuelve id_receta. No se impide insertar manualmente una cabecera vacía: se adopta este procedimiento como flujo operativo del proyecto. Un borrado de receta completa por ON DELETE CASCADE no ejecuta los triggers de componentes; sigue sujeto a las FK que impiden eliminar recetas referenciadas.

### Alcance de las fechas al costear

sp_consultar_escandallo utiliza la composición y selección de precios actuales; p_fecha comprueba la vigencia del precio seleccionado. No reconstruye versiones históricas de recetas o selecciones. Se conserva este alcance sin añadir tablas de histórico.

## 6.5. Script de creación de triggers asociados a reglas de negocio

El archivo `sql/05_triggers.sql` contiene los triggers que aplican las reglas RN-01 a RN-04, protegen los datos históricos relacionados y aplican las reglas de integridad RC-04, RC-12, RC-14, RC-15 y RC-17. Las operaciones que incumplen una comprobación se rechazan mediante `SIGNAL SQLSTATE '45000'`, acompañado de un mensaje explicativo. En total se crean 23 triggers y 2 funciones auxiliares (`fn_validar_precio` y `fn_validar_componente`).

### Reglas implementadas

| Regla | Aplicación |
|---|---|
| **RN-01. Aprovechamiento de ingredientes próximos a caducar** | Antes de registrar una salida para elaboración, se comprueba que el lote sea apto y no esté caducado. Cuando restan menos de 48 horas para su caducidad, solo puede destinarse a un plato del menú del día. |
| **RN-02. Incorporación a la carta** | La autorización debe proceder de un administrador activo, corresponder a un periodo de carta permanente y tener una fecha no posterior a su inicio. Además, se exige un coste calculable y un precio de venta. |
| **RN-03. Política interna de frescura** | Se impide elaborar con un lote fresco desde el instante de recepción más 72 horas, incluido. |
| **RN-04. Prueba de nuevos platos** | La primera incorporación a carta requiere un periodo cerrado de sugerencia del chef de al menos 14 días consecutivos, finalizado a más tardar al comenzar la carta permanente. |
| **RC-04. Vigencias de precio** | Un precio no puede solaparse con otro del mismo proveedor e ingrediente. |
| **RC-12. Ciclos de recetas** | Una línea de receta no puede hacer que una receta quede contenida en sí misma, directa o indirectamente. |
| **RC-15. Unidades compatibles** | Las unidades de precios y componentes deben ser de la misma magnitud que las de su ingrediente o subreceta, y no pueden cambiar unidades, ingredientes o rendimientos que ya tienen datos relacionados. |

### Comprobaciones sobre los lotes

El trigger `trg_movimiento_bi_negocio` aplica RN-01 y RN-03 únicamente a movimientos de tipo `SALIDA` cuya finalidad sea `ELABORACION`.

Las comprobaciones utilizan la fecha del movimiento. Exactamente a 48 horas de la caducidad todavía no se aplica la limitación del menú del día. En cambio, exactamente a las 72 horas desde la recepción ya se prohíbe utilizar un lote fresco.

Las salidas por merma no se consideran elaboración, por lo que estas reglas no impiden retirar un producto caducado o que haya superado el plazo de frescura.

### Autorización e incorporación a la carta

El trigger `trg_autorizacion_bi_negocio` comprueba el administrador, el periodo, las fechas y la disponibilidad de un coste calculable y un precio de venta. Calcula y guarda `coste_evaluado` y `precio_venta_evaluado`, sustituyendo los valores proporcionados en la inserción.

Estos importes se conservan como información histórica. No se exige un margen mínimo ni que el precio de venta supere el coste, porque RN-02 no establece ese requisito.

La obligatoriedad de que cada incorporación tenga una autorización se completa mediante `sp_incorporar_carta`. El procedimiento inserta el periodo y su autorización en una única transacción. Para impedir que se eluda este flujo, las cuentas operativas no deben disponer de escritura directa sobre ambas tablas.

### Periodos de prueba y protección del historial

El trigger `trg_periodo_bi_negocio` impide solapamientos entre periodos de oferta y comprueba la prueba previa exigida por RN-04. Los catorce días deben pertenecer a un único periodo cerrado de sugerencia del chef.

Cada incorporación a la carta requiere autorización, pero la prueba previa solo se exige para la primera incorporación.

Los triggers adicionales impiden modificar o eliminar movimientos y autorizaciones. También protegen los periodos de oferta frente a eliminaciones o cambios de plato, tipo y fecha inicial. Se permite cerrar o acortar un periodo, pero no modificar las fechas finales de las sugerencias cuando ya existe una incorporación a la carta.

Los triggers `trg_merma_bu_historico` y `trg_merma_bd_historico` rechazan cualquier modificación o eliminación de mermas.

### Integridad de precios, recetas y unidades

Los triggers `trg_precio_bi_negocio` y `trg_precio_bu_negocio` aplican RC-04 y RC-15 a los precios de compra. Rechazan vigencias solapadas para un mismo proveedor e ingrediente, y unidades de precio de distinta magnitud que la del ingrediente. Los intervalos incluyen su inicio y excluyen su fin, por lo que dos vigencias contiguas no se consideran solapadas.

Los triggers `trg_componente_bi_negocio` y `trg_componente_bu_negocio` aplican RC-12 y RC-15 a las líneas de receta. Comprueban que la unidad de la línea tenga la misma magnitud que su ingrediente o que el rendimiento de su subreceta, y que la subreceta añadida no pueda alcanzar a la receta contenedora, con lo que se detectan ciclos directos e indirectos, también al modificar líneas.

Los triggers `trg_unidad_bu_negocio`, `trg_ingrediente_bu_negocio` y `trg_receta_bu_negocio` impiden cambiar el código, la magnitud o el factor de una unidad en uso, la unidad de un ingrediente con lotes, precios o componentes, y el rendimiento de una subreceta utilizada por otra receta. De este modo, los datos históricos no se reinterpretan.

Estos triggers comprueban sin bloqueos explícitos: dos conexiones simultáneas podrían crear a la vez dos precios solapados o dos líneas que formen un ciclo. La concurrencia queda pendiente. El alta operativa completa y los borrados/traslados de la última línea se cubren con el procedimiento y los triggers nuevos; la inserción manual de una cabecera vacía sigue permitida.

### Nuevas comprobaciones de integridad

- trg_merma_bi_coherencia exige que una merma de lote coincida con su movimiento en lote, cantidad, fecha, tipo SALIDA y finalidad MERMA. UNIQUE(id_movimiento) impide duplicar el enlace. Las mermas de plato siguen sin movimiento.
- trg_plato_bi_raciones y trg_plato_bu_raciones exigen recetas con rendimiento de magnitud RACION. trg_receta_bu_negocio mantiene esa condición al cambiar su unidad. Las subrecetas sin plato asociado pueden rendir en kg o litros.
- trg_componente_bd_minimo impide borrar la última línea de una receta conservada. trg_componente_bu_negocio impide trasladarla a otra receta. No se certifica concurrencia entre conexiones.
- trg_lote_bu_historico impide cambiar ingrediente o fecha de recepción cuando hay movimientos. Permite editar ubicación y conserva el alcance actual para caducidad, frescura y aptitud; no incorpora historial de aptitud.

### Ejecución y validación

Los archivos se ejecutan con las tablas ya creadas, primero `sql/04_funciones_procedimientos.sql` y después `sql/05_triggers.sql`. Ambos deben estar instalados antes de utilizar los procedimientos.

La instalación de triggers no comprueba retroactivamente los datos que ya existían. No elimina las limitaciones aceptadas: cabeceras de receta vacías insertadas manualmente, escritura directa sin privilegios restringidos y concurrencia general no certificada.

Las pruebas del apartado 6.7 comprueban 128 casos de negocio que cubren cálculos de costes, límites temporales, autorizaciones, saldos, integridad de precios, recetas y unidades, y reversión de operaciones rechazadas. Sus resultados deben conservarse de la ejecución real en la versión de MariaDB utilizada por el equipo.

Queda pendiente verificar la versión de MariaDB utilizada en clase, la integración con los demás scripts, los privilegios de las cuentas operativas y la concurrencia con varias conexiones.

## 6.6. Script de poblado de la base de datos mediante procedimientos (opcional)

El archivo `sql/06_poblado_procedimientos.sql` carga el mismo escenario de demostración que `02_datos.sql`, pero mediante procedimientos almacenados en lugar de sentencias `INSERT` directas. Es una **alternativa** al apartado 6.2: se ejecuta sobre las tablas vacías tras `01_tablas.sql` y no debe combinarse con `02_datos.sql` sobre la misma base.

### Diferencias respecto al poblado con INSERT

| Aspecto | 6.2 (`02_datos.sql`) | 6.6 (`06_poblado_procedimientos.sql`) |
| --- | --- | --- |
| Identificadores | Explícitos en cada `INSERT`. | Autogenerados; las referencias se resuelven por clave natural (nombre, correo, identificador de lote). |
| Reutilización | Sentencias de un solo uso. | Procedimientos de alta que pueden volver a invocarse con otros datos. |
| Validación | Solo `CHECK`, claves y restricciones del DDL. | Además, comprobaciones entre filas antes de insertar (ver más abajo). |
| Atomicidad | Transacción gestionada por el cliente, que debe detenerse al primer error. | Transacción gestionada por el procedimiento principal, con `ROLLBACK` automático ante cualquier error. |
| Mermas de lote | Salida y merma insertadas por separado, enlazadas con IDs fijos. | Un único procedimiento crea la salida y la merma enlazada. |

### Estructura de rutinas

Todas las rutinas llevan el prefijo `pob_` para no colisionar con las de los apartados 6.4 y 6.5.

| Nivel | Rutinas | Función |
| --- | --- | --- |
| Resolución | `pob_id_rol`, `pob_id_permiso`, `pob_id_usuario`, `pob_id_proveedor`, `pob_id_ingrediente`, `pob_id_receta`, `pob_id_plato`, `pob_id_lote` | Convierten una clave natural en su identificador; si no existe, detienen la carga con un mensaje claro. |
| Cálculo | `pob_saldo_lote` | Saldo de un lote: entradas y ajustes con signo menos salidas. |
| Alta | `pob_alta_rol`, `pob_alta_permiso`, `pob_alta_usuario`, `pob_conceder_permiso_rol`, `pob_conceder_permiso_usuario`, `pob_alta_unidad`, `pob_alta_proveedor`, `pob_alta_ingrediente`, `pob_alta_precio_compra`, `pob_alta_receta`, `pob_alta_plato`, `pob_alta_componente`, `pob_alta_lote`, `pob_registrar_movimiento`, `pob_registrar_merma_lote`, `pob_registrar_merma_plato`, `pob_alta_periodo_oferta`, `pob_alta_autorizacion_carta` | Insertan una fila o un hecho de negocio por llamada. |
| Bloque | `pob_bloque_acceso`, `pob_bloque_unidades`, `pob_bloque_compras`, `pob_bloque_cocina`, `pob_bloque_inventario_y_mermas`, `pob_bloque_oferta` | Agrupan los datos del escenario por área, respetando el orden de las claves foráneas. |
| Principal | `pob_poblar_base_datos` | Comprueba que las tablas están vacías, abre la transacción, invoca los bloques en orden, confirma y devuelve el recuento de filas por tabla. |

### Reglas comprobadas durante la carga

Los procedimientos de alta validan, antes de insertar, reglas que el DDL no puede garantizar por sí solo:

- **RC-04:** las vigencias de precio de un mismo proveedor e ingrediente no se solapan. Si el script 05 está instalado, el trigger `trg_precio_bi_negocio` aplica también esta regla.
- **RC-13:** antes de insertar un movimiento se comprueban todos los saldos acumulados del lote, incluyendo el movimiento propuesto y los movimientos posteriores. Se rechaza si cualquier saldo resulta negativo.
- **RC-14:** la merma de un lote crea de forma atómica su salida con finalidad `MERMA`, con la misma cantidad y fecha, y la enlaza.
- **RC-16:** un plato no tiene dos periodos de oferta simultáneos, sean o no del mismo tipo.
- **RC-17:** ningún movimiento puede preceder a la recepción del lote. El primero debe ser una entrada; no se admiten salidas ni ajustes anteriores a la primera entrada registrada.
- **RN-02:** la autorización de carta la emite un administrador con cuenta activa, antes del inicio del periodo de carta.

Los movimientos se ordenan por fecha y, cuando coinciden, por identificador. El movimiento propuesto se evalúa después de los ya existentes en su misma fecha. La validación se realiza antes de insertarlo y no abre ni confirma transacciones: participa en la transacción del procedimiento principal. Se mantiene la hipótesis de una carga inicial de un solo usuario.

Cualquier incumplimiento lanza un error (`SQLSTATE 45000`) con un mensaje que identifica la regla, y el procedimiento principal revierte toda la carga. La concurrencia no se trata aquí: se asume una carga inicial de un solo usuario sobre tablas vacías.

### Datos cargados

Se cargan los mismos registros que en el apartado 6.2 (3 roles, 8 permisos, 4 usuarios, 16 asignaciones de permisos a roles, 1 permiso adicional, 6 unidades, 3 proveedores, 8 ingredientes, 10 precios, 3 recetas, 2 platos, 11 componentes, 8 lotes, 22 movimientos, 3 mermas, 4 periodos de oferta y 2 autorizaciones), con los mismos identificadores resultantes y los mismos saldos finales. Los movimientos se insertan en el orden cronológico del escenario, por lo que el resultado es equivalente al del poblado con `INSERT`.

Ambos poblados usan las mismas fechas de oferta: la carta permanente comienza el 15/10/2026 para la pasta y el 24/10/2026 para la tortilla, es decir, en el instante en que termina su periodo de sugerencia del chef. Con ello se cumplen RC-16 (sin solapes) y RN-04 (sugerencia cerrada de 14 días, terminada a más tardar cuando empieza la carta). Las autorizaciones son previas al alta en carta.

### Ejecución y alcance

1. Ejecutar `01_tablas.sql`.
2. Ejecutar `06_poblado_procedimientos.sql` con un cliente que admita `DELIMITER` (cliente `mariadb`, DBeaver o MySQL Workbench). El script crea las rutinas y, al final, invoca `CALL pob_poblar_base_datos();`.
3. Comprobar el recuento devuelto por el procedimiento principal.

Las rutinas pueden recrearse cuantas veces se desee (cada una se elimina con `DROP ... IF EXISTS` antes de crearse), pero la carga solo se ejecuta una vez: si la base ya contiene datos, el procedimiento principal se detiene sin modificar nada.

La creación de la merma de lote se realiza dentro de `pob_registrar_merma_lote`, que inserta primero la salida y después la merma con su `id_movimiento`.

La equivalencia de los pares rol-permiso entre 02 y 06 se ha comprobado estáticamente: 16 pares únicos (administrador 8, encargado 6 y empleado 2). La equivalencia del resto del escenario y los casos de error deben verificarse ejecutando la carga y las pruebas en una copia vacía, con salida fechada y versión concreta. Esta revisión no acredita ejecución en MariaDB.

### Contrato de transacciones

Los 24 procedimientos internos de alta y de bloque con prefijo `pob_` requieren una transacción activa. Si se invocan sin ella, rechazan la llamada antes de escribir. Las funciones de consulta no necesitan esta comprobación.

El procedimiento `pob_poblar_base_datos` debe invocarse fuera de una transacción. Esta comprobación se realiza antes del bloque que gestiona errores, por lo que su rechazo no confirma ni revierte el trabajo pendiente del llamador.

El principal abre su propia transacción y confirma únicamente cuando termina toda la carga. Ante un error, revierte esa transacción y propaga el fallo. Los procedimientos internos no ejecutan COMMIT ni ROLLBACK.

La salida y la merma creadas por `pob_registrar_merma_lote` participan en esa misma transacción. Si ocurre un error durante la carga, el principal revierte ambas.

Estas comprobaciones no sustituyen los privilegios: las cuentas operativas no deben disponer de permiso para ejecutar las rutinas internas del poblado.

El archivo completo debe instalarse sin una transacción pendiente, porque sus sentencias DDL pueden producir commits implícitos.

## 6.7. Script de creación de pruebas y llamadas

El archivo `sql/07_pruebas.sql` contiene las pruebas del esquema, los datos, las funciones, los procedimientos y los triggers. No necesita otros archivos de pruebas ni un ejecutor Python.

### Organización y cobertura

El script selecciona el bloque de pruebas según la presencia de triggers:

| Bloque | Preparación | Comprobaciones |
|---|---|---:|
| Esquema y poblado | Archivos 01 y 02, sin triggers. | 66 |
| Funciones, triggers y procedimientos | Archivos 01, uno de los poblados y 04/05. | 128 |

El archivo define 206 comprobaciones distintas: 66 del esquema, 128 de negocio y 12 adicionales del procedimiento de movimientos del poblado 06. No todas se ejecutan en cada pasada.

Cuando está instalado `pob_registrar_movimiento`, se ejecutan las pruebas adicionales de salidas y ajustes retroactivos inválidos, movimientos retroactivos válidos, movimientos simultáneos, primera entrada y conservación de la transacción del llamador. Estas pruebas dejan datos auxiliares en la copia, por lo que solo se ejecutan la primera vez: si los lotes auxiliares 9101 a 9103 ya existen, se registra una entrada PENDIENTE en lugar de abortar.

Para comprobar el poblado 06, preparar una copia vacía, ejecutar 01, después 06 y finalmente 07. No cargar 02 en esa misma copia. Estas pruebas no validan por completo las demás rutinas del 06 ni la concurrencia.

Las pruebas del esquema comprueban recuentos, claves, campos obligatorios, dominios, cantidades, precios, componentes, saldos y coherencia del poblado.

Las pruebas de funciones comprueban conversiones, costes de ingredientes y subrecetas, márgenes, stock por fecha y permisos. También verifican la propagación de NULL cuando faltan precios o una subreceta está vacía. Las unidades incompatibles y los ciclos indirectos ya no pueden construirse porque los rechazan los triggers de integridad.

Las pruebas de triggers comprueban la protección del historial, los periodos de oferta, las autorizaciones y las reglas temporales. Incluyen los límites exactos de 48 y 72 horas y un periodo de sugerencia de 14 días. También cubren la integridad de precios, recetas y unidades: solape de vigencias (y su límite contiguo, que se permite), unidad de precio o de componente incompatible, ciclo indirecto y cambios de factor, unidad o rendimiento en elementos en uso.

Las pruebas de procedimientos comprueban permisos, movimientos, mermas, sugerencias, incorporación a carta y cierre de periodos. Verifican que una merma de lote genere su salida enlazada y que una merma de plato no vuelva a descontar ingredientes.

Las 34 regresiones nuevas cubren el enlace de mermas, rendimiento en raciones, borrado y traslado de componentes, edición mínima de lotes, permisos y atomicidad del alta de recetas y el orden de movimientos simultáneos de C-26. La prueba de coste NULL por subreceta vacía crea deliberadamente una cabecera vacía manual; ya no borra todos los componentes de una receta existente.

El bloque de negocio añade tres entradas PENDIENTE: concurrencia, privilegios operativos y cobertura adicional de 06. Si 06 está instalado y sus datos auxiliares ya existen por una pasada anterior, aparece una cuarta entrada PENDIENTE. Estas entradas no cuentan como pruebas aprobadas.

### Método

El script crea procedimientos auxiliares con prefijo `pp67_`.

`pp67_caso` ejecuta una sentencia y compara el código de error obtenido con el esperado. En los rechazos de negocio también comprueba el prefijo del mensaje, evitando aprobar una prueba por una regla distinta.

Las operaciones directas compatibles se ejecutan en una transacción que se revierte después de cada caso. Las llamadas a procedimientos autónomos se realizan sin una transacción exterior, porque estos procedimientos gestionan sus propias transacciones.

`pp67_comprobar` registra condiciones y considera NULL como fallo. Los resultados se almacenan en una tabla temporal MEMORY, que los conserva al revertir las operaciones.

Se comprueba expresamente que un error al insertar una merma no deje su salida guardada y que una autorización fallida tampoco deje creado el periodo de carta.

Al finalizar se muestran el detalle y los totales. Si existe algún FALLO, se lanza un error SQL. Las entradas PENDIENTE no se consideran pruebas aprobadas.

### Ejecución

Utilizar una instancia MariaDB 10.6 o superior dedicada a pruebas. No ejecutar sobre una base con datos reales ni dentro de una transacción de trabajo.

1. Crear una copia desechable mediante `01_tablas.sql`.
2. Cargar `02_datos.sql`.
3. Ejecutar `07_pruebas.sql`: realizará las 66 comprobaciones del esquema.
4. Instalar `04_funciones_procedimientos.sql` y después `05_triggers.sql` completos, incluyendo el procedimiento de mermas, sus triggers de protección y los triggers de integridad de precios, recetas y unidades.
5. Volver a ejecutar `07_pruebas.sql`: realizará las 128 comprobaciones de negocio.

El archivo utiliza la base `plato_plato`, por lo que debe ejecutarse en un entorno de pruebas separado del entorno de trabajo. No debe utilizarse la opción `--force`.

Las pruebas de negocio crean datos auxiliares y ejecutan operaciones que confirman transacciones. Antes de repetir ese bloque debe prepararse una copia nueva. El archivo no elimina ni recrea automáticamente la base.

Se necesitan permisos para crear y eliminar rutinas, crear tablas temporales y ejecutar las operaciones comprobadas. Los auxiliares se eliminan al finalizar correctamente; si ocurre un fallo, pueden permanecer hasta la siguiente ejecución o hasta eliminar la copia de pruebas.

### Hallazgos actuales

Los periodos actuales de sugerencia y carta del poblado no se solapan y cumplen los 14 días de prueba.

Los poblados 02 y 06 crean el permiso GESTIONAR_PLATOS y lo asignan a administrador y encargado, por lo que la comprobación «Integracion: encargado gestiona platos» debe resultar OK. Los recuentos esperados son 8 permisos y 16 asignaciones de permisos a roles.

Al modificar los permisos del poblado deben actualizarse también sus recuentos esperados.

### Límites y validación

El archivo se ha revisado estáticamente, pero esta versión autónoma no se ha ejecutado en MariaDB en el entorno de preparación. Los resultados previstos no equivalen a resultados observados. Debe conservarse la salida real obtenida en la versión utilizada por el equipo, indicando su fecha.

Quedan como PENDIENTE las pruebas coordinadas de concurrencia (también para los triggers de precios, recetas y unidades, que comprueban sin bloqueos), los privilegios operativos y la cobertura adicional del poblado opcional 06.

La detección de NULL al calcular un coste complementa, pero no sustituye, a los triggers que impiden registrar composiciones inválidas.

Las pruebas admiten uno de los poblados: 02 o 06, nunca ambos sobre la misma copia. La ruta alternativa es 01 → 06 → 07. Instalar 04/05 después permite ejecutar negocio en esa copia; si las regresiones de 06 ya dejaron sus datos auxiliares, se registran como PENDIENTE en lugar de repetirse.

## Alcance acordado para la entrega de clase

La revisión del 12/11/2026 incorpora los puntos 5, 6, 7, 10 y la protección mínima del 8 de la lista de incidencias. El punto 1 ya está corregido en 06. La ejecución completa (punto 2) queda aplazada; los nuevos casos de prueba están escritos, pero no ejecutados en MariaDB durante esta revisión.

C-26 usa fecha_movimiento e id_movimiento con ROWS UNBOUNDED PRECEDING, igual que los procedimientos, para detectar negativos intermedios incluso con movimientos simultáneos. En C-12/C-13, «cantidad disponible» significa saldo registrado; no garantiza aptitud para elaboración. Se conserva ese nombre y se consultan aparte caducidad, frescura y aptitud.

Se mantienen fuera del alcance actual los privilegios MariaDB, la concurrencia general, el historial de aptitud, usuario/motivo en movimientos y ajustes, la relación entre ingrediente retirado y receta destino y la ampliación de permisos. RN-02 sigue exigiendo administrador activo; fn_tiene_permiso conserva su comportamiento actual para administradores incluso ante nombres de permiso inexistentes. Se mantiene la convención local Europe/Madrid y su limitación durante cambios de hora, sin añadir configuración de conexión. Estas limitaciones no se consideran funcionalidad implementada.
