# 6. Modelo tecnológico

## 6.1. Script de creación de tablas y restricciones

El archivo `sql/01_tablas.sql` crea una base nueva `plato_plato` y sus 17 tablas. No elimina objetos existentes ni incluye datos iniciales. Se ejecuta completo, deteniéndose al primer error. Usa InnoDB, utf8mb4 y modo estricto. El DDL puede realizar commits implícitos; no debe tratarse como una migración reversible mediante ROLLBACK.

### Decisiones físicas

- Identificadores: INT UNSIGNED autogenerados; claves compuestas en las dos concesiones N:M.
- Unidades: código ASCII binario de hasta 10 caracteres, magnitud y factor positivo DECIMAL(18,6). La unidad base de cada magnitud deberá fijarse en los datos iniciales.
- Cantidades y rendimientos: DECIMAL(14,4); precios de compra: DECIMAL(14,4); precios de venta e importes históricos: DECIMAL(14,2). El redondeo económico final corresponde a las rutinas de cálculo.
- Fechas: `DATETIME(6)` en hora local Europe/Madrid, sin almacenar la zona horaria. `DEFAULT CURRENT_TIMESTAMP` exige que la conexión tenga la hora local correcta; el script no configura la zona con nombre porque depende de las tablas horarias del servidor. Los plazos de RN-01 y RN-03 se calculan en hora local, no como tiempo real transcurrido al cruzar un cambio de hora. Si se necesitan horas reales, habría que migrar coherentemente a UTC.
- Nombres únicos según el MR. La colación utf8mb4_unicode_ci compara sin distinguir mayúsculas; deben revisarse sus efectos sobre las denominaciones del catálogo.
- Porcentaje objetivo opcional en [0,100); imágenes y costes desconocidos admiten NULL.
- FK restrictivas, salvo concesiones y composición ON DELETE CASCADE y códigos de unidad ON UPDATE CASCADE, según 5.1.4. Como un cambio de código, magnitud o factor de una unidad en uso lo rechaza un trigger de 05, el CASCADE solo actúa sobre unidades sin datos relacionados.
- Columna VIRTUAL única para un único precio seleccionado por ingrediente. La vigencia sigue siendo una comprobación posterior.
- La longitud mínima del hash evita cadenas triviales, pero no demuestra que se haya aplicado un algoritmo seguro. El hash se genera fuera de SQL.

### Cobertura del DDL y trabajo pendiente

| Regla | Garantía declarativa incluida | Pendiente de otros bloques |
|---|---|---|
| RC-01–03 | Cantidades, rendimientos y precios positivos; componentes únicos | — |
| RI-04, RC-04, RC-05 | Fechas ordenadas, inicio único por proveedor/ingrediente y selección única | Validación al costear (funciones de 04). Solapamientos de vigencias: triggers `trg_precio_*` de 05; concurrencia pendiente |
| RC-05–08, RC-11 | Objetivo opcional en rango; derivados ausentes de las tablas | Funciones de coste, margen, propagación de NULL y permisos en 04; consultas en 03 |
| RC-09–10 | FK según política y tablas de permisos | Protección del historial en 05, permisos de aplicación en 04 y cuentas operativas de demostración en 08 |
| RC-12 | Impide receta componente igual a receta contenedora | Ciclos indirectos, incluidos UPDATE: triggers `trg_componente_*` de 05. Alta completa en 04 y protección de la última línea en 05; inserción manual de cabeceras vacías aún posible |
| RC-13 | Signo según tipo de movimiento | Saldos históricos comprobados en sp_registrar_movimiento y sp_registrar_merma; concurrencia general no certificada |
| RC-14 | Merma de lote o plato; movimiento obligatorio solo para lote y único | Alta atómica en 04 y coherencia merma/salida en 05. El procedimiento de movimientos rechaza MERMA; la escritura directa aún puede crear salidas huérfanas |
| RC-15 | FK a unidades y factor positivo | Magnitudes compatibles y cambios en datos relacionados: triggers de 05. Para recetas de platos se exige `racion`, magnitud `RACION` y factor 1 |
| RC-16 | Inicio único y fin posterior | Solapamientos comprobados en 05; procedimientos de oferta bloquean el plato |
| RC-17 | Coherencia entre tipo, signo, finalidad y destino | Fecha del lote y primera entrada en procedimientos; 05 bloquea cambios de ingrediente y recepción de lotes con movimientos |
| RN-01–04 | Estructura de lotes, oferta y autorizaciones | Comprobaciones temporales y de aptitud en 05, prueba previa y permiso explícito `AUTORIZAR_CARTA` en 04/05. No se reconstruye aptitud histórica ni se comprueba pertenencia del ingrediente a la receta destino |
| RNF-02 | Hash de longitud mínima | Algoritmo seguro y verificación externa |

`sp_registrar_receta` registra la receta y sus componentes en una transacción y exige al menos una línea. Los triggers impiden borrar o trasladar la última línea de una receta conservada. Una cuenta con escritura directa aún puede insertar una cabecera vacía; las cuentas operativas de 08 no tienen ese acceso. El DDL no garantiza autorización para cada periodo de carta: `sp_incorporar_carta` inserta periodo y autorización en la misma transacción y 08 evita que esas cuentas eludan el procedimiento mediante escrituras directas.

