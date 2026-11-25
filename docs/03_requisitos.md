# 3. Catálogo de requisitos

Este catálogo reúne los requisitos y las reglas vigentes de Plato-Plató. Sus identificadores se usan en los modelos, los escenarios, los scripts SQL y las pruebas.

## 3.1. Usuarios del sistema

El modelo distingue tres perfiles de usuario: **administrador, encargado y empleado** (RI-01). Son perfiles de aplicación, no cuentas de MariaDB (RNF-01). La entrega de clase se limita a la base de datos: incluye datos de demostración, consultas y operaciones concretas mediante procedimientos. No incluye una aplicación ni flujos completos de alta, modificación y baja de datos maestros.

### US-01 — Administrador

El administrador será, generalmente, uno de los propietarios del restaurante, aunque el sistema permitirá la existencia de varios administradores.

Este rol podrá consultar los datos de usuarios, roles y concesiones de la demostración, así como la información económica y los márgenes de los platos. Podrá realizar las operaciones previstas por los procedimientos según sus permisos. La incorporación a carta se rige por RN-02, no por el nombre del rol.

### US-02 — Encargado

El encargado será, generalmente, el jefe de sala o una persona de confianza designada por el administrador.

Su perfil está orientado a las operaciones de stock, mermas, recetas y periodos de oferta permitidas por sus permisos. No podrá consultar costes ni márgenes por defecto; podrá hacerlo si recibe individualmente `CONSULTAR_COSTES`. La gestión de cuentas de empleados no forma parte de esta entrega.

### US-03 — Empleado

El empleado tendrá el nivel de permisos más limitado de los tres perfiles.

El perfil está orientado a consultar los platos y las recetas necesarios para su preparación y a registrar movimientos de stock y mermas mediante los procedimientos previstos, según sus permisos.

### Cuentas de MariaDB

Para la demostración, cada perfil de aplicación tiene una cuenta local de MariaDB con el nombre del perfil precedido de `pp_`: `pp_administrador`, `pp_encargado` y `pp_empleado`. Sus privilegios permiten consultar las vistas y ejecutar los procedimientos previstos para cada perfil, sin dar acceso directo a las tablas.

MariaDB autentica la conexión y comprueba sus privilegios. A su vez, los procedimientos validan los permisos del usuario de aplicación asociado. Son dos controles distintos: por ejemplo, poder ejecutar el procedimiento de incorporación a carta no sustituye el permiso `AUTORIZAR_CARTA` exigido por RN-02.

## 3.2. Requisitos generales

### RG-01 — Gestión de costes y rentabilidad

El sistema deberá permitir gestionar los costes asociados a los ingredientes, recetas y platos de la carta, con el objetivo de automatizar el cálculo de los escandallos y facilitar el análisis de la rentabilidad del restaurante.

### RG-02 — Control de compras y desperdicio

El sistema deberá permitir gestionar la información relacionada con proveedores, precios de compra, stock y mermas, con el objetivo de mejorar el control de los costes y reducir las pérdidas del restaurante.

### RG-03 — Gestión de usuarios y permisos

La base de datos deberá representar usuarios, roles y permisos adicionales, y aplicar las comprobaciones de acceso previstas para las operaciones de la entrega (RC-10, RNF-01).

## 3.3. Requisitos detallados

### 3.3.1. Requisitos de información

Los requisitos de información describen los datos que el sistema deberá almacenar sobre los principales conceptos del dominio.

#### RI-01 — Usuarios y roles

El sistema deberá almacenar la siguiente información sobre los usuarios:

- Nombre.
- Correo electrónico.
- Contraseña almacenada de forma segura.
- Rol.
- Estado de la cuenta (activa/inactiva).
- Fecha de creación.

El sistema deberá disponer, asimismo, de información sobre los roles existentes y los permisos asociados a cada uno, además de permitir añadir permisos adicionales a cada usuario.

#### RI-02 — Proveedores

El sistema deberá almacenar la siguiente información sobre los proveedores:

- Nombre.
- Persona de contacto (opcional).
- Teléfono (opcional).
- Correo de contacto (opcional). Deberá constar, al menos, un teléfono o un correo.
- Forma de pago.
- Estado del proveedor (activo/inactivo).

#### RI-03 — Ingredientes

El sistema deberá almacenar la siguiente información sobre los ingredientes:

