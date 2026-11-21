# Anexo B. Supuestos y limitaciones

## B.1. Supuestos

Los supuestos recogen criterios de interpretación y decisiones de alcance de la entrega final. El Anexo A documenta los cambios respecto a entregas anteriores.

| Id. | Supuesto | Justificación |
|---|---|---|
| S-01 | RN-02 no tiene umbral de margen: toda incorporación a la carta requiere autorización de un usuario activo con `AUTORIZAR_CARTA`, concedido por rol o individualmente. | El rol de administrador no sustituye la concesión. Se exige coste calculable y precio de venta definido. |
| S-02 | Se conservan los identificadores RN, RC y D, y las reglas sin identificador pasan a RC-13 a RC-17. | Mantiene la trazabilidad con lo entregado. |
| S-03 | Se añade `UnidadMedida`, con magnitud y factor de conversión. | RC-05 exige una equivalencia válida entre unidades y el modelo no la definía. |
| S-04 | Los atributos derivados se calculan mediante rutinas o consultas (Tabla 5.6). Los importes de una autorización se guardan como datos históricos. | Los costes corrientes no requieren mantener copias (RC-06); los importes evaluados no se recalculan (RC-09). |
| S-05 | `sp_registrar_merma` crea la salida y la merma de lote juntas; una merma de plato no genera salida. El importe total de pérdida es opcional y se aporta al registrar cualquiera de las dos: si no se conoce, queda `NULL`, sin valoración automática. | El trigger valida la correspondencia de la merma de lote con su salida (RC-14). RI-09 admite un coste desconocido. |
| S-06 | El contacto del proveedor se descompone en persona, teléfono y correo, y el motivo de la merma, en una categoría cerrada y un detalle libre. | Atomicidad (1FN) y análisis de pérdidas por causa. Las categorías son las de RI-09. |
| S-07 | Los movimientos y las mermas registrados no pueden modificarse ni eliminarse. Las diferencias de inventario pueden compensarse mediante movimientos de ajuste, pero estos no modifican las mermas ni sus importes históricos. No se implementa la corrección ni la anulación de mermas. | RC-09. |
| S-08 | RF-11 considera significativo un aumento del 10 % o más, y RF-12 considera próximo un plazo inferior a 48 h. Ambos valores son parámetros. | Los requisitos no fijaban valores. El plazo coincide con RN-01. |
| S-09 | RN-04 exige un único periodo de sugerencia cerrado de al menos 14 días y solo se aplica a la primera incorporación. Es perecedero el lote con fecha de caducidad. | Concreta D-05 y RN-01. RN-02, en cambio, se aplica a todas las incorporaciones. |
| S-10 | La tercera entrega queda fuera de la memoria. | El enunciado solo requiere el contenido de las dos primeras. |
| S-11 | Las recetas no tienen stock: elaborar un plato descuenta directamente los ingredientes de los lotes. | Las salidas de elaboración se destinan a platos, y el modelo no contempla existencias de elaboraciones. |
| S-12 | Para costear se usa el precio actualmente seleccionado si está vigente en la fecha de referencia. El cálculo no filtra por estado del proveedor. | D-01. La entrega no incluye un flujo que cierre precios de forma automática al desactivar un proveedor. |
| S-13 | El cálculo usa la composición registrada sin filtrar por estado de las recetas ni de los ingredientes. | El alta de recetas valida los componentes y sus unidades, pero no excluye referencias por su estado. |
| S-14 | Las fechas con hora son locales del restaurante (Europe/Madrid) y se almacenan sin zona horaria. | Así figuraba en los escenarios de prueba. |

## B.2. Limitaciones conocidas

- **Coste a una fecha pasada.** No se conserva el historial de selección de precios (P-13). Una consulta de coste con fecha pasada usa la selección y la composición actuales, con la vigencia evaluada en esa fecha. No reconstruye la evaluación original. Las autorizaciones guardan los importes evaluados y las mermas el importe aportado o `NULL`.
- **Coste real del lote.** El modelo no permite deducirlo: el lote no se asocia a un proveedor ni a un precio de compra. Un importe de merma aportado puede proceder de una valoración externa, pero el sistema no la calcula ni comprueba su procedencia.
- **Permisos y autenticación.** Las cuentas operativas se autentican en MariaDB y tienen privilegios diferenciados sobre vistas y procedimientos públicos, sin acceso directo a tablas (RNF-01). La vinculación con usuarios de aplicación en esos procedimientos es específica de la demostración; la autenticación de una futura aplicación queda fuera de alcance. En la demostración, solo la cuenta SQL de administrador tiene acceso al procedimiento público de incorporación a carta; el procedimiento interno exige además la concesión explícita de `AUTORIZAR_CARTA` (RN-02).
- **Escrituras fuera del flujo operativo.** Las cuentas privilegiadas pueden insertar directamente filas que no pasan por los procedimientos. C-23 detecta recetas sin componentes y cartas sin autorización; C-26 detecta saldos negativos, mermas discordantes y salidas por merma sin merma asociada. Ninguna consulta bloquea ni corrige esas escrituras.
- **Requisitos no verificables en la base de datos.** RNF-03 (disponibilidad) y RNF-04 (rendimiento) dependen del despliegue y no se verifican mediante scripts.
- **Composición sin versiones.** Modificar una receta cambia el coste calculado desde ese momento; no se conserva la composición anterior.
