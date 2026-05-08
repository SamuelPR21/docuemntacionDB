-- =============================================================================
-- MÓDULO 7 — PUENTE DE INTEGRACIÓN DESACOPLADA
-- Archivo: triggers_modulo7_v1_0.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo7
-- Motor: PostgreSQL
-- Versión: 1.0
-- =============================================================================

-- ÍNDICE
-- TGR-M07-01  Inmutabilidad absoluta del repositorio de auditoría de peticiones (append-only)
-- TGR-M07-02  Validación de formato y presencia del hash SHA-256 en registros de auditoría
-- TGR-M07-03  Transiciones de estado unidireccionales en versiones de contrato AAEF
-- TGR-M07-04  Límite máximo de versiones de contrato AAEF simultáneas en ACTIVO o DEPRECADO
-- TGR-M07-05  Inmutabilidad de campos estructurales en contratos AAEF ACTIVOS o DEPRECADOS
-- TGR-M07-06  Control de transiciones de estado de clientes externos (REVOCADO irreversible)
-- TGR-M07-07  Unicidad de API Key activa por cliente externo (sin solapamiento en renovación)
-- TGR-M07-08  Validación de coherencia de fechas de emisión y expiración en API Keys
-- TGR-M07-09  Validación de formato y presencia del hash SHA-256 en anexos de mapeo AAEF
-- TGR-M07-10  Orden de aprobaciones en anexos de mapeo (interna antes que Agrofusión)
-- TGR-M07-11  Validación de hash SHA-256 obligatorio en metadatos de respuesta AAEF
-- TGR-M07-12  Validación de hash SHA-256 obligatorio en notificaciones webhook
-- TGR-M07-13  Coherencia temporal entre fecha de inicio y finalización en solicitudes

-- =============================================================================
-- TGR-M07-01 — Inmutabilidad absoluta del repositorio de auditoría de peticiones (append-only)
-- Tabla:  modulo7.auditoria_peticiones
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_01_auditoria_peticiones_inmutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            '[TGR-M07-01] El registro de auditoría evento=% no puede modificarse. '
            'El repositorio de auditoría del módulo M07 es absolutamente inmutable '
            '(append-only). Ningún actor, incluido el Administrador, puede alterar '
            'registros existentes. Operación bloqueada: UPDATE. '
            'Requerimiento RF-102, Restricción 4.4.',
            OLD.evento
        USING ERRCODE = 'P0001';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            '[TGR-M07-01] El registro de auditoría evento=% no puede eliminarse. '
            'El repositorio de auditoría del módulo M07 es absolutamente inmutable '
            '(append-only). La retención mínima es de 5 años (10 años para eventos AAEF). '
            'Operación bloqueada: DELETE. '
            'Requerimiento RF-102, Restricción 4.4 y Restricción 4.7 (política de retención).',
            OLD.evento
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_01_auditoria_peticiones_inmutable
    BEFORE UPDATE OR DELETE
    ON modulo7.auditoria_peticiones
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_01_auditoria_peticiones_inmutable();

COMMENT ON TRIGGER tgr_m07_01_auditoria_peticiones_inmutable
    ON modulo7.auditoria_peticiones
    IS 'TGR-M07-01 | RF-102 Restricción 4.4 y RNF-102.2 | Garantiza inmutabilidad '
       'absoluta (append-only) de todos los registros de auditoría del módulo M07. '
       'Bloquea cualquier UPDATE o DELETE sobre la tabla, independientemente del actor '
       'o proceso que lo intente. Protección a nivel de motor de base de datos.';

