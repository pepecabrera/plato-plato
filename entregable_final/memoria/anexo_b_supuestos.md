# Anexo B. Supuestos y limitaciones

## B.1. Supuestos

Los supuestos completan aspectos que los requisitos no fijaban. Ninguno contradice lo entregado, salvo donde el Anexo A indica lo contrario.

| Id. | Supuesto | Justificación |
|---|---|---|
| S-01 | RN-02 no tiene umbral: toda incorporación a la carta requiere autorización. | Es el texto de RN-02 y del apartado 4.7.5 de E2. |
| S-02 | Se conservan los identificadores RN, RC y D, y las reglas sin identificador pasan a RC-13 a RC-17. | Mantiene la trazabilidad con lo entregado. |
| S-03 | Se añade `UnidadMedida`, con magnitud y factor de conversión. | RC-05 exige una equivalencia válida entre unidades y el modelo no la definía. |
| S-04 | Los atributos derivados se calculan mediante funciones y vistas. Los valores evaluados en un hecho se almacenan. | Evita inconsistencias y cumple RC-06 sin mantenimiento. Los valores evaluados son históricos (RC-09). |
| S-05 | La salida de una merma de lote la genera un trigger. Si no se indica el coste, se calcula con el precio seleccionado y vigente en la fecha de la merma; si no es calculable, queda sin valor. | Evita el doble descuento. El escenario 3 valora la merma de esta forma, y RI-09 admite un coste desconocido. |
| S-06 | El contacto del proveedor se descompone en persona, teléfono y correo, y el motivo de la merma, en una categoría cerrada y un detalle libre. | Atomicidad (1FN) y análisis de pérdidas por causa. Las categorías son las de RI-09. |
| S-07 | Movimientos y mermas no se modifican ni se borran; se corrigen con un movimiento de ajuste. | RC-09. |
| S-08 | RF-11 considera significativo un aumento del 10 % o más, y RF-12 considera próximo un plazo inferior a 48 h. Ambos valores son parámetros. | Los requisitos no fijaban valores. El plazo coincide con RN-01. |
| S-09 | RN-04 exige un único periodo de sugerencia cerrado de al menos 14 días y solo se aplica a la primera incorporación. Es perecedero el lote con fecha de caducidad. | Concreta D-05 y RN-01. RN-02, en cambio, se aplica a todas las incorporaciones. |
| S-10 | La tercera entrega queda fuera de la memoria. | El enunciado solo requiere el contenido de las dos primeras. |
| S-11 | Las recetas no tienen stock: elaborar un plato descuenta directamente los ingredientes de los lotes. | Las salidas de elaboración se destinan a platos, y el modelo no contempla existencias de elaboraciones. |
| S-12 | Un precio es válido para costear si está seleccionado y vigente en el instante del cálculo. El estado del proveedor no interviene. | Definición de D-01. Al desactivar un proveedor se cierran sus precios vigentes. |
| S-13 | El estado de una receta no altera el cálculo del coste, pero una receta o un ingrediente inactivos no pueden añadirse como componentes nuevos. | El coste es función de la composición y los precios. El estado controla el uso futuro. |
| S-14 | Las fechas con hora son locales del restaurante (Europe/Madrid) y se almacenan sin zona horaria. | Así figuraba en los escenarios de prueba. |

## B.2. Limitaciones conocidas

- **Coste histórico aproximado.** La selección de precio no conserva su histórico (P-13). Una merma registrada con fecha pasada se valora con la selección actual, si ese precio estaba vigente en esa fecha. Las mermas y autorizaciones ya registradas no se ven afectadas, porque guardan su valor.
- **Coste real del lote.** Una merma se valora al precio seleccionado, no al precio realmente pagado por ese lote, ya que el lote no se asocia a un proveedor ni a un precio.
- **Permisos.** MariaDB no puede aplicar los permisos del modelo a una consulta directa. RC-10 y RNF-01 se aplican en los procedimientos que reciben el usuario, y la autenticación corresponde a la aplicación.
- **Requisitos no verificables en la base de datos.** RNF-03 (disponibilidad) y RNF-04 (rendimiento) dependen del despliegue y no se verifican mediante scripts.
- **Composición sin versiones.** Modificar una receta cambia el coste calculado desde ese momento; no se conserva la composición anterior.
