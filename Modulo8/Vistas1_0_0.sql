-- Configuración de búsqueda para asegurar resolución de esquemas
SET search_path TO modulo8, modulo1, modulo2, modulo3, modulo4, modulo5, modulo6, modulo7, modulo9, public;

-- =============================================================================
-- 1. VISTAS DEL DASHBOARD OPERATIVO (RF-103)
-- =============================================================================

-- 1.1 Estado de alertas (semáforo y conteos)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_alertas_activas AS
SELECT
    COUNT(*) AS total_alertas,
    COUNT(*) FILTER (WHERE severidad IN ('CRITICO')) AS alertas_rojo,
    COUNT(*) FILTER (WHERE severidad = 'MODERADO') AS alertas_amarillo,
    COUNT(*) FILTER (WHERE severidad = 'LEVE') AS alertas_verde
FROM modulo3.alertas
WHERE estado_alerta = 'ACTIVA';

-- 1.2 Inventario biológico por especie y estado
CREATE OR REPLACE VIEW modulo8.vw_dashboard_inventario_biologico AS
SELECT
    e.nombre AS especie,
    COUNT(*) FILTER (WHERE ea.nombre ILIKE '%activo%' OR ea.nombre ILIKE '%vivo%') AS activos,
    COUNT(*) FILTER (WHERE ea.nombre ILIKE '%tratamiento%') AS en_tratamiento,
    COUNT(*) FILTER (WHERE ea.nombre ILIKE '%baja%' OR ea.nombre ILIKE '%muerto%' OR ea.nombre ILIKE '%fa%') AS bajas
FROM modulo2.activos_biologicos ab
JOIN modulo2.estados_activos_biologicos ea ON ab.id_estado = ea.id_estado_activo_biologico
JOIN modulo9.especies e ON ab.id_especie = e.id_especie
WHERE e.es_activo = true
GROUP BY e.nombre;

-- 1.3 Telemetría ambiental (última lectura válida por infraestructura)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_telemetria_ambiental AS
WITH lecturas_recientes AS (
    SELECT 
        t.id_variable, vl.id_infraestructura, t.valor_ajustado, t.estado_calidad,
        ROW_NUMBER() OVER(PARTITION BY t.id_variable, vl.id_infraestructura ORDER BY t.timestamp_captura DESC) as rn
    FROM modulo3.telemetrias t
    JOIN modulo3.vinculaciones_lecturas vl ON t.id_telemetria = vl.id_telemetria
    WHERE t.estado_calidad IN ('LECTURA_VALIDA')
)
SELECT
    i.nombre AS lugar,
    MAX(CASE WHEN va.nombre ILIKE '%temperatura%' THEN lr.valor_ajustado END) AS temp_c,
    MAX(CASE WHEN va.nombre ILIKE '%humedad%' OR va.nombre ILIKE '%hr%' THEN lr.valor_ajustado END) AS humedad_pct,
    CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'SIN DATOS' END AS estado
FROM lecturas_recientes lr
JOIN modulo9.infraestructuras i ON lr.id_infraestructura = i.id_infraestructura
JOIN modulo9.variables_ambientales va ON lr.id_variable = va.id_variable_ambiental
WHERE lr.rn = 1
GROUP BY i.nombre;

-- 1.4 Valor total del inventario (Razonable + Costo)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_valor_inventario AS
SELECT
    COALESCE(SUM(cv.valor_neto), 0) AS valor_razonable,
    COALESCE(SUM(vc.valor_contable_por_costo), 0) AS valor_costo,
    COALESCE(SUM(cv.valor_neto), 0) + COALESCE(SUM(vc.valor_contable_por_costo), 0) AS valor_total_cop,
    CURRENT_DATE AS fecha_valoracion
FROM modulo2.activos_biologicos ab
LEFT JOIN modulo6.calculos_valor_razonable cv 
    ON ab.id_activo_biologico = cv.id_activo_biologico AND cv.estado = 'CALCULADO'
LEFT JOIN modulo6.valoraciones_por_costos vc 
    ON ab.id_activo_biologico = vc.id_activo_biologico AND vc.es_activa = true;

-- 1.5 Conversión alimenticia (último período cerrado)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_conversion_alimenticia AS
SELECT
    ca_calculado AS ratio_kg_kg,
    clasificacion_ca AS estado,
    fecha_fin_periodo
FROM modulo5.resultado_ica
ORDER BY fecha_fin_periodo DESC
LIMIT 1;

-- 1.6 Activos en riesgo alto (modelo predictivo)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_activos_riesgo_alto AS
SELECT
    ab.identificador AS activo_id,
    e.nombre AS especie,
    rrc.nivel_riesgo_contagio AS nivel_riesgo,
    ROUND(rrc.probabilidad_contagio::numeric * 100, 2) AS probabilidad_pct,
    rrc.fecha_calculo