Toda validación entre filas necesita una estrategia de concurrencia. Comprobar mediante SELECT sin acordar bloqueos no garantiza por sí solo que dos operaciones simultáneas mantengan saldos y periodos válidos.

## 6.2. Poblado de la base de datos mediante sentencias INSERT

El poblado inicial se realiza mediante el archivo `02_datos.sql`, que contiene sentencias `INSERT` con datos ficticios y coherentes para comprobar las relaciones del modelo y disponer de ejemplos para las consultas y los siguientes apartados del proyecto.

### Datos incluidos

| Área | Registros incluidos |
| --- | --- |
| Acceso | 3 roles, 8 permisos, 4 usuarios, 15 pares rol-permiso (8 de administrador, 5 de encargado y 2 de empleado) y 1 concesión individual. |
| Unidades | 6 unidades: gramos, kilogramos, mililitros, litros, unidades y raciones. |
| Compras | 3 proveedores, 8 ingredientes y 10 precios de compra. |
| Cocina | 3 recetas, 2 platos y 11 componentes de receta. |
| Inventario | 8 lotes y 22 movimientos de stock. |
| Mermas | 3 mermas: dos de ingredientes y una de un plato elaborado. |
| Oferta | 4 periodos de oferta y 2 autorizaciones de incorporación a carta. |

Los usuarios representan los perfiles de administrador, encargado y empleado. Luis está inactivo; Marta recibe `CONSULTAR_COSTES` como concesión individual y el encargado no lo tiene en el poblado. `GESTIONAR_PLATOS` se concede a administrador y encargado; `AUTORIZAR_CARTA`, solo al rol `ADMINISTRADOR`. Estas son concesiones de aplicación; no amplían los privilegios MariaDB de 08.

Los proveedores e ingredientes incluyen registros activos e inactivos. Los precios permiten comparar dos proveedores para el tomate y consultar un precio histórico cerrado. Cada ingrediente activo tiene un único precio seleccionado para costeo; el perejil, inactivo, solo conserva un precio histórico. Los importes se expresan en euros.

Se incluyen las recetas de salsa de tomate, pasta con tomate y tortilla de patatas. La salsa es una subreceta utilizada por la pasta y rinde 1 kg por elaboración, considerando la reducción durante la cocción. Las recetas de pasta y tortilla producen cuatro raciones cada una. Los componentes utilizan gramos y mililitros aunque los ingredientes se valoren por kilogramo o litro, lo que permite probar conversiones dentro de la misma magnitud.

Los platos tienen precio de venta y margen objetivo. La pasta pertenece al menú del día. No se insertan costes calculados ni márgenes reales en la tabla de platos, ya que esos resultados se obtendrán posteriormente.

### Inventario y mermas

Los movimientos incluyen entradas, salidas para elaboración, salidas por merma y ajustes de inventario positivos y negativos. Las cantidades se expresan en la unidad del ingrediente asociado al lote. No se lleva stock de recetas ni subrecetas: elaborar platos descuenta ingredientes de sus lotes. Las salidas de elaboración corresponden a ocho raciones de pasta y cuatro de tortilla, incluyendo el consumo proporcional de ingredientes de la salsa.

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

El saldo se obtiene sumando entradas y ajustes con su signo y restando las salidas. No se almacena directamente en los lotes. Los ajustes de ejemplo representan diferencias detectadas en el recuento físico; los movimientos, incluidos los ajustes, no registran el usuario responsable ni el motivo.

### Oferta y autorizaciones

Cada plato pasa por un periodo de sugerencia del chef antes de incorporarse a la carta permanente. Los intervalos de un mismo plato no se solapan. Ana, usuaria activa con `AUTORIZAR_CARTA` por su rol, autoriza durante la prueba y antes del comienzo de la carta permanente.

Las autorizaciones conservan costes evaluados por ración de 0,72 € para la pasta y 0,84 € para la tortilla, redondeados a dos decimales, junto con sus precios de venta. Son importes históricos del ejemplo, no resultados que el script calcule automáticamente.

### Ejecución y alcance

El archivo se ejecuta una sola vez después de `01_tablas.sql`, sobre las tablas vacías de `plato_plato`. Utiliza identificadores explícitos para que las referencias entre registros sean claras. No elimina datos ni está diseñado para ejecutarse repetidamente: una segunda ejecución produciría conflictos de claves.

Los registros se insertan respetando las dependencias de claves foráneas, dentro de una transacción. El cliente debe detenerse ante el primer error y ejecutar `ROLLBACK` en esa misma conexión; no debe continuar hasta `COMMIT` si una sentencia falla. Un error de sentencia no implica por sí solo que MariaDB revierta toda la transacción.

Las fechas son fijas y representan hora local de Europe/Madrid. El conjunto describe un escenario de demostración de octubre y noviembre de 2026; no pretende mantener vigentes los lotes conforme avance la fecha real.

Las contraseñas se han derivado fuera de SQL mediante scrypt con una sal aleatoria diferente por usuario. El formato almacenado es `scrypt$16384$8$1$sal_hex$hash_hex`, con clave derivada de 64 bytes. La contraseña de prueba de todos los usuarios es `DemoPlato2026!`. Estas credenciales son exclusivamente de demostración; la aplicación deberá implementar la verificación de este formato o sustituir los hashes por los del algoritmo que utilice.

