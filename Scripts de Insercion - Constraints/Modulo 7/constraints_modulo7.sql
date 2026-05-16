-- ================================================================
-- CONSTRAINTS — MÓDULO 7
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo constraints NO existentes en el DDL del backup6_1_1.sql.
--
-- YA EXISTENTES (NO se re-ejecutan):
--   PKs (15 tablas).
--   FKs ACTIVAS (16 — sin NOT VALID, ya verificadas).
--   CHECKs inline: NINGUNO en el DDL de M7.
--
-- UQs ELIMINADAS EN MIGRACIÓN (7 — re-creadas en PARTE 1):
--   uq_auditoria_evento, uq_cliente_externo_codigo,
--   uq_mapeos_anexos_aaef_codigo_anexo,
--   uq_metadatos_respuesta_aaef_identificador_cambio,
--   uq_permisos_api_codigo, uq_tipos_documentos_aaef_codigo,
--   uq_version_contrato
--
-- FKs ELIMINADAS EN MIGRACIÓN (referencias lógicas — no se recrean):
--   fk_auditoria_usuario_id → modulo1.usuarios
--   fk_integraciones_solicitudes_usuario_id → modulo1.usuarios
--   fk_integraciones_solicitudes_periodo_contable_id → modulo6
--   fk_documentos_generados_aaef_calculo_valor_razonable_id → M6
--   fk_documentos_generados_aaef_cotizaciones_id → M6
--   fk_documentos_generados_aaef_reconocimiento_iniciales → M6
--   fk_documentos_generados_aaef_valoracion_por_costo_id → M6
--   fk_registros_ejecucion_mapeador_usuario_id → modulo1.usuarios
--
-- NOTA SOBRE TYPOS EN COLUMNAS:
--   Los nombres exactos del DDL (incluidos typos) se usan en los
--   CHECKs para garantizar compatibilidad con el motor.
--
-- Se AGREGAN:
--   PARTE 1 — UNIQUE constraints (re-creación de 7 UQs eliminadas)
--   PARTE 2 — CHECK constraints directos
--   PARTE 3 — CHECK constraints diferidos (NOT VALID + VALIDATE)
--   PARTE 4 — Índices de desempeño
-- ================================================================

-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- ----------------------------------------------------------------

-- [P1] Verificar códigos duplicados en tipos_documentos_aaef:
-- SELECT codigo, COUNT(*) FROM modulo7.tipos_documentos_aaef
--  GROUP BY codigo HAVING COUNT(*) > 1;

-- [P2] Verificar versiones duplicadas en versiones_contrato_aaef:
-- SELECT contrato_version, COUNT(*) FROM modulo7.versiones_contrato_aaef
--  GROUP BY contrato_version HAVING COUNT(*) > 1;

-- [P3] Verificar códigos duplicados en clientes_externos:
-- SELECT codigo, COUNT(*) FROM modulo7.clientes_externos
--  GROUP BY codigo HAVING COUNT(*) > 1;

-- [P4] Verificar sha256 de 64 chars en mapeos_anexos_aaef:
-- SELECT id_mapeo_anexo_aaef, canonical_sha256
--   FROM modulo7.mapeos_anexos_aaef
--  WHERE char_length(canonical_sha256) != 64;

-- [P5] Verificar que fecha_emision < fecha_expiracion en apis:
-- SELECT id_identificador_api FROM modulo7.identificadores_apis
--  WHERE fecha_expiracion <= fecha_emision;


-- ================================================================
-- PARTE 1 — UNIQUE CONSTRAINTS (RE-CREACIÓN DE 7 UQs ELIMINADAS)
-- ================================================================

-- [RF-101] UUID del evento de auditoría único (trazabilidad append-only)
CREATE UNIQUE INDEX IF NOT EXISTS uix_auditoria_evento
    ON modulo7.auditoria_peticiones (evento);

-- [RF-99] Código de cliente externo único (identificador de integración)
CREATE UNIQUE INDEX IF NOT EXISTS uix_cliente_externo_codigo
    ON modulo7.clientes_externos (codigo);

-- [RF-AE01] Código del anexo AAEF único (versionado del anexo)
CREATE UNIQUE INDEX IF NOT EXISTS uix_mapeos_anexos_codigo_anexo
    ON modulo7.mapeos_anexos_aaef (codigo_anexo);