-- =============================================================================
-- TGR-M07-02 — Validación de formato y presencia del hash SHA-256 en registros de auditoría
-- Tabla:  modulo7.auditoria_peticiones
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_02_auditoria_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.evento_sha256 IS NULL OR trim(NEW.evento_sha256) = '' THEN
        RAISE EXCEPTION
            '[TGR-M07-02] El campo evento_sha256 es obligatorio y no puede ser nulo '
            'ni vacío al registrar un evento de auditoría. Todo registro de auditoría '
            'debe incluir su hash SHA-256 de integridad calculado por el backend. '
            'Evento UUID: %. '
            'Requerimiento RF-102, Restricción 4.6 y Restricción 4.7.',
            NEW.evento
        USING ERRCODE = 'P0001';
    END IF;

    IF length(NEW.evento_sha256) <> 64 THEN
        RAISE EXCEPTION
            '[TGR-M07-02] El campo evento_sha256 debe tener exactamente 64 caracteres '
            '(representación hexadecimal de SHA-256). Longitud recibida: %. Evento UUID: %. '
            'Requerimiento RF-102, Restricción 4.6.',
            length(NEW.evento_sha256), NEW.evento
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.evento_sha256 !~ '^[a-f0-9]{64}$' THEN
        RAISE EXCEPTION
            '[TGR-M07-02] El campo evento_sha256 contiene caracteres inválidos. '
            'Solo se admiten dígitos hexadecimales en minúscula (a-f, 0-9). '
            'Evento UUID: %. '
            'Requerimiento RF-102, Restricción 4.6.',
            NEW.evento
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_02_auditoria_hash_obligatorio
    BEFORE INSERT
    ON modulo7.auditoria_peticiones
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_02_auditoria_hash_obligatorio();

COMMENT ON TRIGGER tgr_m07_02_auditoria_hash_obligatorio
    ON modulo7.auditoria_peticiones
    IS 'TGR-M07-02 | RF-102 Restricción 4.6 y Restricción 4.7 | Valida que el campo '
       'evento_sha256 esté presente y sea un hash SHA-256 formalmente válido (64 caracteres '
       'hexadecimales en minúscula) en cada registro de auditoría insertado. Rechaza '
       'registros con hash nulo, vacío o malformado como última línea de defensa.';

-- =============================================================================
-- TGR-M07-03 — Transiciones de estado unidireccionales en versiones de contrato AAEF
-- Tabla:  modulo7.versiones_contrato_aaef
-- Evento: BEFORE UPDATE OF estado
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_03_versiones_contrato_transicion_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden_anterior INT;
    v_orden_nuevo    INT;
BEGIN
    -- Sin cambio de estado: permitir sin restricción
    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    -- Mapeo de orden jerárquico para validar dirección de transición
    v_orden_anterior := CASE OLD.estado::TEXT
        WHEN 'PENDIENTE'  THEN 1
        WHEN 'ACTIVO'     THEN 2
        WHEN 'DEPRECADO'  THEN 3
        WHEN 'INACTIVO'   THEN 4
        ELSE 0
    END;

    v_orden_nuevo := CASE NEW.estado::TEXT
        WHEN 'PENDIENTE'  THEN 1
        WHEN 'ACTIVO'     THEN 2
        WHEN 'DEPRECADO'  THEN 3
        WHEN 'INACTIVO'   THEN 4
        ELSE 0
    END;

    -- Bloquear cualquier intento de reactivar un contrato INACTIVO
    IF OLD.estado::TEXT = 'INACTIVO' THEN
        RAISE EXCEPTION
            '[TGR-M07-03] El contrato versión=% se encuentra en estado INACTIVO, '
            'que es irreversible. No se puede reactivar ni cambiar a ningún otro estado. '
            'Estado intentado: %. '
            'Requerimiento RF-98, Restricción 5.1 y FA-13 (REACTIVACION_NO_PERMITIDA).',
            OLD.contrato_version, NEW.estado
        USING ERRCODE = 'P0001';
    END IF;

    -- Bloquear retroceso de estado (orden descendente)
    IF v_orden_nuevo < v_orden_anterior THEN
        RAISE EXCEPTION
            '[TGR-M07-03] Retroceso de estado no permitido para el contrato versión=%. '
            'La secuencia válida es PENDIENTE→ACTIVO→DEPRECADO→INACTIVO. '
            'Transición inválida detectada: % → %. '
            'Requerimiento RF-98, Restricción 5.1 y CA-27.',
            OLD.contrato_version, OLD.estado, NEW.estado
        USING ERRCODE = 'P0001';
    END IF;

    -- Bloquear salto de estado (avanzar más de un paso a la vez)
    IF v_orden_nuevo > v_orden_anterior + 1 THEN
        RAISE EXCEPTION
            '[TGR-M07-03] Salto de estado no permitido para el contrato versión=%. '
            'Solo se puede avanzar un estado a la vez en la secuencia '
            'PENDIENTE→ACTIVO→DEPRECADO→INACTIVO. '
            'Transición inválida detectada: % → %. '
            'Requerimiento RF-98, Restricción 5.1 y CA-26.',
            OLD.contrato_version, OLD.estado, NEW.estado
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_03_versiones_contrato_transicion_estado
    BEFORE UPDATE OF estado
    ON modulo7.versiones_contrato_aaef
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_03_versiones_contrato_transicion_estado();

