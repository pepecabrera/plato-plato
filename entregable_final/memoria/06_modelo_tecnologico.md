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

Los procedimientos de escritura gestionan sus propias transacciones y deben invocarse fuera de una transacción ya abierta. Si una comprobación falla, ejecutan `ROLLBACK` y propagan el error mediante `RESIGNAL`.

El procedimiento de movimientos bloquea el lote durante la operación. Comprueba que ningún movimiento sea anterior a su recepción, que el primero sea una entrada y que todos los saldos acumulados sean no negativos. Esta última comprobación incluye los movimientos posteriores al que se registra, por lo que también permite detectar inconsistencias al introducir movimientos con fecha pasada.

Los procedimientos de oferta bloquean el plato para coordinar las operaciones sobre sus periodos. La incorporación a la carta inserta primero el periodo y después su autorización dentro de una misma transacción. Si la autorización falla, también se deshace la creación del periodo.

Para los usuarios distintos del administrador, se comprueban los permisos `CONSULTAR_COSTES`, `GESTIONAR_STOCK` y `GESTIONAR_PLATOS`, según la operación. Estos nombres deben coordinarse con los datos iniciales de permisos. La incorporación a la carta exige específicamente un administrador activo.

### Alcance

El identificador de usuario recibido por un procedimiento no demuestra su identidad: la autenticación corresponde a la aplicación. Las cuentas operativas deben utilizar los procedimientos autorizados y no disponer de escrituras directas que permitan eludir sus comprobaciones.

Este archivo no implementa el registro automático de mermas. El procedimiento de movimientos rechaza las salidas con finalidad `MERMA` para evitar crear una salida sin su correspondiente registro de merma. Ese flujo requiere una implementación específica.

Tampoco impide introducir ciclos al editar recetas ni solapamientos de precios. La detección de ciclos durante el cálculo evita devolver un coste válido para una composición cíclica, pero no sustituye la validación de su registro.

## 6.5. Script de creación de triggers asociados a reglas de negocio

El archivo `sql/05_triggers.sql` contiene los triggers que aplican las reglas RN-01 a RN-04 y protegen los datos históricos relacionados. Las operaciones que incumplen una comprobación se rechazan mediante `SIGNAL SQLSTATE '45000'`, acompañado de un mensaje explicativo.

### Reglas implementadas

| Regla | Aplicación |
|---|---|
| **RN-01. Aprovechamiento de ingredientes próximos a caducar** | Antes de registrar una salida para elaboración, se comprueba que el lote sea apto y no esté caducado. Cuando restan menos de 48 horas para su caducidad, solo puede destinarse a un plato del menú del día. |
| **RN-02. Incorporación a la carta** | La autorización debe proceder de un administrador activo, corresponder a un periodo de carta permanente y tener una fecha no posterior a su inicio. Además, se exige un coste calculable y un precio de venta. |
| **RN-03. Política interna de frescura** | Se impide elaborar con un lote fresco desde el instante de recepción más 72 horas, incluido. |
| **RN-04. Prueba de nuevos platos** | La primera incorporación a carta requiere un periodo cerrado de sugerencia del chef de al menos 14 días consecutivos, finalizado a más tardar al comenzar la carta permanente. |

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

### Ejecución y validación

Los archivos se ejecutan con las tablas ya creadas, primero `sql/04_funciones_procedimientos.sql` y después `sql/05_triggers.sql`. Ambos deben estar instalados antes de utilizar los procedimientos.

La instalación de triggers no comprueba retroactivamente los datos que ya existían. Tampoco garantiza por sí sola todas las reglas pendientes del proyecto, como el registro automático de mermas o la validación de cambios en las unidades de medida.

Se ejecutaron 48 casos secuenciales en una base temporal con MariaDB 13.0.2, incluyendo cálculos de costes, límites temporales, autorizaciones, saldos y reversión de operaciones rechazadas. Tras revisar los cierres `END IF`, se volvió a comprobar la creación de los nueve triggers sin errores de sintaxis.

Queda pendiente verificar la versión de MariaDB utilizada en clase, la integración con los demás scripts, los privilegios de las cuentas operativas y la concurrencia con varias conexiones. Estas comprobaciones no sustituyen las pruebas del apartado 6.7.