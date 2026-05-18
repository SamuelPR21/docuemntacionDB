-- =============================================================================
-- MÓDULO 7 — VISTAS (TABLAS VIRTUALES)
-- RF-98  Versiones del Contrato de Integración
-- RF-99  Notificaciones Webhook
-- RF-101 Clientes Externos
-- RF-102 Auditoría de Integración
-- =============================================================================
-- Convención de nombres: v_<rf>_<propósito>
-- Todas las vistas son de solo lectura; no reemplazan triggers ni lógica de
-- negocio — sirven para consultas del frontend y reportes.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-98 · VERSIONES DEL CONTRATO DE INTEGRACIÓN
-- Tabla principal: modulo7.versiones_contrato_aaef
-- Columnas UI: Versión · Estado · Vigente desde · Vence en ·
--              Transformador (mapeo activo) · Tipo de cambio
-- ─────────────────────────────────────────────────────────────────────────────

-- Vista principal — una fila por versión de contrato con su mapeo vigente
CREATE OR REPLACE VIEW modulo7.v_rf98_contratos_integracion AS
SELECT
    vc.id_version_contrato_aaef,
    vc.contrato_version                                         AS version,
    vc.estado,
    vc.fecha_comienzo                                           AS vigente_desde,
    vc.descripcion,
    vc.fecha_creacion,

    -- Anexo / transformador vigente vinculado al contrato
    ma.id_mapeo_anexo_aaef,
    ma.codigo_anexo                                             AS transformador,
    ma.version_anexo                                            AS version_transformador,
    ma.estado                                                   AS estado_transformador,
    -- El transformador está "disponible" si su mapeo está en estado VIGENTE
    (ma.estado = 'APROBADO')                                     AS transformador_disponible,
    ma.fecha_aprobacion_agrofusion                              AS fecha_aprobacion_transformador,

    -- Indicador derivado: tipo de cambio según si la versión reemplaza a otra
    CASE
        WHEN vc.contrato_version LIKE '%.0' THEN 'MAYOR'
        WHEN vc.contrato_version LIKE '%.%'
             AND split_part(vc.contrato_version, '.', 2)::int > 0 THEN 'MENOR'
        ELSE 'INICIAL'
    END                                                         AS tipo_cambio,

    -- Conteo de reglas de mapeo para este contrato (indica completitud)
    COUNT(rm.id_regla_mapeo_aaef)                               AS total_reglas_mapeo,
    COUNT(rm.id_regla_mapeo_aaef) FILTER (WHERE rm.es_requerida) AS reglas_requeridas

FROM modulo7.versiones_contrato_aaef vc
LEFT JOIN modulo7.mapeos_anexos_aaef   ma ON ma.id_version_contrato_aaef = vc.id_version_contrato_aaef
LEFT JOIN modulo7.reglas_mapeo_aaef    rm ON rm.id_mapeo_anexo           = ma.id_mapeo_anexo_aaef
GROUP BY
    vc.id_version_contrato_aaef,
    vc.contrato_version,
    vc.estado,
    vc.fecha_comienzo,
    vc.descripcion,
    vc.fecha_creacion,
    ma.id_mapeo_anexo_aaef,
    ma.codigo_anexo,
    ma.version_anexo,
    ma.estado,
    ma.fecha_aprobacion_agrofusion;

COMMENT ON VIEW modulo7.v_rf98_contratos_integracion IS
    'RF-98: Listado de versiones del contrato AAEF con su transformador (mapeo) '
    'activo y métricas de completitud de reglas. Alimenta la tabla principal '
    'y el modal de detalle.';


-- Tarjetas de resumen (stat-cards) — RF-98
CREATE OR REPLACE VIEW modulo7.v_rf98_stats_contratos AS
SELECT
    COUNT(*) FILTER (WHERE estado = 'APROBADO')              AS versiones_vigentes,
    COUNT(*) FILTER (WHERE estado = 'EN_REVISION')    AS en_periodo_gracia,
    COUNT(*) FILTER (WHERE estado IN ('BORRADOR','OBSOLETO')) AS archivadas,
    COUNT(*)                                                AS total
FROM modulo7.versiones_contrato_aaef;

COMMENT ON VIEW modulo7.v_rf98_stats_contratos IS
    'RF-98: Contadores para las stat-cards del encabezado de la pantalla.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-99 · NOTIFICACIONES WEBHOOK