COMMENT ON TRIGGER tgr_m07_03_versiones_contrato_transicion_estado
    ON modulo7.versiones_contrato_aaef
    IS 'TGR-M07-03 | RF-98 Restricción 5.1, 5.7, CA-26 y CA-27 | Garantiza que las '
       'transiciones de estado en versiones de contrato AAEF sean estrictamente '
       'unidireccionales: PENDIENTE→ACTIVO→DEPRECADO→INACTIVO. Bloquea retrocesos, '
       'saltos de estado y reactivaciones desde INACTIVO a nivel de motor de BD.';

-- =============================================================================
-- TGR-M07-04 — Límite máximo de versiones de contrato AAEF simultáneas en ACTIVO o DEPRECADO
-- Tabla:  modulo7.versiones_contrato_aaef
-- Evento: BEFORE UPDATE OF estado
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_04_versiones_contrato_limite_activas()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    -- Solo aplica cuando el nuevo estado es ACTIVO o DEPRECADO
    IF NEW.estado::TEXT NOT IN ('ACTIVO', 'DEPRECADO') THEN
        RETURN NEW;
    END IF;

    -- Si el estado anterior ya era ACTIVO o DEPRECADO, la fila ya estaba
    -- contabilizada; no suma al límite
    IF OLD.estado::TEXT IN ('ACTIVO', 'DEPRECADO') THEN
        RETURN NEW;
    END IF;

    -- Contar versiones actualmente en ACTIVO o DEPRECADO, excluyendo la fila actual
    SELECT count(*)
    INTO v_count
    FROM modulo7.versiones_contrato_aaef
    WHERE estado::TEXT IN ('ACTIVO', 'DEPRECADO')
      AND id_version_contrato_aaef <> NEW.id_version_contrato_aaef;

    IF v_count >= 2 THEN
        RAISE EXCEPTION
            '[TGR-M07-04] Límite de versiones simultáneas excedido. Ya existen % '
            'versiones en estado ACTIVO o DEPRECADO. El máximo permitido es 2. '
            'Versión bloqueada: %. Deprecar una versión existente antes de activar '
            'una nueva (error LIMITE_VERSIONES_EXCEDIDO). '
            'Requerimiento RF-98, Restricción 5.3, 5.6 y CA-21.',
            v_count, NEW.contrato_version
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_04_versiones_contrato_limite_activas
    BEFORE UPDATE OF estado
    ON modulo7.versiones_contrato_aaef
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_04_versiones_contrato_limite_activas();

COMMENT ON TRIGGER tgr_m07_04_versiones_contrato_limite_activas
    ON modulo7.versiones_contrato_aaef
    IS 'TGR-M07-04 | RF-98 Restricción 5.3, 5.6 y CA-21 | Impide que existan más de '
       '2 versiones de contrato AAEF en estado ACTIVO o DEPRECADO de forma simultánea. '
       'Garantía implementada mediante restricción transaccional a nivel de BD para '
       'cubrir escenarios de concurrencia que el backend no puede garantizar solo.';

-- =============================================================================
-- TGR-M07-05 — Inmutabilidad de campos estructurales en contratos AAEF ACTIVOS o DEPRECADOS
-- Tabla:  modulo7.versiones_contrato_aaef
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_05_versiones_contrato_inmutable_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo aplica si el estado actual es ACTIVO o DEPRECADO
    IF OLD.estado::TEXT NOT IN ('ACTIVO', 'DEPRECADO') THEN
        RETURN NEW;
    END IF;

    -- Detectar intentos de modificar campos estructurales (distinto a la columna estado,
    -- cuya transición es controlada exclusivamente por TGR-M07-03)
    IF NEW.contrato_version <> OLD.contrato_version THEN
        RAISE EXCEPTION
            '[TGR-M07-05] El campo contrato_version del contrato id=% es inmutable '
            'cuando el estado es %. Crear una nueva versión para introducir cambios. '
            'Requerimiento RF-98, Restricción 5.12 y RNF-98.11.',
            OLD.id_version_contrato_aaef, OLD.estado
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.fecha_comienzo <> OLD.fecha_comienzo THEN
        RAISE EXCEPTION
            '[TGR-M07-05] El campo fecha_comienzo del contrato id=% es inmutable '
            'cuando el estado es %. Crear una nueva versión para introducir cambios. '
            'Requerimiento RF-98, Restricción 5.12 y RNF-98.11.',
            OLD.id_version_contrato_aaef, OLD.estado
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.descripcion IS DISTINCT FROM OLD.descripcion THEN
        RAISE EXCEPTION
            '[TGR-M07-05] El campo descripcion del contrato id=% es inmutable '
            'cuando el estado es %. Crear una nueva versión para introducir cambios. '
            'Requerimiento RF-98, Restricción 5.12 y RNF-98.11.',
            OLD.id_version_contrato_aaef, OLD.estado
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_05_versiones_contrato_inmutable_activo
    BEFORE UPDATE
    ON modulo7.versiones_contrato_aaef
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_05_versiones_contrato_inmutable_activo();

