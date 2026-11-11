-- Plato-Plató: esquema definitivo (persona 1).
-- MariaDB 10.6+ como objetivo; pendiente de validación en ejecución. InnoDB, utf8mb4.
-- Ejecutar desde una base nueva; no elimina ni sustituye datos existentes.
-- Las fechas DATETIME(6) representan hora local Europe/Madrid (S-14).
-- No incluye datos, funciones, procedimientos ni triggers de negocio.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
CREATE DATABASE plato_plato CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE plato_plato;

-- Acceso: perfiles, permisos y concesiones individuales. Las tablas de roles no conceden por sí solas privilegios del servidor.
CREATE TABLE roles (
    id_rol INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
    CHECK (nombre IN ('ADMINISTRADOR','ENCARGADO','EMPLEADO'))
) ENGINE=InnoDB;

CREATE TABLE permisos (
    id_permiso INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nombre))>0)
) ENGINE=InnoDB;

CREATE TABLE usuarios (
    id_usuario INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL UNIQUE,
    -- El hash se genera fuera de SQL; su longitud no garantiza por sí sola un algoritmo seguro.
    contrasena_protegida VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    fecha_creacion DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    id_rol INT UNSIGNED NOT NULL,
    estado VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    CHECK (estado IN ('ACTIVO','INACTIVO')),
    CHECK (CHAR_LENGTH(TRIM(nombre))>0),
    CHECK (LOCATE('@',correo_electronico)>1 AND correo_electronico=TRIM(correo_electronico)),
    CHECK (CHAR_LENGTH(contrasena_protegida)>=60),
    FOREIGN KEY (id_rol) REFERENCES roles (id_rol) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

-- La clave compuesta evita conceder dos veces el mismo permiso. CASCADE elimina las concesiones al borrar su titular.
CREATE TABLE roles_permisos (
    id_rol INT UNSIGNED NOT NULL,
    id_permiso INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_rol,id_permiso),
    FOREIGN KEY (id_rol) REFERENCES roles (id_rol) ON DELETE CASCADE ON UPDATE RESTRICT,
    FOREIGN KEY (id_permiso) REFERENCES permisos (id_permiso) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE permisos_adicionales_usuario (
    id_usuario INT UNSIGNED NOT NULL,
    id_permiso INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_usuario,id_permiso),
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE ON UPDATE RESTRICT,
    FOREIGN KEY (id_permiso) REFERENCES permisos (id_permiso) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB;

-- Unidades compatibles comparten magnitud; el factor permite convertirlas a una base común (por ejemplo, kg y g).
CREATE TABLE unidades_medida (
    codigo VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nombre))>0),
    magnitud VARCHAR(7) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    factor_a_base DECIMAL(18,6) NOT NULL,
    CHECK (magnitud IN ('MASA','VOLUMEN','UNIDAD','RACION')),
    CHECK (factor_a_base>0),
    CHECK (CHAR_LENGTH(TRIM(codigo))>0)
) ENGINE=InnoDB;

-- Compras: proveedores, ingredientes e histórico de precios. El contacto requiere al menos teléfono o correo.
CREATE TABLE proveedores (
    id_proveedor INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nombre))>0),
    persona_contacto VARCHAR(100) NULL,
    telefono VARCHAR(20) NULL,
    correo_contacto VARCHAR(150) NULL,
    forma_pago VARCHAR(100) NOT NULL,
    estado VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    CHECK (estado IN ('ACTIVO','INACTIVO')),
    CHECK ((telefono IS NOT NULL AND CHAR_LENGTH(TRIM(telefono))>0) OR (correo_contacto IS NOT NULL AND CHAR_LENGTH(TRIM(correo_contacto))>0)),
    CHECK (correo_contacto IS NULL OR LOCATE('@',correo_contacto)>1),
    CHECK (CHAR_LENGTH(TRIM(forma_pago))>0)
) ENGINE=InnoDB;

CREATE TABLE ingredientes (
    id_ingrediente INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nombre))>0),
    categoria VARCHAR(100) NOT NULL,
    unidad_medida VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    FOREIGN KEY (unidad_medida) REFERENCES unidades_medida (codigo) ON DELETE RESTRICT ON UPDATE CASCADE,
    estado VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    CHECK (estado IN ('ACTIVO','INACTIVO')),
    CHECK (CHAR_LENGTH(TRIM(categoria))>0)
) ENGINE=InnoDB;

