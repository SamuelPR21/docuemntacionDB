-- Vistas del modulo 3 (RF-53 a RF-63)
-- Ajustadas al esquema actual del backup_ultima.sql.

-- Base RF-53/RF-61: telemetria con sensor, dispositivo, variable, infraestructura,
-- finca, vinculacion biologica, conectividad, buffer y red.
CREATE OR REPLACE VIEW modulo3.vw_m03_telemetria_contextualizada AS
SELECT
    t.id_telemetria,
    t.id_sensor,
    s.nombre AS nombre_sensor,
    s.categoria::text AS categoria_sensor,
    s.es_activo AS sensor_activo,
    t.id_dispositivo_iot,
    d.serial AS dispositivo_serial,
    d.descripcion AS dispositivo_nombre,
    d.es_activo AS dispositivo_activo,
    t.id_variable,
    va.nombre AS variable_ambiental,
    va.unidad AS unidad_variable,
    va.valor_fisico_min,
    va.valor_fisico_max,
    t.categoria_variable::text AS categoria_variable,
    t.unidad_medida,
    t.valor_crudo,
    t.valor_ajustado,
    COALESCE(t.valor_ajustado, t.valor_crudo) AS valor,
    t.calibrado,
    t.version_calibracion,
    t.parametros_calibracion,
    t.timestamp_captura,
    t.timestamp_envio,
    t.timestamp_procesamiento,
    CASE
        WHEN t.timestamp_envio IS NULL THEN NULL
        ELSE ROUND(EXTRACT(EPOCH FROM (t.timestamp_envio - t.timestamp_captura)) * 1000)::bigint
    END AS latencia_transmision_ms,
    CASE
        WHEN t.latencia_procesamiento_ms IS NOT NULL THEN t.latencia_procesamiento_ms::bigint
        WHEN t.timestamp_envio IS NOT NULL THEN ROUND(EXTRACT(EPOCH FROM (t.timestamp_procesamiento - t.timestamp_envio)) * 1000)::bigint
        ELSE ROUND(EXTRACT(EPOCH FROM (t.timestamp_procesamiento - t.timestamp_captura)) * 1000)::bigint
    END AS latencia_procesamiento_ms,
    ROUND(EXTRACT(EPOCH FROM (t.timestamp_procesamiento - t.timestamp_captura)) * 1000)::bigint AS latencia_total_ms,
    t.origen::text AS origen,
    t.estado_calidad::text AS estado_calidad,
    t.tipo_dato::text AS tipo_dato,
    t.valor_agregado,
    t.ventana_agregacion_min,
    t.latitud,
    t.longitud,
    t.metadatos,
    t.latencia_alta,
    t.frecuencia_anomala,
    t.posible_drift,
    t.dato_buferizado AS dato_bufferizado,
    t.dato_agredado_edge AS dato_agregado_edge,
    t.reloj_desincronizado,
    t.nivel_bateria_pct,
    t.calidad_senal_rssi,
    t.calidad_senal_snr,
    t.frecuencia_muestreo_min,
    t.estado_conectividad,
    vl.id_vinculacion_lectura,
    vl.modelo_manejo::text AS modelo_manejo,
    vl.estado_vinculacion::text AS estado_vinculacion,
    vl.mecanismo_vinculacion::text AS mecanismo_vinculacion,
    COALESCE(vl.id_infraestructura, saa.id_infraestructura, ab.id_infraestructura) AS id_infraestructura,
    i.nombre AS infraestructura,
    i.tipo::text AS tipo_infraestructura,
    i.id_finca,
    f.nombre AS finca,
    saa.punto_instalacion,
    vl.id_activo_biologico,
    ab.identificador AS identificador_activo,
    ab.tipo::text AS tipo_activo,
    eab.nombre AS estado_activo_biologico,
    esp.nombre AS especie_activo,
    edi.estado_actual::text AS estado_dispositivo,
    edi.fecha_ultimo_contacto,
    edi.tiempo_sin_contacto,
    edi.causa_primaria::text AS causa_inactividad,
    mqtt.estado_transmision_mqtt,
    mqtt.reintentos_mqtt,
    mqtt.gateway_id,
    COALESCE(buf.total_registros_buffer, 0) AS buffer_total_registros,
    COALESCE(buf.registros_pendientes, 0) AS buffer_registros_pendientes,
    COALESCE(buf.registros_confirmados, 0) AS buffer_registros_confirmados,
    buf.ultimo_dato_capturado AS buffer_ultimo_dato_capturado,
    COALESCE(buf.horas_buffer_trabajadas, 0) AS buffer_horas_trabajadas,
    COALESCE(buf.intentos_sincronizacion_total, 0) AS buffer_intentos_total,
    COALESCE(buf.intentos_sincronizacion_max, 0) AS buffer_intentos_max
