# 3. Catálogo de requisitos

Los identificadores se conservan respecto a la segunda entrega. La correspondencia con la numeración de la primera entrega y todos los cambios introducidos se recogen en el Anexo A.

## 3.1. Usuarios del sistema

El sistema permitirá el acceso a tres perfiles de usuario, ordenados de mayor a menor nivel de permisos: **administrador, encargado y empleado**.

### US-01 — Administrador

El administrador será, generalmente, uno de los propietarios del restaurante, aunque el sistema permitirá la existencia de varios administradores.

Este rol tendrá acceso a todas las funcionalidades del sistema, incluyendo la gestión de usuarios y la asignación de roles y permisos.

Podrá registrar, modificar, consultar y desactivar proveedores, lotes, ingredientes, platos, recetas y demás elementos gestionados por el sistema. Asimismo, tendrá acceso a la información económica y a los márgenes de los platos.

### US-02 — Encargado

El encargado será, generalmente, el jefe de sala o una persona de confianza designada por el administrador.

Por defecto, tendrá permisos para gestionar ingredientes, platos, proveedores y usuarios con rol de empleado. No tendrá acceso a la información económica ni a los márgenes de los platos, salvo que dichos permisos le sean concedidos por un administrador.

### US-03 — Empleado

El empleado tendrá el nivel de permisos más limitado de los tres perfiles.

Por defecto, podrá consultar los platos y las recetas necesarias para su correcta preparación, así como registrar manualmente las mermas producidas durante la actividad del restaurante.

## 3.2. Requisitos generales

### RG-01 — Gestión de costes y rentabilidad

El sistema deberá permitir gestionar los costes asociados a los ingredientes, recetas y platos de la carta, con el objetivo de automatizar el cálculo de los escandallos y facilitar el análisis de la rentabilidad del restaurante.

### RG-02 — Control de compras y desperdicio

El sistema deberá permitir gestionar la información relacionada con proveedores, precios de compra, stock y mermas, con el objetivo de mejorar el control de los costes y reducir las pérdidas del restaurante.

### RG-03 — Gestión de usuarios y permisos

El sistema deberá permitir gestionar los usuarios, sus roles y sus permisos de acceso, garantizando que cada trabajador pueda realizar únicamente las operaciones autorizadas según su perfil y los permisos adicionales que tenga asignados.

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

#### RI-07 — Lotes

El sistema deberá almacenar la siguiente información sobre los lotes de ingredientes:

- Ingrediente al que pertenece el lote.
- Identificador del lote.
- Cantidad, calculada como saldo de sus movimientos de stock.
- Fecha de entrada.
- Fecha de caducidad (opcional).
- Fresco (indicador lógico).
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

Los requisitos funcionales describen las operaciones y comportamientos que el sistema deberá proporcionar a los usuarios.

#### RF-01 — Gestión de usuarios

El sistema deberá permitir a los usuarios autorizados registrar, modificar, consultar, activar y desactivar cuentas de usuario, así como asignarles un rol o permisos adicionales.

#### RF-02 — Gestión de proveedores

El sistema deberá permitir registrar, modificar, consultar y desactivar proveedores.

#### RF-03 — Gestión de ingredientes

El sistema deberá permitir registrar, modificar, consultar y desactivar ingredientes, incluyendo su unidad de medida y la información relacionada con sus lotes y stock.

#### RF-04 — Gestión de precios

El sistema deberá permitir registrar y actualizar los precios de compra de los ingredientes asociados a sus respectivos proveedores, conservando el histórico de precios.

#### RF-05 — Gestión de platos

El sistema deberá permitir registrar, modificar, consultar y desactivar los platos de la carta.

#### RF-06 — Gestión de recetas

El sistema deberá permitir definir y modificar recetas, sean de un plato o reutilizables como subrecetas, indicando su rendimiento, los ingredientes y/o subrecetas que las forman y la cantidad necesaria de cada componente.

#### RF-07 — Cálculo de escandallos

El sistema deberá permitir calcular automáticamente el coste de producción de un plato a partir de los componentes de su receta, sus cantidades y los precios de compra aplicables.

#### RF-08 — Cálculo de rentabilidad

El sistema deberá permitir calcular el margen bruto de cada plato a partir de su coste de producción y su precio de venta.

