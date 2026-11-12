| Prioridad | Error o pendiente | Qué cambiar | Estado 
|---|---|---|---|
| **Urgente** | Los procedimientos exigen `GESTIONAR_PLATOS`, pero no existe en los poblados. | Añadirlo y asignarlo a los roles correspondientes en `02` y `06`; actualizar recuentos. | Hecho |
| **Urgente** | Las mermas pueden modificarse o borrarse, dejando su salida incoherente. | Proteger `mermas` frente a `UPDATE` y `DELETE` y definir cómo corregirlas. | Hecho |
| **Urgente** | Falta un procedimiento operativo completo para registrar mermas. | Crear uno que valide permisos y saldos y registre salida y merma en una misma transacción. | Hecho |
| **Urgente** | `07_pruebas.sql` espera errores antiguos y no prueba las rutinas actuales. | Adaptarlo a `04` y `05`, distinguiendo pruebas del esquema y de negocio. | Hecho |
| **Importante** | `pob_registrar_movimiento` comprueba el saldo total, no los saldos históricos. | Comprobar todos los saldos acumulados, como hace el procedimiento del `04`. | Hecho |
| **Importante** | Las rutinas `pob_` no son todas seguras al invocarlas por separado. | Restringirlas al poblado o completar sus transacciones; impedir ejecutar el poblado principal dentro de otra transacción. |
| **Importante** | Se permiten ciclos indirectos, precios solapados y unidades incompatibles. | Añadir validaciones de alta y modificación, con bloqueos adecuados. |
| **Importante** | Cambiar unidades puede reinterpretar cantidades históricas. | Impedir cambios incompatibles cuando existan datos relacionados. |
| **Importante** | No están configurados los privilegios de las cuentas operativas. | Añadir permisos de servidor que impidan eludir los procedimientos mediante escrituras directas. |
| **Normal** | C-26 y el procedimiento de movimientos tratan de forma diferente los movimientos simultáneos. | Unificar el orden y el criterio de cálculo del saldo. |
| **Normal** | C-13 llama «disponible» a stock que puede estar caducado o no ser utilizable. | Separar existencias totales y utilizables, o cambiar el nombre. |
| **Normal** | Consultar una fecha pasada utiliza recetas y selección de precios actuales. | Documentar que no reconstruye completamente el escandallo histórico. |
| **Mínimo** | La memoria y los comentarios describen versiones anteriores. | Actualizar el capítulo 6 y `06_7_pruebas.md`: las fechas ya no se solapan, ambos poblados coinciden y sí existen funciones y triggers. |