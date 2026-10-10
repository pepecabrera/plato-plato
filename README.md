# Plato-Plató

**Sistema de apoyo a la gestión de costes, inventario y elaboración de platos para restaurantes.**

> **Estado:** proyecto académico en fase de definición y desarrollo. Las funcionalidades descritas representan el alcance previsto y no implican que estén implementadas.

Plato-Plató es un proyecto desarrollado por un equipo de **cinco integrantes**. Su propósito es reunir en una única aplicación la información sobre proveedores, ingredientes, precios de compra, lotes, existencias, mermas, recetas y platos, y utilizarla para calcular escandallos y facilitar el análisis de rentabilidad.

## Índice

- [1. Motivación](#1-motivación)
- [2. Objetivos](#2-objetivos)
- [3. Alcance funcional previsto](#3-alcance-funcional-previsto)
- [4. Perfiles de usuario](#4-perfiles-de-usuario)
- [5. Modelo de información](#5-modelo-de-información)
- [6. Funcionamiento conceptual](#6-funcionamiento-conceptual)
- [7. Arquitectura y tecnologías](#7-arquitectura-y-tecnologías)
- [8. Organización del repositorio](#8-organización-del-repositorio)
- [9. Instalación y ejecución](#9-instalación-y-ejecución)
- [10. Calidad y pruebas](#10-calidad-y-pruebas)
- [11. Colaboración](#11-colaboración)
- [12. Seguridad y datos](#12-seguridad-y-datos)
- [13. Documentación](#13-documentación)
- [14. Hoja de ruta](#14-hoja-de-ruta)
- [15. Equipo y licencia](#15-equipo-y-licencia)

## 1. Motivación

En un restaurante, la información sobre compras, existencias, elaboración y precios puede encontrarse dispersa en documentos, hojas de cálculo o registros manuales. Esto dificulta conocer el coste real de los platos y detectar variaciones que afectan a su rentabilidad.

Plato-Plató busca centralizar esos datos y relacionarlos entre sí, reduciendo tareas repetitivas y mejorando la trazabilidad de los cálculos.

## 2. Objetivos

- **Centralizar** la información operativa relevante para los costes de cocina.
- **Estructurar** recetas, subrecetas e ingredientes con sus cantidades y unidades.
- **Calcular** costes de elaboración y márgenes a partir de precios de compra.
- **Controlar** lotes, movimientos de stock y mermas.
- **Comparar** precios de distintos proveedores para un mismo ingrediente.
- **Facilitar** la consulta y gestión de información según los permisos de cada perfil.

## 3. Alcance funcional previsto

Las siguientes capacidades forman parte de los requisitos planteados; su disponibilidad efectiva dependerá del avance del desarrollo.

| Área | Capacidades previstas |
| --- | --- |
| Usuarios | Gestión de cuentas, activación/desactivación y roles. |
| Proveedores | Registro, consulta, modificación y desactivación. |
| Ingredientes | Catálogo, categorías, unidades de medida y estado. |
| Precios de compra | Asociación ingrediente-proveedor, vigencias e histórico de precios. |
| Lotes e inventario | Entradas, salidas, ajustes, existencias y fechas de caducidad. |
| Recetas y subrecetas | Composición por ingredientes y otras subrecetas, con cantidades. |
| Platos | Catálogo, categorías, descripciones, imágenes y precios de venta. |
| Escandallos | Cálculo del coste de producción a partir de los componentes de cada receta. |
| Rentabilidad | Cálculo del margen bruto y apoyo al seguimiento de costes. |
| Mermas | Registro de pérdidas, causas, cantidades y costes asociados. |
| Alertas | Avisos por caducidad próxima o variaciones relevantes de costes. |
| Comparación | Consulta de proveedores y precios por ingrediente. |

**Fuera del alcance confirmado:** no se presupone la existencia de un módulo de reservas, comandas, facturación, gestión de turnos o ventas. Cualquier ampliación se documentará antes de incorporarse.

## 4. Perfiles de usuario

El sistema contempla tres perfiles:

- **Administrador:** acceso general y gestión de usuarios, roles y permisos, además de la información económica.
- **Encargado:** gestión operativa de ingredientes, platos y proveedores, con permisos económicos únicamente cuando se le concedan.
- **Empleado:** consulta de la información necesaria para elaborar platos y registro de mermas, de acuerdo con sus permisos.

Los permisos concretos se definirán y verificarán durante el desarrollo.

## 5. Modelo de información

Los principales conceptos del dominio son:

- **Usuario y rol:** identificación, estado y autorización de operaciones.
- **Proveedor:** origen de suministro y condiciones de contacto y pago.
- **Ingrediente:** producto utilizado en las elaboraciones, con unidad de medida.
- **Precio de ingrediente:** precio de compra asociado a proveedor, ingrediente y período de vigencia.
- **Lote:** entrada identificable de un ingrediente, con cantidad, fechas y ubicación.
- **Movimiento de stock:** variación de existencias vinculada a un lote.
- **Plato:** elaboración ofertable con precio de venta y datos descriptivos.
- **Receta y subreceta:** composición de una elaboración a partir de ingredientes y componentes reutilizables.
- **Merma:** pérdida registrada de un lote o plato, con motivo y coste.

El **escandallo** representa el cálculo del coste de elaboración de un plato. El **margen bruto unitario** se obtiene restando ese coste al precio de venta. Las fórmulas y criterios concretos se documentarán junto a los requisitos.

## 6. Funcionamiento conceptual

Un posible recorrido de uso del sistema es:

1. Registrar los proveedores y los ingredientes disponibles.
2. Asociar precios de compra a los ingredientes y conservar su histórico.
3. Registrar la recepción de lotes y sus movimientos de inventario.
4. Definir recetas mediante ingredientes y subrecetas, indicando cantidades.
5. Asociar una receta a un plato y establecer su precio de venta.
6. Consultar el escandallo y el margen estimado del plato.
7. Registrar mermas y revisar alertas relacionadas con existencias o costes.

Este flujo describe el objetivo del producto, no una secuencia ya implementada.

## 7. Arquitectura y tecnologías

La arquitectura definitiva y las tecnologías de implementación **están pendientes de confirmación por el equipo**. Se prevé separar conceptualmente:

- **Interfaz de usuario:** presentación y operaciones permitidas a cada perfil.
- **Lógica de negocio:** reglas de cálculo, validaciones y operaciones sobre el inventario.
- **Persistencia:** almacenamiento de usuarios, productos, recetas, precios, lotes y movimientos.

Las decisiones sobre lenguaje, framework, motor de base de datos, despliegue y autenticación se recogerán en la documentación técnica una vez acordadas.

## 8. Organización del repositorio

Estructura **orientativa**, adaptable a las decisiones técnicas:

```text
plato-plato/
├── docs/                 # Requisitos, modelos y decisiones técnicas
├── src/                  # Código fuente de la aplicación
├── tests/                # Pruebas automatizadas
├── scripts/              # Utilidades de desarrollo y mantenimiento
├── .gitignore
└── README.md
```

No es necesario crear directorios vacíos ni adoptar esta estructura si el framework elegido propone otra más adecuada.

## 9. Instalación y ejecución

**Pendiente de definir.** Las instrucciones reproducibles se incorporarán cuando exista una primera versión ejecutable. Esta sección deberá indicar:

1. Requisitos previos y versiones compatibles.
2. Clonado del repositorio.
3. Instalación de dependencias.
4. Configuración local mediante variables de entorno.
5. Preparación de la base de datos, si procede.
6. Comando de arranque y acceso a la aplicación.
7. Ejecución de pruebas.

No se publicarán credenciales reales. Cuando corresponda, se incluirá un archivo `.env.example` con nombres de variables y valores ficticios.

## 10. Calidad y pruebas

Se prevé verificar, entre otros aspectos:

- Cálculos de costes y márgenes.
- Composición de recetas y subrecetas, evitando referencias cíclicas.
- Coherencia de precios y períodos de vigencia.
- Registro de movimientos de inventario y mermas.
- Restricciones de acceso por rol.
- Integridad de los datos y tratamiento de errores.

El framework de pruebas y la automatización en GitHub Actions se concretarán al fijar la tecnología del proyecto.

## 11. Colaboración

El desarrollo se realiza por un equipo de **cinco integrantes**. Como convención inicial de trabajo se propone:

1. Registrar las tareas y errores en **GitHub Issues**.
2. Crear una rama por cambio (`feature/...`, `fix/...` o `docs/...`).
3. Realizar commits pequeños con mensajes descriptivos.
4. Abrir un **pull request** para integrar cambios en `main`.
5. Solicitar revisión de otro integrante y resolver los comentarios antes de fusionar.
6. Actualizar pruebas y documentación cuando el cambio lo requiera.

Estas convenciones son una propuesta de organización y podrán ajustarse por consenso. Se recomienda no subir directamente a `main` cambios sin revisar.

## 12. Seguridad y datos

- No incluir contraseñas, tokens, claves privadas ni archivos `.env` reales en el repositorio.
- Almacenar las contraseñas de usuarios mediante mecanismos de hash adecuados, nunca en texto plano.
- Aplicar autenticación y autorización según los permisos definidos.
- Utilizar datos ficticios o anonimizados en ejemplos, pruebas y capturas.
- Evitar publicar datos identificativos de personas, información contractual de proveedores o precios internos reales.
- Mantener fuera del control de versiones las copias de seguridad y los volcados de bases de datos con información sensible.

## 13. Documentación

La documentación del proyecto se organizará preferentemente en `docs/` e incluirá, a medida que esté disponible:

- Especificación de requisitos y glosario.
- Reglas de conducta y políticas de negocio.
- Modelo conceptual y diseño de datos.
- Decisiones de arquitectura.
- Guías de desarrollo, despliegue y pruebas.

La documentación debe reflejar las decisiones realmente adoptadas y mantenerse sincronizada con el código.

## 14. Hoja de ruta

La siguiente secuencia es **orientativa**, no un calendario cerrado:

- [ ] Revisar y validar el catálogo de requisitos.
- [ ] Acordar tecnologías y arquitectura.
- [ ] Diseñar el modelo de datos.
- [ ] Preparar la estructura del proyecto y el entorno local.
- [ ] Implementar catálogos de proveedores e ingredientes.
- [ ] Implementar precios, lotes y movimientos de stock.
- [ ] Implementar recetas, subrecetas y platos.
- [ ] Incorporar cálculo de escandallos y márgenes.
- [ ] Incorporar gestión de mermas y alertas.
- [ ] Completar pruebas, documentación y revisión final.

El estado de las tareas se mantendrá preferentemente en los Issues o el tablero del proyecto, para evitar duplicar el seguimiento.

## 15. Equipo y licencia

**Equipo:** cinco estudiantes que colaboran en el desarrollo de Plato-Plató como proyecto académico. Los nombres y funciones individuales podrán añadirse si sus integrantes desean hacerlos públicos.

**Licencia:** pendiente de decisión. Hasta que se incorpore un archivo `LICENSE`, no debe asumirse que el código dispone de una licencia de reutilización abierta.

---

*Plato-Plató — proyecto académico en desarrollo. Este documento se actualizará conforme se validen requisitos y se implementen funcionalidades.*