- Nombre.
- Categoría.
- Unidad de medida (por defecto, kilogramos).
- Estado del ingrediente (activo/inactivo).
- Cantidad total disponible, calculada a partir de los lotes existentes.

#### RI-04 — Precios de ingredientes

El sistema deberá almacenar información sobre los precios de compra de los ingredientes:

- Ingrediente.
- Proveedor.
- Precio de compra.
- Unidad a la que corresponde el precio.
- Fecha de inicio de vigencia.
- Fecha de finalización de vigencia, cuando corresponda.
- Indicación de si dicho precio está seleccionado para el cálculo de costes.

El sistema deberá conservar el histórico de precios de los ingredientes.

Cada ingrediente podrá tener, como máximo, un precio seleccionado para el cálculo de costes. La selección es explícita: el sistema no elige automáticamente el precio más barato (RC-05).

#### RI-05 — Platos

El sistema deberá almacenar la siguiente información sobre los platos:

- Nombre.
- Imagen (opcional).
- Descripción.
- Categoría (entrante, plato principal, postre, etc.).
- Menú del día.
- Precio de venta (puede faltar mientras el plato se prepara; es obligatorio para evaluar su incorporación a la carta).
- Porcentaje de margen objetivo (opcional).
- Estado del plato (activo/inactivo), para permitir su gestión por temporadas.
- Receta del plato.

El sistema podrá disponer, además, de información calculada relativa al coste de producción, margen bruto y porcentaje de margen.

#### RI-06 — Recetas

El sistema deberá almacenar la información necesaria para representar la composición de cada receta:

- Nombre.
- Plato al que pertenece, cuando corresponda.
- Cantidad y unidad de rendimiento.
- Estado de la receta (activa/inactiva).
- Ingredientes y/o subrecetas que la componen.
- Cantidad necesaria de cada componente.
- Unidad de medida utilizada.

Una subreceta es una receta utilizada como componente de otra, no una entidad aparte. Una receta puede reutilizarse en varias recetas, tanto si pertenece a un plato como si no.

#### RI-07 — Lotes

El sistema deberá almacenar la siguiente información sobre los lotes de ingredientes:

- Ingrediente al que pertenece el lote.
- Identificador del lote.
- Cantidad, calculada como saldo de sus movimientos de stock.
- Fecha de entrada.
- Fecha de caducidad (opcional).
- Fresco (indicador lógico del lote, no del ingrediente).
- Apto para el consumo (indicador lógico).
- Ubicación en el almacén.

#### RI-08 — Movimientos de stock

El sistema deberá almacenar información sobre los movimientos de stock de los ingredientes:

- Lote afectado.
- Tipo de movimiento (entrada, salida o ajuste).
- Cantidad.
- Fecha del movimiento.
- Finalidad de la salida (elaboración, merma u otra), cuando el movimiento sea una salida.
- Plato de destino, cuando la salida se destine a elaborar un plato.

El inventario registra existencias de ingredientes por lote, no existencias de recetas ni de platos elaborados. Una salida de elaboración descuenta los ingredientes de los lotes.

#### RI-09 — Mermas

El sistema deberá almacenar información sobre las mermas producidas en el restaurante:

- Elemento afectado (lote o plato).
- Cantidad desperdiciada.
- Fecha de la merma.
- Motivo de la merma (caducidad, deterioro, elaboración incorrecta, plato desechado u otro), con un detalle opcional en texto libre.
- Coste de la pérdida, cuando se conozca.

#### RI-10 — Oferta y autorizaciones

El sistema almacenará los periodos de oferta de cada plato, indicando su tipo (sugerencia del chef o carta permanente) y sus fechas de inicio y finalización. Para cada incorporación a la carta permanente conservará la autorización correspondiente, su emisor, fecha, coste evaluado y precio de venta evaluado.

#### RI-11 — Unidades de medida

El sistema deberá almacenar las unidades de medida admitidas, con su código, nombre, magnitud (masa, volumen, unidad o ración) y factor de conversión a la unidad base de su magnitud.

### 3.3.2. Requisitos funcionales

Los requisitos funcionales (RF) describen las operaciones que deberá ofrecer la base de datos. Se distingue entre la carga inicial de datos de demostración, las consultas a demanda y las operaciones realizadas mediante procedimientos. Las reglas de conducta (RC) describen las restricciones que deben respetar los datos y las operaciones.

#### RF-01 — Consulta de usuarios y permisos