FROM modulo3.telemetrias t
LEFT JOIN modulo9.sensores s
  ON s.id_sensores = t.id_sensor
LEFT JOIN modulo9.dispositivos_iot d
  ON d.id_dispositivo_iot = t.id_dispositivo_iot
LEFT JOIN modulo9.variables_ambientales va
  ON va.id_variable_ambiental = t.id_variable
LEFT JOIN LATERAL (
    SELECT
        v.id_vinculacion_lectura,
        v.id_activo_biologico,
        v.id_infraestructura,
        v.modelo_manejo,
        v.estado_vinculacion,
        v.mecanismo_vinculacion
    FROM modulo3.vinculaciones_lecturas v
    WHERE v.id_telemetria = t.id_telemetria
    ORDER BY v.fecha_creacion DESC, v.id_vinculacion_lectura DESC
    LIMIT 1
) vl ON true
LEFT JOIN modulo2.activos_biologicos ab
  ON ab.id_activo_biologico = vl.id_activo_biologico
LEFT JOIN modulo2.estados_activos_biologicos eab
  ON eab.id_estado_activo_biologico = ab.id_estado
LEFT JOIN modulo9.especies esp
  ON esp.id_especie = ab.id_especie
LEFT JOIN LATERAL (
    SELECT
        a.id_infraestructura,
        a.punto_instalacion
    FROM modulo9.sensores_areas_asociadas a
    WHERE a.id_sensor = t.id_sensor
      AND a.fecha_asociacion <= t.timestamp_captura
      AND (a.fecha_finalizacion IS NULL OR a.fecha_finalizacion > t.timestamp_captura)
    ORDER BY a.fecha_asociacion DESC, a.id_sensores_area_asociada DESC
    LIMIT 1
) saa ON true
LEFT JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = COALESCE(vl.id_infraestructura, saa.id_infraestructura, ab.id_infraestructura)
LEFT JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        e.estado_actual,
        e.fecha_ultimo_contacto,
        e.tiempo_sin_contacto,
        e.causa_primaria
    FROM modulo3.estados_dispositivos_iot e
    WHERE e.id_dispositivo_iot = t.id_dispositivo_iot
    ORDER BY e.fecha_ultima_actualizacion DESC, e.id_estado_dispositivo_iot DESC
    LIMIT 1
) edi ON true
LEFT JOIN LATERAL (
    SELECT
        tm.estado::text AS estado_transmision_mqtt,
        tm.intentos AS reintentos_mqtt,
        tm.gatway_id AS gateway_id
    FROM modulo3.transmisiones_mqtt tm
    WHERE tm.id_dispositivo_iot = t.id_dispositivo_iot
      AND tm.fecha_transmision <= t.timestamp_procesamiento
    ORDER BY tm.fecha_transmision DESC, tm.id_transmicion_mqqt DESC
    LIMIT 1
) mqtt ON true
LEFT JOIN LATERAL (
    SELECT
        count(*) AS total_registros_buffer,
        count(*) FILTER (WHERE b.estado_buffer::text IN ('PENDIENTE', 'ERROR')) AS registros_pendientes,
        count(*) FILTER (WHERE b.estado_buffer::text = 'CONFIRMADO') AS registros_confirmados,
        max(b.fecha_captura) AS ultimo_dato_capturado,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (max(b.fecha_captura) - min(b.fecha_captura))) / 3600.0, 2), 0) AS horas_buffer_trabajadas,
        COALESCE(sum(b.intentos_envio), 0) AS intentos_sincronizacion_total,
        COALESCE(max(b.intentos_envio), 0) AS intentos_sincronizacion_max
    FROM modulo3.buffers b
    WHERE b.id_dispositivo_iot = t.id_dispositivo_iot
) buf ON true;


