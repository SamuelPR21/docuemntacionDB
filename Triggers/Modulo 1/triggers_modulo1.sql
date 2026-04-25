-- =============================================================================
-- MÓDULO 1 — GESTIÓN DE ACCESO Y USUARIOS
-- Archivo: modulo1_triggers.sql
-- Descripción: Triggers e funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo1
-- Motor: PostgreSQL
-- Versión: 1.0
-- Para ampliar explicacion individual de los triggers verificar el documento de informe_triggers_modulo1.
-- =============================================================================
-- ÍNDICE
--   TRG-01  Unicidad de contraseña (no reutilización)
--   TRG-02  Control de versión optimista (OCC)
--   TRG-03  Protección de registros de auditoría (inmutabilidad)
--   TRG-04  Transiciones de estado de cuenta válidas
--   TRG-05  Protección del rol Administrador
--   TRG-06  Bloqueo de eliminación de rol con usuarios vinculados
--   TRG-07  Integridad mínima de permisos por rol
--   TRG-08  Invalidación de sesiones activas al cambiar estado de cuenta
--   TRG-09  Reset de contador de intentos fallidos al activar cuenta
--   TRG-10  Protección de campos críticos del usuario
--   TRG-11  Token de un solo uso (one-time use)
-- =============================================================================


-- =============================================================================
-- TRG-01 — Unicidad de contraseña (no reutilización)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_no_reutilizar_contrasena()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.contrasena_cifrada = OLD.contrasena_cifrada THEN
        RAISE EXCEPTION 'CONSTRAINT_VIOLATION: La nueva contraseña no puede ser idéntica a la anterior.'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_reutilizar_contrasena
BEFORE UPDATE OF contrasena_cifrada ON modulo1.usuarios
FOR EACH ROW
WHEN (OLD.contrasena_cifrada IS NOT NULL)
EXECUTE FUNCTION modulo1.trg_fn_no_reutilizar_contrasena();


-- =============================================================================
-- TRG-02 — Control de versión optimista (OCC)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_incrementar_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version             := OLD.version + 1;
    NEW.fecha_actualizacion := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incrementar_version
BEFORE UPDATE ON modulo1.usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_incrementar_version();


-- =============================================================================
-- TRG-03 — Protección de registros de auditoría (inmutabilidad)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_proteger_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: Los registros de auditoría no pueden ser modificados ni eliminados. Operación bloqueada: %', TG_OP
        USING ERRCODE = 'P0002';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proteger_auditoria_update
BEFORE UPDATE ON modulo1.eventos
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_proteger_auditoria();

CREATE TRIGGER trg_proteger_auditoria_delete
BEFORE DELETE ON modulo1.eventos
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_proteger_auditoria();


-- =============================================================================
-- TRG-04 — Transiciones de estado de cuenta válidas
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_validar_transicion_estado()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_origen  VARCHAR(55);
    v_estado_destino VARCHAR(55);
BEGIN
    -- Si el estado no cambia, no hay nada que validar
    IF NEW.id_estado_cuenta = OLD.id_estado_cuenta THEN
        RETURN NEW;
    END IF;

    SELECT nombre INTO v_estado_origen
    FROM modulo1.estados_cuentas
    WHERE id_estado_cuenta = OLD.id_estado_cuenta;

    SELECT nombre INTO v_estado_destino
    FROM modulo1.estados_cuentas
    WHERE id_estado_cuenta = NEW.id_estado_cuenta;

    -- El estado ELIMINADO es irreversible sin excepción
    IF v_estado_origen = 'ELIMINADO' THEN
        RAISE EXCEPTION 'INVALID_TRANSITION: Una cuenta en estado ELIMINADO no puede cambiar a %. Esta transición es irreversible.',
            v_estado_destino
            USING ERRCODE = 'P0003';
    END IF;

    -- Validar contra la matriz de transiciones permitidas
    IF NOT (
        (v_estado_origen = 'PENDIENTE_ACTIVACION' AND v_estado_destino IN ('ACTIVO', 'ELIMINADO'))
        OR (v_estado_origen = 'ACTIVO'             AND v_estado_destino IN ('INACTIVO', 'BLOQUEADO', 'ELIMINADO'))
        OR (v_estado_origen = 'INACTIVO'           AND v_estado_destino IN ('ACTIVO', 'ELIMINADO'))
        OR (v_estado_origen = 'BLOQUEADO'          AND v_estado_destino IN ('ACTIVO', 'INACTIVO', 'ELIMINADO'))
    ) THEN
        RAISE EXCEPTION 'INVALID_TRANSITION: La transición de "%" a "%" no está permitida por el modelo de estados del sistema.',
            v_estado_origen, v_estado_destino
            USING ERRCODE = 'P0003';
    END IF;

    -- Registrar timestamp del cambio de estado válido
    NEW.fecha_cambio_estado := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_transicion_estado
