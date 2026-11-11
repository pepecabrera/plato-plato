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

- **RC-04:** las vigencias de precio de un mismo proveedor e ingrediente no se solapan.
- **RC-13:** una salida o un ajuste no deja el saldo del lote en negativo.
- **RC-14:** la merma de un lote crea de forma atómica su salida con finalidad `MERMA`, con la misma cantidad y fecha, y la enlaza.
- **RC-16:** un plato no tiene dos periodos de oferta simultáneos, sean o no del mismo tipo.
- **RC-17:** el primer movimiento de un lote es su entrada y ningún movimiento es anterior a ella.
- **RN-02:** la autorización de carta la emite un administrador con cuenta activa, antes del inicio del periodo de carta.

Cualquier incumplimiento lanza un error (`SQLSTATE 45000`) con un mensaje que identifica la regla, y el procedimiento principal revierte toda la carga. La concurrencia no se trata aquí: se asume una carga inicial de un solo usuario sobre tablas vacías.

### Datos cargados

Se cargan los mismos registros que en el apartado 6.2 (3 roles, 7 permisos, 4 usuarios, 3 proveedores, 8 ingredientes, 10 precios, 3 recetas, 2 platos, 11 componentes, 8 lotes, 22 movimientos, 3 mermas, 4 periodos de oferta y 2 autorizaciones), con los mismos identificadores resultantes y los mismos saldos finales. Los movimientos se insertan en el orden cronológico del escenario, por lo que el resultado es equivalente al del poblado con `INSERT`.

**Fechas de la carta permanente.** Este script usa como inicio de la carta permanente el 15/10/2026 para la pasta y el 24/10/2026 para la tortilla, es decir, el instante en que termina su periodo de sugerencia del chef. Con ello se cumplen RC-16 (sin solapes) y RN-04 (sugerencia cerrada de 14 días, terminada a más tardar cuando empieza la carta). Las autorizaciones conservan sus fechas originales, que siguen siendo previas al alta en carta.

### Ejecución y alcance

1. Ejecutar `01_tablas.sql`.
2. Ejecutar `06_poblado_procedimientos.sql` con un cliente que admita `DELIMITER` (cliente `mariadb`, DBeaver o MySQL Workbench). El script crea las rutinas y, al final, invoca `CALL pob_poblar_base_datos();`.
3. Comprobar el recuento devuelto por el procedimiento principal.

Las rutinas pueden recrearse cuantas veces se desee (cada una se elimina con `DROP ... IF EXISTS` antes de crearse), pero la carga solo se ejecuta una vez: si la base ya contiene datos, el procedimiento principal se detiene sin modificar nada.

La creación de la merma de lote se realiza dentro de `pob_registrar_merma_lote`, que inserta primero la salida y después la merma con su `id_movimiento`. Si el trigger de inventario previsto para RC-14 (apartado 6.5) crea esa salida de forma automática, deberá ajustarse este procedimiento para insertar la merma sin movimiento y delegar en el trigger, evitando duplicar la salida.

El script se ha comprobado en MariaDB 10.11 sobre una base creada con `01_tablas.sql`: la carga completa coincide con la de `02_datos.sql` salvo las dos fechas indicadas, y los casos de error (referencia inexistente, saldo negativo, solape de precios, solape de periodos, emisor no administrador y segunda ejecución) detienen la carga sin dejar datos parciales.

# 6.7. Script de creación de pruebas y llamadas

El archivo `sql/07_pruebas.sql` crea dos procedimientos auxiliares, ejecuta 66 comprobaciones y elimina las rutinas auxiliares al finalizar. Está adaptado a la instantánea `3d25a51` de la rama `docs/entregable-final`, que contiene únicamente `01_tablas.sql` y `02_datos.sql`.

## Método y cobertura

