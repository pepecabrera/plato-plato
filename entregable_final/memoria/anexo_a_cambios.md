# Anexo A. Cambios respecto a entregables anteriores

Este anexo mantiene la trazabilidad con la primera entrega (E1) y la segunda entrega (E2). Salvo los cambios aquí indicados, el contenido de esas entregas se conserva.

## A.1. Equivalencia de identificadores

Los identificadores RN-01 a RN-12 de E1 pasaron a ser RC-01 a RC-12 en E2, donde RN-01 a RN-04 designan reglas de negocio nuevas. Por tanto, **un mismo identificador RN tiene un significado distinto en E1 y en E2**. Esta memoria utiliza siempre la numeración de E2.

| E1 | Esta memoria | Regla |
|---|---|---|
| RN-01 | RC-01 | Cantidades de las recetas |
| RN-02 | RC-02 | Componentes de una receta |
| RN-03 | RC-03 | Precios válidos |
| RN-04 | RC-04 | Precios vigentes |
| RN-05 | RC-05 | Cálculo del coste |
| RN-06 | RC-06 | Actualización del coste |
| RN-07 | RC-07 | Margen bruto |
| RN-08 | RC-08 | Margen objetivo |
| RN-09 | RC-09 | Integridad del histórico |
| RN-10 | RC-10 | Permisos según el rol |
| RN-11 | RC-11 | Coste calculable |
| RN-12 | RC-12 | Recetas cíclicas |

Son nuevas en E2 las reglas de negocio RN-01 a RN-04 y el requisito RI-10. Son nuevos en esta memoria RI-11, RC-13 a RC-17 y la inclusión en el catálogo de RG-03 y D-01 a D-07.

## A.2. Problemas detectados y tratamiento

| Id. | Problema | Tratamiento | Sección |
|---|---|---|---|
| P-01 | Coexistían tres versiones del modelo de recetas; una de ellas había perdido el rendimiento, sin el que no puede calcularse el escenario 2. | Se adopta `Receta` recursiva con rendimiento (véase A.3). | 3.3.1, 4.4 |
| P-02 | El borrador del modelo relacional remitía a unas restricciones R-01 a R-15 de un documento inexistente. | Se sustituyen por un catálogo con referencia a cada regla. | 5.1.5 |
| P-03 | RN-02 no tiene umbral, pero el escenario 5 de los archivos de trabajo y la diapositiva 11 de la tercera entrega aplicaban un 35 %. | Prevalece RN-02 y E2 (apartado 4.7.5). Se elimina el umbral (S-01). | 3.3.4, 4.7.5 |
| P-04 | E2 no incorporaba cambios posteriores de requisitos: RG-03, permisos adicionales, precio seleccionado, caducidad opcional y RNF-05. | Se actualizan los requisitos afectados y se incluye la matriz de trazabilidad. | 3 |
| P-05 | Los identificadores RN cambiaron de significado sin tabla de equivalencias. | Se añade la tabla de A.1. | A.1 |
| P-06 | Los escenarios citaban decisiones sin definir (D-01, D-02, D-04, D-05) y archivos inexistentes. | Se definen D-01 a D-07 y se integran los diagramas en la memoria. | 3.3.6, 4.7 |
| P-07 | Había cuatro atributos de unidad sin equivalencias, de modo que el coste no estaba definido con unidades distintas. | Se añaden `UnidadMedida`, RI-11 y RC-15 (S-03). | 3.3.3, 4.3 |
| P-08 | Varias reglas solo aparecían en notas de los diagramas, sin identificador. | Se formalizan RC-13, RC-14, RC-16 y RC-17. | 3.3.3 |
| P-09 | Varios atributos del modelo conceptual no figuraban en ningún requisito de información. | Se incorporan a RI-05, RI-06, RI-07 y RI-08. | 3.3.1 |
| P-10 | Había términos sin definir: «significativo», «próximo», «perecedero», «nueva creación» y «consecutivos». | Se definen en RF-11, RF-12 y los criterios de aplicación de RN-01 y RN-04 (S-08, S-09). | 3.3.2, 3.3.4 |
| P-11 | La merma y su salida duplicaban lote, cantidad y fecha, con riesgo de incoherencia. | Se mantiene como redundancia controlada y justificada (S-05). | 5.3.4 |
| P-12 | `informacionContacto` no era atómico, y `motivo` en texto libre impedía analizar las pérdidas por causa. | Se descomponen ambos atributos (S-06). | 3.3.1, 5.3.1 |
| P-13 | La selección de precio no tiene histórico y el lote no enlaza con su proveedor, por lo que no puede obtenerse el coste real pagado por un lote. | No se modifica, por coherencia con el escenario 3. Se registra como limitación y se guardan los valores evaluados. | 5.3.4, B.2 |
| P-14 | La fila RN-04 de la matriz estaba vacía, y RF-10 contenía una frase propia de RF-09. | Se completa la matriz y se traslada la frase. | 3.3.2, 3.4 |
| P-15 | Ana era encargada en un ejemplo y administradora en el escenario 5. | Ana es administradora; el ejemplo del encargado pasa a Luis. | 4.2 |
| P-16 | La nota de RN-01 del diagrama no coincidía con el requisito. | Las notas de los diagramas reproducen el criterio del requisito. | 4.1, 4.5 |
| P-17 | La vista de oferta tenía notas coloquiales, confundía coste/precio con margen y restringía RN-02 a platos nuevos. | Se reescriben las notas. | 4.6 |

