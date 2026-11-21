# Plato-Plató: seguimiento para la entrega de clase

Estado de la entrega: los cambios implementados, las comprobaciones ya observadas y la validación final de clase se registran por separado.

## Cambios implementados

- [x] **1. Concesiones en 02 y 06.** Ambos poblados registran 8 permisos, 15 pares rol-permiso (8 de administrador, 5 de encargado y 2 de empleado) y una concesión individual: `CONSULTAR_COSTES` para Marta. Administrador y encargado reciben `GESTIONAR_PLATOS`; solo el rol administrador recibe `AUTORIZAR_CARTA` en el poblado.
- [x] **3. Privilegios MariaDB.** 08 concede `SELECT` sobre vistas y `EXECUTE` sobre procedimientos públicos, según el perfil. No concede acceso directo a tablas ni a rutinas internas, tampoco a `pp_administrador`.
- [x] **5. Coherencia de mermas.** BEFORE INSERT comprueba lote, cantidad, fecha, tipo SALIDA y finalidad MERMA del movimiento. UNIQUE impide reutilizar el enlace. Mermas de plato sin cambios.
- [x] **6. Rendimiento en raciones.** INSERT/UPDATE de platos y cambio de unidad en su receta exigen código `racion`, magnitud `RACION` y factor 1. Subrecetas sin plato pueden rendir en kg o litros.
- [x] **7. Alta completa.** sp_registrar_receta exige GESTIONAR_RECETAS y lista JSON no vacía. Registra cabecera y componentes en una transacción y revierte todo ante error.
- [x] **7. Último componente.** Se bloquea su borrado y su traslado a otra receta mediante UPDATE.
- [x] **8. Protección mínima de lotes.** No se permite cambiar ingrediente ni fecha de entrada si existen movimientos. Ubicación editable; sin histórico de aptitud.
- [x] **10. C-26.** Orden por fecha e ID y marco ROWS, igual que los procedimientos. Detecta negativos intermedios entre movimientos simultáneos.
- [x] **12. Costes históricos.** Documentado: composición y selección de precios actuales; la fecha filtra vigencia. No se añade histórico.
- [x] **15. RN-02 por permiso explícito.** Usuario activo con `AUTORIZAR_CARTA` por rol o individual, sin excepción para el administrador. C-02 lista concesiones de usuarios activos y su origen, no los permisos efectivos ni los `GRANT` de 08.
- [x] **Coste de subrecetas.** C-09/C-10 y `fn_coste_receta` admiten hasta 64 enlaces; si se necesita un enlace 65 el coste no es calculable (`NULL`).
- [x] **17. Documentación.** Modelo tecnológico alineado con SQL 01–08, con matrices de privilegios y trazabilidad.
- [x] **Pruebas.** 07 define 66 comprobaciones de esquema, 143 de negocio y 12 de movimientos del poblado 06: 221 en total, no todas en una pasada. Las entradas `PENDIENTE` no se cuentan como aprobadas.

## Rutas de ejecución

| Copia | Orden desde `sql/` | Resultado esperado de 07 |
|---|---|---|
| Pruebas con `INSERT` | `01 → 02 → 03 → 07 → 04 → 05 → 07` | 66 y después 143 |
| Pruebas con procedimientos | `01 → 06 → 03 → 07 → 04 → 05 → 07` | 66 + 12 y después 143; las 12 no se repiten si ya existen los lotes auxiliares |
| Demostración con cuentas | `01 → (02 o 06) → 04 → 05 → 08` | Sin 07; 03 es opcional y se ejecuta con la cuenta instaladora |

No combinar 02 y 06 en una copia. Usar copias desechables y separarlas de la demostración: 07 confirma algunas escrituras. Para 08, instalar con las cuentas aún inexistentes, asignar claves distintas y desbloquearlas según el README antes de probar por socket local.

## Validaciones ya observadas

- En **MariaDB 13.0.2**, se observaron 66 comprobaciones de esquema y 143 de negocio aprobadas con cada poblado, más las 12 de movimientos con 06.
- A fecha de referencia `2026-11-15 12:00:00`, se observó la coincidencia a cuatro decimales entre C-10 y `fn_coste_plato` en ambos poblados: pasta 0,7232 €, tortilla 0,8416 €.
- Fuera de 07 se observaron accesos y llamadas permitidos por 08, y los rechazos de costes al encargado, proveedores al empleado, escritura directa al administrador y llamada del empleado a una rutina interna que recibe un ID de usuario.

## Validación final pendiente (2)

- [ ] Repetir las dos rutas sobre copias limpias en la versión de clase, incluidos C-23 a C-27 y la comparación C-10 frente a la función.
- [ ] En una copia separada, repetir las comprobaciones permitidas y denegadas de 08 desde las tres cuentas operativas locales.
- [ ] Revisar en 07 el **escenario 5: Incorporación autorizada a la carta** (RN-02/RN-04: administrador sin concesión rechazado y encargado con concesión individual admitido) y el **escenario 6: Límite de 48 horas antes de caducar** (RN-01: justo a 48 horas y un microsegundo después).
- [ ] Guardar fecha, versión concreta y salidas de consultas, accesos y `OK`/`FALLO`/`PENDIENTE`; no presentar la evidencia anterior como validación final.

## Decisiones y límites aceptados

| Punto | Decisión |
|---|---|
| 3 | 08 restringe las tres cuentas locales de demostración, no a la instaladora ni a otras cuentas. La matriz del modelo tecnológico separa privilegios SQL de concesiones de aplicación; 07 no comprueba privilegios con conexiones operativas. |
| 4 | Mermas definitivas, sin edición, borrado ni anulación. Ajustar stock no corrige sus informes. |
| 7 | El alta operativa usa el procedimiento. Un INSERT manual puede dejar una cabecera vacía; no se declara garantía universal. El borrado completo por CASCADE no ejecuta los triggers de componentes y sigue sujeto a las FK. |
| 8 | Solo se protegen ingrediente y recepción. Sin historial de aptitud ni congelación de caducidad, frescura o aptitud. |
| 9 | Demostración secuencial; concurrencia general no certificada. Se mantienen los bloqueos existentes. |
| 11 | Se conserva cantidad disponible como saldo registrado; no garantiza uso para elaboración. |
| 13 | Usuario responsable y motivo de ajustes aplazados salvo requisito del enunciado. |
| 14 | No se valida pertenencia del ingrediente retirado a la receta destino. |
| 15 | RN-02 no utiliza el acceso general que `fn_tiene_permiso` conserva para administradores activos. Solo `pp_administrador` tiene `EXECUTE` sobre la incorporación pública en 08, pero necesita además la concesión de aplicación. |
| 16 | Se conserva Europe/Madrid y la limitación documentada del cambio de hora, sin nueva configuración de conexión. |

La concurrencia con varias conexiones y la cobertura de las demás rutinas de 06 siguen sin certificarse.

## Archivos de referencia

El [modelo tecnológico](06_modelo_tecnologico.md) documenta los scripts 01–08, las matrices y el alcance de las pruebas. Esta actualización es solo documental.
