# Plato-Plató · Escenarios de prueba del modelo conceptual

## 1. Alcance y lectura de los diagramas

Este documento presenta cinco escenarios de prueba del modelo conceptual: cuatro situaciones válidas y una operación que debe rechazarse. Cada escenario tiene su propio diagrama de objetos UML en XML editable con draw.io (diagrams.net).

Se toma como referencia `Plato-Plato_modelo_conceptual.puml`, en su versión de un único diagrama. Se mantienen `PeriodoOferta`, `AutorizacionCarta` y los usuarios con roles; las simplificaciones discutidas posteriormente no se han aplicado al modelo.

Los diagramas son **vistas parciales de situaciones concretas**, no diagramas de clases completos:

- Cada cabecera subrayada tiene la forma `nombreObjeto : Clase`.
- Los compartimentos contienen valores concretos de atributos. No se introducen clases ni asociaciones nuevas.
- Las líneas representan enlaces entre los objetos; no muestran multiplicidades, porque cada extremo es un objeto concreto.
- El rombo negro, cuando aparece, está junto a la receta que contiene el componente.
- `/` identifica un valor derivado calculado para la instantánea.
- `sin valor` indica que un atributo opcional no está informado; no es una cadena que deba almacenarse.
- Los atributos y objetos no relevantes se omiten para mejorar la legibilidad. Su omisión no significa que no existan ni que puedan incumplirse las multiplicidades obligatorias.
- Todos los importes monetarios están expresados en euros. Las fechas con hora son locales del restaurante, con zona Europe/Madrid.
- En el escenario 4, los elementos rojos discontinuos son una **operación propuesta y rechazada**, no información persistida.

## 2. Resumen

| Escenario | Objetivo | Reglas principales | Resultado esperado |
| --- | --- | --- | --- |
| 1. Precio seleccionado | Elegir un precio entre dos proveedores del mismo ingrediente | D-01, RC-03, RC-04, RC-11 | Válido; referencia de 1,20 €/kg |
| 2. Coste con subreceta | Aplicar cantidades y rendimiento al escandallo | D-02, RC-01, RC-02, RC-05, RC-07, RC-11, RC-12 | Válido; coste del plato de 0,60 € |
| 3. Merma de lote | Registrar una pérdida y descontar el stock una sola vez | RI-07, RI-08, RI-09, RC-09 | Válido; saldo de 8 kg y pérdida de 4 € |
| 4. Límite de frescura | Rechazar una elaboración justo al cumplir 72 horas | RN-03, D-04 | Rechazado; saldo sin cambios |
| 5. Incorporación a carta | Comprobar prueba previa y autorización económica | RN-02, RN-04, D-05, RC-09 | Válido; incorporación autorizada |

## 3. Escenario 1 · Precio de referencia de un ingrediente

### Descripción textual

El 29 de octubre de 2026 a las 12:00, el restaurante tiene registrado el ingrediente harina y precios de dos proveedores. Distribuciones Norte la ofrece a 1,20 €/kg y Suministros Sur a 1,40 €/kg. Ambos precios son válidos desde el 1 de octubre de 2026 y no tienen fecha de fin. Solo se selecciona el primero para calcular costes.

### Datos y objetos

| Objeto | Clase | Datos relevantes |
| --- | --- | --- |
| `harina` | `Ingrediente` | Nombre: Harina; unidad: kg; activo |
| `proveedorA` | `Proveedor` | Distribuciones Norte; activo |
| `proveedorB` | `Proveedor` | Suministros Sur; activo |
| `precioA` | `PrecioCompra` | 1,20 €/kg; inicio 01/10/2026; sin fin; seleccionado |
| `precioB` | `PrecioCompra` | 1,40 €/kg; inicio 01/10/2026; sin fin; no seleccionado |

### Enlaces representados

`harina` se enlaza mediante `tienePrecio` a los dos precios. Cada proveedor se enlaza mediante `ofrece` a su precio correspondiente. Cada precio pertenece a un único ingrediente y a un único proveedor.

### Comprobación y resultado esperado

