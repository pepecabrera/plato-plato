# Plato-Plató

Base de datos académica para un restaurante: escandallos, stock, mermas y gestión de la carta. Incluye datos ficticios; no incluye una aplicación.

## Instalación

Con **MariaDB 10.6 o superior** y sin una base `plato_plato` existente, abre el cliente desde la raíz del repositorio:

```sh
mariadb --protocol=SOCKET --abort-source-on-error -u instalador -p
```

```sql
SOURCE sql/01_tablas.sql
SOURCE sql/02_datos.sql
SOURCE sql/04_funciones_procedimientos.sql
SOURCE sql/05_triggers.sql
```

Puedes sustituir `02` por `06_poblado_procedimientos.sql`; **no ejecutes ambos**. `08_cuentas_privilegios.sql` es opcional.

## Demostración de las consultas

Ejecuta `SOURCE sql/03_consultas.sql` con cualquiera de los dos poblados, antes de `07`. Al corte por defecto (**15/11/2026 a las 12:00**), seis consultas devuelven cero filas:

- **C-16:** todos los ingredientes que usan los platos tienen un precio seleccionado y vigente. Para ver el aviso, ejecuta `SET @ahora = '2026-09-15 12:00:00';` y lanza solo C-16. El tomate aparece porque su precio seleccionado todavía no está vigente. Ejecutar `03` entero restablece el corte por defecto.
- **C-23 a C-27:** no detectan anomalías de integridad. Estos diagnósticos revisan los datos registrados sin depender del corte de `@ahora`.

## Dos pasadas de `07`

Usa una **copia desechable**, sin `--force` y sin una transacción abierta. Algunas pruebas confirman escrituras; recrea la copia para repetirlas.

1. **Esquema:** ejecuta `01 → (02 o 06) → 07`, sin `04` ni `05`. Se esperan **68 OK**.
2. **Negocio:** en la misma copia, ejecuta `04 → 05 → 07`. Se esperan **154 OK** con `02` o **167 OK** con `06`.

## Verificación adicional

- **Cuentas SQL:** ejecuta [`08`](sql/08_cuentas_privilegios.sql) tras la instalación básica, en una copia desechable. El archivo explica cómo activar las cuentas y comprobar sus permisos desde conexiones separadas.
- **Concurrencia:** `07` es secuencial. En una copia desechable, bloquea un lote o un plato en una conexión y lanza en otra la rutina de stock u oferta. Tras confirmar la primera escritura, comprueba que la segunda se rechaza si dejaría el saldo negativo o solaparía la oferta, y que solo queda la primera.

## Documentación

[Requisitos](docs/03_requisitos.md) · [Modelo conceptual](docs/04_modelo_conceptual.md) · [Modelo relacional](docs/05_modelo_relacional.md) · [Modelo tecnológico](docs/06_modelo_tecnologico.md)