CREATE TABLE precios_compra (
    id_precio_compra INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT UNSIGNED NOT NULL,
    id_ingrediente INT UNSIGNED NOT NULL,
    precio_compra DECIMAL(14,4) NOT NULL,
    unidad_precio VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    FOREIGN KEY (unidad_precio) REFERENCES unidades_medida (codigo) ON DELETE RESTRICT ON UPDATE CASCADE,
    fecha_inicio_vigencia DATETIME(6) NOT NULL,
    fecha_fin_vigencia DATETIME(6) NULL,
    seleccionado_para_costeo BOOLEAN NOT NULL DEFAULT FALSE,
    -- Solo los seleccionados generan un ID: UNIQUE admite varios NULL, pero un solo precio seleccionado por ingrediente.
    id_ingrediente_seleccionado INT UNSIGNED GENERATED ALWAYS AS (CASE WHEN seleccionado_para_costeo=1 THEN id_ingrediente ELSE NULL END) VIRTUAL,
    UNIQUE (id_ingrediente_seleccionado),
    UNIQUE (id_proveedor,id_ingrediente,fecha_inicio_vigencia),
    FOREIGN KEY (id_proveedor) REFERENCES proveedores (id_proveedor) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (id_ingrediente) REFERENCES ingredientes (id_ingrediente) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (precio_compra>0),
    CHECK (seleccionado_para_costeo IN (0,1)),
    CHECK (fecha_fin_vigencia IS NULL OR fecha_fin_vigencia>fecha_inicio_vigencia)
) ENGINE=InnoDB;

-- Recetas: una subreceta es otra fila de esta tabla. El rendimiento indica cuánto produce una elaboración completa.
CREATE TABLE recetas (
    id_receta INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nombre))>0),
    cantidad_rendimiento DECIMAL(14,4) NOT NULL,
    unidad_rendimiento VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    FOREIGN KEY (unidad_rendimiento) REFERENCES unidades_medida (codigo) ON DELETE RESTRICT ON UPDATE CASCADE,
    estado VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    CHECK (estado IN ('ACTIVO','INACTIVO')),
    CHECK (cantidad_rendimiento>0)
) ENGINE=InnoDB;

-- Cada plato tiene una receta principal exclusiva. El coste y el margen se calcularán; no se almacenan aquí.
CREATE TABLE platos (
    id_plato INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_receta INT UNSIGNED NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nombre))>0),
    imagen VARCHAR(255) NULL,
    descripcion VARCHAR(500) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    menu_del_dia BOOLEAN NOT NULL DEFAULT FALSE,
    precio_venta DECIMAL(14,2) NULL,
    porcentaje_margen_objetivo DECIMAL(5,2) NULL,
    estado VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    CHECK (estado IN ('ACTIVO','INACTIVO')),
    FOREIGN KEY (id_receta) REFERENCES recetas (id_receta) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (menu_del_dia IN (0,1)),
    CHECK (precio_venta IS NULL OR precio_venta>0),
    CHECK (porcentaje_margen_objetivo IS NULL OR (porcentaje_margen_objetivo>=0 AND porcentaje_margen_objetivo<100)),
    CHECK (CHAR_LENGTH(TRIM(categoria))>0)
) ENGINE=InnoDB;

-- Cada línea utiliza un ingrediente O una receta. Se evitan duplicados y ciclos directos; los indirectos requieren validación adicional.
CREATE TABLE componentes_receta (
    id_componente INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_receta INT UNSIGNED NOT NULL,
    cantidad DECIMAL(14,4) NOT NULL,
    unidad_medida VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    FOREIGN KEY (unidad_medida) REFERENCES unidades_medida (codigo) ON DELETE RESTRICT ON UPDATE CASCADE,
    id_ingrediente INT UNSIGNED NULL,
    id_receta_componente INT UNSIGNED NULL,
    UNIQUE (id_receta,id_ingrediente),
    UNIQUE (id_receta,id_receta_componente),
    FOREIGN KEY (id_receta) REFERENCES recetas (id_receta) ON DELETE CASCADE ON UPDATE RESTRICT,
    FOREIGN KEY (id_ingrediente) REFERENCES ingredientes (id_ingrediente) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (id_receta_componente) REFERENCES recetas (id_receta) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (cantidad>0),
    CHECK ((id_ingrediente IS NOT NULL AND id_receta_componente IS NULL) OR (id_ingrediente IS NULL AND id_receta_componente IS NOT NULL)),
    CHECK (id_receta_componente IS NULL OR id_receta_componente<>id_receta)
) ENGINE=InnoDB;

-- Inventario: los lotes no guardan saldo; se obtiene de sus movimientos. Frescura y aptitud se clasifican por lote.
CREATE TABLE lotes (
    id_lote INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    identificador_lote VARCHAR(100) NOT NULL UNIQUE,
    id_ingrediente INT UNSIGNED NOT NULL,
    fecha_entrada DATETIME(6) NOT NULL,
    fecha_caducidad DATETIME(6) NULL,
    ubicacion_almacen VARCHAR(100) NOT NULL,
    fresco BOOLEAN NOT NULL,
    apto_para_consumo BOOLEAN NOT NULL,
    FOREIGN KEY (id_ingrediente) REFERENCES ingredientes (id_ingrediente) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (fresco IN (0,1)),
    CHECK (apto_para_consumo IN (0,1)),
    CHECK (CHAR_LENGTH(TRIM(identificador_lote))>0),
    CHECK (CHAR_LENGTH(TRIM(ubicacion_almacen))>0)
) ENGINE=InnoDB;

