# 6. Modelo tecnológico

## 6.1. Script de creación de tablas y restricciones

El archivo `sql/01_tablas.sql` crea una base nueva `plato_plato` y sus 17 tablas. No elimina objetos existentes ni incluye datos iniciales. Se ejecuta completo, deteniéndose al primer error. Usa InnoDB, utf8mb4 y modo estricto. El DDL puede realizar commits implícitos; no debe tratarse como una migración reversible mediante ROLLBACK.

### Decisiones físicas

- Identificadores: INT UNSIGNED autogenerados; claves compuestas en las dos concesiones N:M.
- Unidades: código ASCII binario de hasta 10 caracteres, magnitud y factor positivo DECIMAL(18,6). La unidad base de cada magnitud deberá fijarse en los datos iniciales.
- Cantidades y rendimientos: DECIMAL(14,4); precios de compra: DECIMAL(14,4); precios de venta e importes históricos: DECIMAL(14,2). El redondeo económico final corresponde a las rutinas de cálculo.
- Fechas: DATETIME(6) en hora local Europe/Madrid (S-14). DEFAULT CURRENT_TIMESTAMP exige que la conexión tenga la hora local correcta; el script no configura la zona con nombre porque depende de las tablas horarias del servidor. Los cálculos de 48/72 horas siguen la convención local adoptada; si se necesitan horas reales durante cambios de horario, el equipo deberá migrar coherentemente a UTC.
- Nombres únicos según el MR. La colación utf8mb4_unicode_ci compara sin distinguir mayúsculas; deben revisarse sus efectos sobre las denominaciones del catálogo.
- Porcentaje objetivo opcional en [0,100); imágenes y costes desconocidos admiten NULL.
- FK restrictivas, salvo concesiones y composición ON DELETE CASCADE y códigos de unidad ON UPDATE CASCADE, según 5.1.4.
- Columna VIRTUAL única para un único precio seleccionado por ingrediente. La vigencia sigue siendo una comprobación posterior.
- La longitud mínima del hash evita cadenas triviales, pero no demuestra que se haya aplicado un algoritmo seguro. El hash se genera fuera de SQL.

### Cobertura del DDL y trabajo pendiente

| Regla | Garantía declarativa incluida | Pendiente de otros bloques |
|---|---|---|
| RC-01–03 | Cantidades, rendimientos y precios positivos; componentes únicos | — |
| RC-04, D-01 | Fechas ordenadas, inicio único por proveedor/ingrediente y selección única | Solapamientos de vigencias y validación al costear |
| RC-05–08, RC-11 | Objetivo opcional en rango; derivados ausentes de las tablas | Funciones de coste, vista de margen, propagación de NULL y permisos |
| RC-09–10 | FK según política y tablas de permisos | Protección de hechos históricos, autenticación y autorización |
| RC-12 | Impide receta componente igual a receta contenedora | Ciclos indirectos, incluidos UPDATE |
| RC-13 | Signo según tipo de movimiento | Saldos históricos no negativos y concurrencia |
| RC-14 | Merma de lote o plato; movimiento obligatorio solo para lote y único | Crear salida atómica y comparar lote, cantidad, fecha y finalidad; impedir salidas de merma huérfanas |
| RC-15 | FK a unidades y factor positivo | Magnitudes compatibles y rendimiento en raciones; proteger cambios relacionados |
| RC-16 | Inicio único y fin posterior | Solapamientos de oferta |
| RC-17 | Coherencia entre tipo, signo, finalidad y destino | Fecha del lote, primera entrada y unidad implícita del movimiento |
| RN-01–04 | Estructura de lotes, oferta y autorizaciones | Todas las comprobaciones temporales, de aptitud, prueba previa y administrador |
| RNF-02 | Hash de longitud mínima | Algoritmo seguro y verificación externa |

Una receta puede quedar temporalmente sin componentes: el procedimiento que registra la receta completa debe verificar su mínimo 1..*. El DDL no garantiza autorización para cada periodo de carta. El procedimiento de incorporación debe insertar periodo y autorización en una transacción y gestionar el error; los privilegios deben impedir eludirlo mediante escrituras directas.

Para la merma de lote se prevé un trigger BEFORE INSERT que cree el movimiento y asigne NEW.id_movimiento antes de validar la referencia. El bloque de inventario debe probarlo: este DDL no crea el trigger ni acepta una merma de lote sin movimiento. No debe intentarse completar esa referencia mediante un trigger AFTER INSERT que actualice la misma merma.

Toda validación entre filas necesita una estrategia de concurrencia. Comprobar mediante SELECT sin acordar bloqueos no garantiza por sí solo que dos operaciones simultáneas mantengan saldos y periodos válidos.