## A.3. Cambio de modelo: de `Subreceta` a `Receta` recursiva

E2 modelaba `Subreceta` como entidad propia y exigía que cada receta perteneciera a un plato o a una subreceta. Después de esa entrega, el equipo decidió eliminar la entidad (D-07). Este es el único cambio que modifica la estructura presentada en E2, y se justifica por lo siguiente:

- **Coherencia con el glosario:** una subreceta ya se definía como una receta utilizada como componente de otra.
- **Reutilización:** una misma elaboración puede ser la receta de un plato y componente de otra receta, sin duplicar datos.
- **Modelo más simple:** desaparecen una entidad, una asociación exclusiva y la duplicidad de la asociación `tieneReceta`.
- **Sin pérdida de información:** `nombre`, `cantidadRendimiento`, `unidadRendimiento` y `/costeUnitario` pasan a `Receta`.

**Tabla A.1. Efecto del cambio en el recuento del modelo conceptual.**

| Elemento | E2 | Esta memoria |
|---|---|---|
| Entidades | 15, con `Subreceta` | 15: se elimina `Subreceta` y se añade `UnidadMedida` |
| Asociaciones | 19 | 22: se elimina una, y se añaden 4 de `UnidadMedida` |
| Asociaciones exclusivas | 3 | 2 |

## A.4. Otros cambios en el modelo conceptual

- **Proveedor:** `informacionContacto` se sustituye por `personaContacto`, `telefono` y `correoContacto`.
- **Merma:** `motivo` pasa al enumerado `MotivoMerma` y se añade `detalleMotivo`.
- **Ingrediente, PrecioCompra, Receta y ComponenteReceta:** sus atributos de unidad pasan a asociaciones con `UnidadMedida`.
- **Enumerados nuevos:** `MotivoMerma` y `TipoMagnitud`.

## A.5. Cambios respecto al borrador del modelo relacional

El modelo relacional no se incluyó en E1 ni en E2. Existía un borrador de trabajo (v1.1, 16 relaciones), del que el modelo final difiere en lo siguiente:

- Se añade la relación `unidades_medida`, con lo que el total es de 17 relaciones.
- Los nombres se normalizan a `snake_case`, para coincidir con el código SQL.
- `roles_permisos` y `permisos_adicionales_usuario` usan clave primaria compuesta en lugar de una clave subrogada, que no aportaba información.
- Se añaden como claves alternativas el nombre de `proveedores`, `ingredientes`, `recetas` y `platos`, y las de `precios_compra` y `periodos_oferta`.
- Los atributos de `proveedores` y `mermas` se adaptan a lo indicado en A.4.

## A.6. Observación sobre la tercera entrega

La tercera entrega, una presentación del modelo conceptual, no forma parte de esta memoria porque el enunciado solo requiere el contenido de las dos primeras (S-10). Conviene tener en cuenta que su diapositiva 11 mantiene el umbral del 35 %, y que su modelo incluye `Subreceta` como entidad. Ambos aspectos quedan superados por lo indicado en este anexo.