El poblado deberá incluir usuarios de aplicación, roles y concesiones de demostración. Se podrán consultar las cuentas, su estado, su rol y los permisos concedidos por rol o individualmente. El alta, la edición y la desactivación de cuentas de aplicación, así como la gestión interactiva de sus concesiones, quedan fuera de esta entrega.

#### RF-02 — Consulta de proveedores

El poblado deberá incluir proveedores con sus datos de contacto, forma de pago y estado. La entrega deberá permitir consultarlos, sin ofrecer un flujo operativo de alta, edición o desactivación.

#### RF-03 — Consulta de ingredientes y existencias

El poblado deberá incluir ingredientes, sus unidades de medida y lotes de demostración. La entrega deberá permitir consultar la unidad, los lotes y las existencias por ingrediente. Los movimientos se registrarán según RF-09; no se incluye un flujo de mantenimiento del catálogo de ingredientes.

#### RF-04 — Consulta del histórico de precios

El poblado deberá incluir precios de compra por ingrediente y proveedor, con sus vigencias y la selección para el cálculo de costes. La entrega deberá permitir consultar el histórico y sus variaciones. No se incluye un flujo operativo de edición de precios o de cambio de la selección.

#### RF-05 — Consulta de platos y gestión de su oferta

Los platos de demostración se cargarán con el poblado. La entrega deberá permitir consultar sus datos y su historial de oferta, así como registrar sugerencias, incorporar platos a la carta y cerrar periodos de oferta mediante procedimientos. La incorporación a carta deberá cumplir RN-02 y RN-04. No se incluye un flujo de alta, edición o desactivación de platos.

#### RF-06 — Alta y consulta de recetas

La entrega deberá permitir consultar la composición y el rendimiento de las recetas, incluidas las subrecetas. Además de las recetas del poblado, un procedimiento deberá permitir dar de alta una receta completa en una sola transacción, con su rendimiento, unidad y componentes (ingredientes o subrecetas), cada uno con su cantidad y unidad. No se incluye un flujo completo de edición de recetas.

#### RF-07 — Cálculo de escandallos

El sistema deberá permitir calcular automáticamente el coste de producción de un plato a partir de los componentes de su receta, sus cantidades y los precios de compra aplicables.

#### RF-08 — Cálculo de rentabilidad

El sistema deberá permitir calcular el margen bruto de cada plato a partir de su coste de producción y su precio de venta.

#### RF-09 — Gestión de stock

La entrega deberá permitir registrar mediante procedimientos y consultar los movimientos de stock de los ingredientes, incluyendo entradas, salidas y ajustes. Se permitirán movimientos con fecha pasada siempre que no provoquen saldos negativos en el momento afectado ni en momentos posteriores (RC-13). Las salidas por merma se registrarán mediante el flujo de RF-10.

#### RF-10 — Gestión de mermas

La entrega deberá permitir registrar mermas mediante un procedimiento y consultar su detalle: elemento afectado, cantidad, motivo y fecha. El coste de la pérdida es opcional: si se conoce, se aporta al registrar la merma y se conserva para su análisis; si no se aporta, queda como desconocido y no se calcula automáticamente.

#### RF-11 — Consulta de subidas del precio de referencia

La entrega deberá ofrecer una consulta a demanda que compare el precio seleccionado y vigente de cada ingrediente con el precio anterior del mismo proveedor, en una unidad común. La consulta mostrará las subidas de al menos el 10 % por defecto, con umbral configurable, y los platos activos que usan el ingrediente. No mide la variación del margen del plato ni envía notificaciones automáticas.

#### RF-12 — Consulta de lotes próximos a caducar

La entrega deberá ofrecer una consulta a demanda de lotes con existencias que aún no hayan caducado y a los que les queden menos de 48 horas por defecto. El plazo de la consulta es configurable y no modifica la regla RN-01. No se incluyen notificaciones automáticas.

#### RF-13 — Comparación de proveedores

El sistema deberá permitir consultar los proveedores que suministran un determinado ingrediente y comparar sus precios para facilitar la selección del proveedor.

### 3.3.3. Reglas de conducta

#### RC-01 — Cantidades de las recetas

El sistema deberá impedir el registro de cantidades de ingredientes o subrecetas, o de rendimientos de receta, iguales o inferiores a cero.

#### RC-02 — Componentes de una receta

Un mismo ingrediente o subreceta no podrá aparecer más de una vez como componente de una misma receta.

