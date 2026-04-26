-- ==============================================================================
-- Archivo: procedimientos_modulo9.sql
-- Descripción: Procedimientos almacenados para el Módulo 9 (Catálogos y Configuraciones)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-15: Catálogo de Especies Productivas (Registrar)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo9.sp_registrar_especie(
    p_id_usuario INT,
    p_nombre VARCHAR,
    p_descripcion VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_especie INT;
    v_id_umbral_defecto INT;
    v_es_admin BOOLEAN;
BEGIN
    -- 1. Validar que el usuario sea Administrador (RF-15)
    SELECT EXISTS (
        SELECT 1 FROM modulo1.usuarios u 
        JOIN modulo1.roles r ON u.id_rol = r.id_rol 
        WHERE u.id_usuario = p_id_usuario AND r.nombre_rol ILIKE '%Administrador%'
    ) INTO v_es_admin;

    IF NOT v_es_admin THEN
        RAISE EXCEPTION 'Acceso denegado: Solo el rol Administrador puede registrar nuevas especies.';
    END IF;

    -- Validar longitud del nombre (3 a 50 caracteres)
    IF LENGTH(p_nombre) < 3 OR LENGTH(p_nombre) > 50 THEN
        RAISE EXCEPTION 'El nombre de la especie debe tener entre 3 y 50 caracteres.';
    END IF;

    -- Validar unicidad (case-insensitive)
    IF EXISTS (SELECT 1 FROM modulo9.especies WHERE LOWER(nombre) = LOWER(p_nombre)) THEN
        RAISE EXCEPTION 'La especie % ya se encuentra registrada en el sistema.', p_nombre;
    END IF;

    -- Insertar especie
    INSERT INTO modulo9.especies (
        nombre, descripcion, fecha_creacion, es_activo
    ) VALUES (
        TRIM(p_nombre), TRIM(p_descripcion), CURRENT_TIMESTAMP, TRUE
    ) RETURNING id_especie INTO v_id_especie;

    -- 2. Registro en auditoría gestion_especies (RF-15)
    -- Buscamos un umbral ambiental por defecto o creamos uno vacío si es necesario (el esquema lo exige)
    SELECT id_umbral_ambiental INTO v_id_umbral_defecto FROM modulo9.umbrales_ambientales LIMIT 1;
    
    INSERT INTO modulo9.gestion_especies (
        id_usuario, id_especie, fecha_gestion, id_umbral_ambiental
    ) VALUES (
        p_id_usuario, v_id_especie, CURRENT_TIMESTAMP, COALESCE(v_id_umbral_defecto, 1)
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-15: Catálogo de Especies Productivas (Editar)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo9.sp_editar_especie(
    p_id_usuario INT,
    p_id_especie INT,
    p_nuevo_nombre VARCHAR,
    p_nueva_descripcion VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tiene_permiso BOOLEAN;
    v_id_umbral_actual INT;
BEGIN
    -- 1. Validar rol Administrador o Ingeniero de Campo (RF-15)
    SELECT EXISTS (
        SELECT 1 FROM modulo1.usuarios u 
        JOIN modulo1.roles r ON u.id_rol = r.id_rol 
        WHERE u.id_usuario = p_id_usuario 
        AND (r.nombre_rol ILIKE '%Administrador%' OR r.nombre_rol ILIKE '%Ingeniero de Campo%')
    ) INTO v_tiene_permiso;

    IF NOT v_tiene_permiso THEN
        RAISE EXCEPTION 'Acceso denegado: Solo el Administrador o el Ingeniero de Campo pueden editar especies.';
    END IF;

    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM modulo9.especies WHERE id_especie = p_id_especie) THEN
        RAISE EXCEPTION 'La especie a editar no existe.';
    END IF;

    -- Validar longitud del nombre si se envió
    IF p_nuevo_nombre IS NOT NULL THEN
        IF LENGTH(p_nuevo_nombre) < 3 OR LENGTH(p_nuevo_nombre) > 50 THEN
            RAISE EXCEPTION 'El nombre de la especie debe tener entre 3 y 50 caracteres.';
        END IF;

        -- Validar unicidad excluyendo la especie actual
        IF EXISTS (SELECT 1 FROM modulo9.especies 
                   WHERE LOWER(nombre) = LOWER(p_nuevo_nombre) 
                   AND id_especie != p_id_especie) THEN
            RAISE EXCEPTION 'La especie % ya se encuentra registrada por otro identificador.', p_nuevo_nombre;
        END IF;
    END IF;

    -- Actualizar especie
    UPDATE modulo9.especies
    SET nombre = COALESCE(p_nuevo_nombre, nombre),
        descripcion = COALESCE(p_nueva_descripcion, descripcion),
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE id_especie = p_id_especie;

    -- 2. Registro en auditoría gestion_especies
    SELECT id_umbral_ambiental INTO v_id_umbral_actual 
    FROM modulo9.umbrales_ambientales WHERE id_especie = p_id_especie LIMIT 1;

    INSERT INTO modulo9.gestion_especies (
        id_usuario, id_especie, fecha_gestion, id_umbral_ambiental
    ) VALUES (
        p_id_usuario, p_id_especie, CURRENT_TIMESTAMP, COALESCE(v_id_umbral_actual, 1)
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-15: Catálogo de Especies Productivas (Desactivar Lógicamente)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo9.sp_desactivar_especie(
    p_id_usuario INT,
    p_id_especie INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_id_umbral_actual INT;
BEGIN
    -- 1. Validar que el usuario sea Administrador
    SELECT EXISTS (
        SELECT 1 FROM modulo1.usuarios u 
        JOIN modulo1.roles r ON u.id_rol = r.id_rol 
        WHERE u.id_usuario = p_id_usuario AND r.nombre_rol ILIKE '%Administrador%'
    ) INTO v_es_admin;

    IF NOT v_es_admin THEN
        RAISE EXCEPTION 'Acceso denegado: Solo el rol Administrador puede desactivar especies.';
    END IF;

    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM modulo9.especies WHERE id_especie = p_id_especie) THEN
        RAISE EXCEPTION 'La especie a desactivar no existe.';
    END IF;

    -- 2. Validar que no haya procesos críticos activos (Entrenamiento de modelos IA, etc. RF-15)
    -- Nota: Se simula la validación consultando si hay activos biológicos en estado crítico o activo.
    IF EXISTS (SELECT 1 FROM modulo2.activos_biologicos WHERE id_especie = p_id_especie AND id_estado = (SELECT id_estado_activo_biologico FROM modulo2.estados_activos_biologicos WHERE nombre ILIKE '%ACTIVO%' LIMIT 1)) THEN
        RAISE EXCEPTION 'Operación rechazada: No se puede desactivar la especie porque existen activos biológicos vinculados en estado activo.';
    END IF;

    UPDATE modulo9.especies
    SET es_activo = FALSE,
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE id_especie = p_id_especie;

    -- 3. Registro en auditoría
    SELECT id_umbral_ambiental INTO v_id_umbral_actual 
    FROM modulo9.umbrales_ambientales WHERE id_especie = p_id_especie LIMIT 1;

    INSERT INTO modulo9.gestion_especies (
        id_usuario, id_especie, fecha_gestion, id_umbral_ambiental
    ) VALUES (
        p_id_usuario, p_id_especie, CURRENT_TIMESTAMP, COALESCE(v_id_umbral_actual, 1)
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-20: Infraestructuras (Registrar)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo9.sp_registrar_infraestructura(
    p_id_usuario INT,
    p_nombre VARCHAR,
    p_descripcion VARCHAR,
    p_id_finca INT,
    p_superficie NUMERIC(10,2),
    p_tipo modulo9.enum_tipo_infraestructura
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    -- 1. Validar que el usuario sea Administrador (RF-20)
    SELECT EXISTS (
        SELECT 1 FROM modulo1.usuarios u 
        JOIN modulo1.roles r ON u.id_rol = r.id_rol 
        WHERE u.id_usuario = p_id_usuario AND r.nombre_rol ILIKE '%Administrador%'
    ) INTO v_es_admin;

    IF NOT v_es_admin THEN
        RAISE EXCEPTION 'Acceso denegado: Solo el rol Administrador puede registrar infraestructuras.';
    END IF;

    -- 2. Validar existencia de finca
    IF NOT EXISTS (SELECT 1 FROM modulo9.finca WHERE id_finca = p_id_finca) THEN
        RAISE EXCEPTION 'La finca asociada no existe en el sistema.';
    END IF;

    -- 3. Validar unicidad del nombre dentro de la misma finca (RF-20)
    IF EXISTS (SELECT 1 FROM modulo9.infraestructuras WHERE id_finca = p_id_finca AND LOWER(nombre) = LOWER(p_nombre)) THEN
        RAISE EXCEPTION 'Conflicto: Ya existe una infraestructura con el nombre % en esta finca.', p_nombre;
    END IF;

    -- Validar superficie positiva
    IF p_superficie <= 0 THEN
        RAISE EXCEPTION 'La superficie debe ser mayor a cero.';
    END IF;

    INSERT INTO modulo9.infraestructuras (
        nombre, descripcion, id_finca, superficie, es_activo, tipo
    ) VALUES (
        TRIM(p_nombre), TRIM(p_descripcion), p_id_finca, p_superficie, TRUE, p_tipo
    );

    -- 4. Registro en auditoría general (Usando el procedimiento del Módulo 1 si está disponible)
    -- En este entorno, insertamos directamente en eventos si es necesario, o llamamos al SP.
    -- Para este entregable, invocamos el procedimiento de auditoría del Módulo 1.
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario, 
        NULL, -- p_id_sesion (el backend debe proveerlo, aquí simulamos con NULL o un valor por defecto)
        5,    -- p_id_tipo_evento (Creación de recurso)
        'Modulo 9',
        'Infraestructura',
        'Registro de nueva infraestructura: ' || p_nombre,
        'exitoso',
        'activo',
        jsonb_build_object('finca', p_id_finca, 'tipo', p_tipo)
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