FROM modulo4.resultados_riesgo_contagio rrc
JOIN modulo2.activos_biologicos ab ON rrc.id_activo_biologico = ab.id_activo_biologico
JOIN modulo9.especies e ON ab.id_especie = e.id_especie
WHERE rrc.nivel_riesgo_contagio >= 8
ORDER BY rrc.probabilidad_contagio DESC;

-- 1.7 Distribución de probabilidades (últimos 30 días)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_distribucion_probabilidad AS
SELECT
    COUNT(*) FILTER (WHERE nivel_riesgo >= 8) AS alta,
    COUNT(*) FILTER (WHERE nivel_riesgo BETWEEN 5 AND 7) AS media,
    COUNT(*) FILTER (WHERE nivel_riesgo < 5) AS baja
FROM modulo4.resultados_inferencia
WHERE fecha_inferencia >= CURRENT_DATE - INTERVAL '30 days';

-- 1.8 Retroalimentaciones pendientes (>48h)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_retroalimentaciones_pendientes AS
SELECT
    COUNT(*) AS pendientes,
    MIN(rf.fecha_registro) AS antiguedad_minima
FROM modulo8.retroalimentacion_feedback rf
JOIN modulo8.historiales_clinicos hc ON rf.id_historial_clinico = hc.id_historial_clinicos
WHERE rf.estado = 'PARCIAL'
  AND rf.fecha_registro < CURRENT_TIMESTAMP - INTERVAL '48 hours';

-- 1.9 Alertas patológicas activas
CREATE OR REPLACE VIEW modulo8.vw_dashboard_alertas_patologicas_activas AS
SELECT
    ap.id_alerta_patologica,
    ab.identificador AS activo_id,
    p.nombre AS patologia,
    ap.nivel_criticidad,
    ap.probabilidad_pct,
    ap.fecha_generacion
FROM modulo4.alertas_patologicas ap
JOIN modulo2.activos_biologicos ab ON ap.id_activo_biologico = ab.id_activo_biologico
JOIN modulo9.patologias p ON ap.id_patologia = p.id_patologia
WHERE ap.estado_alerta = 'PENDIENTE'
ORDER BY ap.probabilidad_pct DESC;

-- 1.10 Períodos contables recientes
CREATE OR REPLACE VIEW modulo8.vw_dashboard_periodos_contables AS
SELECT
    id_periodo_contable,
    fecha_inicio AS apertura,
    fecha_fin AS cierre,
    estado,
    fecha_cierre
FROM modulo6.periodos_contables
ORDER BY fecha_inicio DESC
LIMIT 5;

-- 1.11 Activos pendientes de reconocimiento inicial
CREATE OR REPLACE VIEW modulo8.vw_dashboard_reconocimientos_pendientes AS
SELECT COUNT(*) AS pendientes
FROM modulo6.reconocimientos_iniciales
WHERE estado = 'PENDIENTE_CONFIRMACION';

-- 1.12 Exportaciones SIGCON
CREATE OR REPLACE VIEW modulo8.vw_dashboard_exportaciones_sigcon AS
SELECT
    id_integracion_solicitud AS exportacion_id,
    estado,
    CASE WHEN id_error IS NOT NULL THEN 1 ELSE 0 END AS reintentos,
    fecha_comienzoo,
    fecha_finalizacion
FROM modulo7.integraciones_solicitudes
ORDER BY fecha_comienzoo DESC
LIMIT 10;

-- 1.13 Precios próximos a vencer
CREATE OR REPLACE VIEW modulo8.vw_dashboard_precios_proximos_vencer AS
SELECT
    pm.id_precio_mercado,
    e.nombre AS especie,
    pm.precio_unitario,
    pm.unidad_medida,
    pm.fecha_vencimiento
FROM modulo6.precios_mercado pm
JOIN modulo9.especies e ON pm.id_especie = e.id_especie
WHERE pm.fecha_vencimiento IS NOT NULL
  AND pm.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days'
  AND pm.estado = 'ACTIVO'
ORDER BY pm.fecha_vencimiento ASC;

-- 1.14 Estado de dispositivos IoT
CREATE OR REPLACE VIEW modulo8.vw_dashboard_dispositivos_iot_estado AS
SELECT
    d.id_dispositivo_iot,
    d.serial AS dispositivo,
    i.nombre AS lugar,
    edi.estado_actual AS estado,
    edi.fecha_ultimo_contacto AS ult_lectura
FROM modulo9.dispositivos_iot d
JOIN modulo3.estados_dispositivos_iot edi ON d.id_dispositivo_iot = edi.id_dispositivo_iot
LEFT JOIN modulo9.sensores s ON d.id_dispositivo_iot = s.id_dispositivo_iot
LEFT JOIN modulo9.sensores_areas_asociadas saa ON s.id_sensores = saa.id_sensor
LEFT JOIN modulo9.infraestructuras i ON saa.id_infraestructura = i.id_infraestructura
GROUP BY d.id_dispositivo_iot, d.serial, i.nombre, edi.estado_actual, edi.fecha_ultimo_contacto;

