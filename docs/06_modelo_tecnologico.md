# 6. Modelo tecnológico

La base de datos usa MariaDB 10.6 o superior con InnoDB. Las cuentas operativas consultan vistas y ejecutan procedimientos autorizados sin acceso directo a las tablas. La instalación y las comprobaciones se describen en el [README](../README.md).

## 6.1. Script de creación de tablas y restricciones

[`01_tablas.sql`](../sql/01_tablas.sql) crea la base de datos y sus tablas. Incluye claves y restricciones para mantener la integridad de los datos.

## 6.2. Poblado de la base de datos mediante sentencias INSERT

[`02_datos.sql`](../sql/02_datos.sql) carga datos ficticios del restaurante: usuarios, proveedores, precios, recetas, platos, existencias, mermas e historial de oferta.

## 6.3. Script de consultas a tablas en SQL

[`03_consultas.sql`](../sql/03_consultas.sql) incluye listados, cálculos de costes y márgenes, avisos de precios y caducidad, y comprobaciones de integridad. No modifica datos. Para calcular el coste usa la receta y la selección de precios actuales, y comprueba la vigencia del precio en la fecha de referencia.

## 6.4. Script de creación de funciones y procedimientos

[`04_funciones_procedimientos.sql`](../sql/04_funciones_procedimientos.sql) define funciones para calcular costes, márgenes y existencias y comprobar permisos. Incluye procedimientos para consultar escandallos y registrar movimientos, mermas, recetas y cambios en la oferta.

## 6.5. Script de creación de triggers asociados a reglas de negocio

[`05_triggers.sql`](../sql/05_triggers.sql) aplica comprobaciones automáticas al guardar datos. Valida, entre otros, los lotes usados en cocina, los periodos de oferta, los precios y los componentes de las recetas. También protege el historial.

## 6.6. Script de poblado de la base de datos mediante procedimientos (opcional)

[`06_poblado_procedimientos.sql`](../sql/06_poblado_procedimientos.sql) es una alternativa a `02_datos.sql`. Carga los mismos datos de demostración mediante procedimientos con validaciones de carga; no sustituye a los flujos operativos de `04` y `05`. Sus regresiones de movimientos se ejecutan solo en la pasada de negocio de `07` cuando se ha elegido este poblado.

## 6.7. Script de creación de pruebas y llamadas

[`07_pruebas.sql`](../sql/07_pruebas.sql) es una suite secuencial con [dos pasadas](../README.md#dos-pasadas-de-07) sobre una copia desechable. La primera comprueba el esquema con `01` y un solo poblado (`02` o `06`), sin `04` ni `05`. La segunda, tras instalar `04` y `05` completos, comprueba las reglas y los permisos de negocio. Si se usó `06`, también comprueba el rechazo de una segunda carga y ejecuta las 12 regresiones de movimientos. El resumen esperado contiene solo `OK`. Las escrituras confirmadas se conservan, así que cada repetición empieza en una copia nueva.

La [verificación adicional del README](../README.md#verificación-adicional) resume los casos de concurrencia para las rutinas de stock y oferta; no cubre escrituras directas. Para comparar los poblados, ejecuta `03` en copias limpias con el mismo corte.

## 6.8. Cuentas y privilegios de MariaDB (opcional)

[`08_cuentas_privilegios.sql`](../sql/08_cuentas_privilegios.sql) crea las cuentas de demostración de administrador, encargado y empleado. Define qué vistas puede consultar y qué procedimientos puede ejecutar cada cuenta, sin darles acceso directo a las tablas.

Los comentarios al inicio de `08` explican cómo activar las cuentas y comprobar los privilegios desde conexiones separadas. Estos privilegios de MariaDB son distintos de los permisos de negocio que comprueba `07`.
