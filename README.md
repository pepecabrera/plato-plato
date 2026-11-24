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

## Verificación del negocio y del poblado

Ejecuta `sql/07_pruebas.sql` solo en una copia desechable: comprueba reglas y permisos de negocio definidos mediante usuarios, roles y concesiones, y algunas pruebas confirman escrituras. No sustituye las conexiones separadas de `08`.

Para verificar que los datos de `02` pasan también con los triggers activos, usa **otra copia nueva** y ejecuta `01 → 04 → 05 → 02 → 03`. Para esa carga, el reloj de la sesión debe ser posterior a la última autorización del poblado (16/10/2026 a las 18:00). Los diagnósticos C-23 a C-27 deben devolver cero filas. Esta ruta no cambia el orden de instalación oficial.

## Documentación

- [Descripción del problema](docs/01_descripcion_problema.md), [glosario](docs/02_glosario.md) y [requisitos](docs/03_requisitos.md).
- [Modelo conceptual y escenarios](docs/04_modelo_conceptual.md) y [modelo relacional](docs/05_modelo_relacional.md).
- [Modelo tecnológico](docs/06_modelo_tecnologico.md), con un resumen de cada script SQL.