-- [RF-96] Identificador de cambio del metadato de respuesta único
-- (UUID que identifica un cambio específico en la respuesta AAEF)
CREATE UNIQUE INDEX IF NOT EXISTS uix_metadatos_identificador_cambio
    ON modulo7.metadatos_respuesta_aaef (identificador_de_cambio);

-- [RF-99] Código de permiso de API único (catálogo de permisos)
CREATE UNIQUE INDEX IF NOT EXISTS uix_permisos_api_codigo
    ON modulo7.permisos_api (codigo);

-- [RF-95] Código de tipo de documento AAEF único (catálogo de tipos)
CREATE UNIQUE INDEX IF NOT EXISTS uix_tipos_documentos_aaef_codigo
    ON modulo7.tipos_documentos_aaef (codigo);

-- [RF-97] Versión de contrato AAEF única (formato MAJOR.MINOR)
CREATE UNIQUE INDEX IF NOT EXISTS uix_version_contrato
    ON modulo7.versiones_contrato_aaef (contrato_version);

-- [RF-97] Solo puede haber una versión APROBADO activa simultáneamente
CREATE UNIQUE INDEX IF NOT EXISTS uix_version_contrato_aprobado_activa
    ON modulo7.versiones_contrato_aaef (estado)
    WHERE estado = 'APROBADO';


-- ================================================================
-- PARTE 2 — CHECK CONSTRAINTS DIRECTOS
-- ================================================================

-- ──────────────────────────────────────────────────────────────
-- TABLA: versiones_contrato_aaef
-- ──────────────────────────────────────────────────────────────

-- [RF-97] Formato de versión: MAJOR.MINOR (ej. '2.0', '1.0')
ALTER TABLE modulo7.versiones_contrato_aaef
    ADD CONSTRAINT chk_version_contrato_formato
        CHECK (contrato_version ~ '^\d+\.\d+$');

-- [RF-97] fecha_comienzo no futura
ALTER TABLE modulo7.versiones_contrato_aaef
    ADD CONSTRAINT chk_version_contrato_fecha_no_futura
        CHECK (fecha_comienzo <= CURRENT_DATE);

-- ──────────────────────────────────────────────────────────────
-- TABLA: clientes_externos
-- ──────────────────────────────────────────────────────────────

-- [RF-99] Código de cliente no vacío
ALTER TABLE modulo7.clientes_externos
    ADD CONSTRAINT chk_cliente_codigo_no_vacio
        CHECK (char_length(trim(codigo)) > 0);