-- Tabla principal: modulo7.notificaciones_weebhook
-- Columnas UI: Tipo de evento · Cliente · Fecha del evento · Estado ·
--              Intentos · Latencia
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo7.v_rf99_webhooks AS
SELECT
    nw.id_notificacion_weebhook,
    nw.tipo_evento,
    nw.estado_notifiacion                                       AS estado,
    nw.url_destino,
    nw.payload_sha256,
    nw.codigo_respuesta,
    nw.fecha_envio,
    nw.fecha_recepcion,

    -- Latencia calculada en milisegundos (NULL si aún no hay recepción)
    EXTRACT(MILLISECOND FROM (nw.fecha_recepcion - nw.fecha_envio))
                                                                AS latencia_ms,

    -- Indicador de firma: el payload tiene sha256 → firma válida si no es NULL
    (nw.payload_sha256 IS NOT NULL)                             AS firma_valida,

    -- Datos del cliente que originó la solicitud
    ce.id_cliente_externo,
    ce.nombre                                                   AS cliente_nombre,
    ce.codigo                                                   AS cliente_codigo,
    ce.estado                                                   AS cliente_estado,

    -- Solicitud de integración asociada
    ins.id_integracion_solicitud,
    ins.estado                                                  AS estado_solicitud,
    ins.correlacion_id,
    ins.duracion_ms                                             AS duracion_solicitud_ms,

    -- Indicador de reenvío: si la misma solicitud tiene más de un webhook
    (
        SELECT COUNT(*)
        FROM modulo7.notificaciones_weebhook nx
        WHERE nx.id_integracion_solicitudes = nw.id_integracion_solicitudes
    )                                                           AS intentos_totales

FROM modulo7.notificaciones_weebhook       nw
JOIN  modulo7.integraciones_solicitudes    ins ON ins.id_integracion_solicitud = nw.id_integracion_solicitudes
JOIN  modulo7.clientes_externos            ce  ON ce.id_cliente_externo        = ins.id_cliente_externo;

COMMENT ON VIEW modulo7.v_rf99_webhooks IS
    'RF-99: Historial de notificaciones webhook enriquecido con datos del cliente '
    'y la solicitud. Columna intentos_totales facilita mostrar el chip de reintentos.';


-- Tarjetas de resumen — RF-99
CREATE OR REPLACE VIEW modulo7.v_rf99_stats_webhooks AS
SELECT
    COUNT(*) FILTER (
        WHERE fecha_envio::date = CURRENT_DATE
    )                                                           AS enviados_hoy,
    COUNT(*) FILTER (
        WHERE estado_notifiacion = 'PERIODO_CERRADO'
          AND fecha_envio::date  = CURRENT_DATE
    )                                                           AS confirmados_hoy,
    COUNT(*) FILTER (
        WHERE estado_notifiacion NOT IN ('PERIODO_CERRADO')
          AND fecha_envio::date  = CURRENT_DATE
    )                                                           AS en_curso_hoy,
    COUNT(*) FILTER (
        WHERE estado_notifiacion = 'PERIODO_CERRADO'
          AND fecha_envio::date  = CURRENT_DATE
    )                                                           AS fallidos_hoy
FROM modulo7.notificaciones_weebhook;

COMMENT ON VIEW modulo7.v_rf99_stats_webhooks IS
    'RF-99: Contadores diarios para las stat-cards de la pantalla de webhooks.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-101 · CLIENTES EXTERNOS