#### RC-03 — Precios válidos

El sistema deberá impedir el registro de precios de compra inferiores o iguales a cero.

#### RC-04 — Precios vigentes

Para un determinado proveedor e ingrediente no podrá existir más de un precio de compra vigente simultáneamente. La vigencia se interpreta como un intervalo que incluye su inicio y excluye su fin; un precio sin fecha de fin permanece vigente.

#### RC-05 — Cálculo del coste

El coste de producción de un plato se calcula a partir de la composición registrada, recorriendo las subrecetas. Para cada ingrediente se usa el precio actualmente seleccionado si está vigente en la fecha de referencia (RI-04, RC-04). El cálculo no filtra por estado del proveedor, del ingrediente ni de la receta:

- **Coste de una línea de ingrediente:** cantidad convertida a la unidad del precio × precio de compra seleccionado y vigente.
- **Coste de una línea de subreceta:** cantidad convertida a la unidad de rendimiento × coste unitario de la receta utilizada.
- **Coste de elaboración de una receta:** suma de los costes de sus líneas.
- **Coste unitario de una receta:** coste de elaboración / cantidad de rendimiento.
- **Coste de producción de un plato:** coste por ración de su receta (RC-15).

#### RC-06 — Actualización del coste

El coste corriente y el margen se derivan al consultar los datos; no se mantienen copias que haya que actualizar al cambiar un precio. Los importes históricos de autorizaciones y mermas se conservan según RC-09.

#### RC-07 — Margen bruto

El margen bruto por unidad de un plato se calculará como la diferencia entre su precio de venta y su coste de producción.

#### RC-08 — Margen objetivo

Cada plato podrá tener un porcentaje de margen objetivo opcional, expresado sobre su precio de venta. Se utilizará para evaluar si el margen calculado alcanza el objetivo, no como condición para autorizar la incorporación a carta (RN-02).

#### RC-09 — Integridad del histórico

Los movimientos de stock, las mermas y las autorizaciones registradas no se modifican ni se eliminan. Una corrección de inventario se registra como un ajuste nuevo: no modifica ni anula una merma ni su importe. Las autorizaciones conservan el coste y el precio evaluados y las mermas conservan el importe aportado, si se conoce. No se eliminan los datos referenciados si con ello se pierde información histórica.

#### RC-10 — Permisos según el rol

Las operaciones se autorizan para usuarios de aplicación activos según los permisos concedidos a su rol o individualmente. En las comprobaciones generales, el administrador activo dispone de acceso general; RN-02 exige una concesión explícita incluso para él. Los permisos de aplicación no otorgan por sí solos privilegios a las cuentas de MariaDB (RNF-01).

#### RC-11 — Coste calculable

Si alguna rama de la receta no puede costearse, el coste queda sin valor (`NULL`): no se sustituye por cero ni se devuelve un total parcial. Esto incluye la falta de un precio seleccionado y vigente, las unidades incompatibles, las recetas sin componentes y las dependencias cíclicas. El modelo tecnológico documenta el límite técnico del recorrido.

#### RC-12 — Recetas cíclicas

Una receta no podrá contenerse a sí misma, ni directa ni indirectamente, mediante una cadena de subrecetas.

#### RC-13 — Saldo no negativo

El saldo de un lote no podrá ser negativo en ningún instante. Al registrar un movimiento, incluso con fecha pasada, deberá comprobarse tanto el momento afectado como todos los posteriores.

#### RC-14 — Merma exclusiva y sin doble descuento

Cada merma afectará exactamente a un lote o a un plato. El procedimiento de registro guardará en una sola transacción la merma de lote y su única salida con finalidad `MERMA`, para el mismo lote, cantidad y fecha. Una merma de plato no generará movimientos de stock, porque sus ingredientes ya se descontaron al elaborarlo. El importe de pérdida, cuando se conozca, se aporta según RF-10.

#### RC-15 — Unidades compatibles

Una cantidad solo podrá convertirse a otra unidad de su misma magnitud mediante los factores de conversión de RI-11. La receta de un plato deberá usar la unidad base `racion` (magnitud `RACION`, factor 1). Las demás recetas podrán declarar el rendimiento en otra unidad; las cantidades de subreceta se convierten a su unidad de rendimiento al costear (RC-05).

#### RC-16 — Periodos de oferta sin solape