COMMENT ON TRIGGER tgr_m07_05_versiones_contrato_inmutable_activo
    ON modulo7.versiones_contrato_aaef
    IS 'TGR-M07-05 | RF-98 Restricción 5.12, RNF-98.11 y CA-20 | Protege la inmutabilidad '
       'de los campos estructurales (contrato_version, fecha_comienzo, descripcion) de '
       'contratos en estado ACTIVO o DEPRECADO. El único cambio permitido sobre estas '
       'filas es la transición de estado, controlada por TGR-M07-03.';

-- =============================================================================
-- TGR-M07-06 — Control de transiciones de estado de clientes externos
--              (REVOCADO irreversible; desde SUSPENDIDO solo a ACTIVO o REVOCADO)
-- Tabla:  modulo7.clientes_externos
-- Evento: BEFORE UPDATE OF estado
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_06_cliente_externo_estado_valido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Sin cambio de estado: permitir sin restricción
    IF OLD.estado IS NOT DISTINCT FROM NEW.estado THEN
        RETURN NEW;
    END IF;

    -- REVOCADO es irreversible: bloquear cualquier cambio desde ese estado
    IF OLD.estado::TEXT = 'REVOCADO' THEN
        RAISE EXCEPTION
            '[TGR-M07-06] El cliente externo id=% (código=%, nombre=%) se encuentra '
            'en estado REVOCADO, que es permanente e irreversible. No se puede '
            'cambiar a ningún otro estado. Estado intentado: %. '
            'Requerimiento RF-101, Restricción 6 y Proceso Fase 4.',
            OLD.id_cliente_externo, OLD.codigo, OLD.nombre, NEW.estado
        USING ERRCODE = 'P0001';
    END IF;

    -- Desde SUSPENDIDO solo se permite transición a ACTIVO o REVOCADO
    IF OLD.estado::TEXT = 'SUSPENDIDO'
       AND NEW.estado::TEXT NOT IN ('ACTIVO', 'REVOCADO') THEN
        RAISE EXCEPTION
            '[TGR-M07-06] El cliente externo id=% (código=%) tiene estado SUSPENDIDO. '
            'Desde este estado solo se permite transición a ACTIVO (reactivación) '
            'o REVOCADO (revocación definitiva). Estado intentado: %. '
            'Requerimiento RF-101, Restricción 6.',
            OLD.id_cliente_externo, OLD.codigo, NEW.estado
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_06_cliente_externo_estado_valido
    BEFORE UPDATE OF estado
    ON modulo7.clientes_externos
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_06_cliente_externo_estado_valido();

COMMENT ON TRIGGER tgr_m07_06_cliente_externo_estado_valido
    ON modulo7.clientes_externos
    IS 'TGR-M07-06 | RF-101 Restricción 6 y Proceso Fase 3/4 | Garantiza que el estado '
       'REVOCADO de clientes externos sea irreversible y que desde SUSPENDIDO solo se '
       'permita transición a ACTIVO o REVOCADO. Protege la integridad del ciclo de vida '
       'de seguridad de credenciales a nivel de motor de BD.';