-- Tabla principal: modulo7.clientes_externos
-- Columnas UI: Sistema · Tipo · Estado · Vence · Webhooks · Última actividad
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo7.v_rf101_clientes_externos AS
SELECT
    ce.id_cliente_externo,
    ce.codigo,
    ce.nombre                                                   AS sistema,
    ce.tipo,
    ce.estado,
    ce.ip_permitida,
    ce.fecha_creacion,

    -- Credencial API activa (la más reciente no revocada)
    api.id_identificador_api,
    api.fecha_expiracion                                        AS clave_vence,
    api.fecha_revocacion                                        AS clave_revocada_en,
    api.estado                                                  AS estado_clave,
    -- Días hasta la expiración (negativo = ya expiró)
    (api.fecha_expiracion::date - CURRENT_DATE)                 AS dias_para_vencer,

    -- Cantidad de permisos asignados
    (
        SELECT COUNT(*)
        FROM modulo7.permisos_clientes pc
        WHERE pc.id_clienete_externo = ce.id_cliente_externo
    )                                                           AS total_permisos,

    -- Webhooks: cuenta de notificaciones distintas asociadas a este cliente
    (
        SELECT COUNT(*)
        FROM modulo7.notificaciones_weebhook  nw
        JOIN  modulo7.integraciones_solicitudes ins
              ON ins.id_integracion_solicitud = nw.id_integracion_solicitudes
        WHERE ins.id_cliente_externo = ce.id_cliente_externo
    )                                                           AS total_webhooks,

    -- Última actividad: fecha de la solicitud más reciente
    (
        SELECT MAX(fecha_comienzoo)
        FROM modulo7.integraciones_solicitudes ins
        WHERE ins.id_cliente_externo = ce.id_cliente_externo
    )                                                           AS ultima_actividad,

    -- Última solicitud exitosa
    (
        SELECT MAX(fecha_comienzoo)
        FROM modulo7.integraciones_solicitudes ins
        WHERE ins.id_cliente_externo = ce.id_cliente_externo
          AND ins.estado = 'SUCCESS'
    )                                                           AS ultima_solicitud_exitosa

FROM modulo7.clientes_externos ce
-- Solo trae la credencial más reciente no revocada
LEFT JOIN LATERAL (
    SELECT *
    FROM modulo7.identificadores_apis ia
    WHERE ia.id_cliente_externo = ce.id_cliente_externo
      AND ia.fecha_revocacion IS NULL
    ORDER BY ia.fecha_creacion DESC
    LIMIT 1
) api ON true;

COMMENT ON VIEW modulo7.v_rf101_clientes_externos IS
    'RF-101: Directorio de clientes externos con su credencial API vigente, '
    'conteo de webhooks y timestamp de última actividad. '
    'Usa LATERAL para obtener solo la clave activa más reciente.';


-- Vista complementaria: log de operaciones por cliente (panel de historial)
CREATE OR REPLACE VIEW modulo7.v_rf101_historial_cliente AS
SELECT
    ap.id_auditoria,
    ap.id_intgracion_solucitud                                  AS id_integracion_solicitud,
    ins.id_cliente_externo,
    ce.nombre                                                   AS cliente_nombre,
    ap.tipo                                                     AS evento,
    ap.fecha,
    ap.datos ->> 'ip_origen'                                    AS ip,
    ap.datos ->> 'motivo'                                       AS motivo,
    ap.evento_sha256,
    ap.es_inmuntable
FROM modulo7.auditoria_peticiones           ap
JOIN modulo7.integraciones_solicitudes      ins ON ins.id_integracion_solicitud = ap.id_intgracion_solucitud
JOIN modulo7.clientes_externos              ce  ON ce.id_cliente_externo        = ins.id_cliente_externo
ORDER BY ap.fecha DESC;

COMMENT ON VIEW modulo7.v_rf101_historial_cliente IS
    'RF-101: Historial de operaciones por cliente (panel lateral de auditoría). '
    'Proyecta ip_origen y motivo desde la columna JSONB datos.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-102 · AUDITORÍA DE INTEGRACIÓN
