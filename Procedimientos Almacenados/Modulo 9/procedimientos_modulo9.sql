-- ==============================================================================
-- Archivo: procedimientos_modulo9.sql
-- Descripción: Procedimientos almacenados para el Módulo 9 (Catálogos y Configuraciones)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-15: Catálogo de Especies Productivas (Registrar)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo9.sp_registrar_especie(
    p_nombre VARCHAR,
    p_descripcion VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
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
    p_id_especie INT,
    p_nuevo_nombre VARCHAR,
    p_nueva_descripcion VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
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
    p_id_especie INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM modulo9.especies WHERE id_especie = p_id_especie) THEN
        RAISE EXCEPTION 'La especie a desactivar no existe.';
    END IF;

    -- En un caso real, aquí validaríamos que no haya procesos críticos o activos biológicos usando esta especie
    IF EXISTS (SELECT 1 FROM modulo2.activos_biologicos WHERE id_especie = p_id_especie AND id_estado = (SELECT id_estado FROM modulo2.estados_activos_biologicos WHERE nombre ILIKE '%ACTIVO%' LIMIT 1)) THEN
        RAISE WARNING 'Existen activos biológicos vinculados a esta especie. Desactivarla impedirá crear nuevos, pero los existentes se mantienen.';
    END IF;

    UPDATE modulo9.especies
    SET es_activo = FALSE,
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE id_especie = p_id_especie;

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
    p_nombre VARCHAR,
    p_descripcion VARCHAR,
    p_id_finca INT,
    p_superficie NUMERIC(10,2),
    p_tipo modulo9.enum_tipo_infraestructura
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar existencia de finca
    IF NOT EXISTS (SELECT 1 FROM modulo9.fincas WHERE id_finca = p_id_finca) THEN
        RAISE EXCEPTION 'La finca asociada no existe en el sistema.';
    END IF;

    -- Validar superficie positiva
    IF p_superficie <= 0 THEN
        RAISE EXCEPTION 'La superficie debe ser mayor a cero.';
    END IF;

    INSERT INTO modulo9.infraestructuras (
        nombre, descripcion, id_finca, superficie, es_activo, tipo
    ) VALUES (
        p_nombre, p_descripcion, p_id_finca, p_superficie, TRUE, p_tipo
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
