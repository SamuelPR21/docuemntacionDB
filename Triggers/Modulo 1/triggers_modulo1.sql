-- =============================================================================
-- MÓDULO 1 — GESTIÓN DE ACCESO Y USUARIOS
-- Archivo: modulo1_triggers.sql
-- Descripción: Triggers e funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo1
-- Motor: PostgreSQL
-- Versión: 1.1 (TRG-07 corregido: cobertura DELETE + UPDATE)
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
    IF NEW.id_estado_cuenta = OLD.id_estado_cuenta THEN
        RETURN NEW;
    END IF;

    SELECT nombre INTO v_estado_origen
    FROM modulo1.estados_cuentas
    WHERE id_estado_cuenta = OLD.id_estado_cuenta;

    SELECT nombre INTO v_estado_destino
    FROM modulo1.estados_cuentas
    WHERE id_estado_cuenta = NEW.id_estado_cuenta;

    IF v_estado_origen = 'ELIMINADO' THEN
        RAISE EXCEPTION 'INVALID_TRANSITION: Una cuenta en estado ELIMINADO no puede cambiar a %.',
            v_estado_destino
            USING ERRCODE = 'P0003';
    END IF;

    IF NOT (
        (v_estado_origen = 'PENDIENTE_ACTIVACION' AND v_estado_destino IN ('ACTIVO', 'ELIMINADO'))
        OR (v_estado_origen = 'ACTIVO' AND v_estado_destino IN ('INACTIVO', 'BLOQUEADO', 'ELIMINADO'))
        OR (v_estado_origen = 'INACTIVO' AND v_estado_destino IN ('ACTIVO', 'ELIMINADO'))
        OR (v_estado_origen = 'BLOQUEADO' AND v_estado_destino IN ('ACTIVO', 'INACTIVO', 'ELIMINADO'))
    ) THEN
        RAISE EXCEPTION 'INVALID_TRANSITION: Transición no permitida.'
            USING ERRCODE = 'P0003';
    END IF;

    NEW.fecha_cambio_estado := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_transicion_estado
BEFORE UPDATE OF id_estado_cuenta ON modulo1.cuentas_usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_validar_transicion_estado();


-- =============================================================================
-- TRG-05 — Protección del rol Administrador
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_proteger_rol_admin()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' AND OLD.es_protegido = TRUE THEN
        RAISE EXCEPTION 'PROTECTED_ROLE: Rol protegido.'
            USING ERRCODE = 'P0004';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.es_protegido = TRUE AND NEW.nombre_rol <> OLD.nombre_rol THEN
        RAISE EXCEPTION 'PROTECTED_ROLE: No se puede modificar.'
            USING ERRCODE = 'P0004';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.es_protegido = TRUE AND NEW.es_protegido = FALSE THEN
        RAISE EXCEPTION 'PROTECTED_ROLE: No se puede desproteger.'
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
        RAISE EXCEPTION 'ROLE_IN_USE'
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
-- TRG-07 — Integridad mínima de permisos por rol (FIX COMPLETO)
-- =============================================================================

-- VALIDACIÓN DELETE (ya existente)
CREATE OR REPLACE FUNCTION modulo1.trg_fn_validar_permiso_minimo_rol()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM modulo1.permisos
    WHERE id_rol = OLD.id_rol
      AND id_permiso <> OLD.id_permiso
      AND es_activo = TRUE;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'MIN_PERMISSION: No se puede eliminar el último permiso activo.'
            USING ERRCODE = 'P0006';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_permiso_minimo_rol
BEFORE DELETE ON modulo1.permisos
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_validar_permiso_minimo_rol();


-- VALIDACIÓN UPDATE (CORRECCIÓN)
CREATE OR REPLACE FUNCTION modulo1.trg_fn_validar_permiso_minimo_rol_update()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF OLD.es_activo = TRUE AND NEW.es_activo = FALSE THEN

        SELECT COUNT(*) INTO v_count
        FROM modulo1.permisos
        WHERE id_rol = OLD.id_rol
          AND id_permiso <> OLD.id_permiso
          AND es_activo = TRUE;

        IF v_count = 0 THEN
            RAISE EXCEPTION 'MIN_PERMISSION: No se puede desactivar el último permiso activo.'
                USING ERRCODE = 'P0006';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_permiso_minimo_rol_update
BEFORE UPDATE OF es_activo ON modulo1.permisos
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_validar_permiso_minimo_rol_update();


-- =============================================================================
-- TRG-08 — Invalidación de sesiones
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_invalidar_sesiones_por_estado()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_estado_cuenta <> OLD.id_estado_cuenta THEN
        UPDATE modulo1.sesiones
        SET es_activa = FALSE
        WHERE id_cuenta_usuario = NEW.id_cuenta_usuario;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invalidar_sesiones_por_estado
AFTER UPDATE OF id_estado_cuenta ON modulo1.cuentas_usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_invalidar_sesiones_por_estado();


-- =============================================================================
-- TRG-09 — Reset intentos
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_reset_intentos_al_activar()
RETURNS TRIGGER AS $$
BEGIN
    NEW.intentos_fallidos := 0;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reset_intentos_al_activar
BEFORE UPDATE OF id_estado_cuenta ON modulo1.cuentas_usuarios
FOR EACH ROW
EXECUTE FUNCTION modulo1.trg_fn_reset_intentos_al_activar();


-- =============================================================================
-- TRG-10 — Protección campos críticos
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_proteger_campos_criticos_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_usuario <> OLD.id_usuario THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD'
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
-- TRG-11 — Token de un solo uso
-- =============================================================================

CREATE OR REPLACE FUNCTION modulo1.trg_fn_token_un_solo_uso()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.fecha_uso IS NOT NULL THEN
        RAISE EXCEPTION 'TOKEN_ALREADY_USED'
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