-- Alias operacional de lecturas; mantiene nombres orientados a consulta.
CREATE OR REPLACE VIEW modulo3.vw_m03_lectura_contextualizada AS
SELECT
    id_telemetria AS id_lectura_sensor,
    id_telemetria,
    id_sensor,
    nombre_sensor,
    sensor_activo,
    id_dispositivo_iot,
    dispositivo_nombre,
    dispositivo_serial,
    id_infraestructura,
    infraestructura,
    id_finca,
    finca,
    id_variable,
    variable_ambiental,
    categoria_variable,
    valor,
    valor_crudo,
    valor_ajustado,
    unidad_medida,
    estado_calidad AS estado_lectura,
    origen AS origen_procesamiento,
    tipo_dato AS mecanismo_dato,
    estado_conectividad,
    estado_dispositivo,
    estado_transmision_mqtt,
    reintentos_mqtt,
    timestamp_captura AS fecha_captura,
    timestamp_envio AS fecha_envio,
    timestamp_procesamiento AS fecha_recepcion,
    latencia_transmision_ms,
    latencia_procesamiento_ms,
    latencia_total_ms,
    estado_vinculacion,
    mecanismo_vinculacion
FROM modulo3.vw_m03_telemetria_contextualizada;


-- Resumen operacional por dispositivo IoT, buffer y conectividad.
CREATE OR REPLACE VIEW modulo3.vw_m03_dispositivo_operacional AS
SELECT
    d.id_dispositivo_iot,
    d.serial AS dispositivo_serial,
    d.descripcion AS dispositivo_nombre,
    d.es_activo AS dispositivo_activo,
    COALESCE(infra_sensor.id_infraestructura, infra_activo.id_infraestructura) AS id_infraestructura,
    i.nombre AS infraestructura,
    i.id_finca,
    f.nombre AS finca,
    COALESCE(edi.estado_actual::text, CASE WHEN d.es_activo THEN 'ACTIVO' ELSE 'INACTIVO' END) AS conexion,
    edi.fecha_ultimo_contacto,
    hb.fecha_recepcion AS fecha_ultimo_heartbeat,
    hb.nivel_bateria_pct,
    hb.calidad_senal_rssi,
    hb.calidad_senal_snr,
    hb.reloj_sincronizado,
    tx.estado_transmision_mqtt,
    tx.reintentos_mqtt,
    COALESCE(sensores.total_sensores, 0) AS total_sensores,
    COALESCE(edge.total_registros_buffer, 0) AS cantidad_registros_edge,
    COALESCE(edge.registros_evento_edge, 0) AS registros_evento_edge,
    COALESCE(edge.registros_pendientes, 0) AS registros_pendientes,
    COALESCE(edge.registros_confirmados, 0) AS registros_confirmados,
    COALESCE(edge.registros_error, 0) AS registros_error,
    COALESCE(edge.intentos_sincronizacion_total, 0) AS intentos_sincronizacion_total,
    COALESCE(edge.intentos_sincronizacion_max, 0) AS intentos_sincronizacion_max,
    CASE
        WHEN edge.ultimo_buffer_capturado IS NULL AND tel.ultimo_telemetria_capturada IS NULL THEN NULL
        ELSE GREATEST(COALESCE(edge.ultimo_buffer_capturado, '-infinity'::timestamp with time zone),
                      COALESCE(tel.ultimo_telemetria_capturada, '-infinity'::timestamp with time zone))
    END AS ultimo_dato_capturado,
    CASE
        WHEN edge.ultimo_buffer_capturado IS NULL AND tel.ultimo_telemetria_capturada IS NULL THEN NULL
        ELSE COALESCE(edge.ultimo_valor_buffer, tel.ultimo_valor_telemetria)
    END AS ultimo_valor_capturado,
    COALESCE(edge.horas_buffer_trabajadas, 0) AS capacidad_utilizada_horas_buffer