-- 1.15 Lecturas en tiempo real (último valor por sensor)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_lecturas_tiempo_real AS
WITH ultimos_datos AS (
    SELECT id_sensor, id_variable, valor_ajustado, estado_calidad,
           ROW_NUMBER() OVER(PARTITION BY id_sensor ORDER BY timestamp_captura DESC) as rn
    FROM modulo3.telemetrias
)
SELECT
    s.nombre AS sensor,
    va.nombre AS tipo,
    ud.valor_ajustado AS valor,
    ud.estado_calidad AS estado
FROM ultimos_datos ud
JOIN modulo9.sensores s ON ud.id_sensor = s.id_sensores
JOIN modulo9.variables_ambientales va ON ud.id_variable = va.id_variable_ambiental
WHERE ud.rn = 1;

-- 1.16 Dispositivos sin heartbeat (>10 min)
CREATE OR REPLACE VIEW modulo8.vw_dashboard_dispositivos_sin_heartbeat AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    MAX(h.fecha_registro) AS ultimo_hearbeat
FROM modulo9.dispositivos_iot d
LEFT JOIN modulo3.heartbeats h ON d.id_dispositivo_iot = h.id_dispositivo_iot
GROUP BY d.id_dispositivo_iot, d.serial
HAVING MAX(h.fecha_registro) IS NULL OR MAX(h.fecha_registro) < CURRENT_TIMESTAMP - INTERVAL '10 minutes';


-- =============================================================================
-- 2. VISTAS DEL HISTORIAL PREDICTIVO (RF-106) & RETROALIMENTACIÓN
-- =============================================================================

-- 2.1 Historial clínico base por activo
CREATE OR REPLACE VIEW modulo8.vw_historial_predictivo_activo AS
SELECT
    hc.id_historial_clinicos,
    hc.id_activo_biologico,
    hc.procentaje_probabilidad,
    hc.nivel_riesgo,
    hc.fecha_inicio,
    hc.fecha_fin,
    hc.modo_visualizacion
FROM modulo8.historiales_clinicos hc;

-- 2.2 Línea de tiempo unificada (Predicciones + Eventos Sanitarios)
CREATE OR REPLACE VIEW modulo8.vw_linea_tiempo_predictiva AS
SELECT
    'PREDICCION' AS tipo_evento,
    r.id_resultado_inferencia::text AS id_referencia,
    r.id_activo_biologico,
    r.nivel_riesgo,
    r.probabilidad_riesgo,
    r.fecha_inferencia AS fecha,
    NULL::text AS observaciones
FROM modulo4.resultados_inferencia r

UNION ALL

SELECT
    'EVENTO_SANITARIO' AS tipo_evento,
    es.id_evento::text AS id_referencia,
    ab.id_activo_biologico,
    0 AS nivel_riesgo,
    NULL::jsonb AS probabilidad_riesgo,
    ea.fecha,
    ea.descripcion AS observaciones
FROM modulo2.eventos_sanitarios es
JOIN modulo2.eventos_activos ea 
    ON es.id_evento = ea.id_eventos
JOIN modulo2.activos_biologicos ab 
    ON ea.id_activo_biologico = ab.id_activo_biologico

ORDER BY fecha DESC;
-- 2.3 Retroalimentaciones contradictorias (tabla del mockup)
CREATE OR REPLACE VIEW modulo8.vw_retroalimentaciones_contradictorias AS
SELECT
    rc.id_retroalimentacion,
    u.nombre || ' ' || u.apellidos AS veterinario,
    CASE 
        WHEN rc.es_conflicto_retroalimentacion THEN 'Conflicto' 
        ELSE rc.estado_registro 
    END AS valoracion,
    rc.fecha_retroalimentacion AS fecha
FROM modulo4.retroalimentaciones_clinicas rc
JOIN modulo1.usuarios u ON rc.id_usuario_veterinario = u.id_usuario
WHERE rc.es_conflicto_retroalimentacion = true
ORDER BY rc.fecha_retroalimentacion DESC;

-- 2.4 Métricas de validación clínica (Tasa de validación)
CREATE OR REPLACE VIEW modulo8.vw_metricas_validacion_predictiva AS
SELECT
    COUNT(*) AS total_retroalimentaciones,
    COUNT(*) FILTER (WHERE estado_registro = 'ACTIVO' AND NOT es_conflicto_retroalimentacion) AS validadas_clinicamente,
    ROUND(
        COUNT(*) FILTER (WHERE estado_registro = 'ACTIVO' AND NOT es_conflicto_retroalimentacion)::numeric / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) AS tasa_validacion_pct
FROM modulo4.retroalimentaciones_clinicas;


