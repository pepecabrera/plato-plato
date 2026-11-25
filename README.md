# Plato-Plató

Demostración académica de base de datos para un restaurante. Permite consultar escandallos y márgenes por ración, registrar stock y mermas y gestionar la incorporación de platos a carta. Incluye datos ficticios y tres perfiles de acceso en MariaDB. No incluye una aplicación ni una interfaz de usuario.

## Instalación

Usa una instancia local de **MariaDB 10.6 o superior** donde todavía no existan la base `plato_plato` ni las tres cuentas de demostración. Desde la raíz del repositorio, abre el cliente con la cuenta instaladora (sustituye `instalador` por su nombre):

```sh
MYSQL_HISTFILE=/dev/null mariadb --protocol=SOCKET --abort-source-on-error -u instalador -p
```

Ejecuta estos archivos en orden:

```sql
SOURCE sql/01_tablas.sql
SOURCE sql/02_datos.sql
SOURCE sql/04_funciones_procedimientos.sql
SOURCE sql/05_triggers.sql
SOURCE sql/08_cuentas_privilegios.sql
```

Si prefieres el poblado mediante procedimientos, sustituye `02_datos.sql` por `06_poblado_procedimientos.sql` en una base nueva. **No ejecutes ambos poblados.** No uses la cuenta instaladora para la demostración operativa.

La cuenta instaladora debe poder crear la base, sus objetos y las cuentas, y conceder los permisos de `08`. Debe conservar los privilegios que usan las vistas y procedimientos que define.

### Activar las cuentas locales

`08` crea las cuentas bloqueadas. En la sesión del instalador, sustituye los marcadores por tres contraseñas distintas y desbloquea las cuentas. No guardes las contraseñas en el repositorio.

```sql
ALTER USER 'pp_administrador'@'localhost' IDENTIFIED BY '<clave de administrador>' ACCOUNT UNLOCK;
ALTER USER 'pp_encargado'@'localhost' IDENTIFIED BY '<clave de encargado>' ACCOUNT UNLOCK;
ALTER USER 'pp_empleado'@'localhost' IDENTIFIED BY '<clave de empleado>' ACCOUNT UNLOCK;
```

### Comprobación desde conexiones separadas

Esta comprobación valida los privilegios **de MariaDB** definidos en `08`, no los permisos de negocio de los usuarios del restaurante. Conéctate por socket. `-p` solicita la contraseña sin escribirla en el comando. Comprueba al menos un acceso permitido y otro denegado por cada cuenta:

```sh
mariadb --protocol=SOCKET -u pp_administrador -p plato_plato -e 'SELECT nombre, coste_por_racion FROM v_admin_costes;'
mariadb --protocol=SOCKET -u pp_administrador -p plato_plato -e 'SELECT nombre FROM platos;'
mariadb --protocol=SOCKET -u pp_encargado -p plato_plato -e 'SELECT nombre FROM v_gestion_proveedores;'
mariadb --protocol=SOCKET -u pp_encargado -p plato_plato -e 'SELECT nombre, coste_por_racion FROM v_admin_costes;'
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e 'SELECT nombre FROM v_operativa_platos;'
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e 'SELECT nombre FROM v_gestion_proveedores;'
```

En cada par, la primera consulta debe funcionar y la segunda debe devolver `ERROR 1142` (permiso SQL denegado).

Comprueba también, desde cada una de las tres conexiones operativas, que las siguientes escrituras directas se deniegan con `ERROR 1142`. Los `SELECT` no producen filas: la comprobación no inserta datos aunque un permiso esté mal concedido.

```sql
INSERT INTO movimientos_stock (id_lote, tipo, cantidad, fecha_movimiento)
SELECT 1, 'ENTRADA', 1, NOW(6) WHERE 1 = 0;
INSERT INTO periodos_oferta (id_plato, tipo, fecha_inicio)
SELECT 1, 'CARTA_PERMANENTE', NOW(6) WHERE 1 = 0;
INSERT INTO autorizaciones_carta (id_periodo_oferta, id_emisor, fecha_autorizacion, coste_evaluado, precio_venta_evaluado)
SELECT 1, 1, NOW(6), 1, 1 WHERE 1 = 0;
```

Las cuentas operativas escriben solo mediante los procedimientos de fachada. El saldo histórico no negativo (RC-13) y el alta atómica de carta con autorización previa (RN-02) se garantizan por esa vía, no mediante `INSERT` directo de la cuenta instaladora. Reserva esta última para instalación y mantenimiento y ejecuta los diagnósticos tras una carga directa.

## Verificación del negocio y del poblado

Ejecuta `sql/07_pruebas.sql` solo en una copia desechable: comprueba reglas y permisos de negocio definidos mediante usuarios, roles y concesiones, y algunas pruebas confirman escrituras. No sustituye las conexiones separadas de `08`.

Para verificar que los datos de `02` pasan también con los triggers activos, usa **otra copia nueva** y ejecuta `01 → 04 → 05 → 02 → 03`. Para esa carga, el reloj de la sesión debe ser posterior a la última autorización del poblado (16/10/2026 a las 18:00). Los diagnósticos C-23 a C-27 deben devolver cero filas. Esta ruta no cambia el orden de instalación oficial.

### Demostración de las consultas

Ejecuta `SOURCE sql/03_consultas.sql` después de cargar `02` **o** `06`, antes de ejecutar `07`. Ambos poblados representan los mismos casos. Con el corte por defecto (**15/11/2026 a las 12:00**), puedes mostrar:

| Consultas | Resultado esperado |
| --- | --- |
| C-04, C-13, C-15, C-22 | Dos recetas reutilizan la salsa y ambas se ven afectadas por la subida del tomate. *Huevos con salsa de tomate* tiene un margen del 86,69 % frente al objetivo del 90 % y es candidato a carta tras una prueba cerrada de 14 días. |
| C-07, C-08, C-20 | Octubre tiene una merma de plato sin valorar. `DETERIORO` agrupa esa merma y una de lote valorada en 1,20 €. El total de los dos meses es de 4 mermas y 6,72 € de coste conocido. |
| C-10, C-11 | Marta recibe `GESTIONAR_STOCK` por rol y a título individual. La oferta de tomate de Despensa Central, de 0,0027 €/g, se compara como 2,70 €/kg. |
| C-16, C-23 a C-27 | Sin incidencias al corte principal. Los diagnósticos de integridad deben seguir vacíos con una carga válida. |

Para ver C-16 con filas, ejecuta solo esa consulta tras `SET @ahora = '2026-09-15 12:00:00'`: el tomate tiene un precio vigente, pero el seleccionado aún no ha entrado en vigor. Con `SET @ahora = '2026-11-09 08:00:00'`, C-05 y C-06 muestran 12 kg en dos lotes de tomate y C-19 identifica el antiguo como no apto. Volver a ejecutar `03` completo restablece el corte por defecto.

Para comparar los poblados, ejecuta las consultas con el mismo corte en dos bases nuevas, una con cada carga. Compara los resultados por nombre o identificador de negocio, no por el orden de filas empatadas.

## Documentación

- [Descripción del problema](docs/01_descripcion_problema.md), [glosario](docs/02_glosario.md) y [requisitos](docs/03_requisitos.md).
- [Modelo conceptual y escenarios](docs/04_modelo_conceptual.md) y [modelo relacional](docs/05_modelo_relacional.md).
- [Modelo tecnológico](docs/06_modelo_tecnologico.md), descripción sencilla de cada archivo sql.
