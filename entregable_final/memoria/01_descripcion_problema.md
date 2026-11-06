# 1. Descripción del problema

El sistema tiene como objetivo proporcionar al restaurante Plato-Plató SlowBar (Sevilla) una solución software que permita gestionar de forma integrada los proveedores, ingredientes, stock, mermas, recetas, platos y escandallos.

La información gestionada por el sistema estará interconectada, permitiendo automatizar el cálculo de los costes de producción y facilitar el análisis de la rentabilidad de los platos.

De esta forma, se pretende reducir la dependencia de herramientas poco eficientes, como los cálculos manuales en papel o mediante hojas de cálculo, y centralizar la información relevante para la gestión de costes del restaurante.

La base de datos debe responder, en particular, a tres preguntas de gestión:

- **Cuánto cuesta producir cada plato** (escandallo), teniendo en cuenta recetas que reutilizan otras recetas, sus rendimientos y el precio de compra seleccionado para cada ingrediente.
- **Qué margen deja cada plato**, comparando su coste con el precio de venta y con el margen objetivo fijado por el restaurante.
- **Cuánto se pierde por mermas**, valorando cada pérdida en el momento de registrarla y permitiendo analizarla por causa, ingrediente, plato y periodo.

**Fuera del alcance:** reservas, comandas, facturación, gestión de turnos y registro de ventas. Por este motivo, el modelo calcula costes y márgenes unitarios, pero no ingresos ni unidades vendidas.
