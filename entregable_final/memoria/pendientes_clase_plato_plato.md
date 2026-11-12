# Plato-Plató: seguimiento para la entrega de clase

Actualizado: 12/11/2026. Casillas marcadas = implementado y revisado estáticamente, no ejecutado en MariaDB. La validación real del punto 2 sigue aplazada.

## Cambios implementados

- [x] **1. Permiso en 06.** ADMINISTRADOR recibe GESTIONAR_PLATOS. Los mismos 16 pares rol-permiso que 02. Corrección anterior incluida en el paquete.
- [x] **5. Coherencia de mermas.** BEFORE INSERT comprueba lote, cantidad, fecha, tipo SALIDA y finalidad MERMA del movimiento. UNIQUE impide reutilizar el enlace. Mermas de plato sin cambios.
- [x] **6. Rendimiento en raciones.** INSERT/UPDATE de platos y cambio de unidad en su receta exigen magnitud RACION. Subrecetas sin plato pueden rendir en kg o litros.
- [x] **7. Alta completa.** sp_registrar_receta exige GESTIONAR_RECETAS y lista JSON no vacía. Registra cabecera y componentes en una transacción y revierte todo ante error.
- [x] **7. Último componente.** Se bloquea su borrado y su traslado a otra receta mediante UPDATE.
- [x] **8. Protección mínima de lotes.** No se permite cambiar ingrediente ni fecha de entrada si existen movimientos. Ubicación editable; sin histórico de aptitud.
- [x] **10. C-26.** Orden por fecha e ID y marco ROWS, igual que los procedimientos. Detecta negativos intermedios entre movimientos simultáneos.
- [x] **12. Costes históricos.** Documentado: composición y selección de precios actuales; la fecha filtra vigencia. No se añade histórico.
- [x] **17. Documentación.** Actualizados 6.1–6.7, cobertura y límites. Eliminadas afirmaciones de ejecución con versión sin rellenar.
- [x] **Pruebas.** 66 de esquema, 128 de negocio y 12 opcionales del poblado. 206 definidas, no todas en una misma pasada. 34 regresiones nuevas.

## Validación pendiente (2)

- [ ] En una copia vacía: 01 → 02 → 03 → 07; después 04 → 05 → 07.
- [ ] En otra copia vacía: 01 → 06 → 07.
- [ ] Verificar procedimientos, JSON_TABLE y triggers en la versión MariaDB del equipo.
- [ ] Guardar fecha, versión concreta y salidas OK/FALLO/PENDIENTE; corregir los fallos observados.
- [ ] Incorporar solo resultados reales a la documentación.

## Decisiones y límites aceptados

| Punto | Decisión |
|---|---|
| 3 | Privilegios MariaDB aplazados; no se crea 08 ni se impiden todas las escrituras directas. |
| 4 | Mermas definitivas, sin edición, borrado ni anulación. Ajustar stock no corrige sus informes. |
| 7 | El alta operativa usa el procedimiento. Un INSERT manual puede dejar una cabecera vacía; no se declara garantía universal. El borrado completo por CASCADE no ejecuta los triggers de componentes y sigue sujeto a las FK. |
| 8 | Solo se protegen ingrediente y recepción. Sin historial de aptitud ni congelación de caducidad, frescura o aptitud. |
| 9 | Demostración secuencial; concurrencia general no certificada. Se mantienen los bloqueos existentes. |
| 11 | Se conserva cantidad disponible como saldo registrado; no garantiza uso para elaboración. |
| 13 | Usuario responsable y motivo de ajustes aplazados salvo requisito del enunciado. |
| 14 | No se valida pertenencia del ingrediente retirado a la receta destino. |
| 15 | Se conserva RN-02 con administrador activo y el comportamiento actual de fn_tiene_permiso ante nombres inexistentes del administrador. |
| 16 | Se conserva Europe/Madrid y la limitación documentada del cambio de hora, sin nueva configuración de conexión. |

## Archivos

SQL 03, 04, 05 y 07 modificados; 06 incluye la corrección anterior del punto 1. Modelo tecnológico actualizado. 01 y 02 no requieren cambios.