La carga directa no instala procedimientos ni dispara los triggers de 05 en el orden de referencia. Para comprobar los datos cargados se usan los controles de 03 y el bloque de esquema de 07; el bloque de negocio prueba las operaciones tras instalar 04 y 05 (véase 6.7).

## 6.3. Script de consultas a tablas en SQL

El archivo `03_consultas.sql` contiene 27 consultas numeradas (C-01 a C-27) que se ejecutan después de `01_tablas.sql` y `02_datos.sql`. Solo lee datos: no crea objetos ni modifica filas, por lo que puede ejecutarse tantas veces como se quiera. No depende de funciones, procedimientos ni triggers; los atributos derivados (saldos, costes y márgenes) se calculan en la propia consulta a partir de las tablas.

### Parámetros

Al principio del script se fijan tres variables. `@ahora` es el instante en que se evalúan vigencias, saldos y plazos; se fija en el 15 de noviembre de 2026 a las 12:00, dentro del escenario de ambos poblados, y puede sustituirse por `NOW(6)` para consultar la situación real. RF-11 muestra subidas del precio de referencia de al menos `@porcentaje_aviso_precio` (10 % por defecto); RF-12 muestra lotes con existencias que aún no han caducado y a los que les quedan menos de `@horas_aviso_caducidad` (48 horas por defecto). Cambiar el umbral de la consulta no modifica RN-01.

### Consultas incluidas

| Bloque | Consultas | Contenido | Requisitos |
| --- | --- | --- | --- |
| Acceso | C-01, C-02 | Cuentas con su rol y recuentos; concesiones registradas para usuarios activos, con su origen (`ROL`, `ADICIONAL` o `ROL Y ADICIONAL`). | RF-01, RC-10, RNF-01 |
| Compras | C-03 a C-06 | Proveedores, comparación de precios vigentes, histórico con variación y avisos de sobrecoste con los platos afectados. | RF-02, RF-04, RF-11, RF-13, RC-04 |
| Recetas | C-07 a C-11 | Composición, subrecetas reutilizadas, escandallo detallado, coste y margen de cada plato, e ingredientes que impiden costear. | RF-06 a RF-08, RC-05 a RC-08, RC-11 |
| Inventario | C-12 a C-16 | Saldo por lote, existencias por ingrediente, extracto de movimientos, avisos de caducidad y existencias que ya no pueden usarse. | RF-03, RF-09, RF-12, RC-13, RN-01, RN-03 |
| Mermas | C-17 a C-20 | Detalle de pérdidas, análisis por motivo, evolución mensual con total e ingredientes con más pérdida. | RF-10, RG-02 |
| Oferta | C-21, C-22 | Historial de periodos con su autorización y platos que ya pueden proponerse para la carta. | RI-10, RN-02, RN-04 |
| Control | C-23 a C-27 | Reglas que el DDL no garantiza: recetas sin componentes, periodos de carta sin autorización, solapes, ciclos, saldos negativos, mermas incoherentes y plazos de RN-01 a RN-04. Deben devolver cero filas. | RC-04, RC-12 a RC-14, RC-16, RN-01 a RN-04 |

Cada consulta va precedida de un comentario con su objetivo, las reglas que trata y la técnica empleada. Se usan combinaciones internas y externas, agrupaciones con `HAVING` y `WITH ROLLUP`, subconsultas escalares, correlacionadas y en `FROM`, `EXISTS` y `NOT EXISTS`, `UNION`, funciones de ventana (`RANK`, `LAG` y sumas acumuladas) y expresiones de tabla comunes recursivas. No se usa `SELECT *`.

C-02 agrupa por usuario y permiso para no duplicar una concesión recibida por ambas vías. No enumera permisos efectivos: no aplica el acceso general del administrador ni informa de los `GRANT` de MariaDB. C-12 y C-13 muestran saldo registrado, no aptitud para elaboración; esta depende también de la caducidad, la frescura y el estado del lote.

Los controles son diagnósticos: no bloquean ni corrigen escrituras. C-23 detecta recetas sin componentes y periodos de carta sin autorización. C-26 detecta saldos negativos, mermas discordantes y salidas por merma sin merma asociada. Para detectar saldos negativos intermedios entre movimientos de igual fecha, ordena por fecha e identificador con un marco `ROWS`, igual que los procedimientos de movimientos. C-27 comprueba el tipo de periodo y la fecha de la autorización; no hay historial de concesiones para saber quién tenía permiso entonces. Tampoco reconstruye la aptitud ni comprueba el destino al menú del día de RN-01.

### Cálculo del coste

Tanto las consultas como las funciones usan la composición registrada y el precio seleccionado actualmente, cuya vigencia se comprueba en la fecha de referencia (RI-04, RC-05). No hay versiones de la composición ni historial de cambios de selección: consultar una fecha pasada no reconstruye el escandallo de entonces y puede devolver `NULL` aunque exista otro precio histórico no seleccionado. El cálculo no filtra por estado del proveedor, del ingrediente ni de la receta. Desactivar un proveedor no cierra automáticamente sus precios.