Se comprueban los recuentos de las 17 tablas del poblado original, 37 operaciones válidas o inválidas, los ocho saldos de inventario y cuatro propiedades de coherencia de datos. Las operaciones abarcan claves únicas y foráneas, valores obligatorios, dominios, cantidades, precios, márgenes, exclusividad de componentes, ciclos directos, movimientos, mermas y fechas.

`pp67_caso` ejecuta una sentencia con SQL preparado, captura el código de error mediante un manejador y lo compara con el código esperado. Esperar un rechazo no basta: un error de sintaxis o una columna inexistente no se considera éxito. Cada operación se revierte a un punto de guardado. `pp67_comprobar` registra el resultado de una condición, considerando NULL como fallo. Las llamadas `CALL` incluidas ejecutan los casos.

Los resultados se guardan en una tabla temporal MEMORY para conservarlos al revertir la transacción. Se muestran el detalle y los totales por resultado. Un FALLO no interrumpe la suite: debe revisarse la tabla de resultados; el código de salida del cliente no certifica que todas las pruebas hayan pasado.

## Ejecución

En una instancia de MariaDB 10.6 o superior dedicada a pruebas, cargar una vez `01_tablas.sql` y después `02_datos.sql`. Ejecutar `07_pruebas.sql` completo en la misma base `plato_plato`, con las comprobaciones de integridad activadas. No ejecutar sobre una base con trabajo real ni dentro de una transacción pendiente: crear o eliminar procedimientos produce commits implícitos. Se necesitan permisos de creación, ejecución y eliminación de rutinas, tablas temporales y acceso a las tablas.

Las escrituras de prueba se revierten; los contadores AUTO_INCREMENT pueden avanzar. Las rutinas con prefijo `pp67_` quedan reservadas para esta suite. Si se interrumpe la ejecución, realizar ROLLBACK o cerrar la conexión antes de volver a ejecutar. La tabla temporal desaparece al cerrar la conexión. El script elimina y recrea sus auxiliares para permitir otra ejecución.

## Hallazgos del poblado recibido

Por inspección del SQL se esperan dos comprobaciones fallidas:

- RC-16: los intervalos de sugerencia y carta se solapan en ambos platos. La pasta tiene sugerencia del 1 al 15 de octubre y carta desde el 8; la tortilla, sugerencia del 10 al 24 y carta desde el 17.
- RN-04: ambos platos pasan a carta a los siete días, antes de completar los catorce requeridos.

Una corrección posible, que debe acordarse con el responsable del 6.2, es mantener los periodos de sugerencia, pasar la pasta a carta el 16 de octubre y autorizarla el 15 a las 18:00; pasar la tortilla a carta el 25 y autorizarla el 24 a las 18:00. No se modifica aquí el trabajo del 6.2. La memoria actual afirma que no hay solapamientos, pero las fechas del SQL contradicen esa afirmación.

## Límites y validación

No se ha ejecutado la suite en MariaDB en el entorno de preparación; se ha revisado estáticamente. Los resultados previstos no son resultados observados. Debe conservarse la salida real al validarla en el entorno del equipo.

El ZIP recibido no contiene funciones, procedimientos de negocio ni triggers. Las pruebas del 6.4 y del 6.5, así como las de concurrencia, se identifican explícitamente como PENDIENTE. Los procedimientos de este archivo son auxiliares de prueba, no la implementación del 6.4. Comprobar que los datos existentes son coherentes no demuestra que el servidor impida insertar datos incoherentes.

Al integrar las rutinas de negocio se debe adaptar la suite a sus firmas y errores reales. Faltan, entre otros: conversiones de unidades y costes recursivos con NULL, ciclos indirectos, vigencias solapadas, saldos históricos y concurrencia, creación atómica de mermas, frescura de 72 horas, caducidad próxima de 48 horas, autorización por administrador y prueba previa de 14 días. Las pruebas negativas deberán incluir INSERT y UPDATE y las fronteras temporales exactas. No se consideran aprobadas por ausencia de implementación.