-- Tabla principal: modulo7.auditoria_peticiones
-- Columnas UI (vista auditor): Fecha y hora · Categoría · Evento ·
--   Sistema/Actor · IP de origen · Código HTTP · Severidad · Integridad
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo7.v_rf102_auditoria_integracion AS
SELECT
    ap.id_auditoria,
    ap.evento                                                   AS evento_uuid,
    ap.fecha                                                    AS timestamp_evento,
    ap.tipo                                                     AS tipo_evento_label,
    ap.es_inmuntable,

    -- Integridad: el registro es íntegro si tiene sha256 y es inmutable
    (ap.evento_sha256 IS NOT NULL AND ap.es_inmuntable = true) AS es_integro,
    ap.evento_sha256,

    -- Datos del actor / sistema externo
    ins.id_cliente_externo,
    ce.nombre                                                   AS sistema_externo,
    ce.tipo                                                     AS tipo_sistema,
    u.nombre || ' ' || u.apellidos                              AS actor_usuario,
    COALESCE(ce.nombre, u.nombre || ' ' || u.apellidos, '—')   AS actor,

    -- IP de origen extraída del JSONB datos
    ap.datos ->> 'ip_origen'                                    AS ip_origen,

    -- Solicitud de integración
    ins.id_integracion_solicitud,
    ins.estado                                                  AS estado_solicitud,
    ins.correlacion_id,

    -- Código HTTP del error (si existió), desde el catálogo
    ce_err.estado_http                                          AS codigo_http,
    ce_err.mensaje                                              AS mensaje_error,
    ce_err.codigo                                               AS codigo_error_enum,

    -- Severidad derivada del código HTTP y del estado de la solicitud
    CASE
        WHEN ce_err.estado_http >= 500                          THEN 'CRITICO'
        WHEN ce_err.estado_http >= 400                          THEN 'ADVERTENCIA'
        WHEN ins.estado = 'SUCCESS'                             THEN 'INFORMATIVO'
        ELSE 'INFORMATIVO'
    END                                                         AS severidad,

    -- Categoría para el badge de la UI
    CASE
        WHEN ap.tipo ILIKE '%EXPORTACION%'
          OR ap.tipo ILIKE '%AEEF%'                             THEN 'EXPORTACION_AEEF'
        WHEN ap.tipo ILIKE '%AUTENTICACION%'
          OR ap.tipo ILIKE '%ACCESO%'                           THEN 'AUTENTICACION'
        WHEN ap.tipo ILIKE '%ERROR%'
          OR ce_err.id_catalogo_error IS NOT NULL               THEN 'ERROR'
        ELSE 'OPERACION'
    END                                                         AS categoria,

    -- Auditoría financiera vinculada (si corresponde)
    af.id_auditoria_financiera,
    af.tipo                                                     AS tipo_auditoria_financiera,
    af.severidad                                                AS severidad_auditoria_financiera,

    -- Período contable
    ins.id_periodo_contable

FROM modulo7.auditoria_peticiones               ap
JOIN  modulo7.integraciones_solicitudes         ins ON ins.id_integracion_solicitud = ap.id_intgracion_solucitud
JOIN  modulo7.clientes_externos                 ce  ON ce.id_cliente_externo        = ins.id_cliente_externo
LEFT JOIN modulo1.usuarios                      u   ON u.id_usuario                 = ap.id_usuario
LEFT JOIN modulo7.catalogo_errores_de_integracion ce_err
                                                    ON ce_err.id_catalogo_error     = ins.id_error
LEFT JOIN modulo6.auditorias_financieras        af  ON af.id_auditoria_financiera   = ap.id_auditorias_financieras;

COMMENT ON VIEW modulo7.v_rf102_auditoria_integracion IS
    'RF-102: Historial de auditoría de integración completo. '
    'Combina auditoria_peticiones + solicitudes + cliente + usuario + error + '
    'auditoría financiera. Severidad y Categoría son campos derivados que '
    'alimentan los badges de la UI. es_integro valida que el registro tenga '
    'sha256 y no haya sido mutado (es_inmuntable = true).';


-- Tarjetas de resumen — RF-102
CREATE OR REPLACE VIEW modulo7.v_rf102_stats_auditoria AS
SELECT
    -- Eventos de hoy
    COUNT(*) FILTER (
        WHERE ap.fecha::date = CURRENT_DATE
    )                                                               AS eventos_hoy,

    -- Consultas AEEF exitosas hoy
    COUNT(*) FILTER (
        WHERE ap.fecha::date = CURRENT_DATE
          AND ins.estado     = 'SUCCESS'
          AND (ap.tipo ILIKE '%AEEF%' OR ap.tipo ILIKE '%EXPORTACION%')
    )                                                               AS consultas_aeef_exitosas,

    -- Alertas críticas hoy (HTTP >= 500 o solicitud con error)
    COUNT(*) FILTER (
        WHERE ap.fecha::date = CURRENT_DATE
          AND (
              ce_err.estado_http >= 500
              OR ins.estado = 'FAILED'
          )
    )                                                               AS alertas_criticas,

    -- Registros con integridad comprometida
    COUNT(*) FILTER (
        WHERE ap.evento_sha256 IS NULL OR ap.es_inmuntable = false
    )                                                               AS integridad_comprometida