El coste recorre las subrecetas con una CTE recursiva. Para cada receta se calcula cuántas elaboraciones de cada subreceta necesita, convirtiendo la cantidad a la unidad de rendimiento mediante `factor_a_base`. El precio aplicable de cada ingrediente se convierte a la unidad de la línea. Solo se convierten unidades de la misma magnitud (RC-15).

Para C-09 y C-10 el recorrido admite hasta 64 enlaces de subreceta, igual que `fn_coste_receta`. Un precio no válido, unidades incompatibles, una receta vacía, un ciclo o necesitar un enlace 65 invalidan el coste en vez de devolver cero o un subtotal (RC-11). Para el coste por ración de un plato, la unidad de rendimiento debe ser `racion`, de magnitud `RACION` y factor 1. Los costes se presentan a cuatro decimales; las valoraciones y los porcentajes, a dos.

La comparación entre C-10 y `fn_coste_plato` se recoge en la [verificación de la entrega](#verificación-de-la-entrega).

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
| `fn_tiene_permiso` | Comprueba permisos generales: exige usuario activo y admite al administrador sin comprobar la concesión ni la existencia del nombre solicitado; para los demás exige concesión por rol o individual. No se usa para RN-02. |
| `fn_puede_autorizar_carta` | Exige una cuenta activa y la concesión explícita `AUTORIZAR_CARTA` por rol o individual, sin excepción por ser administrador. |

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

Las operaciones generales comprueban el permiso correspondiente (`CONSULTAR_COSTES`, `GESTIONAR_STOCK`, `REGISTRAR_MERMAS`, `GESTIONAR_PLATOS` o `GESTIONAR_RECETAS`). Para incorporar a carta se aplica RN-02: un administrador sin concesión no puede autorizar y otro usuario activo sí puede si la recibe. Esta regla de negocio es independiente de que en 08 solo `pp_administrador` tenga acceso al procedimiento público de incorporación.

### Alcance

El identificador recibido por un procedimiento de 04 no demuestra la identidad. En la demostración sin aplicación, 08 autentica mediante las cuentas locales de MariaDB y vincula la conexión al usuario de demostración en sus procedimientos públicos (véase 6.8). No expone las rutinas que aceptan un identificador de usuario del llamador.

`sp_registrar_merma` exige el permiso `REGISTRAR_MERMAS`. Para una merma de lote, bloquea el lote, comprueba los saldos históricos y registra conjuntamente la salida y la merma, revirtiendo ambas ante cualquier error. Para una merma de plato no genera movimientos de stock. En ambos casos, el importe total de la pérdida se aporta al registrarla o queda en `NULL` (RI-09, RF-10). No hay valoración automática: el lote no se vincula a un proveedor ni a un precio de compra, así que no se puede deducir su coste real ni verificar la procedencia de una valoración externa. Las mermas registradas son definitivas: no se permite editarlas, borrarlas ni anularlas. Un ajuste de stock no modifica sus importes históricos ni los informes de pérdidas.

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

## 6.5. Script de creación de triggers asociados a reglas de negocio

El archivo `sql/05_triggers.sql` contiene los triggers que aplican las reglas RN-01 a RN-04, protegen los datos históricos relacionados y aplican las reglas de integridad RC-04, RC-12, RC-14, RC-15 y RC-17. Las operaciones que incumplen una comprobación se rechazan mediante `SIGNAL SQLSTATE '45000'`, acompañado de un mensaje explicativo. En total se crean 23 triggers y 2 funciones auxiliares (`fn_validar_precio` y `fn_validar_componente`).

### Reglas implementadas

| Regla | Aplicación |
|---|---|
| **RN-01. Aprovechamiento de ingredientes próximos a caducar** | Antes de registrar una salida para elaboración, se comprueba que el lote sea apto y no esté caducado. Cuando restan menos de 48 horas para su caducidad, solo puede destinarse a un plato del menú del día. |
| **RN-02. Incorporación a la carta** | La autorización debe proceder de un usuario activo con `AUTORIZAR_CARTA` concedido por rol o individualmente, corresponder a un periodo de carta permanente y no fecharse en el futuro ni después de su inicio. Además, se exige un coste calculable y un precio de venta. |
| **RN-03. Política interna de frescura** | Se impide elaborar con un lote fresco desde el instante de recepción más 72 horas, incluido. |
| **RN-04. Prueba de nuevos platos** | La primera incorporación a carta requiere un periodo cerrado de sugerencia del chef de al menos 14 días consecutivos, finalizado a más tardar al comenzar la carta permanente. |
| **RC-04. Vigencias de precio** | Un precio no puede solaparse con otro del mismo proveedor e ingrediente. |
| **RC-12. Ciclos de recetas** | Una línea de receta no puede hacer que una receta quede contenida en sí misma, directa o indirectamente. |
| **RC-15. Unidades compatibles** | Las unidades de precios y componentes deben ser de la misma magnitud que las de su ingrediente o subreceta, y no pueden cambiar unidades, ingredientes o rendimientos que ya tienen datos relacionados. |

### Comprobaciones sobre los lotes

El trigger `trg_movimiento_bi_negocio` aplica RN-01 y RN-03 únicamente a movimientos de tipo `SALIDA` cuya finalidad sea `ELABORACION`. Se considera perecedero el lote con fecha de caducidad.

Las comprobaciones utilizan la fecha del movimiento. Exactamente a 48 horas de la caducidad todavía no se aplica la limitación del menú del día. En cambio, exactamente a las 72 horas desde la recepción ya se prohíbe utilizar un lote fresco.

Las salidas por merma no se consideran elaboración, por lo que estas reglas no impiden retirar un producto caducado o que haya superado el plazo de frescura.

### Autorización e incorporación a la carta

El trigger `trg_autorizacion_bi_negocio` comprueba `fn_puede_autorizar_carta`, el periodo, las fechas y la disponibilidad de un coste calculable y un precio de venta. Calcula y guarda `coste_evaluado` y `precio_venta_evaluado`, sustituyendo los valores proporcionados en la inserción.

Estos importes se conservan como información histórica. No se exige un margen mínimo ni que el precio de venta supere el coste, porque RN-02 no establece ese requisito.

La obligatoriedad de que cada incorporación tenga una autorización se completa mediante `sp_incorporar_carta`. El procedimiento inserta el periodo y su autorización en una única transacción. Las cuentas operativas de 08 no tienen escritura directa sobre ninguna de las dos tablas.

### Periodos de prueba y protección del historial

El trigger `trg_periodo_bi_negocio` impide solapamientos entre periodos de oferta y comprueba la prueba previa exigida por RN-04. Los catorce días deben pertenecer a un único periodo cerrado de sugerencia del chef.

Cada incorporación a la carta requiere autorización, pero la prueba previa solo se exige para la primera incorporación.

Los triggers adicionales impiden modificar o eliminar movimientos y autorizaciones. También protegen los periodos de oferta frente a eliminaciones o cambios de plato, tipo y fecha inicial. Se permite cerrar o acortar un periodo, pero no modificar las fechas finales de las sugerencias cuando ya existe una incorporación a la carta.

Los triggers `trg_merma_bu_historico` y `trg_merma_bd_historico` rechazan cualquier modificación o eliminación de mermas.

### Integridad de precios, recetas y unidades

Los triggers `trg_precio_bi_negocio` y `trg_precio_bu_negocio` aplican RC-04 y RC-15 a los precios de compra. Rechazan vigencias solapadas para un mismo proveedor e ingrediente, y unidades de precio de distinta magnitud que la del ingrediente. Los intervalos incluyen su inicio y excluyen su fin, por lo que dos vigencias contiguas no se consideran solapadas.

Los triggers `trg_componente_bi_negocio` y `trg_componente_bu_negocio` aplican RC-12 y RC-15 a las líneas de receta. Comprueban que la unidad de la línea tenga la misma magnitud que su ingrediente o que el rendimiento de su subreceta, y que la subreceta añadida no pueda alcanzar a la receta contenedora, con lo que se detectan ciclos directos e indirectos, también al modificar líneas.

Los triggers `trg_unidad_bu_negocio`, `trg_ingrediente_bu_negocio` y `trg_receta_bu_negocio` impiden cambiar el código, la magnitud o el factor de una unidad en uso, la unidad de un ingrediente con lotes, precios o componentes, y el rendimiento de una subreceta utilizada por otra receta. De este modo, los datos históricos no se reinterpretan.

Estos triggers comprueban sin bloqueos explícitos: dos conexiones simultáneas podrían crear a la vez dos precios solapados o dos líneas que formen un ciclo. La concurrencia queda pendiente. El procedimiento y los triggers cubren el alta operativa completa y el borrado o traslado de la última línea; una cuenta con escritura directa aún puede insertar una cabecera vacía.

### Nuevas comprobaciones de integridad

- trg_merma_bi_coherencia exige que una merma de lote coincida con su movimiento en lote, cantidad, fecha, tipo SALIDA y finalidad MERMA. UNIQUE(id_movimiento) impide duplicar el enlace. Las mermas de plato siguen sin movimiento.
- `trg_plato_bi_raciones` y `trg_plato_bu_raciones` exigen rendimiento en `racion` (magnitud `RACION`, factor 1, no docenas). `trg_receta_bu_negocio` mantiene esa condición al cambiar la unidad de la receta. Las subrecetas sin plato asociado pueden rendir en kg o litros.
- trg_componente_bd_minimo impide borrar la última línea de una receta conservada. trg_componente_bu_negocio impide trasladarla a otra receta. No se certifica concurrencia entre conexiones.
- `trg_lote_bu_historico` impide cambiar ingrediente o fecha de recepción cuando hay movimientos. No impide editar ubicación, caducidad, frescura o aptitud, ni conserva el historial de aptitud.

### Ejecución y validación

Los archivos se ejecutan con las tablas ya creadas, primero `sql/04_funciones_procedimientos.sql` y después `sql/05_triggers.sql`. Ambos deben estar instalados antes de utilizar los procedimientos.

La instalación de triggers no comprueba retroactivamente los datos que ya existían. Las cuentas con acceso directo, incluida la instaladora, no tienen las restricciones de 08. La concurrencia general no está certificada.

El bloque de negocio de 07 contiene 143 comprobaciones que cubren costes, límites temporales, autorizaciones, saldos, integridad de precios, recetas y unidades, y reversión de operaciones rechazadas. Véase 6.7 para los resultados previos y la validación final pendiente.

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
- **RN-02:** la autorización la emite un usuario activo con concesión explícita `AUTORIZAR_CARTA` por rol o individual, como máximo al inicio del periodo de carta.

Los movimientos se ordenan por fecha y, cuando coinciden, por identificador. El movimiento propuesto se evalúa después de los ya existentes en su misma fecha. La validación se realiza antes de insertarlo y no abre ni confirma transacciones: participa en la transacción del procedimiento principal. Se mantiene la hipótesis de una carga inicial de un solo usuario.

Cualquier incumplimiento lanza un error (`SQLSTATE 45000`) con un mensaje que identifica la regla, y el procedimiento principal revierte toda la carga. La concurrencia no se trata aquí: se asume una carga inicial de un solo usuario sobre tablas vacías.

### Datos cargados

Se carga el escenario de 6.2, con los mismos recuentos, 15 pares rol-permiso y 1 concesión individual. Los identificadores se generan en el orden de la carga y coinciden en una base recién creada. Los movimientos se insertan en el orden cronológico del escenario y se obtienen los mismos saldos finales que con `INSERT`.

Ambos poblados usan las mismas fechas de oferta: la carta permanente comienza el 15/10/2026 para la pasta y el 24/10/2026 para la tortilla, es decir, en el instante en que termina su periodo de sugerencia del chef. Con ello se cumplen RC-16 (sin solapes) y RN-04 (sugerencia cerrada de 14 días, terminada a más tardar cuando empieza la carta). Las autorizaciones son previas al alta en carta.

### Ejecución y alcance

1. Ejecutar `01_tablas.sql`.
2. Ejecutar `06_poblado_procedimientos.sql` con un cliente que admita `DELIMITER` (cliente `mariadb`, DBeaver o MySQL Workbench). El script crea las rutinas y, al final, invoca `CALL pob_poblar_base_datos();`.
3. Comprobar el recuento devuelto por el procedimiento principal.

Las rutinas pueden recrearse cuantas veces se desee (cada una se elimina con `DROP ... IF EXISTS` antes de crearse), pero la carga solo se ejecuta una vez: si la base ya contiene datos, el procedimiento principal se detiene sin modificar nada.

La creación de la merma de lote se realiza dentro de `pob_registrar_merma_lote`, que inserta primero la salida y después la merma con su `id_movimiento`.

Ambos poblados contienen los mismos 15 pares únicos (administrador 8, encargado 5 y empleado 2). Véase 6.7 para la evidencia de ejecución anterior y la cobertura adicional de 06 que sigue pendiente.

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
| Esquema y poblado | 01 y uno de los poblados (02 o 06), sin 04/05. | 66 |
| Funciones, triggers y procedimientos | 01, uno de los poblados y 04/05 completos. | 143 |
| Regresiones del poblado por procedimientos | 06 instalado y sin los lotes auxiliares 9101 a 9103 de una pasada anterior. | 12 |

El archivo define **221 comprobaciones (66 + 143 + 12)**, no todas en una misma pasada. Las marcas `PENDIENTE` no cuentan como comprobaciones aprobadas.

Cuando está instalado `pob_registrar_movimiento`, se ejecutan las pruebas adicionales de salidas y ajustes retroactivos inválidos, movimientos retroactivos válidos, movimientos simultáneos, primera entrada y conservación de la transacción del llamador. Estas pruebas dejan datos auxiliares en la copia, por lo que solo se ejecutan la primera vez: si los lotes auxiliares 9101 a 9103 ya existen, se registra una entrada PENDIENTE en lugar de abortar.

Con 06 presente, las 12 regresiones se añaden al bloque que corresponda en la primera pasada de 07. No validan por completo las demás rutinas de 06 ni la concurrencia.

Las pruebas del esquema comprueban recuentos, claves, campos obligatorios, dominios, cantidades, precios, componentes, saldos y coherencia del poblado.

Las pruebas de funciones comprueban conversiones, costes de ingredientes y subrecetas, márgenes, stock por fecha y permisos. También verifican la propagación de NULL cuando faltan precios o una subreceta está vacía. Las unidades incompatibles y los ciclos indirectos ya no pueden construirse porque los rechazan los triggers de integridad.

Las pruebas de triggers comprueban la protección del historial, los periodos de oferta, las autorizaciones y las reglas temporales. Incluyen los límites exactos de 48 y 72 horas y un periodo de sugerencia de 14 días. También cubren la integridad de precios, recetas y unidades: solape de vigencias (y su límite contiguo, que se permite), unidad de precio o de componente incompatible, ciclo indirecto y cambios de factor, unidad o rendimiento en elementos en uso.

Las pruebas de procedimientos comprueban permisos, movimientos, mermas, sugerencias, incorporación a carta y cierre de periodos. Verifican que una merma de lote genere su salida enlazada y que una merma de plato no vuelva a descontar ingredientes.

Las regresiones incluyen el enlace de mermas, el rechazo de docenas de raciones, el límite de 64 frente a 65 enlaces, el borrado y traslado de componentes, la edición mínima de lotes, el permiso explícito de RN-02, la atomicidad del alta de recetas y el orden de movimientos simultáneos de C-26. La prueba de coste `NULL` por subreceta vacía crea deliberadamente una cabecera vacía manual.

El bloque de negocio añade tres entradas PENDIENTE: concurrencia, privilegios operativos y cobertura adicional de 06. Si 06 está instalado y sus datos auxiliares ya existen por una pasada anterior, aparece una cuarta entrada PENDIENTE. Estas entradas no cuentan como pruebas aprobadas.

### Método

El script crea procedimientos auxiliares con prefijo `pp67_`.

`pp67_caso` ejecuta una sentencia y compara el código de error obtenido con el esperado. En los rechazos de negocio también comprueba el prefijo del mensaje, evitando aprobar una prueba por una regla distinta.

Las operaciones directas compatibles se ejecutan en una transacción que se revierte después de cada caso. Las llamadas a procedimientos autónomos se realizan sin una transacción exterior, porque estos procedimientos gestionan sus propias transacciones.

`pp67_comprobar` registra condiciones y considera NULL como fallo. Los resultados se almacenan en una tabla temporal MEMORY, que los conserva al revertir las operaciones.

Se comprueba expresamente que un error al insertar una merma no deje su salida guardada y que una autorización fallida tampoco deje creado el periodo de carta.

Al finalizar se muestran el detalle y los totales. Si existe algún FALLO, se lanza un error SQL. Las entradas PENDIENTE no se consideran pruebas aprobadas.

### Verificación de la entrega

#### Rutas de ejecución

Utilizar una instancia MariaDB 10.6 o superior dedicada a pruebas. No ejecutar sobre una base con datos reales ni dentro de una transacción de trabajo.

Desde la raíz del repositorio, ejecutar los archivos de `sql/` con un cliente que admita `DELIMITER`, como `mariadb`. Preparar una copia nueva y desechable por ruta; **02 y 06 son alternativas**. No ejecutar 07 en la copia de demostración, pues algunas pruebas confirman escrituras.

| Ruta | Orden | Bloques de 07 |
|---|---|---|
| Pruebas con `INSERT` | `01 → 02 → 03 → 07 → 04 → 05 → 07` | 66 de esquema y después 143 de negocio |
| Pruebas con procedimientos | `01 → 06 → 03 → 07 → 04 → 05 → 07` | 66 de esquema + 12 de movimientos; después 143 de negocio y aviso de que las 12 no se repiten |
| Demostración con cuentas | `01 → (02 o 06) → 04 → 05 → 08` | Sin 07; 03 es una consulta opcional de la cuenta instaladora, no un requisito de 08 |

El archivo utiliza la base `plato_plato`, por lo que debe ejecutarse en un entorno de pruebas separado del entorno de trabajo. No debe utilizarse la opción `--force`.

Las pruebas de negocio crean datos auxiliares. Antes de repetir ese bloque debe prepararse una copia nueva: 07 no elimina ni recrea automáticamente la base.

Se necesitan permisos para crear y eliminar rutinas, crear tablas temporales y ejecutar las operaciones comprobadas. Los auxiliares se eliminan al finalizar correctamente; si ocurre un fallo, pueden permanecer hasta la siguiente ejecución o hasta eliminar la copia de pruebas.

#### Validaciones ya observadas

En ejecuciones anteriores con **MariaDB 13.0.2** se observaron 66 comprobaciones de esquema y 143 de negocio aprobadas en cada ruta de poblado, y las 12 regresiones de movimientos aprobadas en la ruta de 06. Las entradas `PENDIENTE` de la suite no forman parte de esos recuentos.

En ambos poblados se observó que C-10 y `fn_coste_plato` coincidían a cuatro decimales para la fecha de referencia (`2026-11-15 12:00:00`): 0,7232 € por ración para la pasta y 0,8416 € para la tortilla. Redondeados a dos decimales, coinciden con los importes de las autorizaciones de ejemplo (6.2). La suite 07 incluye una referencia SQL independiente para el coste de la pasta, pero no ejecuta C-10.

Por separado se observaron comprobaciones de 08 desde conexiones operativas: acceso a las vistas y llamadas concedidas, denegación de costes al encargado y de proveedores al empleado, y rechazo de escritura directa incluso al administrador y de una llamada del empleado a una rutina interna que acepta un ID de usuario. Estas comprobaciones no son parte de 07 ni certifican todos los privilegios de un despliegue.

#### Validación final pendiente

En la versión de MariaDB de clase, repetir las dos rutas de pruebas sobre copias limpias. Comprobar que C-23 a C-27 devuelven cero filas y volver a contrastar C-10 con `fn_coste_plato` en ambos poblados. En el bloque de negocio de 07, revisar expresamente estos casos:

- **Escenario 5: Incorporación autorizada a la carta (RN-02/RN-04).** Se rechaza al administrador sin `AUTORIZAR_CARTA` y se admite al encargado activo con concesión individual. El periodo y la autorización se guardan juntos, con coste y precio históricos. Se verifica sobre las rutinas de negocio, no desde `pp_encargado`, que no puede ejecutar la incorporación pública de 08.
- **Escenario 6: Límite de 48 horas antes de caducar (RN-01).** Justo a 48 horas se admite una salida para un plato ordinario. Un microsegundo después se rechaza para ese destino y se admite para el menú del día. Las tres salidas se evalúan por separado.

En una copia de demostración separada, comprobar los accesos y llamadas permitidos y denegados de 08 por socket desde las tres cuentas locales, con las claves asignadas y las cuentas desbloqueadas según el [README](../README.md#comprobación-desde-conexiones-separadas). Estas comprobaciones se hacen fuera de 07, que usa una cuenta de pruebas.

Guardar la fecha, la versión exacta de MariaDB y las salidas de consultas, accesos y pruebas (`OK`, `FALLO`, `PENDIENTE`). Las observaciones anteriores no sustituyen la validación final. Las pruebas son secuenciales: no certifican la concurrencia entre conexiones ni cubren por completo las demás rutinas del poblado 06. Tampoco se ha verificado `ONLY_FULL_GROUP_BY`.

## 6.8. Cuentas y privilegios de MariaDB

`sql/08_cuentas_privilegios.sql` se instala una sola vez con una cuenta instaladora, después de 04 y 05 completos y en una instancia donde no existan las tres cuentas locales. Se crean bloqueadas; antes de probarlas, asignar una clave distinta a cada una y desbloquearlas según el README. La cuenta instaladora conserva los privilegios requeridos por los objetos `SQL SECURITY DEFINER`; las restricciones de 08 se aplican solo a las tres cuentas operativas, no a la instaladora ni a otras cuentas.

### Matriz de privilegios de 08

| Privilegio / objetos | `pp_administrador` | `pp_encargado` | `pp_empleado` |
|---|---|---|---|
| `SELECT`: `v_operativa_platos`, `v_operativa_recetas`, `v_operativa_lotes` | Sí | Sí | Sí |
| `SELECT`: `v_gestion_oferta`, `v_gestion_proveedores` | Sí | Sí | No |
| `SELECT`: `v_admin_costes`, `v_admin_usuarios` (sin hashes) | Sí | No | No |
| `EXECUTE`: `sp_demo_registrar_movimiento`, `sp_demo_registrar_merma` | Sí | Sí | Sí |
| `EXECUTE`: `sp_demo_registrar_receta`, `sp_demo_registrar_sugerencia`, `sp_demo_cerrar_periodo` | Sí | Sí | No |
| `EXECUTE`: `sp_demo_consultar_escandallo`, `sp_demo_incorporar_carta` | Sí | No | No |
| Acceso directo a tablas o ejecución directa de funciones y rutinas internas (04, 05, 06, 07 y `fn_demo_usuario_sql`) | No | No | No |

Las cuentas se conectan por socket local. Los procedimientos `sp_demo_*` resuelven con `USER()` el usuario activo de demostración por correo y perfil (Ana, Carlos o Marta), sin aceptar un ID de usuario del cliente. Después aplican las comprobaciones de 04 y 05. Una concesión de aplicación no añade un privilegio SQL: el `CONSULTAR_COSTES` individual de Marta no da acceso a las vistas económicas ni al procedimiento público de escandallo de 08. Del mismo modo, el `EXECUTE` de `pp_administrador` sobre `sp_demo_incorporar_carta` no sustituye el permiso explícito `AUTORIZAR_CARTA`.

### Matriz breve de trazabilidad

| Requisito | Modelo o SQL | Escenario o prueba | Estado |
|---|---|---|---|
| RI-01 a RI-11 | Entidades, atributos y relaciones de los capítulos 4 y 5; DDL de 01 | Inspección del esquema y comprobaciones de 07 | Esquema implementado |
| RF-01 a RF-06 | Poblados 02/06; consultas de 03; alta de receta y oferta en 04 | Consultas y casos de alta y oferta de 07 | Consultas y flujos acotados; sin CRUD completo |
| RF-07/RF-08, RC-05/11/12/15 | C-09/C-10, funciones de coste y triggers de recetas y unidades | Escenarios 1 y 2; concordancia C-10 y función; casos `NULL`, ciclos y límite de 64 en 07 | Concordancia observada a cuatro decimales |
| RF-09/RF-10, RC-13/14/17 | Movimientos y mermas en 04/06; DDL y triggers | Escenario 3; C-26 y casos de saldos y atomicidad de 07 | Implementado en el flujo operativo |
| RF-11 a RF-13 | C-06, C-15 y C-04 | Resultados a demanda sobre el poblado | Consultas implementadas; sin notificaciones |
| RN-01/RN-03 | `sp_registrar_movimiento` y `trg_movimiento_bi_negocio` | Escenarios 6 y 4; casos de aptitud, destino y límites de 48/72 h en 07 | Pruebas secuenciales observadas |
| RN-02/RN-04, RC-10/16 | Concesiones de 01/02/06 y procedimientos y triggers de oferta de 04/05 | Escenario 5; C-23/C-24/C-27 y casos de permiso, reversión, prueba y solape de 07 | Pruebas secuenciales observadas |
| RNF-01/RNF-02 | Cuentas y vistas de 08; hashes de demostración en 02/06 | Conexiones separadas e inspección de los poblados | Accesos observados; sin autenticación de aplicación |
| RNF-03 a RNF-06 | Operaciones documentadas, restricciones y diagnósticos | Ejecución de 07 para integridad | Disponibilidad y rendimiento dependen del despliegue y no se evalúan con los scripts; sin interfaz ni certificación concurrente |