Un plato no podrá tener dos periodos de oferta simultáneos, sean o no del mismo tipo. El periodo se interpreta como un intervalo que incluye su inicio y excluye su fin.

#### RC-17 — Coherencia de los movimientos

Las entradas y salidas tendrán cantidad positiva; los ajustes, cantidad no nula con signo. Solo las salidas tendrán finalidad. Una salida tendrá plato de destino si y solo si su finalidad es la elaboración. Ningún movimiento de un lote podrá ser anterior a su fecha de entrada, y el primero será su entrada.

### 3.3.4. Reglas de negocio

Las reglas de negocio representan políticas internas adoptadas por Plato-Plató. Sus plazos, porcentajes y umbrales son decisiones del restaurante, no restricciones universales del sector.

#### RN-01 — Aprovechamiento de ingredientes próximos a caducar

Los lotes de ingredientes perecederos a los que les queden menos de 48 horas para alcanzar su fecha de caducidad solo podrán destinarse a la elaboración de platos del menú del día, siempre que sigan siendo aptos para el consumo.

*Criterio de aplicación:* es perecedero el lote que tiene fecha de caducidad. El plazo se evalúa en la fecha del movimiento. Un lote caducado o no apto no puede destinarse a ningún plato.

#### RN-02 — Incorporación a la carta

Toda incorporación de un plato a la carta permanente deberá ser autorizada por un usuario activo con el permiso `AUTORIZAR_CARTA`, concedido por su rol o individualmente. La autorización se registrará a más tardar al inicio del periodo y conservará el emisor, la fecha, el coste evaluado y el precio de venta evaluado. Para autorizar se exige un coste calculable y un precio de venta definido, pero no un umbral de margen.

*Criterio de aplicación:* la autorización se exige en cada incorporación, también tras una retirada de la carta. El rol de administrador no sustituye la concesión de `AUTORIZAR_CARTA`. La prueba de 14 días solo se exige para la primera incorporación (RN-04).

#### RN-03 — Política interna de frescura

Los lotes catalogados por el restaurante como frescos no podrán utilizarse una vez transcurridas 72 horas desde la recepción de su lote, aunque su fecha de caducidad sea posterior.

*Criterio de aplicación:* la prohibición rige desde el instante de recepción más 72 horas, incluido. Impide elaborar con el lote, pero no registrar después su merma.

#### RN-04 — Prueba de nuevos platos

Todo plato de nueva creación deberá ofrecerse inicialmente durante un mínimo de catorce días como sugerencia del chef antes de poder incorporarse a la carta permanente.

*Criterio de aplicación:* es de nueva creación el plato que aún no ha tenido ningún periodo de carta permanente. En su primera incorporación se exige que un solo periodo cerrado de sugerencia del chef reúna al menos 14 días consecutivos y termine a más tardar al inicio de la carta. No se suman varios periodos ni se repite la prueba para posteriores incorporaciones.

### 3.3.5. Requisitos no funcionales

#### RNF-01 — Control de acceso

La entrega deberá incluir cuentas operativas autenticadas por MariaDB y con privilegios diferenciados, comprobables mediante operaciones permitidas y denegadas al conectarse con cada cuenta. Las cuentas del servidor se distinguen de los usuarios y permisos de aplicación (RI-01, RC-10). Las comprobaciones sobre un usuario de aplicación no sustituyen la autenticación de la conexión; la autenticación propia de una futura aplicación queda fuera de esta entrega.

Las tres cuentas operativas de demostración solo tendrán acceso a las vistas y los procedimientos públicos que se les concedan en MariaDB, sin acceso directo a las tablas. En particular, el privilegio SQL de ejecutar la incorporación a carta no sustituye el permiso de aplicación `AUTORIZAR_CARTA` exigido por RN-02.

#### RNF-02 — Seguridad de las credenciales

Las contraseñas de los usuarios de aplicación no se almacenarán en texto plano. El poblado deberá almacenar hashes generados con scrypt y una sal individual. El `CHECK` de longitud mínima del valor almacenado es solo una comprobación estructural: no acredita el algoritmo ni la seguridad del hash.

#### RNF-03 — Disponibilidad

En un futuro despliegue, el sistema deberá estar disponible durante el horario habitual del restaurante. La disponibilidad no se verifica en esta entrega de clase.

#### RNF-04 — Rendimiento

El rendimiento de las operaciones habituales se deberá evaluar en un futuro despliegue con una carga representativa. La entrega de clase no fija ni acredita tiempos de respuesta.