FROM modulo9.dispositivos_iot d
LEFT JOIN LATERAL (
    SELECT count(*) AS total_sensores
    FROM modulo9.sensores s
    WHERE s.id_dispositivo_iot = d.id_dispositivo_iot
) sensores ON true
LEFT JOIN LATERAL (
    SELECT a.id_infraestructura
    FROM modulo9.sensores_areas_asociadas a
    WHERE a.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY (a.fecha_finalizacion IS NULL) DESC, a.fecha_asociacion DESC, a.id_sensores_area_asociada DESC
    LIMIT 1
) infra_sensor ON true
LEFT JOIN LATERAL (
    SELECT ab.id_infraestructura
    FROM modulo2.activos_biologicos ab
    WHERE ab.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY ab.fecha_creacion DESC, ab.id_activo_biologico DESC
    LIMIT 1
) infra_activo ON true
LEFT JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = COALESCE(infra_sensor.id_infraestructura, infra_activo.id_infraestructura)
LEFT JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        e.estado_actual,
        e.fecha_ultimo_contacto
    FROM modulo3.estados_dispositivos_iot e
    WHERE e.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY e.fecha_ultima_actualizacion DESC, e.id_estado_dispositivo_iot DESC
    LIMIT 1
) edi ON true
LEFT JOIN LATERAL (
    SELECT
        h.fecha_recepcion,
        h.nivel_bateria_pct,
        h.calidad_senal_rssi,
        h.calidad_senal_snr,
        h.reloj_sincronizado
    FROM modulo3.heartbeats h
    WHERE h.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY h.fecha_recepcion DESC, h.id_heartbeat DESC
    LIMIT 1
) hb ON true
LEFT JOIN LATERAL (
    SELECT
        tm.estado::text AS estado_transmision_mqtt,
        tm.intentos AS reintentos_mqtt
    FROM modulo3.transmisiones_mqtt tm
    WHERE tm.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY tm.fecha_transmision DESC, tm.id_transmicion_mqqt DESC
    LIMIT 1
) tx ON true
LEFT JOIN LATERAL (
    SELECT
        count(*) AS total_registros_buffer,
        count(*) FILTER (WHERE b.tipo_dato::text = 'EVENTO_EDGE') AS registros_evento_edge,
        count(*) FILTER (WHERE b.estado_buffer::text IN ('PENDIENTE', 'ERROR')) AS registros_pendientes,
        count(*) FILTER (WHERE b.estado_buffer::text = 'CONFIRMADO') AS registros_confirmados,
        count(*) FILTER (WHERE b.estado_buffer::text = 'ERROR') AS registros_error,
        COALESCE(sum(b.intentos_envio), 0) AS intentos_sincronizacion_total,
        COALESCE(max(b.intentos_envio), 0) AS intentos_sincronizacion_max,
        max(b.fecha_captura) AS ultimo_buffer_capturado,
        (array_agg((b.payload_raw ->> 'valor')::numeric ORDER BY b.fecha_captura DESC, b.id_buffer DESC)
            FILTER (WHERE (b.payload_raw ->> 'valor') ~ '^-?[0-9]+(\.[0-9]+)?$'))[1] AS ultimo_valor_buffer,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (max(b.fecha_captura) - min(b.fecha_captura))) / 3600.0, 2), 0) AS horas_buffer_trabajadas
    FROM modulo3.buffers b
    WHERE b.id_dispositivo_iot = d.id_dispositivo_iot
) edge ON true
LEFT JOIN LATERAL (
    SELECT
        max(t.timestamp_captura) AS ultimo_telemetria_capturada,
        (array_agg(COALESCE(t.valor_ajustado, t.valor_crudo) ORDER BY t.timestamp_captura DESC, t.id_telemetria DESC))[1] AS ultimo_valor_telemetria
    FROM modulo3.telemetrias t
    WHERE t.id_dispositivo_iot = d.id_dispositivo_iot
) tel ON true;