-- =============================================================================
-- TGR-M07-07 — Unicidad de API Key activa por cliente externo
--              (sin solapamiento en procesos de renovación)
-- Tabla:  modulo7.identificadores_apis
-- Evento: BEFORE INSERT OR UPDATE OF estado
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_07_identificadores_apis_un_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    -- Solo aplica cuando el nuevo estado es ACTIVO
    IF NEW.estado::TEXT <> 'ACTIVO' THEN
        RETURN NEW;
    END IF;

    -- En UPDATE: si la fila ya estaba en ACTIVO para sí misma, no hay solapamiento
    IF TG_OP = 'UPDATE' AND OLD.estado::TEXT = 'ACTIVO' THEN
        RETURN NEW;
    END IF;

    -- Verificar que no exista otra API Key en estado ACTIVO para el mismo cliente
    SELECT count(*)
    INTO v_count
    FROM modulo7.identificadores_apis
    WHERE id_cliente_externo = NEW.id_cliente_externo
      AND estado::TEXT        = 'ACTIVO'
      AND id_identificador_api <> COALESCE(NEW.id_identificador_api, -1);

    IF v_count > 0 THEN
        RAISE EXCEPTION
            '[TGR-M07-07] Ya existe una API Key en estado ACTIVO para el cliente '
            'externo id=%. No puede coexistir más de una credencial activa simultáneamente. '
            'Invalidar (revocar o expirar) la credencial anterior antes de activar '
            'la nueva, garantizando renovación atómica sin solapamiento. '
            'Requerimiento RF-101, Proceso Fase 2 y CA-5.',
            NEW.id_cliente_externo
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_07_identificadores_apis_un_activo
    BEFORE INSERT OR UPDATE OF estado
    ON modulo7.identificadores_apis
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_07_identificadores_apis_un_activo();

COMMENT ON TRIGGER tgr_m07_07_identificadores_apis_un_activo
    ON modulo7.identificadores_apis
    IS 'TGR-M07-07 | RF-101 Proceso Fase 2 y CA-5 | Garantiza que un cliente externo no '
       'tenga más de una API Key en estado ACTIVO simultáneamente. Previene solapamiento '
       'de credenciales en procesos de renovación, asegurando que la clave anterior '
       'sea invalidada antes de activar la nueva.';

-- =============================================================================
-- TGR-M07-08 — Validación de coherencia de fechas de emisión y expiración en API Keys
-- Tabla:  modulo7.identificadores_apis
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_08_identificadores_apis_fecha_valida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar que fecha_expiracion esté presente
    IF NEW.fecha_expiracion IS NULL THEN
        RAISE EXCEPTION
            '[TGR-M07-08] El campo fecha_expiracion es obligatorio para toda API Key. '
            'Toda credencial debe tener una fecha de vencimiento definida. '
            'Cliente externo id=%. '
            'Requerimiento RF-101, Restricción 9.',
            NEW.id_cliente_externo
        USING ERRCODE = 'P0001';
    END IF;

    -- Validar que fecha_expiracion sea estrictamente posterior a fecha_emision
    IF NEW.fecha_expiracion <= NEW.fecha_emision THEN
        RAISE EXCEPTION
            '[TGR-M07-08] fecha_expiracion=% debe ser estrictamente posterior a '
            'fecha_emision=%. Una API Key no puede expirar en la misma fecha en que '
            'fue emitida ni antes. Cliente externo id=%. '
            'Requerimiento RF-101, Restricción 9.',
            NEW.fecha_expiracion, NEW.fecha_emision, NEW.id_cliente_externo
        USING ERRCODE = 'P0001';
    END IF;

    -- Validar que fecha_revocacion, si existe, no sea anterior a fecha_emision
    IF NEW.fecha_revocacion IS NOT NULL
       AND NEW.fecha_revocacion < NEW.fecha_emision THEN
        RAISE EXCEPTION
            '[TGR-M07-08] fecha_revocacion=% no puede ser anterior a '
            'fecha_emision=%. Una API Key no puede revocarse antes de haber sido emitida. '
            'Cliente externo id=%. '
            'Requerimiento RF-101, Restricción 9.',
            NEW.fecha_revocacion, NEW.fecha_emision, NEW.id_cliente_externo
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_08_identificadores_apis_fecha_valida
    BEFORE INSERT OR UPDATE
    ON modulo7.identificadores_apis
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_08_identificadores_apis_fecha_valida();

COMMENT ON TRIGGER tgr_m07_08_identificadores_apis_fecha_valida
    ON modulo7.identificadores_apis
    IS 'TGR-M07-08 | RF-101 Restricción 9 | Garantiza coherencia temporal en API Keys: '
       '(1) fecha_expiracion obligatoria, (2) fecha_expiracion > fecha_emision, '
       '(3) fecha_revocacion >= fecha_emision si se informa. Previene registros de '
       'credenciales con fechas incoherentes que afectarían la validación de vigencia.';