FROM modulo7.auditoria_peticiones               ap
JOIN  modulo7.integraciones_solicitudes         ins ON ins.id_integracion_solicitud = ap.id_intgracion_solucitud
LEFT JOIN modulo7.catalogo_errores_de_integracion ce_err
                                                    ON ce_err.id_catalogo_error     = ins.id_error;

COMMENT ON VIEW modulo7.v_rf102_stats_auditoria IS
    'RF-102: Contadores para las 4 stat-cards del encabezado de auditoría.';


-- ─────────────────────────────────────────────────────────────────────────────
-- VISTA TRANSVERSAL — Pipeline completo de una solicitud
-- Útil para el modal de "Detalle del evento" en RF-102 y el drawer de RF-99
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo7.v_pipeline_solicitud AS
SELECT
    ins.id_integracion_solicitud,
    ins.correlacion_id,
    ins.estado                                                  AS estado_solicitud,
    ins.fecha_comienzoo                                         AS inicio,
    ins.fecha_finalizacion                                      AS fin,
    ins.duracion_ms,

    -- Cliente
    ce.id_cliente_externo,
    ce.nombre                                                   AS cliente,
    ce.codigo                                                   AS cliente_codigo,

    -- Versión de contrato usada
    vc.contrato_version,
    vc.estado                                                   AS estado_contrato,

    -- Pasos del mapeador (ordenados)
    COALESCE(
        json_agg(
            json_build_object(
                'orden',         rem.orden_ejecucion,
                'nombre',        rem.nombre,
                'estado',        rem.estado,
                'duracion_ms',   rem.duration_ms,
                'error',         rem.mensaje_error
            ) ORDER BY rem.orden_ejecucion
        ) FILTER (WHERE rem.id_registro_ejecucion_mapeador IS NOT NULL),
        '[]'::json
    )                                                           AS pasos_mapeador,

    -- Documentos generados
    COUNT(dg.id_documentos_generados_aaef)                      AS documentos_generados,

    -- Webhook de notificación (el más reciente)
    nw.estado_notifiacion                                       AS webhook_estado,
    nw.codigo_respuesta                                         AS webhook_codigo_http,
    nw.fecha_envio                                              AS webhook_enviado_en,
    nw.fecha_recepcion                                          AS webhook_confirmado_en,

    -- Error del catálogo
    ce_err.codigo                                               AS error_codigo,
    ce_err.mensaje                                              AS error_mensaje,
    ce_err.estado_http                                          AS error_http

FROM modulo7.integraciones_solicitudes              ins
JOIN  modulo7.clientes_externos                     ce      ON ce.id_cliente_externo        = ins.id_cliente_externo
LEFT JOIN modulo7.versiones_contrato_aaef           vc      ON vc.id_version_contrato_aaef  = ins.id_version_contrato
LEFT JOIN modulo7.registros_ejecucion_mapeador      rem     ON rem.id_integracion_solicitud = ins.id_integracion_solicitud
LEFT JOIN modulo7.documentos_generados_aaef         dg      ON dg.id_integracion_solicitud  = ins.id_integracion_solicitud
LEFT JOIN LATERAL (
    SELECT *
    FROM modulo7.notificaciones_weebhook nwi
    WHERE nwi.id_integracion_solicitudes = ins.id_integracion_solicitud
    ORDER BY nwi.fecha_envio DESC
    LIMIT 1
) nw ON true
LEFT JOIN modulo7.catalogo_errores_de_integracion   ce_err  ON ce_err.id_catalogo_error     = ins.id_error
GROUP BY
    ins.id_integracion_solicitud, ins.correlacion_id, ins.estado,
    ins.fecha_comienzoo, ins.fecha_finalizacion, ins.duracion_ms,
    ce.id_cliente_externo, ce.nombre, ce.codigo,
    vc.contrato_version, vc.estado,
    nw.estado_notifiacion, nw.codigo_respuesta, nw.fecha_envio, nw.fecha_recepcion,
    ce_err.codigo, ce_err.mensaje, ce_err.estado_http;

COMMENT ON VIEW modulo7.v_pipeline_solicitud IS
    'Vista transversal: traza el ciclo de vida completo de una solicitud de '
    'integración — cliente → mapeador (pasos) → documentos generados → webhook. '
    'Alimenta los modales de detalle en RF-99 (Detalle de entrega) y RF-102 '
    '(Detalle del evento). Usa LATERAL para traer solo el último webhook.';