-- Alertas con fuente de generacion, telemetria, evento edge, inferencia y contexto.
CREATE OR REPLACE VIEW modulo3.vw_m03_alerta_contextualizada AS
SELECT
    a.id_alerta AS id_alerta_telemetria,
    a.id_alerta,
    COALESCE(ra.nombre, a.tipo_alerta::text) AS nombre_alerta,
    a.tipo_alerta::text AS tipo_alerta,
    a.tipo_variable,
    a.estado_alerta::text AS estado_alerta,
    a.severidad::text AS nivel_criticidad,
    a.origen_evento::text AS origen_evento,
    COALESCE(tctx.valor, ee.valor_evaluado, pi.valor_numerico) AS valor_detectado,
    CASE
        WHEN a.origen_evento::text = 'EDGE' THEN 'EDGE'
        WHEN a.origen_evento::text = 'IA' THEN 'IA'
        WHEN a.origen_evento::text = 'BACKEND' THEN 'BACKEND'
        WHEN a.id_evento_edge_computing IS NOT NULL THEN 'EDGE'
        WHEN a.id_paquete_inferencia IS NOT NULL THEN 'IA'
        ELSE 'BACKEND'
    END AS como_se_genera,
    COALESCE(a.fecha_evento, ee.fecha_captura, tctx.timestamp_captura, pi.fecha_envio, a.fecha_registro) AS fecha_alerta,
    COALESCE(a.fecha_evento, ee.fecha_captura, tctx.timestamp_captura, pi.fecha_envio, a.fecha_registro) AS fecha_evento,
    a.fecha_generacion,
    a.fecha_notificacion,
    a.fecha_atencion,
    a.fecha_resolucion,
    a.fecha_vencimiento,
    a.id_regla_alerta,
    ra.nombre AS nombre_regla,
    ra.es_regla_compuesta,
    a.id_evento_edge_computing,
    ee.tipo_evento::text AS tipo_evento_edge,
    ee.severidad::text AS severidad_edge,
    a.id_telemetria,
    a.id_paquete_inferencia,
    pi.estado_paquete::text AS estado_paquete_inferencia,
    pi.intento_envios AS intentos_inferencia,
    COALESCE(a.id_sensor, tctx.id_sensor, ee.id_sensor, pi.id_sensor) AS id_sensor,
    COALESCE(tctx.nombre_sensor, s.nombre) AS nombre_sensor,
    COALESCE(a.id_dispositivo_ioit, tctx.id_dispositivo_iot, ee.id_dispositivo_iot, pi.id_dispositivo_iot) AS id_dispositivo_iot,
    COALESCE(tctx.dispositivo_nombre, d.descripcion) AS dispositivo_nombre,
    COALESCE(tctx.dispositivo_serial, d.serial) AS dispositivo_serial,
    COALESCE(a.id_infraestructura, tctx.id_infraestructura, saa.id_infraestructura, ab.id_infraestructura) AS id_infraestructura,
    i.nombre AS infraestructura,
    i.id_finca,
    f.nombre AS finca,
    COALESCE(a.id_activo_biologico, tctx.id_activo_biologico) AS id_activo_biologico,
    ab.identificador AS identificador_activo,
    a.conflicto_resolucion::text AS conflicto_resolucion,
    a.severidad_edge_original::text AS severidad_edge_original,
    a.serveridad_ia::text AS severidad_ia,
    a.tipo_edge_original::text AS tipo_edge_original,
    a.tipo_ia_original::text AS tipo_ia_original,
    a.diagnostico,
    a.motivo_descarte,
    a.accion_sugerida,
    a.metadato_evento,
    CASE a.estado_alerta::text
        WHEN 'RESUELTA' THEN 'EXITOSO'
        WHEN 'DESCARTADA' THEN 'RECHAZADO'
        WHEN 'VENCIDA' THEN 'FALLIDO'
        WHEN 'EN_ATENCION' THEN 'PARCIAL'
        ELSE 'ADVERTENCIA'
    END AS resultado_evento,
    a.tipo_alerta::text AS nivel_alerta_raw
FROM modulo3.alertas a
LEFT JOIN modulo3.vw_m03_telemetria_contextualizada tctx
  ON tctx.id_telemetria = a.id_telemetria
LEFT JOIN modulo3.eventos_edge_computing ee
  ON ee.id_evento_edge_computing = a.id_evento_edge_computing
LEFT JOIN modulo3.paquetes_inferencia pi
  ON pi.id_paquetes_inferencia = a.id_paquete_inferencia
LEFT JOIN modulo3.reglas_alertas ra
  ON ra.id_regla_alertas = a.id_regla_alerta
LEFT JOIN modulo9.sensores s
  ON s.id_sensores = COALESCE(a.id_sensor, tctx.id_sensor, ee.id_sensor, pi.id_sensor)
LEFT JOIN modulo9.dispositivos_iot d
  ON d.id_dispositivo_iot = COALESCE(a.id_dispositivo_ioit, tctx.id_dispositivo_iot, ee.id_dispositivo_iot, pi.id_dispositivo_iot)
LEFT JOIN LATERAL (
    SELECT x.id_infraestructura
    FROM modulo9.sensores_areas_asociadas x
    WHERE x.id_sensor = COALESCE(a.id_sensor, tctx.id_sensor, ee.id_sensor, pi.id_sensor)
      AND x.fecha_asociacion <= COALESCE(a.fecha_evento, ee.fecha_captura, tctx.timestamp_captura, pi.fecha_envio, a.fecha_registro)
      AND (x.fecha_finalizacion IS NULL OR x.fecha_finalizacion > COALESCE(a.fecha_evento, ee.fecha_captura, tctx.timestamp_captura, pi.fecha_envio, a.fecha_registro))
    ORDER BY x.fecha_asociacion DESC, x.id_sensores_area_asociada DESC
    LIMIT 1
) saa ON true
LEFT JOIN modulo2.activos_biologicos ab
  ON ab.id_activo_biologico = COALESCE(a.id_activo_biologico, tctx.id_activo_biologico)
LEFT JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = COALESCE(a.id_infraestructura, tctx.id_infraestructura, saa.id_infraestructura, ab.id_infraestructura)
LEFT JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca;