-- =============================================================================
-- TGR-M07-09 — Validación de formato y presencia del hash SHA-256 en anexos de mapeo AAEF
-- Tabla:  modulo7.mapeos_anexos_aaef
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_09_mapeos_anexos_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.canonical_sha256 IS NULL OR trim(NEW.canonical_sha256) = '' THEN
        RAISE EXCEPTION
            '[TGR-M07-09] El campo canonical_sha256 es obligatorio al registrar un '
            'anexo de mapeo AAEF. El hash SHA-256 del documento canónico formal es el '
            'mecanismo de verificación de integridad del Anexo. Código anexo: %. '
            'Requerimiento RF-AE02, Restricción 5.6 y CA-20.',
            NEW.codigo_anexo
        USING ERRCODE = 'P0001';
    END IF;

    IF length(NEW.canonical_sha256) <> 64 THEN
        RAISE EXCEPTION
            '[TGR-M07-09] El campo canonical_sha256 debe tener exactamente 64 caracteres '
            '(representación hexadecimal de SHA-256). Longitud recibida: %. Código anexo: %. '
            'Requerimiento RF-AE02, Restricción 5.6.',
            length(NEW.canonical_sha256), NEW.codigo_anexo
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.canonical_sha256 !~ '^[a-f0-9]{64}$' THEN
        RAISE EXCEPTION
            '[TGR-M07-09] El campo canonical_sha256 contiene caracteres inválidos. '
            'Solo se admiten dígitos hexadecimales en minúscula (a-f, 0-9). '
            'Código anexo: %. '
            'Requerimiento RF-AE02, Restricción 5.6 y CA-27.',
            NEW.codigo_anexo
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_09_mapeos_anexos_hash_obligatorio
    BEFORE INSERT
    ON modulo7.mapeos_anexos_aaef
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_09_mapeos_anexos_hash_obligatorio();

COMMENT ON TRIGGER tgr_m07_09_mapeos_anexos_hash_obligatorio
    ON modulo7.mapeos_anexos_aaef
    IS 'TGR-M07-09 | RF-AE02 Restricción 5.6, CA-20 y CA-27 | Garantiza que todo '
       'anexo de mapeo AAEF registrado incluya un hash SHA-256 válido del documento '
       'canónico formal (64 caracteres hexadecimales en minúscula). Sin este hash '
       'no es posible la verificación de integridad posterior requerida por RF-AE02.';

-- =============================================================================
-- TGR-M07-10 — Orden de aprobaciones en anexos de mapeo
--              (aprobación interna obligatoria antes que aprobación de Agrofusión)
-- Tabla:  modulo7.mapeos_anexos_aaef
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_10_mapeos_anexos_orden_aprobaciones()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Bloquear registro de aprobación de Agrofusión sin aprobación interna previa
    IF NEW.fecha_aprobacion_agrofusion IS NOT NULL
       AND NEW.fecha_aprobacion_interna IS NULL THEN
        RAISE EXCEPTION
            '[TGR-M07-10] No se puede registrar la aprobación de Agrofusión '
            '(fecha_aprobacion_agrofusion=%) sin que exista previamente una aprobación '
            'interna del Equipo Contable/Financiero (fecha_aprobacion_interna IS NULL). '
            'La aprobación interna es precondición obligatoria para el envío externo. '
            'Código anexo: %. '
            'Requerimiento RF-AE02, Restricción 5.9 y CA-31.',
            NEW.fecha_aprobacion_agrofusion, NEW.codigo_anexo
        USING ERRCODE = 'P0001';
    END IF;

    -- Validar coherencia cronológica: aprobación de Agrofusión no puede
    -- ser anterior a la aprobación interna
    IF NEW.fecha_aprobacion_agrofusion IS NOT NULL
       AND NEW.fecha_aprobacion_interna IS NOT NULL
       AND NEW.fecha_aprobacion_agrofusion < NEW.fecha_aprobacion_interna THEN
        RAISE EXCEPTION
            '[TGR-M07-10] La fecha_aprobacion_agrofusion=% no puede ser anterior a '
            'fecha_aprobacion_interna=%. El proceso de aprobación externa siempre '
            'ocurre después del proceso interno. Código anexo: %. '
            'Requerimiento RF-AE02, Restricción 5.9 y CA-31.',
            NEW.fecha_aprobacion_agrofusion,
            NEW.fecha_aprobacion_interna,
            NEW.codigo_anexo
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_10_mapeos_anexos_orden_aprobaciones
    BEFORE INSERT OR UPDATE
    ON modulo7.mapeos_anexos_aaef
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_10_mapeos_anexos_orden_aprobaciones();