1. Los dos importes son positivos: se cumple RC-03.
2. Hay un único registro para cada par proveedor–ingrediente; no existe solapamiento de vigencias para un mismo par: se cumple RC-04.
3. Ambos precios están vigentes en el instante de evaluación, pero solo `precioA` tiene `seleccionadoParaCosteo = true`: se cumple D-01.
4. El precio utilizado para costear la harina es **1,20 €/kg**. Una cantidad hipotética de 0,5 kg tendría un coste de `0,5 × 1,20 = 0,60 €`. Esta cantidad es un ejemplo de cálculo, no otro objeto del diagrama.

**Resultado: válido.** La selección es explícita: el sistema no elige automáticamente el proveedor más barato. Que aquí coincida con el más barato es circunstancial.

**Diagrama:** [01_precio_seleccionado.xml](01_precio_seleccionado.xml).

## 4. Escenario 2 · Coste de un plato que utiliza una subreceta

### Descripción textual

El 29 de octubre de 2026 a las 12:00, el restaurante calcula el coste de una degustación de salsa de tomate. Para aislar el cálculo, este ejemplo académico utiliza una salsa simplificada con un único ingrediente: tomate.

Una elaboración de la subreceta consume 2 kg de tomate y produce 1,5 kg de salsa. El precio seleccionado y vigente del tomate es 3 €/kg. La receta del plato utiliza 0,15 kg de esa salsa para una ración. El plato se vende a 3 €.

### Datos y objetos

| Objeto | Clase | Datos relevantes |
| --- | --- | --- |
| `degustacion` | `Plato` | Degustación de salsa; precio de venta: 3 € |
| `recetaPlato` | `Receta` | Activa; produce una unidad del plato |
| `porcionSalsa` | `ComponenteReceta` | 0,15 kg de `salsa` |
| `salsa` | `Subreceta` | Salsa de tomate; rendimiento: 1,5 kg |
| `recetaSalsa` | `Receta` | Activa; produce el rendimiento de la subreceta |
| `tomateSalsa` | `ComponenteReceta` | 2 kg de `tomate` |
| `tomate` | `Ingrediente` | Tomate; unidad: kg |
| `precioTomate` | `PrecioCompra` | 3 €/kg; vigente desde 01/10/2026, sin fin; seleccionado |
| `huerta` | `Proveedor` | Huerta Local; activo |

### Enlaces representados

`degustacion` tiene `recetaPlato`, que se compone de `porcionSalsa`. Esa línea utiliza la subreceta `salsa`. A su vez, `salsa` tiene `recetaSalsa`, compuesta por `tomateSalsa`, que utiliza `tomate`. Este ingrediente tiene `precioTomate`, ofrecido por `huerta`.

Cada receta tiene exactamente un propietario: una pertenece al plato y la otra a la subreceta. Cada componente pertenece a una única receta y utiliza un ingrediente **o** una subreceta, nunca ambos.

### Comprobación y resultado esperado

| Cálculo | Operación | Resultado |
| --- | --- | --- |
| Coste de una elaboración de salsa | 2 kg × 3 €/kg | 6 € |
| Coste unitario de salsa | 6 € / 1,5 kg | 4 €/kg |
| Coste de una ración de degustación | 0,15 kg × 4 €/kg | 0,60 € |
| Margen bruto de la ración | 3 € − 0,60 € | 2,40 € |
| Porcentaje de margen | 100 × 2,40 / 3 | 80 % |

Todas las cantidades y el rendimiento son positivos. Las unidades son compatibles, no hay líneas repetidas y no hay ciclos entre subrecetas. Todas las dependencias tienen un precio válido. Los valores derivados del diagrama coinciden con los cálculos.

**Resultado: válido.** El coste de una elaboración completa de salsa no debe confundirse con el coste de la cantidad que utiliza el plato. Este escenario comprueba el escandallo; no registra una elaboración real ni movimientos de almacén.

**Diagrama:** [02_coste_subreceta.xml](02_coste_subreceta.xml).

## 5. Escenario 3 · Merma de ingrediente y saldo del lote

### Descripción textual

El 28 de octubre de 2026 a las 09:00 se reciben 10 kg de arroz en el lote ARR-001. La recepción queda registrada mediante un movimiento de entrada. El 29 de octubre a las 10:00 se rompe un envase y se derraman 2 kg, que se registran como merma.