-- Activos biologicos con los valores de telemetria asociados a su infraestructura.
CREATE OR REPLACE VIEW modulo3.vw_m03_activo_biologico_valor_infraestructura AS
SELECT
    t.id_telemetria,
    t.id_activo_biologico,
    t.identificador_activo,
    t.tipo_activo,
    t.especie_activo AS especie,
    t.estado_activo_biologico AS estado_biologico,
    t.id_infraestructura,
    t.infraestructura,
    t.id_finca,
    t.finca,
    t.variable_ambiental AS tipo_variable,
    t.valor AS valor_infraestructura,
    t.timestamp_captura AS fecha_ultima_captura,
    t.estado_calidad AS estado_ultima_telemetria,
    t.estado_vinculacion,
    t.mecanismo_vinculacion
FROM modulo3.vw_m03_telemetria_contextualizada t
WHERE t.id_activo_biologico IS NOT NULL;


-- 1) Telemetria, sensor, dispositivo IoT, infraestructura, finca y buffer.
CREATE OR REPLACE VIEW modulo3.vw_m03_01_monitor_ingesta AS
SELECT
    id_telemetria,
    nombre_sensor,
    variable_ambiental,
    origen,
    valor,
    valor_crudo,
    valor_ajustado,
    unidad_medida,
    estado_calidad,
    latencia_total_ms AS latencia_ms,
    timestamp_captura AS momento_captura,
    dispositivo_nombre,
    dispositivo_serial,
    infraestructura,
    finca,
    buffer_total_registros,
    buffer_registros_pendientes,
    buffer_ultimo_dato_capturado
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 1.1) Tiempos de captura, envio, procesamiento y latencias.
CREATE OR REPLACE VIEW modulo3.vw_m03_02_monitor_ingesta AS
SELECT
    id_telemetria,
    id_sensor,
    nombre_sensor,
    id_dispositivo_iot,
    dispositivo_nombre,
    variable_ambiental,
    timestamp_captura,
    timestamp_envio,
    timestamp_procesamiento,
    latencia_transmision_ms,
    latencia_procesamiento_ms,
    latencia_total_ms,
    latencia_alta,
    origen,
    estado_calidad
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 2) Infraestructura, dispositivo, conexion, Edge y buffer.
CREATE OR REPLACE VIEW modulo3.vw_m03_01_buffer_sincronizacion AS
SELECT
    id_infraestructura,
    infraestructura,
    finca,
    id_dispositivo_iot,
    dispositivo_nombre,
    dispositivo_serial,
    conexion,
    estado_transmision_mqtt,
    cantidad_registros_edge,
    registros_evento_edge,
    registros_pendientes,
    registros_confirmados,
    registros_error,
    ultimo_dato_capturado,
    ultimo_valor_capturado,
    capacidad_utilizada_horas_buffer,
    intentos_sincronizacion_total,
    intentos_sincronizacion_max,
    nivel_bateria_pct,
    calidad_senal_rssi,
    calidad_senal_snr,
    reloj_sincronizado
FROM modulo3.vw_m03_dispositivo_operacional;


-- 3) Variable, valor, severidad, origen, estado e intentos de sincronizacion.
CREATE OR REPLACE VIEW modulo3.vw_m03_02_buffer_sincronizacion  AS
SELECT
    pi.id_paquetes_inferencia,
    pi.id_sensor,
    s.nombre AS nombre_sensor,
    pi.id_dispositivo_iot,
    d.descripcion AS dispositivo_nombre,
    pi.tipo_variable AS variable,
    pi.valor_numerico AS valor,
    pi.unidad,
    pi.severidad::text AS tipo_severidad,
    pi.origen::text AS origen,
    pi.estado_calidad::text AS estado_calidad,
    pi.estado_desviacion::text AS estado_desviacion,
    pi.estado_paquete::text AS estado,
    pi.intento_envios AS intentos_sincronizacion,
    pi.fecha_envio
FROM modulo3.paquetes_inferencia pi
LEFT JOIN modulo9.sensores s
  ON s.id_sensores = pi.id_sensor
LEFT JOIN modulo9.dispositivos_iot d
  ON d.id_dispositivo_iot = pi.id_dispositivo_iot;


