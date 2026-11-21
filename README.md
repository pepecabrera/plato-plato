# Plato-Plató

**Sistema de apoyo a la gestión de costes, inventario y elaboración de platos para restaurantes.**

> **Entrega de clase:** demostración de base de datos MariaDB. Incluye esquema, datos ficticios, consultas, procedimientos, triggers, pruebas y cuentas SQL. No incluye una aplicación ni una interfaz de usuario. Véase la [memoria vigente (PDF)](entregable_final/plato_plato_memoria.pdf).

Plato-Plató es un proyecto de **cinco integrantes**. Reúne la información sobre proveedores, ingredientes, precios de compra, lotes, existencias, mermas, recetas y platos para calcular escandallos y analizar el margen unitario.

## Índice

- [1. Motivación](#1-motivación)
- [2. Objetivos](#2-objetivos)
- [3. Alcance de la entrega](#3-alcance-de-la-entrega)
- [4. Perfiles de usuario](#4-perfiles-de-usuario)
- [5. Modelo de información](#5-modelo-de-información)
- [6. Funcionamiento conceptual](#6-funcionamiento-conceptual)
- [7. Arquitectura y tecnologías](#7-arquitectura-y-tecnologías)
- [8. Organización del repositorio](#8-organización-del-repositorio)
- [9. Instalación y ejecución](#9-instalación-y-ejecución)
- [10. Calidad y pruebas](#10-calidad-y-pruebas)
- [11. Colaboración](#11-colaboración)
- [12. Seguridad y datos](#12-seguridad-y-datos)
- [13. Documentación](#13-documentación)
- [14. Hoja de ruta](#14-hoja-de-ruta)
- [15. Equipo y licencia](#15-equipo-y-licencia)

## 1. Motivación

En un restaurante, la información sobre compras, existencias, elaboración y precios puede encontrarse dispersa en documentos, hojas de cálculo o registros manuales. Esto dificulta estimar el coste por ración y detectar variaciones que afectan al margen.

Plato-Plató busca centralizar esos datos y relacionarlos entre sí, reduciendo tareas repetitivas y mejorando la trazabilidad de los cálculos.

## 2. Objetivos

- **Centralizar** la información operativa relevante para los costes de cocina.
- **Estructurar** recetas, subrecetas e ingredientes con sus cantidades y unidades.
- **Calcular** costes de elaboración y márgenes a partir de precios de compra.
- **Controlar** lotes, movimientos de stock y mermas.
- **Comparar** precios de distintos proveedores para un mismo ingrediente.
- **Facilitar** la consulta y gestión de información según los permisos de cada perfil.

## 3. Alcance de la entrega

La [especificación vigente](entregable_final/memoria/03_requisitos.md) distingue la carga de demostración, las consultas y las operaciones disponibles por procedimiento.

| Área | Capacidad de la demo |
| --- | --- |
| Usuarios | Consulta de usuarios de demostración y sus concesiones, sin CRUD de aplicación. |
| Proveedores | Consulta del catálogo cargado con el poblado. |
| Ingredientes | Catálogo, categorías, unidades de medida y estado. |
| Precios de compra | Asociación ingrediente-proveedor, vigencias e histórico de precios. |
| Lotes e inventario | Entradas, salidas, ajustes, existencias y fechas de caducidad. |
| Recetas y subrecetas | Consulta de composición y alta completa por procedimiento. |
| Platos | Catálogo de demostración y procedimientos para la oferta y la incorporación a carta. |
| Escandallos | Cálculo del coste de producción a partir de los componentes de cada receta. |
| Rentabilidad | Cálculo del margen bruto y apoyo al seguimiento de costes. |
| Mermas | Registro de pérdidas, causas, cantidades y costes asociados. |
| Avisos | Consultas a demanda de lotes próximos a caducar y subidas del precio de referencia del mismo proveedor. |
| Comparación | Consulta de proveedores y precios por ingrediente. |

**Fuera del alcance confirmado:** no se presupone la existencia de un módulo de reservas, comandas, facturación, gestión de turnos o ventas. Cualquier ampliación se documentará antes de incorporarse.

## 4. Perfiles de usuario

La demo separa los perfiles de aplicación de las cuentas de MariaDB. Las cuentas SQL de administrador, encargado y empleado reciben vistas y operaciones distintas; la [matriz de acceso](#cuentas-operativas-de-mariadb) detalla las concesiones. La regla de negocio RN-02 exige el permiso explícito `AUTORIZAR_CARTA`, no un rol concreto. En la demo, solo `pp_administrador` tiene además el privilegio SQL para llamar al procedimiento público de incorporación.

## 5. Modelo de información

Los principales conceptos del dominio son:

- **Usuario y rol:** identificación, estado y autorización de operaciones.
- **Proveedor:** origen de suministro y condiciones de contacto y pago.
- **Ingrediente:** producto utilizado en las elaboraciones, con unidad de medida.
- **Precio de ingrediente:** precio de compra asociado a proveedor, ingrediente y período de vigencia.
- **Lote:** entrada identificable de un ingrediente, con cantidad, fechas y ubicación.
- **Movimiento de stock:** variación de existencias vinculada a un lote.
- **Plato:** elaboración ofertable con precio de venta y datos descriptivos.
- **Receta y subreceta:** composición de una elaboración a partir de ingredientes y componentes reutilizables.
- **Merma:** pérdida registrada de un lote o plato, con motivo y coste.

El **escandallo** representa el cálculo del coste de elaboración de un plato. El **margen bruto unitario** se obtiene restando ese coste al precio de venta. Las fórmulas y criterios concretos se documentarán junto a los requisitos.

## 6. Funcionamiento conceptual

Un posible recorrido de uso del sistema es:

1. Cargar proveedores, ingredientes, precios, lotes, recetas y platos de demostración con `02` o `06`.
2. Consultar recetas, existencias y, con el perfil SQL autorizado, el escandallo y el margen por ración.
3. Registrar movimientos, mermas o periodos de oferta mediante los procedimientos habilitados para cada cuenta.

## 7. Arquitectura y tecnologías

La entrega usa **MariaDB** para la persistencia y las reglas de negocio. Las cuentas operativas consultan vistas y llaman a procedimientos; no acceden directamente a las tablas. El [modelo tecnológico](entregable_final/memoria/06_modelo_tecnologico.md) documenta las garantías y sus límites.

## 8. Organización del repositorio

```text
plato-plato/
├── docs/                 # Entregas anteriores y materiales de trabajo
├── entregable_final/     # Memoria vigente, figuras y herramientas de generación
├── sql/                  # Instalación, poblados, consultas y pruebas de MariaDB
└── README.md
```

## 9. Instalación y ejecución

La entrega de clase se ejecuta en **MariaDB 10.6 o superior**, sin aplicación. Usad una instancia local desechable y un cliente que admita `DELIMITER`, como `mariadb`. Desde la raíz del repositorio, conectad por socket con la cuenta instaladora. Esa cuenta debe conservar los privilegios que utilizan las vistas y rutinas con `SQL SECURITY DEFINER`; no se usa para la demostración operativa.

```sql
SOURCE sql/01_tablas.sql
SOURCE sql/02_datos.sql
SOURCE sql/04_funciones_procedimientos.sql
SOURCE sql/05_triggers.sql
SOURCE sql/08_cuentas_privilegios.sql
```

Para usar el poblado por procedimientos, sustituid `02_datos.sql` por `06_poblado_procedimientos.sql` en una base recién creada. No carguéis ambos. `03_consultas.sql` y `07_pruebas.sql` no son necesarios para instalar las cuentas. No ejecutéis `07` sobre una copia que queráis conservar para la demo: las pruebas de negocio confirman algunos cambios.

### Cuentas operativas de MariaDB

`08` crea estas tres cuentas locales, bloqueadas y sin claves en el repositorio. Ejecutad el script una sola vez en una instancia donde no existan ya esos nombres. Después, como instalador, asignad una clave distinta a cada cuenta y desbloqueadla. Introducid los comandos en una sesión local sin guardar historial (por ejemplo, iniciando el cliente con `MYSQL_HISTFILE=/dev/null`); los valores entre ángulos son marcadores, no claves de ejemplo para usar.

```sql
ALTER USER 'pp_administrador'@'localhost' IDENTIFIED BY '<clave de administrador>' ACCOUNT UNLOCK;
ALTER USER 'pp_encargado'@'localhost' IDENTIFIED BY '<clave de encargado>' ACCOUNT UNLOCK;
ALTER USER 'pp_empleado'@'localhost' IDENTIFIED BY '<clave de empleado>' ACCOUNT UNLOCK;
```

| Cuenta | Vistas de consulta | Operaciones mediante `CALL` |
|---|---|---|
| `pp_empleado` | `v_operativa_*`: platos, recetas y lotes, sin importes económicos. | Registrar movimientos y mermas. |
| `pp_encargado` | Las anteriores y `v_gestion_*`: proveedores y periodos de oferta sin importes. | También dar de alta recetas, registrar sugerencias y cerrar periodos. |
| `pp_administrador` | Las anteriores y `v_admin_*`: costes y usuarios, sin hashes de contraseñas. | También consultar el escandallo e incorporar platos a carta, sujeto a RN-02. |

Las cuentas solo reciben `SELECT` sobre las vistas indicadas y `EXECUTE` sobre procedimientos públicos concretos (`sp_demo_*`). No reciben acceso directo a tablas ni a las rutinas internas de negocio, carga o pruebas. Cada procedimiento público toma la identidad de la conexión local y busca el usuario activo de demostración por correo y perfil: Ana, Carlos o Marta. No acepta un ID de usuario elegido por el cliente. Las concesiones de aplicación no amplían por sí solas los privilegios SQL; por ejemplo, el permiso individual de Marta no habilita las vistas de costes para `pp_empleado`.

### Comprobación desde conexiones separadas

Ejecutad los comandos desde una base de demostración recién instalada. `-p` pide la clave sin ponerla en el comando. El primer grupo debe funcionar; la llamada del empleado añade una merma de plato al poblado.

```sh
mariadb --protocol=SOCKET -u pp_administrador -p plato_plato -e "SELECT nombre, coste_por_racion FROM v_admin_costes; CALL sp_demo_consultar_escandallo(1, '2026-11-15 12:00:00');"
mariadb --protocol=SOCKET -u pp_encargado -p plato_plato -e "SELECT nombre FROM v_gestion_proveedores;"
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e "SELECT nombre FROM v_operativa_platos; CALL sp_demo_registrar_merma(NULL, 1, 1, '2026-11-15 12:00:00', 'PLATO_DESECHADO', 'Prueba de permisos', NULL);"
```

Cada comando siguiente debe fallar por permisos: lectura de costes por el encargado, consulta de proveedores por el empleado, escritura directa incluso como administrador y llamada a una rutina que recibe un ID de usuario.

```sh
mariadb --protocol=SOCKET -u pp_encargado -p plato_plato -e "SELECT * FROM v_admin_costes;"
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e "SELECT * FROM v_gestion_proveedores;"
mariadb --protocol=SOCKET -u pp_administrador -p plato_plato -e "UPDATE platos SET descripcion = descripcion WHERE id_plato = 1;"
mariadb --protocol=SOCKET -u pp_empleado -p plato_plato -e "CALL sp_consultar_escandallo(1, 1, '2026-11-15 12:00:00');"
```

## 10. Calidad y pruebas

`07_pruebas.sql` comprueba el esquema y los flujos de negocio en una copia desechable. La secuencia de verificación, los resultados previos y lo que queda pendiente se detallan en el [seguimiento de clase](entregable_final/memoria/pendientes_clase_plato_plato.md). Los privilegios se verifican desde las conexiones separadas indicadas arriba.

## 11. Colaboración

El desarrollo se realiza por un equipo de **cinco integrantes**. Como convención inicial de trabajo se propone:

1. Registrar las tareas y errores en **GitHub Issues**.
2. Crear una rama por cambio (`feature/...`, `fix/...` o `docs/...`).
3. Realizar commits pequeños con mensajes descriptivos.
4. Abrir un **pull request** para integrar cambios en `main`.
5. Solicitar revisión de otro integrante y resolver los comentarios antes de fusionar.
6. Actualizar pruebas y documentación cuando el cambio lo requiera.

Estas convenciones son una propuesta de organización y podrán ajustarse por consenso. Se recomienda no subir directamente a `main` cambios sin revisar.

## 12. Seguridad y datos

- No incluir contraseñas, tokens, claves privadas ni archivos `.env` reales en el repositorio.
- Almacenar las contraseñas de usuarios mediante mecanismos de hash adecuados, nunca en texto plano.
- Aplicar autenticación y autorización según los permisos definidos.
- Utilizar datos ficticios o anonimizados en ejemplos, pruebas y capturas.
- Evitar publicar datos identificativos de personas, información contractual de proveedores o precios internos reales.
- Mantener fuera del control de versiones las copias de seguridad y los volcados de bases de datos con información sensible.

## 13. Documentación

La [memoria vigente](entregable_final/plato_plato_memoria.pdf) se genera a partir de los Markdown de `entregable_final/memoria/`. Para regenerarla desde la raíz, ejecutad `bash entregable_final/herramientas/generar_memoria.sh` con Pandoc y XeLaTeX instalados. `docs/entregas/` conserva los PDF históricos sin modificaciones; los requisitos y modelos de trabajo en `docs/` no sustituyen a la memoria vigente.

## 14. Hoja de ruta

El [seguimiento de clase](entregable_final/memoria/pendientes_clase_plato_plato.md) recoge la validación final y los límites aceptados. Una aplicación completa queda fuera de esta entrega.

## 15. Equipo y licencia

**Equipo:** cinco estudiantes que colaboran en el desarrollo de Plato-Plató como proyecto académico. Los nombres y funciones individuales podrán añadirse si sus integrantes desean hacerlos públicos.

**Licencia:** pendiente de decisión. Hasta que se incorpore un archivo `LICENSE`, no debe asumirse que el código dispone de una licencia de reutilización abierta.

---

*Plato-Plató — proyecto académico en desarrollo. Este documento se actualizará conforme se validen requisitos y se implementen funcionalidades.*
