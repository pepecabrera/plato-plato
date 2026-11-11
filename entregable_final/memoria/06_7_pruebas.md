# 6.7. Script de creación de pruebas y llamadas

El archivo `sql/07_pruebas.sql` crea dos procedimientos auxiliares, ejecuta 66 comprobaciones y elimina las rutinas auxiliares al finalizar. Está adaptado a la instantánea `3d25a51` de la rama `docs/entregable-final`, que contiene únicamente `01_tablas.sql` y `02_datos.sql`.

## Método y cobertura

Se comprueban los recuentos de las 17 tablas del poblado original, 37 operaciones válidas o inválidas, los ocho saldos de inventario y cuatro propiedades de coherencia de datos. Las operaciones abarcan claves únicas y foráneas, valores obligatorios, dominios, cantidades, precios, márgenes, exclusividad de componentes, ciclos directos, movimientos, mermas y fechas.

`pp67_caso` ejecuta una sentencia con SQL preparado, captura el código de error mediante un manejador y lo compara con el código esperado. Esperar un rechazo no basta: un error de sintaxis o una columna inexistente no se considera éxito. Cada operación se revierte a un punto de guardado. `pp67_comprobar` registra el resultado de una condición, considerando NULL como fallo. Las llamadas `CALL` incluidas ejecutan los casos.

Los resultados se guardan en una tabla temporal MEMORY para conservarlos al revertir la transacción. Se muestran el detalle y los totales por resultado. Un FALLO no interrumpe la suite: debe revisarse la tabla de resultados; el código de salida del cliente no certifica que todas las pruebas hayan pasado.

## Ejecución

En una instancia de MariaDB 10.6 o superior dedicada a pruebas, cargar una vez `01_tablas.sql` y después `02_datos.sql`. Ejecutar `07_pruebas.sql` completo en la misma base `plato_plato`, con las comprobaciones de integridad activadas. No ejecutar sobre una base con trabajo real ni dentro de una transacción pendiente: crear o eliminar procedimientos produce commits implícitos. Se necesitan permisos de creación, ejecución y eliminación de rutinas, tablas temporales y acceso a las tablas.

Las escrituras de prueba se revierten; los contadores AUTO_INCREMENT pueden avanzar. Las rutinas con prefijo `pp67_` quedan reservadas para esta suite. Si se interrumpe la ejecución, realizar ROLLBACK o cerrar la conexión antes de volver a ejecutar. La tabla temporal desaparece al cerrar la conexión. El script elimina y recrea sus auxiliares para permitir otra ejecución.

## Hallazgos del poblado recibido

Por inspección del SQL se esperan dos comprobaciones fallidas:

- RC-16: los intervalos de sugerencia y carta se solapan en ambos platos. La pasta tiene sugerencia del 1 al 15 de octubre y carta desde el 8; la tortilla, sugerencia del 10 al 24 y carta desde el 17.
- RN-04: ambos platos pasan a carta a los siete días, antes de completar los catorce requeridos.

Una corrección posible, que debe acordarse con el responsable del 6.2, es mantener los periodos de sugerencia, pasar la pasta a carta el 16 de octubre y autorizarla el 15 a las 18:00; pasar la tortilla a carta el 25 y autorizarla el 24 a las 18:00. No se modifica aquí el trabajo del 6.2. La memoria actual afirma que no hay solapamientos, pero las fechas del SQL contradicen esa afirmación.

## Límites y validación

No se ha ejecutado la suite en MariaDB en el entorno de preparación; se ha revisado estáticamente. Los resultados previstos no son resultados observados. Debe conservarse la salida real al validarla en el entorno del equipo.

El ZIP recibido no contiene funciones, procedimientos de negocio ni triggers. Las pruebas del 6.4 y del 6.5, así como las de concurrencia, se identifican explícitamente como PENDIENTE. Los procedimientos de este archivo son auxiliares de prueba, no la implementación del 6.4. Comprobar que los datos existentes son coherentes no demuestra que el servidor impida insertar datos incoherentes.

Al integrar las rutinas de negocio se debe adaptar la suite a sus firmas y errores reales. Faltan, entre otros: conversiones de unidades y costes recursivos con NULL, ciclos indirectos, vigencias solapadas, saldos históricos y concurrencia, creación atómica de mermas, frescura de 72 horas, caducidad próxima de 48 horas, autorización por administrador y prueba previa de 14 días. Las pruebas negativas deberán incluir INSERT y UPDATE y las fronteras temporales exactas. No se consideran aprobadas por ausencia de implementación.