#### RF-09 — Gestión de stock

El sistema deberá permitir registrar y consultar los movimientos de stock de los ingredientes, incluyendo entradas, salidas y ajustes. Se permitirá registrar movimientos con fecha pasada, siempre que no provoquen saldos negativos en el momento afectado ni en momentos posteriores (RC-13).

#### RF-10 — Gestión de mermas

El sistema deberá permitir registrar y consultar las mermas producidas, indicando el elemento afectado, la cantidad, el motivo y la fecha de la pérdida, así como analizar el coste de las pérdidas.

#### RF-11 — Alertas de sobrecostes

El sistema deberá permitir generar avisos cuando la variación del precio de un ingrediente provoque un aumento significativo del coste de producción de un plato o una reducción de su margen. Se considera significativo un aumento del precio de al menos el 10 %, valor configurable al solicitar el aviso (S-08).

#### RF-12 — Alertas de caducidad

El sistema deberá permitir generar avisos cuando un lote almacenado se encuentre próximo a su fecha de caducidad. Se considera próximo un lote al que le falten menos de 48 horas, valor configurable al solicitar el aviso (S-08).

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

El coste de producción de un plato deberá calcularse a partir de la suma del coste de todos los componentes necesarios para elaborar una unidad del plato. El cálculo se aplica de forma recursiva a través de las subrecetas:

- **Coste de una línea de ingrediente:** cantidad convertida a la unidad del precio × precio de compra seleccionado y vigente.
- **Coste de una línea de subreceta:** cantidad convertida a la unidad de rendimiento × coste unitario de la receta utilizada.
- **Coste de elaboración de una receta:** suma de los costes de sus líneas.
- **Coste unitario de una receta:** coste de elaboración / cantidad de rendimiento.
- **Coste de producción de un plato:** coste unitario de su receta, cuyo rendimiento se expresa en unidades del plato.

#### RC-06 — Actualización del coste

Cuando cambie el precio aplicable de un ingrediente, el coste de los platos que lo utilicen deberá actualizarse en consecuencia.

#### RC-07 — Margen bruto

El margen bruto por unidad de un plato se calculará como la diferencia entre su precio de venta y su coste de producción.

#### RC-08 — Margen objetivo

El sistema deberá permitir establecer un margen objetivo para los platos, que podrá ser modificado por los usuarios con permisos suficientes.

#### RC-09 — Integridad del histórico

Los elementos que formen parte de información histórica no deberán eliminarse de forma que se pierda dicha información.

#### RC-10 — Permisos según el rol

Cada usuario únicamente podrá realizar las operaciones que correspondan a los permisos asociados a su rol más los permisos adicionales del usuario.

#### RC-11 — Coste calculable

Un plato no podrá considerarse correctamente costeado cuando alguno de los componentes necesarios para su receta, incluidos los de sus subrecetas, no disponga de un precio de compra válido. En ese caso, el coste queda sin valor y no se sustituye por cero.

#### RC-12 — Recetas cíclicas

Una receta no podrá contenerse a sí misma, ni directa ni indirectamente, mediante una cadena de subrecetas.

#### RC-13 — Saldo no negativo

El saldo de un lote no podrá ser negativo en ningún instante. Al registrar un movimiento, incluso con fecha pasada, deberá comprobarse tanto el momento afectado como todos los posteriores.

#### RC-14 — Merma exclusiva y sin doble descuento

Cada merma afectará exactamente a un lote o a un plato. La merma de un lote originará una única salida con finalidad de merma, por la misma cantidad y fecha. La merma de un plato no generará movimientos de stock, porque sus ingredientes ya se descontaron al elaborarlo.

#### RC-15 — Unidades compatibles

Una cantidad solo podrá convertirse a otra unidad de su misma magnitud. No se supone que kilogramos, litros y unidades sean intercambiables. La receta de un plato deberá expresar su rendimiento en raciones.

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

Toda incorporación de un plato a la carta permanente deberá ser autorizada previamente por un administrador, con independencia de su relación entre coste de elaboración y precio de venta. La autorización registrará el administrador, la fecha, el coste evaluado y el precio de venta evaluado. No podrá autorizarse un plato cuyo coste no sea calculable.