COMMENT ON TRIGGER tgr_m07_10_mapeos_anexos_orden_aprobaciones
    ON modulo7.mapeos_anexos_aaef
    IS 'TGR-M07-10 | RF-AE02 Restricción 5.9 y CA-31 | Garantiza el orden correcto del '
       'proceso de aprobación del Anexo de Mapeo AAEF: (1) la aprobación de Agrofusión '
       'no puede registrarse sin aprobación interna previa, (2) fecha_aprobacion_agrofusion '
       'debe ser cronológicamente posterior a fecha_aprobacion_interna.';

-- =============================================================================
-- TGR-M07-11 — Validación de hash SHA-256 obligatorio en metadatos de respuesta AAEF
-- Tabla:  modulo7.metadatos_respuesta_aaef
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_11_metadatos_respuesta_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.sha256_sobre IS NULL OR trim(NEW.sha256_sobre) = '' THEN
        RAISE EXCEPTION
            '[TGR-M07-11] El campo sha256_sobre es obligatorio al registrar un envelope '
            'de respuesta AAEF. El hash SHA-256 del contenido canónico es el mecanismo '
            'de verificación de integridad que Agrofusión utiliza para validar el payload. '
            'Solicitud id=%. '
            'Requerimiento RF-97 Fase 9 y RF-AE01 RNF-AE01.5.',
            NEW.id_integracion_solicitud
        USING ERRCODE = 'P0001';
    END IF;

    IF length(NEW.sha256_sobre) <> 64 THEN
        RAISE EXCEPTION
            '[TGR-M07-11] El campo sha256_sobre debe tener exactamente 64 caracteres '
            '(representación hexadecimal de SHA-256). Longitud recibida: %. Solicitud id=%. '
            'Requerimiento RF-97 Fase 9 y RF-AE01 RNF-AE01.5.',
            length(NEW.sha256_sobre), NEW.id_integracion_solicitud
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.sha256_sobre !~ '^[a-f0-9]{64}$' THEN
        RAISE EXCEPTION
            '[TGR-M07-11] El campo sha256_sobre contiene caracteres inválidos. '
            'Solo se admiten dígitos hexadecimales en minúscula (a-f, 0-9). '
            'Solicitud id=%. '
            'Requerimiento RF-97 Fase 9 y RF-AE01 CA-10.',
            NEW.id_integracion_solicitud
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_11_metadatos_respuesta_hash_obligatorio
    BEFORE INSERT
    ON modulo7.metadatos_respuesta_aaef
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_11_metadatos_respuesta_hash_obligatorio();

COMMENT ON TRIGGER tgr_m07_11_metadatos_respuesta_hash_obligatorio
    ON modulo7.metadatos_respuesta_aaef
    IS 'TGR-M07-11 | RF-97 Fase 9, RF-AE01 RNF-AE01.5 y CA-10 | Valida que el hash '
       'SHA-256 del envelope AAEF esté presente y sea formalmente válido (64 caracteres '
       'hexadecimales en minúscula) al registrar cada respuesta generada. Un envelope '
       'sin hash hace imposible la verificación de integridad requerida por Agrofusión.';