#### RNF-05 — Usabilidad e integración

La base de datos deberá ofrecer consultas y procedimientos documentados que puedan integrarse en una futura aplicación. No se incluye una interfaz ni un servicio de aplicación en esta entrega.

#### RNF-06 — Integridad de los datos

El esquema deberá aplicar sus restricciones declarativas, y las operaciones de escritura de la entrega deberán respetar las reglas de integridad que validan sus procedimientos y triggers. Los controles de diagnóstico complementan esas garantías, pero no impiden por sí mismos escrituras incoherentes.

## 3.4. Matriz de trazabilidad

La siguiente matriz relaciona los requisitos generales con los requisitos detallados. La trazabilidad completa de cada regla hasta el modelo, el código y las pruebas se presenta en el modelo tecnológico.

| Requisito | RG-01 | RG-02 | RG-03 |
|---|---|---|---|
| **Requisitos de información** | | | |
| RI-01 — Usuarios y roles | | | ● |
| RI-02 — Proveedores | | ● | |
| RI-03 — Ingredientes | ○ | ● | |
| RI-04 — Precios de ingredientes | ● | ● | |
| RI-05 — Platos | ● | | |
| RI-06 — Recetas | ● | | |
| RI-07 — Lotes | | ● | |
| RI-08 — Movimientos de stock | | ● | |
| RI-09 — Mermas | | ● | |
| RI-10 — Oferta y autorizaciones | ○ | | ○ |
| RI-11 — Unidades de medida | ● | ○ | |
| **Requisitos funcionales** | | | |
| RF-01 — Consulta de usuarios y permisos | | | ● |
| RF-02 — Consulta de proveedores | | ● | |
| RF-03 — Consulta de ingredientes y existencias | ○ | ● | |
| RF-04 — Consulta del histórico de precios | ● | ● | |
| RF-05 — Consulta de platos y gestión de su oferta | ● | | |
| RF-06 — Alta y consulta de recetas | ● | | |
| RF-07 — Cálculo de escandallos | ● | | |
| RF-08 — Cálculo de rentabilidad | ● | | |
| RF-09 — Gestión de stock | | ● | |
| RF-10 — Gestión de mermas | | ● | |
| RF-11 — Consulta de subidas del precio de referencia | ● | | |
| RF-12 — Consulta de lotes próximos a caducar | | ● | |
| RF-13 — Comparación de proveedores | ● | ● | |
| **Reglas de conducta** | | | |
| RC-01 — Cantidades de las recetas | ● | | |
| RC-02 — Componentes de una receta | ● | | |
| RC-03 — Precios válidos | ● | ● | |
| RC-04 — Precios vigentes | ● | ● | |
| RC-05 — Cálculo del coste | ● | | |
| RC-06 — Actualización del coste | ● | | |
| RC-07 — Margen bruto | ● | | |
| RC-08 — Margen objetivo | ● | | |
| RC-09 — Integridad del histórico | ○ | ○ | |
| RC-10 — Permisos según el rol | | | ● |
| RC-11 — Coste calculable | ● | | |
| RC-12 — Recetas cíclicas | ● | | |
| RC-13 — Saldo no negativo | | ● | |
| RC-14 — Merma exclusiva y sin doble descuento | ○ | ● | |
| RC-15 — Unidades compatibles | ● | ○ | |
| RC-16 — Periodos de oferta sin solape | ○ | | |
| RC-17 — Coherencia de los movimientos | | ● | |
| **Reglas de negocio** | | | |
| RN-01 — Aprovechamiento de ingredientes próximos a caducar | | ● | |
| RN-02 — Incorporación a la carta | ● | | ● |
| RN-03 — Política interna de frescura | | ● | |
| RN-04 — Prueba de nuevos platos | ○ | | |
| **Requisitos no funcionales** | | | |
| RNF-01 — Control de acceso | | | ● |
| RNF-02 — Seguridad de las credenciales | | | ● |
| RNF-03 — Disponibilidad | ○ | ○ | ○ |
| RNF-04 — Rendimiento | ○ | ○ | ○ |
| RNF-05 — Usabilidad e integración | ○ | ○ | ○ |
| RNF-06 — Integridad de los datos | ○ | ○ | ○ |

**Leyenda:** ● relación directa; ○ relación complementaria o transversal; celda vacía: sin relación significativa.