La valoración aplicable a ese registro es de 2 €/kg. El precio seleccionado que permite obtener esa valoración se supone válido y se omite, junto con su proveedor, porque esta vista se centra en el inventario. ARR-001 es el único lote de arroz y no tiene otros movimientos.

### Datos y objetos

| Objeto | Clase | Datos relevantes |
| --- | --- | --- |
| `arroz` | `Ingrediente` | Arroz; unidad: kg; existencia total derivada: 8 kg |
| `loteArroz` | `Lote` | ARR-001; entrada 28/10/2026 09:00; no fresco; apto; saldo derivado: 8 kg |
| `entradaArroz` | `MovimientoStock` | ENTRADA; 10 kg; 28/10/2026 09:00; sin finalidad de salida |
| `salidaMerma` | `MovimientoStock` | SALIDA; 2 kg; 29/10/2026 10:00; finalidad MERMA |
| `mermaArroz` | `Merma` | 2 kg; misma fecha que la salida; motivo: envase roto y derrame; pérdida: 4 € |

El lote caduca el 28/10/2027 a las 09:00. Este dato no impide registrar la pérdida por derrame.

### Enlaces representados

`arroz` tiene `loteArroz`. Este lote recibe los movimientos `entradaArroz` y `salidaMerma`. `mermaArroz` afecta a ese lote y origina exactamente `salidaMerma`. No afecta a un plato y el movimiento de merma no tiene plato destino.

### Comprobación y resultado esperado

1. La entrada inicial se cuenta una sola vez mediante su movimiento.
2. La merma y su salida tienen el mismo lote, cantidad y fecha.
3. El saldo es `10 − 2 = 8 kg`; no resulta negativo.
4. La existencia total del ingrediente es 8 kg porque solo tiene ese lote.
5. El coste de la pérdida es `2 kg × 2 €/kg = 4 €`. Se conserva en `costePerdida`; no se recalcula por cambios futuros de precios.

**Resultado: válido.** Se descuenta el movimiento de salida una vez. Restar además la cantidad de la entidad `Merma` produciría un saldo incorrecto de 6 kg.

**Diagrama:** [03_merma_lote.xml](03_merma_lote.xml).

## 6. Escenario 4 · Rechazo de un lote fresco al cumplir 72 horas

### Descripción textual

Un lote fresco de lechuga entra el 26 de octubre de 2026 a las 10:00. El 29 de octubre de 2026 a las 10:00 se intenta registrar una salida de 0,20 kg para elaborar una ensalada del menú del día.

El lote tiene 3 kg disponibles, sigue marcado como apto y no caduca hasta el 5 de noviembre de 2026 a las 10:00. Sin embargo, en el instante del intento se cumplen exactamente 72 horas desde la recepción.

### Datos y objetos

| Objeto | Clase | Datos relevantes |
| --- | --- | --- |
| `lechuga` | `Ingrediente` | Lechuga; unidad: kg |
| `loteLechuga` | `Lote` | LEC-001; fresco; apto; saldo: 3 kg; entrada 26/10/2026 10:00 |
| `ensalada` | `Plato` | Ensalada verde; activa; `menuDelDia = true` |
| `salidaPropuesta` | `MovimientoStock` | Intento de SALIDA; 0,20 kg; 29/10/2026 10:00; finalidad ELABORACION |

El saldo previo de 3 kg procede de una entrada de 3 kg y de la ausencia de otras salidas o ajustes. Esa entrada y la receta del plato se omiten por no ser el foco de la prueba.

### Enlaces representados

El enlace `lechuga — loteLechuga` representa información existente. Los enlaces discontinuos `loteLechuga — salidaPropuesta` y `salidaPropuesta — ensalada` representan lo que se intenta añadir; no son enlaces ya aceptados en la base de datos.

### Comprobación y resultado esperado

1. Límite de uso por frescura: `26/10/2026 10:00 + 72 h = 29/10/2026 10:00`.
2. RN-03 prohíbe usar el lote **a partir de** ese límite, incluida la igualdad.
3. La fecha de caducidad, la existencia suficiente, el valor `aptoParaConsumo = true` y pertenecer al menú del día no eliminan la prohibición de frescura.
4. El movimiento propuesto no se registra. El saldo permanece en **3 kg**, no pasa a 2,80 kg.
5. El rechazo no crea automáticamente una merma ni retira físicamente el lote. Cualquier pérdida posterior debe registrarse por separado.