-- 4) Variable, min/max, nivel de desviacion, categoria, ventana y estado.
CREATE OR REPLACE VIEW modulo3.vw_m03_procesamiento_edge AS
WITH base AS (
    SELECT
        id_telemetria,
        id_sensor,
        nombre_sensor,
        id_variable,
        variable_ambiental AS variable,
        categoria_variable AS categoria,
        valor,
        unidad_medida,
        valor_fisico_min AS minimo,
        valor_fisico_max AS maximo,
        ventana_agregacion_min AS ventana,
        estado_calidad AS estado,
        CASE
            WHEN valor_fisico_min IS NULL OR valor_fisico_max IS NULL THEN NULL
            WHEN valor < valor_fisico_min AND NULLIF(ABS(valor_fisico_min), 0) IS NOT NULL
                THEN ROUND(((valor_fisico_min - valor) / NULLIF(ABS(valor_fisico_min), 0)) * 100, 2)
            WHEN valor > valor_fisico_max AND NULLIF(ABS(valor_fisico_max), 0) IS NOT NULL
                THEN ROUND(((valor - valor_fisico_max) / NULLIF(ABS(valor_fisico_max), 0)) * 100, 2)
            WHEN valor < valor_fisico_min OR valor > valor_fisico_max THEN NULL
            ELSE 0
        END AS desviacion_pct
    FROM modulo3.vw_m03_telemetria_contextualizada
)
SELECT
    id_telemetria,
    id_sensor,
    nombre_sensor,
    id_variable,
    variable,
    valor,
    unidad_medida,
    minimo,
    maximo,
    desviacion_pct AS nivel_desviacion_pct,
    CASE
        WHEN minimo IS NULL OR maximo IS NULL THEN 'SIN_RANGO'
        WHEN desviacion_pct IS NULL THEN 'ERROR_CONFIGURACION'
        WHEN desviacion_pct = 0 THEN 'NORMAL'
        WHEN desviacion_pct <= 10 THEN 'LEVE'
        WHEN desviacion_pct <= 25 THEN 'MODERADO'
        ELSE 'CRITICO'
    END AS nivel_desviacion,
    categoria,
    ventana,
    estado AS estado_calidad,
    CASE
        WHEN minimo IS NULL OR maximo IS NULL THEN 'SIN_RANGO'
        WHEN desviacion_pct = 0 THEN 'NORMAL'
        ELSE 'DESVIACION_SIMPLE'
    END AS estado_desviacion
FROM base;


-- 5) Dispositivo IoT, contexto, variable, registros, severidad, origen, estados y reintentos.
CREATE OR REPLACE VIEW modulo3.vw_m03_pipeline_inferencia AS
SELECT
    pi.id_paquetes_inferencia,
    pi.id_dispositivo_iot,
    d.dispositivo_nombre,
    d.dispositivo_serial,
    d.infraestructura,
    d.finca,
    pi.contexto_ambiental AS contexto,
    pi.contexto_incomplento AS contexto_incompleto,
    pi.tipo_variable,
    pi.valor_numerico AS valor,
    count(*) OVER (PARTITION BY pi.id_dispositivo_iot, pi.tipo_variable) AS registros,
    pi.severidad::text AS severidad,
    pi.origen::text AS origen,
    pi.estado_calidad::text AS estado_calidad,
    pi.intento_envios AS reintentos,
    pi.estado_paquete::text AS estado_paquete,
    pi.fecha_envio
FROM modulo3.paquetes_inferencia pi
LEFT JOIN modulo3.vw_m03_dispositivo_operacional d
  ON d.id_dispositivo_iot = pi.id_dispositivo_iot;


-- 6) Alertas de telemetria con infraestructura, estado, criticidad, valor, generacion y fecha.
CREATE OR REPLACE VIEW modulo3.vw_m03_06_alertas_telemetria AS
SELECT
    id_alerta_telemetria,
    nombre_alerta,
    tipo_alerta,
    tipo_variable,
    infraestructura,
    finca,
    estado_alerta,
    nivel_criticidad,
    valor_detectado AS valor,
    como_se_genera,
    fecha_alerta AS fecha,
    nombre_sensor,
    dispositivo_nombre,
    diagnostico,
    accion_sugerida
FROM modulo3.vw_m03_alerta_contextualizada;


-- 7) Tipo de variable con su valor e infraestructura asociada.
CREATE OR REPLACE VIEW modulo3.vw_m03_historial_lecturas AS
SELECT
    id_telemetria,
    id_variable,
    variable_ambiental AS tipo_variable,
    valor,
    unidad_medida,
    id_infraestructura,
    infraestructura,
    finca,
    timestamp_captura,
    estado_calidad,
    origen
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 8) Estado biologico con el valor de la infraestructura asociada.
CREATE OR REPLACE VIEW modulo3.vw_m03_estados_dispositivos AS
SELECT
    id_telemetria,
    id_activo_biologico,
    identificador_activo,
    especie,
    estado_biologico,
    id_infraestructura,
    infraestructura,
    finca,
    tipo_variable,
    valor_infraestructura,
    fecha_ultima_captura,
    estado_ultima_telemetria,
    estado_vinculacion,
    mecanismo_vinculacion