*Criterio de aplicación:* se exige en cada incorporación, también en las posteriores a una retirada de la carta. El emisor debe tener rol de administrador y una cuenta activa al autorizar.

#### RN-03 — Política interna de frescura

Los lotes catalogados por el restaurante como frescos no podrán utilizarse una vez transcurridas 72 horas desde la recepción de su lote, aunque su fecha de caducidad sea posterior.

*Criterio de aplicación:* la prohibición rige desde el instante de recepción más 72 horas, incluido. Impide elaborar con el lote, pero no registrar después su merma.

#### RN-04 — Prueba de nuevos platos

Todo plato de nueva creación deberá ofrecerse inicialmente durante un mínimo de catorce días como sugerencia del chef antes de poder incorporarse a la carta permanente.

*Criterio de aplicación:* es de nueva creación el plato que aún no ha tenido ningún periodo de carta permanente. Se exige un periodo de sugerencia del chef cerrado, de al menos 14 días consecutivos, terminado a más tardar cuando empieza la carta permanente.

### 3.3.5. Requisitos no funcionales

#### RNF-01 — Control de acceso

El sistema deberá permitir el acceso únicamente a usuarios registrados y autenticados, aplicando los permisos correspondientes a su rol más los permisos adicionales.

#### RNF-02 — Seguridad de las credenciales

El sistema no deberá almacenar las contraseñas de los usuarios en texto plano.

#### RNF-03 — Disponibilidad

El sistema deberá ofrecer una disponibilidad adecuada para permitir su utilización durante el horario habitual de funcionamiento del restaurante.

#### RNF-04 — Rendimiento

El sistema deberá ofrecer tiempos de respuesta adecuados en las operaciones habituales de consulta, registro y modificación de información.

#### RNF-05 — Usabilidad e integración

El sistema deberá proporcionar operaciones que permitan consultar y gestionar la información de forma estructurada, facilitando su integración con una posible interfaz de usuario sin necesidad de que esta acceda directamente a la base de datos.

#### RNF-06 — Integridad de los datos

El sistema deberá garantizar la integridad y consistencia de la información almacenada, evitando registros que incumplan las relaciones y restricciones definidas en el sistema.

### 3.3.6. Decisiones de modelado

Las decisiones de modelado recogen criterios adoptados por el equipo al construir el modelo conceptual. Se citan en los escenarios de prueba y en los diagramas.

#### D-01 — Precio seleccionado

Cada ingrediente tiene, como máximo, un precio seleccionado explícitamente para calcular costes, que debe estar vigente al calcular. La selección es manual: no se elige automáticamente el precio más barato.

#### D-02 — Rendimiento de las recetas

Cada receta declara la cantidad y la unidad que produce. La receta de un plato expresa su rendimiento en unidades del plato.

#### D-03 — Permisos adicionales

Un usuario puede tener permisos adicionales individuales, además de los de su rol.

#### D-04 — Clasificación de frescura

La clasificación como fresco pertenece a cada lote, no al ingrediente.

#### D-05 — Periodo de prueba

La prueba de un plato nuevo se realiza como sugerencia del chef durante 14 días consecutivos.

#### D-06 — Margen objetivo

El porcentaje de margen objetivo es opcional, se define por plato y se expresa sobre el precio de venta.

#### D-07 — Subreceta como papel

Una subreceta no es una entidad propia, sino una receta utilizada como componente de otra. Una receta puede no pertenecer a ningún plato y puede utilizarse en varias recetas.

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
| RF-01 — Gestión de usuarios | | | ● |
| RF-02 — Gestión de proveedores | | ● | |
| RF-03 — Gestión de ingredientes | ○ | ● | |
| RF-04 — Gestión de precios | ● | ● | |
| RF-05 — Gestión de platos | ● | | |
| RF-06 — Gestión de recetas | ● | | |
| RF-07 — Cálculo de escandallos | ● | | |
| RF-08 — Cálculo de rentabilidad | ● | | |
| RF-09 — Gestión de stock | | ● | |
| RF-10 — Gestión de mermas | | ● | |
| RF-11 — Alertas de sobrecostes | ● | | |
| RF-12 — Alertas de caducidad | | ● | |
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