-- [RF-99] Nombre de cliente no vacío
ALTER TABLE modulo7.clientes_externos
    ADD CONSTRAINT chk_cliente_nombre_no_vacio
        CHECK (char_length(trim(nombre)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: permisos_api
-- ──────────────────────────────────────────────────────────────

-- [RF-99] Endpoint_patron no vacío
ALTER TABLE modulo7.permisos_api
    ADD CONSTRAINT chk_permiso_endpoint_no_vacio
        CHECK (char_length(trim(endpoint_patron)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: identificadores_apis
-- ──────────────────────────────────────────────────────────────

-- [RF-99] fecha_expiracion posterior a fecha_emision
ALTER TABLE modulo7.identificadores_apis
    ADD CONSTRAINT chk_api_key_fechas_coherentes
        CHECK (fecha_expiracion > fecha_emision);

-- [RF-99] fecha_revocacion posterior a fecha_emision
ALTER TABLE modulo7.identificadores_apis
    ADD CONSTRAINT chk_api_key_revocacion_posterior
        CHECK (
            fecha_revocacion IS NULL
            OR fecha_revocacion >= fecha_emision
        );

-- [RF-99] Si estado = REVOCADA → fecha_revocacion NOT NULL
ALTER TABLE modulo7.identificadores_apis
    ADD CONSTRAINT chk_api_key_revocada_tiene_fecha
        CHECK (
            estado != 'REVOCADA'
            OR fecha_revocacion IS NOT NULL
        );

-- [RF-99] api_llave_encriptada no vacía
ALTER TABLE modulo7.identificadores_apis
    ADD CONSTRAINT chk_api_key_llave_no_vacia
        CHECK (char_length(trim(api_llave_encriptada)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: catalogo_errores_de_integracion
-- ──────────────────────────────────────────────────────────────

-- [RF-95] estado_http en rango HTTP válido (100-599)
ALTER TABLE modulo7.catalogo_errores_de_integracion
    ADD CONSTRAINT chk_error_estado_http_valido
        CHECK (estado_http >= 100 AND estado_http <= 599);

-- [RF-95] mensaje no vacío
ALTER TABLE modulo7.catalogo_errores_de_integracion
    ADD CONSTRAINT chk_error_mensaje_no_vacio
        CHECK (char_length(trim(mensaje)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: mapeos_anexos_aaef
-- ──────────────────────────────────────────────────────────────

-- [RF-AE01] canonical_sha256 exactamente 64 caracteres hex
ALTER TABLE modulo7.mapeos_anexos_aaef
    ADD CONSTRAINT chk_mapeo_sha256_formato
        CHECK (canonical_sha256 ~ '^[a-f0-9]{64}$');

-- [RF-AE01] direccion_pdf no vacía
ALTER TABLE modulo7.mapeos_anexos_aaef
    ADD CONSTRAINT chk_mapeo_direccion_no_vacia
        CHECK (char_length(trim(direccion_pdf)) > 0);

-- [RF-AE01] Aprobación Agrofusión posterior a aprobación interna
ALTER TABLE modulo7.mapeos_anexos_aaef
    ADD CONSTRAINT chk_mapeo_aprobacion_orden
        CHECK (
            fecha_aprobacion_agrofusion IS NULL
            OR fecha_aprobacion_interna IS NULL
            OR fecha_aprobacion_agrofusion >= fecha_aprobacion_interna
        );

-- [RF-AE01] Estado APROBADO requiere ambas fechas de aprobación
ALTER TABLE modulo7.mapeos_anexos_aaef
    ADD CONSTRAINT chk_mapeo_aprobado_tiene_fechas
        CHECK (
            estado != 'APROBADO'
            OR (fecha_aprobacion_interna IS NOT NULL
                AND fecha_aprobacion_agrofusion IS NOT NULL)
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: integraciones_solicitudes
-- ──────────────────────────────────────────────────────────────

-- [RF-95] fecha_finalizacion >= fecha_comienzoo (typo en DDL)
ALTER TABLE modulo7.integraciones_solicitudes
    ADD CONSTRAINT chk_solicitud_fechas_coherentes
        CHECK (fecha_finalizacion >= fecha_comienzoo);

-- [RF-95] duracion_ms no negativa cuando está definida
ALTER TABLE modulo7.integraciones_solicitudes
    ADD CONSTRAINT chk_solicitud_duracion_no_negativa
        CHECK (duracion_ms IS NULL OR duracion_ms >= 0);

-- [RF-95] Si estado = FAILED/TIMEOUT/UNAUTHORIZED/FORBIDDEN
--         y hay error asignado, debe ser consistente
ALTER TABLE modulo7.integraciones_solicitudes
    ADD CONSTRAINT chk_solicitud_error_coherente
        CHECK (
            estado = 'SUCCESS'
            OR id_error IS NOT NULL
            OR estado = 'TIMEOUT'
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: documentos_generados_aaef
-- ──────────────────────────────────────────────────────────────

-- [RF-96] tamaño_payload_bytes positivo (con tilde en DDL)
ALTER TABLE modulo7.documentos_generados_aaef
    ADD CONSTRAINT chk_documento_tamano_positivo
        CHECK ("tamaño_payload_bytes" > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: reglas_mapeo_aaef
-- ──────────────────────────────────────────────────────────────

-- [RF-95] entidad_origen, campo_origen, campo_destino no vacíos
ALTER TABLE modulo7.reglas_mapeo_aaef
    ADD CONSTRAINT chk_regla_campos_no_vacios
        CHECK (
            char_length(trim(entidad_origen)) > 0
            AND char_length(trim(campo_origen)) > 0
            AND char_length(trim(campo_destino)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: metadatos_respuesta_aaef
-- ──────────────────────────────────────────────────────────────

-- [RF-96] sha256_sobre exactamente 64 caracteres hex
ALTER TABLE modulo7.metadatos_respuesta_aaef
    ADD CONSTRAINT chk_metadato_sha256_formato
        CHECK (sha256_sobre ~ '^[a-f0-9]{64}$');

-- [RF-96] metadatos, facturas y resumen no vacíos
ALTER TABLE modulo7.metadatos_respuesta_aaef
    ADD CONSTRAINT chk_metadato_jsonb_no_vacios
        CHECK (
            metadatos != '{}'::jsonb
            AND facturas != '[]'::jsonb
            AND resumen != '{}'::jsonb
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: notificaciones_weebhook
-- ──────────────────────────────────────────────────────────────

-- [RF-98] payload_sha256 exactamente 64 caracteres hex
ALTER TABLE modulo7.notificaciones_weebhook
    ADD CONSTRAINT chk_webhook_sha256_formato
        CHECK (payload_sha256 ~ '^[a-f0-9]{64}$');

-- [RF-98] url_destino no vacía
ALTER TABLE modulo7.notificaciones_weebhook
    ADD CONSTRAINT chk_webhook_url_no_vacia
        CHECK (char_length(trim(url_destino)) > 0);

-- [RF-98] codigo_respuesta en rango HTTP cuando está definido
ALTER TABLE modulo7.notificaciones_weebhook
    ADD CONSTRAINT chk_webhook_codigo_http_valido
        CHECK (
            codigo_respuesta IS NULL
            OR (codigo_respuesta >= 100 AND codigo_respuesta <= 599)
        );

-- [RF-98] Si estado_notifiacion = SENT → fecha_recepcion NOT NULL
ALTER TABLE modulo7.notificaciones_weebhook
    ADD CONSTRAINT chk_webhook_sent_tiene_recepcion
        CHECK (
            estado_notifiacion != 'SENT'
            OR fecha_recepcion IS NOT NULL
        );

-- [RF-98] fecha_recepcion >= fecha_envio cuando está definida
ALTER TABLE modulo7.notificaciones_weebhook
    ADD CONSTRAINT chk_webhook_fechas_coherentes
        CHECK (
            fecha_recepcion IS NULL
            OR fecha_recepcion >= fecha_envio
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: registros_ejecucion_mapeador
-- ──────────────────────────────────────────────────────────────

-- [RF-95] orden_ejecucion positivo (>= 1)
ALTER TABLE modulo7.registros_ejecucion_mapeador
    ADD CONSTRAINT chk_mapeador_orden_positivo
        CHECK (orden_ejecucion >= 1);

-- [RF-95] duration_ms no negativa cuando está definida
ALTER TABLE modulo7.registros_ejecucion_mapeador
    ADD CONSTRAINT chk_mapeador_duracion_no_negativa
        CHECK (duration_ms IS NULL OR duration_ms >= 0);

-- [RF-95] Si estado = FAILED → mensaje_error NOT NULL
ALTER TABLE modulo7.registros_ejecucion_mapeador
    ADD CONSTRAINT chk_mapeador_failed_tiene_mensaje
        CHECK (
            estado != 'FAILED'
            OR mensaje_error IS NOT NULL
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: auditoria_peticiones
-- ──────────────────────────────────────────────────────────────

-- [RF-101] evento_sha256 exactamente 64 caracteres hex
ALTER TABLE modulo7.auditoria_peticiones
    ADD CONSTRAINT chk_auditoria_sha256_formato
        CHECK (evento_sha256 ~ '^[a-f0-9]{64}$');

-- [RF-101] tipo no vacío
ALTER TABLE modulo7.auditoria_peticiones
    ADD CONSTRAINT chk_auditoria_tipo_no_vacio
        CHECK (char_length(trim(tipo)) > 0);

-- [RF-101] datos no vacío (JSONB con contenido)
ALTER TABLE modulo7.auditoria_peticiones
    ADD CONSTRAINT chk_auditoria_datos_no_vacio
        CHECK (datos != '{}'::jsonb);

-- [RF-101] es_inmuntable siempre true (append-only inmutable)
ALTER TABLE modulo7.auditoria_peticiones
    ADD CONSTRAINT chk_auditoria_inmutable
        CHECK (es_inmuntable = true);


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS DIFERIDOS (NOT VALID + VALIDATE)
-- ================================================================

-- [RF-99] fecha_emision de API Key no futura
ALTER TABLE modulo7.identificadores_apis
    ADD CONSTRAINT chk_api_key_emision_no_futura
        CHECK (fecha_emision <= NOW()) NOT VALID;
ALTER TABLE modulo7.identificadores_apis
    VALIDATE CONSTRAINT chk_api_key_emision_no_futura;

-- [RF-96] fecha_generacion de documentos no futura
ALTER TABLE modulo7.documentos_generados_aaef
    ADD CONSTRAINT chk_documento_fecha_no_futura
        CHECK (fecha_generacion <= NOW()) NOT VALID;
ALTER TABLE modulo7.documentos_generados_aaef
    VALIDATE CONSTRAINT chk_documento_fecha_no_futura;

-- [RF-95] fecha_comienzoo de integracion no futura
ALTER TABLE modulo7.integraciones_solicitudes
    ADD CONSTRAINT chk_solicitud_fecha_no_futura
        CHECK (fecha_comienzoo <= NOW()) NOT VALID;
ALTER TABLE modulo7.integraciones_solicitudes
    VALIDATE CONSTRAINT chk_solicitud_fecha_no_futura;

-- [RF-101] fecha de auditoría no futura
ALTER TABLE modulo7.auditoria_peticiones
    ADD CONSTRAINT chk_auditoria_fecha_no_futura
        CHECK (fecha <= NOW()) NOT VALID;
ALTER TABLE modulo7.auditoria_peticiones
    VALIDATE CONSTRAINT chk_auditoria_fecha_no_futura;

-- [RF-98] fecha_envio de webhook no futura
ALTER TABLE modulo7.notificaciones_weebhook
    ADD CONSTRAINT chk_webhook_envio_no_futuro
        CHECK (fecha_envio <= NOW()) NOT VALID;
ALTER TABLE modulo7.notificaciones_weebhook
    VALIDATE CONSTRAINT chk_webhook_envio_no_futuro;


-- ================================================================
-- PARTE 4 — ÍNDICES DE DESEMPEÑO
-- ================================================================

-- [RF-95] Solicitudes por cliente y estado (monitoreo de integraciones)
CREATE INDEX IF NOT EXISTS idx_solicitud_cliente_estado
    ON modulo7.integraciones_solicitudes
    (id_cliente_externo, estado, fecha_comienzoo DESC);

-- [RF-96] Documentos por solicitud (trazabilidad de generación)
CREATE INDEX IF NOT EXISTS idx_documento_solicitud
    ON modulo7.documentos_generados_aaef
    (id_integracion_solicitud, id_tipo_documento_aaef);

-- [RF-99] API Keys activas por cliente
CREATE INDEX IF NOT EXISTS idx_api_key_cliente_estado
    ON modulo7.identificadores_apis (id_cliente_externo, estado)
    WHERE estado = 'ACTIVA';

-- [RF-101] Auditorías por tipo y fecha (trazabilidad)
CREATE INDEX IF NOT EXISTS idx_auditoria_tipo_fecha
    ON modulo7.auditoria_peticiones (tipo, fecha DESC);

-- [RF-98] Webhooks pendientes de entrega
CREATE INDEX IF NOT EXISTS idx_webhook_estado_pendiente
    ON modulo7.notificaciones_weebhook (estado_notifiacion, fecha_envio DESC)
    WHERE estado_notifiacion = 'PENDING';

-- [RF-95] Ejecuciones del mapeador por solicitud y orden
CREATE INDEX IF NOT EXISTS idx_mapeador_solicitud_orden
    ON modulo7.registros_ejecucion_mapeador
    (id_integracion_solicitud, orden_ejecucion);

-- [RF-97] Versiones del contrato por estado
CREATE INDEX IF NOT EXISTS idx_version_contrato_estado
    ON modulo7.versiones_contrato_aaef (estado, fecha_comienzo DESC);

-- [RF-99] Permisos por cliente externo
CREATE INDEX IF NOT EXISTS idx_permisos_cliente
    ON modulo7.permisos_clientes (id_clienete_externo, id_permiso_api);