**Resultado: rechazado por RN-03.** El diagrama muestra deliberadamente un intento inválido, claramente marcado en rojo y con trazo discontinuo. No se presenta como un estado válido del modelo.

**Diagrama:** [04_rechazo_lote_fresco.xml](04_rechazo_lote_fresco.xml).

## 7. Escenario 5 · Incorporación a la carta con autorización

### Descripción textual

La lasaña se ofrece de forma real y continuada como sugerencia del chef desde el 1 de octubre de 2026 a las 12:00 hasta el 15 de octubre a las 12:00. Al terminar la prueba se incorpora por primera vez a la carta permanente.

Su coste de producción es de 4 € por unidad y su precio de venta es de 10 €. Como el coste supera el 35 % del precio de venta, Ana, administradora activa, autoriza la incorporación el 15 de octubre a las 11:00. El coste y el precio evaluados siguen siendo aplicables una hora después, al comenzar el periodo de carta permanente.

### Datos y objetos

| Objeto | Clase | Datos relevantes |
| --- | --- | --- |
| `lasana` | `Plato` | Lasaña; activa; precio: 10 €; coste derivado: 4 € |
| `pruebaLasana` | `PeriodoOferta` | SUGERENCIA_CHEF; 01/10/2026 12:00 a 15/10/2026 12:00 |
| `cartaLasana` | `PeriodoOferta` | CARTA_PERMANENTE; desde 15/10/2026 12:00, sin fin |
| `aprobacionLasana` | `AutorizacionCarta` | 15/10/2026 11:00; coste evaluado: 4 €; precio evaluado: 10 € |
| `ana` | `Usuario` | Ana; activa |
| `rolAdmin` | `Rol` | ADMINISTRADOR |

Se supone verificado que Ana está autenticada y tiene ese rol al emitir la aprobación. Se omiten la receta de la lasaña, sus componentes, los precios vigentes que justifican el coste y los permisos del rol; no se está permitiendo un plato sin receta ni un coste sin justificación.

### Enlaces representados

`lasana` tiene los dos periodos de oferta. `cartaLasana` tiene `aprobacionLasana`, emitida por `ana`, que tiene `rolAdmin`. La aprobación se asocia al periodo de carta permanente, no al periodo de prueba.

### Comprobación y resultado esperado

1. La prueba dura exactamente **14 días consecutivos**, ya transcurridos cuando comienza la carta permanente. Se cumple RN-04.
2. Proporción de coste: `100 × 4 / 10 = 40 %`. Como `40 % > 35 %`, se necesita autorización según RN-02.
3. La autorización se emite a las 11:00 y la incorporación se produce a las 12:00: es previa.
4. La emisora tiene el rol ADMINISTRADOR en el momento de autorizar.
5. El coste y precio guardados en la autorización coinciden con la evaluación aplicable a la incorporación. No cambia la evaluación entre la autorización y el alta.
6. Se conservan fecha, autora y evaluación como registro histórico. Los periodos no duplican intervalos del mismo tipo.

**Resultado: válido.** Puede iniciarse el periodo de carta permanente. La autorización económica no sustituye a los 14 días de prueba: se cumplen ambas condiciones.

**Diagrama:** [05_carta_autorizada.xml](05_carta_autorizada.xml).

## 8. Archivos y apertura

- `01_precio_seleccionado.xml` a `05_carta_autorizada.xml`: cinco diagramas independientes.
- `Plato-Plato_5_escenarios.xml`: los mismos cinco diagramas reunidos en un archivo con cinco páginas.
- `Escenarios_de_prueba.md`: este documento.

Para abrir un XML, entra en draw.io / diagrams.net y utiliza **Archivo → Abrir desde → Dispositivo**. Selecciona el XML. En el archivo conjunto, cambia de escenario mediante las pestañas de las páginas. También puedes utilizar una extensión de draw.io compatible con tu editor.

Estos XML son documentos de draw.io (`mxfile`), no archivos PlantUML ni XMI para intercambio entre herramientas CASE. Cada escenario muestra un caso concreto; el conjunto no pretende ser una prueba exhaustiva de todas las reglas del proyecto.