-- =============================================================================
-- TGR-M07-12 — Validación de hash SHA-256 obligatorio en notificaciones webhook
-- Tabla:  modulo7.notificaciones_weebhook
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_12_webhook_payload_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.payload_sha256 IS NULL OR trim(NEW.payload_sha256) = '' THEN
        RAISE EXCEPTION
            '[TGR-M07-12] El campo payload_sha256 es obligatorio al registrar una '
            'notificación webhook. El hash SHA-256 del payload es evidencia de integridad '
            'necesaria para auditoría y verificación posterior del mensaje enviado. '
            'Solicitud id=%. '
            'Requerimiento RF-99, Restricción de firma obligatoria y RNF-99.8.',
            NEW.id_integracion_solicitudes
        USING ERRCODE = 'P0001';
    END IF;

    IF length(NEW.payload_sha256) <> 64 THEN
        RAISE EXCEPTION
            '[TGR-M07-12] El campo payload_sha256 debe tener exactamente 64 caracteres '
            '(representación hexadecimal de SHA-256). Longitud recibida: %. Solicitud id=%. '
            'Requerimiento RF-99, Restricción de firma HMAC.',
            length(NEW.payload_sha256), NEW.id_integracion_solicitudes
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.payload_sha256 !~ '^[a-f0-9]{64}$' THEN
        RAISE EXCEPTION
            '[TGR-M07-12] El campo payload_sha256 contiene caracteres inválidos. '
            'Solo se admiten dígitos hexadecimales en minúscula (a-f, 0-9). '
            'Solicitud id=%. '
            'Requerimiento RF-99, Restricción de firma HMAC y RNF-99.14.',
            NEW.id_integracion_solicitudes
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_12_webhook_payload_hash_obligatorio
    BEFORE INSERT
    ON modulo7.notificaciones_weebhook
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_12_webhook_payload_hash_obligatorio();

COMMENT ON TRIGGER tgr_m07_12_webhook_payload_hash_obligatorio
    ON modulo7.notificaciones_weebhook
    IS 'TGR-M07-12 | RF-99 Restricción de firma obligatoria, RNF-99.8 y RNF-99.14 | '
       'Valida que el hash SHA-256 del payload de cada notificación webhook registrada '
       'sea formalmente válido (64 caracteres hexadecimales en minúscula). Garantiza '
       'trazabilidad e integridad verificable de todos los mensajes enviados a Agrofusión.';

-- =============================================================================
-- TGR-M07-13 — Coherencia temporal entre fecha de inicio y finalización en solicitudes
-- Tabla:  modulo7.integraciones_solicitudes
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo7.fn_tgr_m07_13_integraciones_fechas_coherentes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo validar cuando ambas fechas estén presentes
    IF NEW.fecha_finalizacion IS NULL OR NEW.fecha_comienzoo IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.fecha_finalizacion < NEW.fecha_comienzoo THEN
        RAISE EXCEPTION
            '[TGR-M07-13] La fecha_finalizacion=% no puede ser anterior a '
            'fecha_comienzoo=% en la solicitud de integración id=%. '
            'Un registro con duración negativa produciría métricas de rendimiento '
            'erróneas e invalidaría la trazabilidad de la operación. '
            'Requerimiento RF-95 RNF-95.2 y RF-102 Restricción 4.7.',
            NEW.fecha_finalizacion,
            NEW.fecha_comienzoo,
            NEW.id_integracion_solicitud
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER tgr_m07_13_integraciones_fechas_coherentes
    BEFORE INSERT OR UPDATE
    ON modulo7.integraciones_solicitudes
    FOR EACH ROW
    EXECUTE FUNCTION modulo7.fn_tgr_m07_13_integraciones_fechas_coherentes();

COMMENT ON TRIGGER tgr_m07_13_integraciones_fechas_coherentes
    ON modulo7.integraciones_solicitudes
    IS 'TGR-M07-13 | RF-95 RNF-95.2 y RF-102 Restricción 4.7 | Garantiza coherencia '
       'temporal en los registros de solicitudes de integración: fecha_finalizacion '
       'debe ser mayor o igual a fecha_comienzoo cuando ambas están presentes. '
       'Previene registros con duraciones negativas que corromperían métricas y auditoría.';

-- =============================================================================
-- Total de funciones de trigger: 13 (1 por cada trigger, sin funciones compartidas)
-- Total de triggers registrados: 13
--   TGR-M07-01  auditoria_peticiones
--   TGR-M07-02  auditoria_peticiones
--   TGR-M07-03  versiones_contrato_aaef
--   TGR-M07-04  versiones_contrato_aaef
--   TGR-M07-05  versiones_contrato_aaef
--   TGR-M07-06  clientes_externos
--   TGR-M07-07  identificadores_apis
--   TGR-M07-08  identificadores_apis
--   TGR-M07-09  mapeos_anexos_aaef
--   TGR-M07-10  mapeos_anexos_aaef
--   TGR-M07-11  metadatos_respuesta_aaef
--   TGR-M07-12  notificaciones_weebhook
--   TGR-M07-13  integraciones_solicitudes
-- =============================================================================