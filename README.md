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

Conéctate por socket. `-p` solicita la contraseña sin escribirla en el comando. La consulta de costes debe funcionar para el administrador y denegarse al encargado. El empleado puede consultar los platos, pero no los proveedores.

```sh
mariadb --protocol=SOCKET -u pp_administrador -p plato_plato -e 'SELECT nombre, coste_por_racion FROM v_admin_costes;'
mariadb --protocol=SOCKET -u pp_encargado -p plato_plato -e 'SELECT nombre, coste_por_racion FROM v_admin_costes;'
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e 'SELECT nombre FROM v_operativa_platos;'
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e 'SELECT nombre FROM v_gestion_proveedores;'
```

## Documentación

- [Descripción del problema](docs/01_descripcion_problema.md), [glosario](docs/02_glosario.md) y [requisitos](docs/03_requisitos.md).
- [Modelo conceptual y escenarios](docs/04_modelo_conceptual.md) y [modelo relacional](docs/05_modelo_relacional.md).
- [Modelo tecnológico](docs/06_modelo_tecnologico.md), con las rutas de [verificación](docs/06_modelo_tecnologico.md#verificación-de-la-entrega) y la [matriz de privilegios](docs/06_modelo_tecnologico.md#matriz-de-privilegios-de-08).

Ejecuta `sql/07_pruebas.sql` solo en una copia desechable: algunas pruebas confirman escrituras.