BEFORE UPDATE OF id_estado_cuenta ON modulo1.cuentas_usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_validar_transicion_estado();


-- =============================================================================
-- TRG-05 — Protección del rol Administrador (no eliminación / no renombramiento)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_proteger_rol_admin()
RETURNS TRIGGER AS $$
BEGIN
    -- Bloquear eliminación de rol protegido
    IF TG_OP = 'DELETE' AND OLD.es_protegido = TRUE THEN
        RAISE EXCEPTION 'PROTECTED_ROLE: El rol "%" está marcado como protegido y no puede ser eliminado.',
            OLD.nombre_rol
            USING ERRCODE = 'P0004';
    END IF;

    -- Bloquear cambio de nombre en rol protegido
    IF TG_OP = 'UPDATE' AND OLD.es_protegido = TRUE AND NEW.nombre_rol <> OLD.nombre_rol THEN
        RAISE EXCEPTION 'PROTECTED_ROLE: El nombre del rol protegido "%" no puede ser modificado.',
            OLD.nombre_rol
            USING ERRCODE = 'P0004';
    END IF;

    -- Bloquear intento de desproteger el rol
    IF TG_OP = 'UPDATE' AND OLD.es_protegido = TRUE AND NEW.es_protegido = FALSE THEN
        RAISE EXCEPTION 'PROTECTED_ROLE: No se puede desmarcar el flag de protección del rol "%".',
            OLD.nombre_rol
            USING ERRCODE = 'P0004';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proteger_rol_admin_update
BEFORE UPDATE ON modulo1.roles
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_proteger_rol_admin();

CREATE TRIGGER trg_proteger_rol_admin_delete
BEFORE DELETE ON modulo1.roles
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_proteger_rol_admin();


-- =============================================================================
-- TRG-06 — Bloqueo de eliminación de rol con usuarios vinculados
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_bloquear_eliminacion_rol_en_uso()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM modulo1.usuarios
    WHERE id_rol = OLD.id_rol;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'ROLE_IN_USE: No se puede eliminar el rol "%" porque tiene % usuario(s) vinculado(s). Reasigne los usuarios antes de proceder.',
            OLD.nombre_rol, v_count
            USING ERRCODE = 'P0005';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloquear_eliminacion_rol_en_uso
BEFORE DELETE ON modulo1.roles
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_bloquear_eliminacion_rol_en_uso();


-- =============================================================================
-- TRG-07 — Integridad mínima de permisos por rol (prevención de rol huérfano)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_validar_permiso_minimo_rol()
RETURNS TRIGGER AS $$
DECLARE
    v_count      INTEGER;
    v_nombre_rol VARCHAR(100);
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM modulo1.permisos
    WHERE id_rol      = OLD.id_rol
      AND id_permiso <> OLD.id_permiso
      AND es_activo   = TRUE;

    IF v_count = 0 THEN
        SELECT nombre_rol INTO v_nombre_rol
        FROM modulo1.roles
        WHERE id_rol = OLD.id_rol;

        RAISE EXCEPTION 'MIN_PERMISSION: No se puede eliminar el permiso porque es el único activo del rol "%". Un rol debe tener al menos un permiso asociado.',
            v_nombre_rol
            USING ERRCODE = 'P0006';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_permiso_minimo_rol
