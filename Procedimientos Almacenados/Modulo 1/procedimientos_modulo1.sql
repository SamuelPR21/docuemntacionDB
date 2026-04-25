-- ==============================================================================
-- Archivo: procedimientos_modulo1.sql
-- Descripción: Procedimientos almacenados para el Módulo 1 (Gestión de Acceso y Usuarios)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-01: Registro de Usuarios
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo1.sp_registrar_usuario(
    p_tipo_identificacion VARCHAR,
    p_numero_identificacion VARCHAR,
    p_nombres VARCHAR,
    p_apellidos VARCHAR,
    p_fecha_nacimiento DATE,
    p_genero modulo1.enum_usuario_genero,
    p_correo_electronico VARCHAR,
    p_contrasena_cifrada VARCHAR,
    p_telefono VARCHAR,
    p_direccion VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_rol INT;
    v_id_usuario INT;
    v_id_estado_pendiente INT;
BEGIN
    -- Validar caracteres permitidos en nombres y apellidos
    IF p_nombres !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$' OR p_apellidos !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$' THEN
        RAISE EXCEPTION 'Error de formato: Los nombres y apellidos solo deben contener letras y espacios.';
    END IF;

    -- Validar formato básico de correo electrónico
    IF p_correo_electronico !~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$' THEN
        RAISE EXCEPTION 'Error de formato: El campo correo_electronico tiene un formato inválido.';
    END IF;

    -- Validar edad (mayor de 18)
    IF EXTRACT(YEAR FROM age(CURRENT_DATE, p_fecha_nacimiento)) < 18 THEN
        RAISE EXCEPTION 'Registro denegado. Debe ser mayor de 18 años para registrarse en el sistema.';
    END IF;

    -- Validar unicidad de correo
    IF EXISTS (SELECT 1 FROM modulo1.usuarios WHERE correo_electronico = p_correo_electronico) THEN
        RAISE EXCEPTION 'La dirección de correo % ya está en uso.', p_correo_electronico;
    END IF;

    -- Validar unicidad de identificación
    IF EXISTS (SELECT 1 FROM modulo1.usuarios WHERE numero_identificacion = p_numero_identificacion) THEN
        RAISE EXCEPTION 'El número de identificación % ya se encuentra vinculado a una cuenta.', p_numero_identificacion;
    END IF;

    -- Obtener rol por defecto (Ej: Productor)
    SELECT id_rol INTO v_id_rol FROM modulo1.roles WHERE nombre_rol ILIKE 'Productor' LIMIT 1;
    IF v_id_rol IS NULL THEN
        SELECT id_rol INTO v_id_rol FROM modulo1.roles ORDER BY id_rol LIMIT 1;
    END IF;

    -- Insertar usuario
    INSERT INTO modulo1.usuarios (
        tipo_identificacion, numero_identificacion, nombre, apellidos,
        fecha_nacimiento, genero, correo_electronico, contrasena_cifrada,
        telefono, direccion, id_rol
    ) VALUES (
        p_tipo_identificacion, p_numero_identificacion, p_nombres, p_apellidos,
        p_fecha_nacimiento, p_genero, p_correo_electronico, p_contrasena_cifrada,
        p_telefono, p_direccion, v_id_rol
    ) RETURNING id_usuario INTO v_id_usuario;

    -- Obtener estado pendiente
    SELECT id_estado_cuenta INTO v_id_estado_pendiente FROM modulo1.estados_cuentas WHERE nombre ILIKE '%PENDIENTE%';
    IF v_id_estado_pendiente IS NULL THEN
        v_id_estado_pendiente := 1; -- Fallback seguro si no existe el texto exacto
    END IF;

    -- Crear cuenta de usuario asociada
    INSERT INTO modulo1.cuentas_usuarios (
        id_usuario, id_estado_cuenta, tiene_correo_verificado
    ) VALUES (
        v_id_usuario, v_id_estado_pendiente, FALSE
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-03: Gestión de Roles (Crear)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo1.sp_crear_rol(
    p_nombre_rol VARCHAR,
    p_descripcion VARCHAR,
    p_permisos JSONB -- Array de objetos [{"id_recurso": 1, "id_accion": 2}]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_rol INT;
    v_permiso JSONB;
BEGIN
    -- Validar si ya existe el nombre de rol
    IF EXISTS (SELECT 1 FROM modulo1.roles WHERE nombre_rol = p_nombre_rol) THEN
        RAISE EXCEPTION 'Conflicto de identidad: El nombre de rol % ya se encuentra registrado.', p_nombre_rol;
    END IF;

    -- Validar que tenga al menos un permiso
    IF jsonb_array_length(p_permisos) = 0 THEN
        RAISE EXCEPTION 'Operación rechazada: Todo rol debe poseer al menos un permiso asociado.';
    END IF;

    -- Insertar rol
    INSERT INTO modulo1.roles (nombre_rol, descripcion, es_protegido)
    VALUES (p_nombre_rol, p_descripcion, FALSE)
    RETURNING id_rol INTO v_id_rol;

    -- Asignar permisos
    FOR v_permiso IN SELECT * FROM jsonb_array_elements(p_permisos)
    LOOP
        INSERT INTO modulo1.permisos (
            nombre, descripcion, id_rol, id_recurso, id_accion
        ) VALUES (
            p_nombre_rol || '_permiso', 'Permiso asignado', v_id_rol, 
            (v_permiso->>'id_recurso')::INT, (v_permiso->>'id_accion')::INT
        );
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-05: Actualizar Usuario
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo1.sp_actualizar_usuario(
    p_id_actor INT,
    p_id_usuario INT,
    p_nombres VARCHAR,
    p_apellidos VARCHAR,
    p_correo_electronico VARCHAR,
    p_telefono VARCHAR,
    p_id_estado_cuenta INT,
    p_id_rol INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_es_admin BOOLEAN := FALSE;
    v_correo_actual VARCHAR;
    v_id_estado_pendiente INT;
BEGIN
    -- Verificar si el actor es administrador (suponiendo que rol Administrador es id_rol = 1 o por nombre)
    SELECT EXISTS (
        SELECT 1 FROM modulo1.usuarios u 
        JOIN modulo1.roles r ON u.id_rol = r.id_rol 
        WHERE u.id_usuario = p_id_actor AND r.nombre_rol ILIKE '%Administrador%'
    ) INTO v_es_admin;

    -- Validar permisos de actor
    IF NOT v_es_admin AND p_id_actor != p_id_usuario THEN
        RAISE EXCEPTION 'Acceso restringido. No tiene permisos para modificar este usuario.';
    END IF;

    -- Si no es admin y trata de cambiar rol o estado (asumiendo que en la app pasan NULL si no cambian)
    IF NOT v_es_admin AND (p_id_estado_cuenta IS NOT NULL OR p_id_rol IS NOT NULL) THEN
        RAISE EXCEPTION 'Acceso restringido. No tiene permisos para modificar campos críticos (Rol/Estado).';
    END IF;

    -- Validar formato de nombres
    IF p_nombres !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$' OR p_apellidos !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$' THEN
        RAISE EXCEPTION 'Error de formato. Los nombres y apellidos solo deben contener letras y espacios.';
    END IF;

    -- Validar teléfono numérico
    IF p_telefono IS NOT NULL AND p_telefono !~ '^[0-9]+$' THEN
        RAISE EXCEPTION 'Número telefónico inválido. Asegúrese de ingresar solo dígitos numéricos.';
    END IF;

    -- Validar correo duplicado
    IF EXISTS (SELECT 1 FROM modulo1.usuarios WHERE correo_electronico = p_correo_electronico AND id_usuario != p_id_usuario) THEN
        RAISE EXCEPTION 'La dirección % ya se encuentra vinculada a otra cuenta.', p_correo_electronico;
    END IF;

    -- Obtener correo actual para ver si cambió
    SELECT correo_electronico INTO v_correo_actual FROM modulo1.usuarios WHERE id_usuario = p_id_usuario;

    -- Actualizar tabla usuarios
    UPDATE modulo1.usuarios
    SET nombre = p_nombres,
        apellidos = p_apellidos,
        correo_electronico = p_correo_electronico,
        telefono = p_telefono,
        id_rol = COALESCE(p_id_rol, id_rol),
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE id_usuario = p_id_usuario;

    -- Si cambió correo, poner cuenta en pendiente (lógica de verificación)
    IF v_correo_actual != p_correo_electronico THEN
        SELECT id_estado_cuenta INTO v_id_estado_pendiente FROM modulo1.estados_cuentas WHERE nombre ILIKE '%PENDIENTE%';
        
        UPDATE modulo1.cuentas_usuarios
        SET tiene_correo_verificado = FALSE,
            id_estado_cuenta = COALESCE(v_id_estado_pendiente, id_estado_cuenta)
        WHERE id_usuario = p_id_usuario;
    END IF;

    -- Actualizar estado si es admin y lo mandó
    IF v_es_admin AND p_id_estado_cuenta IS NOT NULL THEN
        UPDATE modulo1.cuentas_usuarios
        SET id_estado_cuenta = p_id_estado_cuenta,
            fecha_cambio_estado = CURRENT_TIMESTAMP
        WHERE id_usuario = p_id_usuario;
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-10: Registrar Auditoría
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo1.sp_registrar_auditoria(
    p_id_usuario INT,
    p_nombre_usuario VARCHAR,
    p_tipo_evento modulo1.enum_evento_resultado,
    p_modulo VARCHAR,
    p_descripcion TEXT,
    p_direccion_ip VARCHAR,
    p_user_agent VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Se asume inserción en tabla eventos
    INSERT INTO modulo1.eventos (
        id_usuario, tipo_evento, modulo, descripcion, 
        resultado, direccion_ip, user_agent, fecha_hora
    ) VALUES (
        p_id_usuario, p_tipo_evento, p_modulo, p_descripcion, 
        'exitoso', p_direccion_ip, p_user_agent, CURRENT_TIMESTAMP
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