FROM modulo3.vw_m03_activo_biologico_valor_infraestructura;


-- 9) Historial filtrable por variable, infraestructura y rango de fechas.
CREATE OR REPLACE VIEW modulo3.vw_m03_calidad_datos_telemetria AS
SELECT
    id_telemetria,
    id_variable,
    variable_ambiental AS variable,
    id_infraestructura,
    infraestructura,
    finca,
    id_sensor,
    nombre_sensor,
    id_dispositivo_iot,
    dispositivo_nombre,
    valor,
    valor_crudo,
    valor_ajustado,
    unidad_medida,
    origen,
    estado_calidad,
    timestamp_captura,
    timestamp_envio,
    timestamp_procesamiento
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 10) Alertas y caracteristicas principales con nombre del dispositivo IoT.
CREATE OR REPLACE VIEW modulo3.vw_m03_01_bitacora_alertas_dispositivo_iot AS
SELECT
    id_alerta_telemetria,
    nombre_alerta,
    tipo_alerta,
    tipo_variable,
    dispositivo_nombre,
    dispositivo_serial,
    infraestructura,
    finca,
    estado_alerta,
    nivel_criticidad,
    valor_detectado,
    como_se_genera,
    fecha_alerta,
    nombre_sensor,
    resultado_evento
FROM modulo3.vw_m03_alerta_contextualizada;


-- 11) Lecturas de sensores, dispositivo IoT, infraestructura, estado y mecanismos.
CREATE OR REPLACE VIEW modulo3.vw_m03_02_bitacora_lecturas_sensores_mecanismos AS
SELECT
    id_lectura_sensor,
    nombre_sensor,
    sensor_activo,
    dispositivo_nombre,
    dispositivo_serial,
    infraestructura,
    finca,
    valor,
    unidad_medida,
    estado_lectura AS estado,
    origen_procesamiento AS mecanismo_origen,
    mecanismo_dato AS mecanismo_dato,
    estado_conectividad,
    estado_dispositivo,
    estado_transmision_mqtt,
    reintentos_mqtt,
    fecha_captura,
    fecha_envio,
    fecha_recepcion,
    latencia_transmision_ms,
    latencia_procesamiento_ms,
    latencia_total_ms,
    estado_vinculacion,
    mecanismo_vinculacion
FROM modulo3.vw_m03_lectura_contextualizada;


-- 12) Estado del sensor con las lecturas capturadas y el estado de cada lectura.
CREATE OR REPLACE VIEW modulo3.vw_m03_03_bitacora_estado_sensor_con_lecturas AS
SELECT
    l.id_lectura_sensor,
    l.id_sensor,
    l.nombre_sensor,
    CASE WHEN l.sensor_activo THEN 'ACTIVO' ELSE 'INACTIVO' END AS estado_sensor,
    eas.estado_semaforo AS estado_semaforo_sensor,
    eas.estado_calidad::text AS estado_calidad_actual_sensor,
    eas.estado_desviacion::text AS estado_desviacion_actual_sensor,
    l.dispositivo_nombre,
    l.infraestructura,
    l.finca,
    l.valor,
    l.unidad_medida,
    l.estado_lectura,
    l.origen_procesamiento AS mecanismo,
    l.fecha_captura,
    l.fecha_recepcion
FROM modulo3.vw_m03_lectura_contextualizada l
LEFT JOIN modulo3.estados_actuales_sensores eas
  ON eas.id_estado_actual_sensor = l.id_sensor
 AND eas.id_dispositivo_iot = l.id_dispositivo_iot;


-- 13) Alertas: nivel de alerta, resultado, severidad y tipo de evento.
CREATE OR REPLACE VIEW modulo3.vw_m03_04_bitacora_alertas_nivel_resultado_severidad_evento AS
SELECT
    id_alerta_telemetria,
    nombre_alerta,
    nivel_alerta_raw AS nivel_alerta,
    resultado_evento AS resultado,
    nivel_criticidad AS severidad,
    COALESCE(tipo_evento_edge, tipo_edge_original, tipo_ia_original, tipo_alerta) AS tipo_evento,
    fecha_evento,
    dispositivo_nombre,
    infraestructura,
    finca
FROM modulo3.vw_m03_alerta_contextualizada;