BEFORE DELETE ON modulo1.permisos
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_validar_permiso_minimo_rol();


-- =============================================================================
-- TRG-08 — Invalidación de sesiones activas al cambiar estado de cuenta
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_invalidar_sesiones_por_estado()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_nuevo VARCHAR(55);
BEGIN
    -- Solo actuar si el estado efectivamente cambió
    IF NEW.id_estado_cuenta = OLD.id_estado_cuenta THEN
        RETURN NEW;
    END IF;

    SELECT nombre INTO v_estado_nuevo
    FROM modulo1.estados_cuentas
    WHERE id_estado_cuenta = NEW.id_estado_cuenta;

    IF v_estado_nuevo IN ('INACTIVO', 'BLOQUEADO', 'ELIMINADO') THEN
        UPDATE modulo1.sesiones
        SET es_activa = FALSE
        WHERE id_cuenta_usuario = NEW.id_cuenta_usuario
          AND es_activa = TRUE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invalidar_sesiones_por_estado
AFTER UPDATE OF id_estado_cuenta ON modulo1.cuentas_usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_invalidar_sesiones_por_estado();


-- =============================================================================
-- TRG-09 — Reset de contador de intentos fallidos al activar cuenta
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_reset_intentos_al_activar()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_nuevo VARCHAR(55);
BEGIN
    -- Solo actuar si el estado efectivamente cambió
    IF NEW.id_estado_cuenta = OLD.id_estado_cuenta THEN
        RETURN NEW;
    END IF;

    SELECT nombre INTO v_estado_nuevo
    FROM modulo1.estados_cuentas
    WHERE id_estado_cuenta = NEW.id_estado_cuenta;

    IF v_estado_nuevo = 'ACTIVO' THEN
        NEW.intentos_fallidos       := 0;
        NEW.bloqueado_hasta         := NULL;
        NEW.ultimo_intento_fallido  := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reset_intentos_al_activar
BEFORE UPDATE OF id_estado_cuenta ON modulo1.cuentas_usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_reset_intentos_al_activar();


-- =============================================================================
-- TRG-10 — Protección de campos críticos del usuario (inmutables post-registro)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_proteger_campos_criticos_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_usuario <> OLD.id_usuario THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El campo id_usuario es inmutable y no puede ser modificado.'
            USING ERRCODE = 'P0007';
    END IF;

    IF NEW.numero_identificacion <> OLD.numero_identificacion THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El número de identificación no puede ser modificado una vez registrado.'
            USING ERRCODE = 'P0007';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proteger_campos_criticos_usuario
BEFORE UPDATE ON modulo1.usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_proteger_campos_criticos_usuario();


-- =============================================================================
-- TRG-11 — Token de un solo uso (one-time use)
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_token_un_solo_uso()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el token ya fue usado, bloquear cualquier intento de cambiar fecha_uso
    IF OLD.fecha_uso IS NOT NULL AND NEW.fecha_uso IS NOT NULL
       AND NEW.fecha_uso <> OLD.fecha_uso THEN
        RAISE EXCEPTION 'TOKEN_ALREADY_USED: Este token ya fue utilizado el %. No puede reutilizarse ni modificarse su fecha de uso.',
            OLD.fecha_uso
            USING ERRCODE = 'P0008';
    END IF;

    -- Bloquear intento de "desmarcar" un token ya usado (revertir a NULL)
    IF OLD.fecha_uso IS NOT NULL AND NEW.fecha_uso IS NULL THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El estado de uso de un token no puede revertirse una vez marcado como utilizado.'
            USING ERRCODE = 'P0008';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_token_un_solo_uso
BEFORE UPDATE OF fecha_uso ON modulo1.tokens
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_token_un_solo_uso();


-- =============================================================================
-- Total de funciones de trigger:  11
-- =============================================================================