# Plato-Plató — Especificación de requisitos

## Índice

- [1. Descripción del problema](#1-descripción-del-problema)
- [2. Glosario de términos](#2-glosario-de-términos)
- [3. Catálogo de requisitos](#3-catálogo-de-requisitos)
  - [3.1. Usuarios del sistema](#31-usuarios-del-sistema)
  - [3.2. Requisitos generales](#32-requisitos-generales)
  - [3.3. Requisitos detallados](#33-requisitos-detallados)
    - [3.3.1. Requisitos de información](#331-requisitos-de-información)
    - [3.3.2. Requisitos funcionales](#332-requisitos-funcionales)
    - [3.3.3. Reglas de conducta](#333-reglas-de-conducta)
    - [3.3.4. Reglas de negocio](#334-reglas-de-negocio)
    - [3.3.5. Requisitos no funcionales](#335-requisitos-no-funcionales)

---

# 1. Descripción del problema

El sistema tiene como objetivo proporcionar al restaurante Plato-Plató una solución software que permita gestionar de forma integrada los proveedores, ingredientes, stock, mermas, recetas, platos y escandallos.

La información gestionada por el sistema estará interconectada, permitiendo automatizar el cálculo de los costes de producción y facilitar el análisis de la rentabilidad de los platos.

De esta forma, se pretende reducir la dependencia de herramientas poco eficientes, como los cálculos manuales en papel o mediante hojas de cálculo, y centralizar la información relevante para la gestión de costes del restaurante.

---

# 2. Glosario de términos

- **Escandallo:** cálculo del coste de producción de un plato y de los indicadores económicos asociados, como el precio de venta y el margen.
- **Merma:** pérdida de ingredientes, platos u otros productos gestionados por el restaurante debido a causas como caducidad, deterioro, elaboración incorrecta o desecho de un plato.
- **Lote:** conjunto de unidades de un determinado ingrediente recibido en una misma entrada de mercancía, identificado individualmente y asociado a una fecha de entrada y, cuando corresponda, a una fecha de caducidad.
- **Subreceta:** receta utilizada como componente de otra receta o plato.

---

# 3. Catálogo de requisitos

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

---

## 3.2. Requisitos generales

### RG-01 — Gestión de costes y rentabilidad

El sistema deberá permitir gestionar los costes asociados a los ingredientes, recetas y platos de la carta, con el objetivo de automatizar el cálculo de los escandallos y facilitar el análisis de la rentabilidad del restaurante.

### RG-02 — Control de compras y desperdicio

El sistema deberá permitir gestionar la información relacionada con proveedores, precios de compra, stock y mermas, con el objetivo de mejorar el control de los costes y reducir las pérdidas del restaurante.

---

## 3.3. Requisitos detallados

### 3.3.1. Requisitos de información

Los requisitos de información describen los datos que el sistema deberá almacenar sobre los principales conceptos del dominio.

### RI-01 — Usuarios y roles

El sistema deberá almacenar la siguiente información sobre los usuarios:

- Nombre.
- Correo electrónico.
- Contraseña almacenada de forma segura.
- Rol.
- Estado de la cuenta (activa/inactiva).
- Fecha de creación.

El sistema deberá disponer, asimismo, de información sobre los roles existentes y los permisos asociados a cada uno.

### RI-02 — Proveedores

El sistema deberá almacenar la siguiente información sobre los proveedores:

- Nombre.
- Información de contacto.
- Forma de pago.
- Estado del proveedor (activo/inactivo).

### RI-03 — Ingredientes

El sistema deberá almacenar la siguiente información sobre los ingredientes:

- Nombre.
- Categoría.
- Unidad de medida (por defecto, kilogramos).
- Estado del ingrediente (activo/inactivo).
- Cantidad total disponible, calculada a partir de los lotes existentes.

### RI-04 — Precios de ingredientes

El sistema deberá almacenar información sobre los precios de compra de los ingredientes:

- Ingrediente.
- Proveedor.
- Precio de compra.
- Unidad a la que corresponde el precio.
- Fecha de inicio de vigencia.
- Fecha de finalización de vigencia, cuando corresponda.

El sistema deberá conservar el histórico de precios de los ingredientes.

### RI-05 — Platos

El sistema deberá almacenar la siguiente información sobre los platos:

- Nombre.
- Imagen (opcional).
- Descripción.
- Categoría (entrante, plato principal, postre, etc.).
- Menú del día.
- Precio de venta.
- Estado del plato (activo/inactivo), para permitir su gestión por temporadas.

El sistema podrá disponer, además, de información calculada relativa al coste de producción, margen bruto y porcentaje de margen.

### RI-06 — Recetas

El sistema deberá almacenar la información necesaria para representar la composición de cada plato o subreceta:

- Plato o subreceta a la que pertenece.
- Ingredientes y/o subrecetas que la componen.
- Cantidad necesaria de cada componente.
- Unidad de medida utilizada.

### RI-07 — Lotes

El sistema deberá almacenar la siguiente información sobre los lotes de ingredientes:

- Ingrediente al que pertenece el lote.
- Identificador del lote.
- Cantidad.
- Fecha de entrada.
- Fecha de caducidad.
- Fresco (bool).
- Ubicación en el almacén.

### RI-08 — Movimientos de stock

El sistema deberá almacenar información sobre los movimientos de stock de los ingredientes:

- Lote afectado.
- Tipo de movimiento (entrada, salida, ajuste, etc.).
- Cantidad.
- Fecha del movimiento.

### RI-09 — Mermas

El sistema deberá almacenar información sobre las mermas producidas en el restaurante:

- Elemento afectado (lote o plato).
- Cantidad desperdiciada.
- Fecha de la merma.
- Motivo de la merma (caducidad, deterioro, elaboración incorrecta, plato desechado, etc.).
- Coste de la pérdida, cuando se conozca.

### RI-10 - Oferta y autorizaciones

El sistema almacenará los periodos de oferta de cada plato, indicando su tipo —sugerencia del chef o carta permanente— y sus fechas de inicio y finalización. Para cada incorporación a la carta permanente conservará la autorización correspondiente, su emisor, fecha, coste evaluado y precio de venta evaluado.

---

### 3.3.2. Requisitos funcionales

Los requisitos funcionales describen las operaciones y comportamientos que el sistema deberá proporcionar a los usuarios.

### RF-01 — Gestión de usuarios

El sistema deberá permitir a los usuarios autorizados registrar, modificar, consultar, activar y desactivar cuentas de usuario, así como asignarles un rol.

### RF-02 — Gestión de proveedores

El sistema deberá permitir registrar, modificar, consultar y desactivar proveedores.

### RF-03 — Gestión de ingredientes

El sistema deberá permitir registrar, modificar, consultar y desactivar ingredientes, incluyendo su unidad de medida y la información relacionada con sus lotes y stock.

### RF-04 — Gestión de precios

El sistema deberá permitir registrar y actualizar los precios de compra de los ingredientes asociados a sus respectivos proveedores, conservando el histórico de precios.

### RF-05 — Gestión de platos

El sistema deberá permitir registrar, modificar, consultar y desactivar los platos de la carta.

### RF-06 — Gestión de recetas

El sistema deberá permitir definir y modificar la composición de un plato o subreceta, indicando los ingredientes y/o subrecetas que lo forman y la cantidad necesaria de cada componente.

### RF-07 — Cálculo de escandallos

El sistema deberá permitir calcular automáticamente el coste de producción de un plato a partir de los componentes de su receta, sus cantidades y los precios de compra aplicables.

### RF-08 — Cálculo de rentabilidad

El sistema deberá permitir calcular el margen bruto de cada plato a partir de su coste de producción y su precio de venta.

### RF-09 — Gestión de stock

El sistema deberá permitir registrar y consultar los movimientos de stock de los ingredientes, incluyendo entradas, salidas y ajustes.

### RF-10 — Gestión de mermas

El sistema deberá permitir registrar y consultar las mermas producidas, indicando el elemento afectado, la cantidad, el motivo y la fecha de la pérdida. Se permitirá registrar movimientos con fecha pasada, siempre que no provoquen saldos negativos en el momento afectado ni en momentos posteriores.

### RF-11 — Alertas de sobrecostes

El sistema deberá permitir generar avisos cuando la variación del precio de un ingrediente provoque un aumento significativo del coste de producción de un plato o una reducción de su margen.

### RF-12 — Alertas de caducidad

El sistema deberá permitir generar avisos cuando un lote almacenado se encuentre próximo a su fecha de caducidad.

### RF-13 — Comparación de proveedores

El sistema deberá permitir consultar los proveedores que suministran un determinado ingrediente y comparar sus precios para facilitar la selección del proveedor.

---

### 3.3.3. Reglas de conducta

### RC-01 — Cantidades de las recetas

El sistema deberá impedir el registro de cantidades de ingredientes o subrecetas iguales o inferiores a cero.

### RC-02 — Componentes de una receta

Un mismo ingrediente o subreceta no podrá aparecer más de una vez como componente de una misma receta.

### RC-03 — Precios válidos

El sistema deberá impedir el registro de precios de compra inferiores o iguales a cero.

### RC-04 — Precios vigentes

Para un determinado proveedor e ingrediente no podrá existir más de un precio de compra vigente simultáneamente.

### RC-05 — Cálculo del coste

El coste de producción de un plato deberá calcularse a partir de la suma del coste de todos los componentes necesarios para elaborar una unidad del plato.

### RC-06 — Actualización del coste

Cuando cambie el precio aplicable de un ingrediente, el coste de los platos que lo utilicen deberá actualizarse en consecuencia.

### RC-07 — Margen bruto

El margen bruto por unidad de un plato se calculará como la diferencia entre su precio de venta y su coste de producción.

### RC-08 — Margen objetivo

El sistema deberá permitir establecer un margen objetivo para los platos, que podrá ser modificado por los usuarios con permisos suficientes.

### RC-09 — Integridad del histórico

Los elementos que formen parte de información histórica no deberán eliminarse de forma que se pierda dicha información.

### RC-10 — Permisos según el rol

Cada usuario únicamente podrá realizar las operaciones que correspondan a los permisos asociados a su rol más los permisos adicionales del usuario.

### RC-11 — Coste calculable

Un plato no podrá considerarse correctamente costeado cuando alguno de los componentes necesarios para su receta no disponga de un precio de compra válido.

### RC-12 — Recetas cíclicas

Una receta no podrá contenerse a sí misma, ni directa ni indirectamente, mediante una cadena de subrecetas.

---

### 3.3.4. Reglas de negocio

Las reglas de negocio representan políticas internas adoptadas por Plato-Plató. Sus plazos, porcentajes y umbrales son decisiones del restaurante, no restricciones universales del sector.

### RN-01 — Aprovechamiento de ingredientes próximos a caducar

Los lotes de ingredientes perecederos a los que les queden menos de 48 horas para alcanzar su fecha de caducidad solo podrán destinarse a la elaboración de platos del menú del día, siempre que sigan siendo aptos para el consumo.

### RN-02 — Incorporación a la carta

Toda incorporación de un plato a la carta permanente deberá ser autorizada previamente por un administrador, con independencia de su relación entre coste de elaboración y precio de venta. La autorización registrará el administrador, la fecha, el coste evaluado y el precio de venta evaluado. No podrá autorizarse un plato cuyo coste no sea calculable.

### RN-03 — Política interna de frescura

Los lotes catalogados por el restaurante como frescos no podrán utilizarse una vez transcurridas 72 horas desde la recepción de su lote, aunque su fecha de caducidad sea posterior.

### RN-04 — Prueba de nuevos platos

Todo plato de nueva creación deberá ofrecerse inicialmente durante un mínimo de catorce días como sugerencia del chef antes de poder incorporarse a la carta permanente.

---

### 3.3.5. Requisitos no funcionales

### RNF-01 — Control de acceso

El sistema deberá permitir el acceso únicamente a usuarios registrados y autenticados, aplicando los permisos correspondientes a su rol.

### RNF-02 — Seguridad de las credenciales

El sistema no deberá almacenar las contraseñas de los usuarios en texto plano.

### RNF-03 — Disponibilidad

El sistema deberá ofrecer una disponibilidad adecuada para permitir su utilización durante el horario habitual de funcionamiento del restaurante.

### RNF-04 — Rendimiento

El sistema deberá ofrecer tiempos de respuesta adecuados en las operaciones habituales de consulta, registro y modificación de información.

### RNF-05 — Usabilidad

La interfaz deberá permitir a los usuarios consultar y gestionar la información relacionada con costes, platos, recetas e ingredientes de forma clara e intuitiva.

### RNF-06 — Integridad de los datos

El sistema deberá garantizar la integridad y consistencia de la información almacenada, evitando registros que incumplan las relaciones y restricciones definidas en el sistema.