-- Entradas y salidas usan cantidades positivas; los ajustes llevan signo. Solo una salida de elaboración tiene plato de destino.
CREATE TABLE movimientos_stock (
    id_movimiento INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_lote INT UNSIGNED NOT NULL,
    tipo VARCHAR(7) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    cantidad DECIMAL(14,4) NOT NULL,
    fecha_movimiento DATETIME(6) NOT NULL,
    finalidad_salida VARCHAR(11) CHARACTER SET ascii COLLATE ascii_bin NULL,
    id_plato_destino INT UNSIGNED NULL,
    KEY ix_mov_lote_fecha (id_lote,fecha_movimiento,id_movimiento),
    FOREIGN KEY (id_lote) REFERENCES lotes (id_lote) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (id_plato_destino) REFERENCES platos (id_plato) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (tipo IN ('ENTRADA','SALIDA','AJUSTE')),
    CHECK ((tipo IN ('ENTRADA','SALIDA') AND cantidad>0) OR (tipo='AJUSTE' AND cantidad<>0)),
    CHECK ((tipo IN ('ENTRADA','AJUSTE') AND finalidad_salida IS NULL AND id_plato_destino IS NULL) OR (tipo='SALIDA' AND finalidad_salida IS NOT NULL AND ((finalidad_salida='ELABORACION' AND id_plato_destino IS NOT NULL) OR (finalidad_salida IN ('MERMA','OTRA') AND id_plato_destino IS NULL))))
) ENGINE=InnoDB;

-- Una merma afecta a lote O plato. La de lote exige una salida asociada y única; la de plato no vuelve a descontar ingredientes.
CREATE TABLE mermas (
    id_merma INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    cantidad_desperdiciada DECIMAL(14,4) NOT NULL,
    fecha_merma DATETIME(6) NOT NULL,
    motivo VARCHAR(25) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    detalle_motivo VARCHAR(500) NULL,
    -- Importe histórico: NULL significa desconocido; cero representa una pérdida valorada en cero.
    coste_perdida DECIMAL(14,2) NULL,
    id_lote INT UNSIGNED NULL,
    id_plato INT UNSIGNED NULL,
    id_movimiento INT UNSIGNED NULL UNIQUE,
    FOREIGN KEY (id_lote) REFERENCES lotes (id_lote) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (id_plato) REFERENCES platos (id_plato) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (id_movimiento) REFERENCES movimientos_stock (id_movimiento) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (cantidad_desperdiciada>0),
    CHECK (coste_perdida IS NULL OR coste_perdida>=0),
    CHECK (motivo IN ('CADUCIDAD','DETERIORO','ELABORACION_INCORRECTA','PLATO_DESECHADO','OTRO')),
    CHECK ((id_lote IS NOT NULL AND id_plato IS NULL AND id_movimiento IS NOT NULL) OR (id_lote IS NULL AND id_plato IS NOT NULL AND id_movimiento IS NULL))
) ENGINE=InnoDB;

-- Oferta: los intervalos incluyen el inicio y excluyen el fin. Impedir solapamientos queda pendiente de triggers/procedimientos.
CREATE TABLE periodos_oferta (
    id_periodo_oferta INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_plato INT UNSIGNED NOT NULL,
    tipo VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    fecha_inicio DATETIME(6) NOT NULL,
    fecha_fin DATETIME(6) NULL,
    UNIQUE (id_plato,fecha_inicio),
    FOREIGN KEY (id_plato) REFERENCES platos (id_plato) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (tipo IN ('SUGERENCIA_CHEF','CARTA_PERMANENTE')),
    CHECK (fecha_fin IS NULL OR fecha_fin>fecha_inicio)
) ENGINE=InnoDB;

-- Se conservan los importes evaluados al autorizar. Validar administrador, prueba previa y autorización obligatoria queda pendiente.
CREATE TABLE autorizaciones_carta (
    id_autorizacion INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_periodo_oferta INT UNSIGNED NOT NULL UNIQUE,
    id_emisor INT UNSIGNED NOT NULL,
    fecha_autorizacion DATETIME(6) NOT NULL,
    coste_evaluado DECIMAL(14,2) NOT NULL,
    precio_venta_evaluado DECIMAL(14,2) NOT NULL,
    FOREIGN KEY (id_periodo_oferta) REFERENCES periodos_oferta (id_periodo_oferta) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (id_emisor) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CHECK (coste_evaluado>=0),
    CHECK (precio_venta_evaluado>0)
) ENGINE=InnoDB;

-- Las FK y CHECK no garantizan saldos, vigencias sin solape ni reglas temporales de negocio.
-- Esas comprobaciones se completarán con procedimientos y triggers en los siguientes scripts.
