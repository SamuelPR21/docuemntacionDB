-- Vistas del modulo 3 (RF-53 a RF-63)

-- Vista base de telemetria del modulo 3: une telemetrias con sensor, dispositivo, variable, infraestructura, finca, activo biologico, conectividad y buffer.
CREATE OR REPLACE VIEW modulo3.vw_m03_telemetria_contextualizada AS
SELECT
    t.id_telemetria,
    t.id_sensor,
    s.nombre AS nombre_sensor,
    s.categoria AS categoria_sensor,
    t.id_dispositivo_iot,
    d.serial AS dispositivo_serial,
    d.descripcion AS dispositivo_nombre,
    t.id_variable,
    va.nombre AS variable_ambiental,
    va.unidad AS unidad_variable,
    CASE
        WHEN va.id_variable_ambiental IN (1, 2, 3, 4, 5, 6, 7, 8) THEN 'HIDRICA'::modulo3.enum_variable_categoria
        ELSE 'AMBIENTAL'::modulo3.enum_variable_categoria
    END AS categoria_variable,
    va.valor_fisico_min,
    va.valor_fisico_max,
    t.valor_crudo,
    t.valor_ajustado,
    COALESCE(t.valor_ajustado, t.valor_crudo) AS valor,
    t.timestamp_captura,
    t.timestamp_envio,
    t.timestamp_procesamiento,
    ROUND(EXTRACT(EPOCH FROM (t.timestamp_procesamiento - t.timestamp_envio)) * 1000)::bigint AS latencia_ms,
    t.origen,
    t.estado_calidad,
    t.calibrado,
    t.metadatos,
    NULLIF(t.metadatos ->> 'ventana_agregacion', '')::integer AS ventana_agregacion,
    COALESCE(saa_hist.id_infraestructura, d.id_infraestructura) AS id_infraestructura,
    COALESCE(i_sensor.nombre, i.nombre) AS infraestructura,
    COALESCE(i_sensor.id_finca, i.id_finca) AS id_finca,
    f.nombre AS finca,
    COALESCE(saa_hist.punto_instalacion, '') AS punto_instalacion,
    abx.id_activo_biologico,
    abx.identificador AS identificador_activo,
    abx.tipo AS tipo_activo,
    abx.estado_activo_biologico,
    abx.especie_activo,
    COALESCE(ec.estado::text, CASE WHEN d.es_activo IS TRUE THEN 'CONECTADO' ELSE 'DESCONECTADO' END) AS estado_conectividad,
    ec.rssi_dbm,
    ec.snr_db,
    ec.gatway_id AS gateway_id,
    COALESCE(buf.total_registros_buffer, 0) AS buffer_total_registros,
    COALESCE(buf.registros_pendientes, 0) AS buffer_registros_pendientes,
    COALESCE(buf.registros_sincronizados, 0) AS buffer_registros_sincronizados,
    buf.ultimo_dato_capturado AS buffer_ultimo_dato_capturado,
    COALESCE(buf.horas_buffer_total, 0) AS buffer_horas_total,
    COALESCE(buf.intentos_sincronizacion_total, 0) AS buffer_intentos_total,
    COALESCE(buf.intentos_sincronizacion_max, 0) AS buffer_intentos_max
FROM modulo3.telemetrias t
JOIN modulo9.sensores s
  ON s.id_sensores = t.id_sensor
JOIN modulo9.dispositivos_iot d
  ON d.id_dispositivo_iot = t.id_dispositivo_iot
JOIN modulo9.variables_ambientales va
  ON va.id_variable_ambiental = t.id_variable
LEFT JOIN LATERAL (
    SELECT
        saa_actual.id_sensores_area_asociada,
        saa_actual.id_infraestructura,
        saa_actual.punto_instalacion
    FROM modulo9.sensores_areas_asociadas saa_actual
    WHERE saa_actual.id_sensor = t.id_sensor
      AND saa_actual.fecha_asociacion <= t.timestamp_captura
      AND (saa_actual.fecha_finalizacion IS NULL OR saa_actual.fecha_finalizacion > t.timestamp_captura)
    ORDER BY saa_actual.fecha_asociacion DESC, saa_actual.id_sensores_area_asociada DESC
    LIMIT 1
) saa_hist ON true
LEFT JOIN modulo9.infraestructuras i_sensor
  ON i_sensor.id_infraestructura = saa_hist.id_infraestructura
LEFT JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = d.id_infraestructura
LEFT JOIN modulo9.fincas f
  ON f.id_finca = COALESCE(i_sensor.id_finca, i.id_finca)
LEFT JOIN LATERAL (
    SELECT
        aas.id_activo_biologico,
        ab.identificador,
        ab.tipo,
        eab.nombre AS estado_activo_biologico,
        esp.nombre AS especie_activo
    FROM modulo2.asociaciones_activos_sensores aas
    LEFT JOIN modulo2.activos_biologicos ab
      ON ab.id_activo_biologico = aas.id_activo_biologico
    LEFT JOIN modulo2.estados_activos_biologicos eab
      ON eab.id_estado_activo_biologico = ab.id_estado
    LEFT JOIN modulo9.especies esp
      ON esp.id_especie = ab.id_especie
    WHERE aas.id_sensor = t.id_sensor
      AND aas.fecha_inicio <= t.timestamp_captura
      AND aas.fecha_fin > t.timestamp_captura
    ORDER BY aas.fecha_inicio DESC, aas.id_asociacion_activo_sensor DESC
    LIMIT 1
) abx ON true
LEFT JOIN LATERAL (
    SELECT
        e.id_estado_conectividad,
        e.estado,
        e.rssi_dbm,
        e.snr_db,
        e.gatway_id
    FROM modulo3.estados_conectividad e
    WHERE e.id_dispositivo_iot = t.id_dispositivo_iot
    ORDER BY e.fecha_registro DESC, e.id_estado_conectividad DESC
    LIMIT 1
) ec ON true
LEFT JOIN LATERAL (
    SELECT
        count(*) AS total_registros_buffer,
        count(*) FILTER (WHERE b.es_sincronizado IS FALSE) AS registros_pendientes,
        count(*) FILTER (WHERE b.es_sincronizado IS TRUE) AS registros_sincronizados,
        max(b.fecha_captura) AS ultimo_dato_capturado,
        COALESCE(sum(COALESCE(b.horas_buffer, 0)), 0) AS horas_buffer_total,
        COALESCE(sum(b.intentos_sincronizacion), 0) AS intentos_sincronizacion_total,
        max(b.intentos_sincronizacion) AS intentos_sincronizacion_max
    FROM modulo3.buffers b
    WHERE b.id_dispositivo = t.id_dispositivo_iot
) buf ON true;

-- Vista base de lecturas de sensores: une lecturas_sensores con sensor, dispositivo, infraestructura, finca, conectividad y ultimo estado MQTT.
CREATE OR REPLACE VIEW modulo3.vw_m03_lectura_contextualizada AS
SELECT
    l.id_lectura_sensor,
    l.id_sensor,
    s.nombre AS nombre_sensor,
    s.es_activo AS sensor_activo,
    l.id_dispositivo_iot,
    d.serial AS dispositivo_serial,
    d.descripcion AS dispositivo_nombre,
    d.id_infraestructura,
    i.nombre AS infraestructura,
    f.id_finca,
    f.nombre AS finca,
    l.valor,
    l.unidad_medida,
    l.origen_procesamiento,
    CASE
        WHEN l.es_valida IS TRUE THEN 'LECTURA_VALIDA'
        ELSE 'NO_VALIDA'
    END AS estado_lectura,
    l.latencia_procesamiento_ms,
    ROUND(EXTRACT(EPOCH FROM (l.fecha_recepcion - l.fecha_captura)) * 1000)::bigint AS latencia_total_ms,
    l.fecha_captura,
    l.fecha_recepcion,
    l.es_valida,
    l.metadata,
    COALESCE(ec.estado::text, CASE WHEN d.es_activo IS TRUE THEN 'CONECTADO' ELSE 'DESCONECTADO' END) AS estado_conectividad,
    ec.rssi_dbm,
    ec.snr_db,
    tm.estado AS estado_transmision_mqtt,
    tm.intentos AS reintentos_mqtt,
    tm.fecha_transmision AS fecha_ultima_transmision
FROM modulo3.lecturas_sensores l
JOIN modulo9.sensores s
  ON s.id_sensores = l.id_sensor
JOIN modulo9.dispositivos_iot d
  ON d.id_dispositivo_iot = l.id_dispositivo_iot
JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        e.estado,
        e.rssi_dbm,
        e.snr_db
    FROM modulo3.estados_conectividad e
    WHERE e.id_dispositivo_iot = l.id_dispositivo_iot
    ORDER BY e.fecha_registro DESC, e.id_estado_conectividad DESC
    LIMIT 1
) ec ON true
LEFT JOIN LATERAL (
    SELECT
        t.estado,
        t.intentos,
        t.fecha_transmision
    FROM modulo3.transmiciones_mqqt t
    WHERE t.id_dispositivo_iot = l.id_dispositivo_iot
    ORDER BY t.fecha_transmision DESC, t.id_transmicion_mqqt DESC
    LIMIT 1
) tm ON true;

-- Vista base de alertas de telemetria: une alertas, reglas, sensor, dispositivo, infraestructura, finca y evento Edge asociado.
CREATE OR REPLACE VIEW modulo3.vw_m03_alerta_contextualizada AS
SELECT
    a.id_alerta_telemetria,
    a.id_regla_alerta,
    ra.nombre AS nombre_alerta,
    ra.descripcion AS descripcion_alerta,
    ra.tipo_sensor,
    ra.nivel_alerta AS nivel_alerta_raw,
    CASE
        WHEN ra.nivel_alerta IN ('CRITICAL', 'EMERGENCY') THEN 'CRITICO'
        WHEN ra.nivel_alerta = 'WARNING' THEN 'MODERADO'
        ELSE 'LEVE'
    END AS nivel_criticidad,
    a.estado AS estado_alerta,
    a.valor_detectado,
    a.mensaje AS mensaje_alerta,
    a.es_generada_edge,
    CASE
        WHEN a.es_generada_edge IS TRUE THEN 'EDGE'
        ELSE 'BACKEND'
    END AS como_se_genera,
    COALESCE(a.fecha_reconocimeinot, a.fecha_creacion) AS fecha_alerta,
    a.latencia_generacion_ms,
    a.reconocida_por,
    a.fecha_reconocimeinot,
    a.fecha_creacion,
    a.id_lectura_sensor,
    a.id_sensor,
    s.nombre AS nombre_sensor,
    s.categoria AS categoria_sensor,
    a.id_dispositivo_iot,
    d.serial AS dispositivo_serial,
    d.descripcion AS dispositivo_nombre,
    d.id_infraestructura,
    i.nombre AS infraestructura,
    f.id_finca,
    f.nombre AS finca,
    eec.id_evento_edge_computing,
    eec.tipo_evento AS tipo_evento_edge,
    CASE
        WHEN eec.cumple_sla IS TRUE THEN 'EXITOSO'
        WHEN eec.cumple_sla IS FALSE THEN 'FALLIDO'
        ELSE NULL
    END AS resultado_evento,
    eec.descripcion AS descripcion_evento,
    eec.latencia_ms AS latencia_evento_ms,
    eec.cumple_sla,
    eec.fecha_registro AS fecha_evento
FROM modulo3.alertas_telemetria a
JOIN modulo3.reglas_alertas ra
  ON ra.id_regla_alertas = a.id_regla_alerta
JOIN modulo9.sensores s
  ON s.id_sensores = a.id_sensor
JOIN modulo9.dispositivos_iot d
  ON d.id_dispositivo_iot = a.id_dispositivo_iot
JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        eec.id_evento_edge_computing,
        eec.tipo_evento,
        eec.descripcion,
        eec.latencia_ms,
        eec.cumple_sla,
        eec.fecha_registro
    FROM modulo3.eventos_edge_computing eec
    WHERE eec.id_alerta_telemetria = a.id_alerta_telemetria
    ORDER BY eec.fecha_registro DESC, eec.id_evento_edge_computing DESC
    LIMIT 1
) eec ON true;

-- Vista base del estado operativo del dispositivo IoT: resume infraestructura, finca, conectividad, buffer, lecturas, telemetrias y transmision MQTT.
CREATE OR REPLACE VIEW modulo3.vw_m03_dispositivo_operacional AS
SELECT
    d.id_dispositivo_iot,
    d.serial AS dispositivo_serial,
    d.descripcion AS dispositivo_nombre,
    d.id_infraestructura,
    i.nombre AS infraestructura,
    f.id_finca,
    f.nombre AS finca,
    COALESCE(ec.estado::text, CASE WHEN d.es_activo IS TRUE THEN 'CONECTADO' ELSE 'DESCONECTADO' END) AS estado_conectividad,
    ec.rssi_dbm,
    ec.snr_db,
    ec.gatway_id AS gateway_id,
    COALESCE(buf.total_registros_buffer, 0) AS total_registros_buffer,
    COALESCE(buf.registros_pendientes, 0) AS registros_pendientes,
    COALESCE(buf.registros_sincronizados, 0) AS registros_sincronizados,
    buf.ultimo_dato_capturado,
    buf.ultima_sincronizacion,
    COALESCE(buf.horas_buffer_total, 0) AS horas_buffer_total,
    COALESCE(buf.intentos_sincronizacion_total, 0) AS intentos_sincronizacion_total,
    COALESCE(buf.intentos_sincronizacion_max, 0) AS intentos_sincronizacion_max,
    COALESCE(tcount.total_telemetrias, 0) AS total_telemetrias,
    COALESCE(lcount.total_lecturas, 0) AS total_lecturas,
    COALESCE(buf.total_registros_buffer, 0) + COALESCE(tcount.total_telemetrias, 0) + COALESCE(lcount.total_lecturas, 0) AS registros_totales,
    tel.id_telemetria AS ultima_telemetria_id,
    tel.id_variable AS id_variable_ultima,
    tel.variable_ambiental AS tipo_variable_ultima,
    tel.valor AS valor_ultimo,
    tel.origen AS origen_ultimo,
    tel.estado_calidad AS estado_ultimo_dato,
    CASE
        WHEN tel.estado_calidad = 'LECTURA_VALIDA' THEN 'LEVE'
        WHEN tel.estado_calidad = 'FUERA_DE_RANGO' THEN 'MODERADO'
        WHEN tel.estado_calidad = 'ERROR_CALIBRACION' THEN 'CRITICO'
        ELSE NULL
    END AS severidad_ultima,
    tel.timestamp_captura AS fecha_ultima_captura,
    tm.estado AS estado_transmision_mqtt,
    tm.intentos AS reintentos_mqtt,
    tm.fecha_transmision AS fecha_ultima_transmision,
    concat_ws(' / ', f.nombre, i.nombre) AS contexto
FROM modulo9.dispositivos_iot d
JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        e.estado,
        e.rssi_dbm,
        e.snr_db,
        e.gatway_id
    FROM modulo3.estados_conectividad e
    WHERE e.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY e.fecha_registro DESC, e.id_estado_conectividad DESC
    LIMIT 1
) ec ON true
LEFT JOIN LATERAL (
    SELECT
        count(*) AS total_registros_buffer,
        count(*) FILTER (WHERE b.es_sincronizado IS FALSE) AS registros_pendientes,
        count(*) FILTER (WHERE b.es_sincronizado IS TRUE) AS registros_sincronizados,
        max(b.fecha_captura) AS ultimo_dato_capturado,
        max(b.fecha_sincronizacion) AS ultima_sincronizacion,
        COALESCE(sum(COALESCE(b.horas_buffer, 0)), 0) AS horas_buffer_total,
        COALESCE(sum(b.intentos_sincronizacion), 0) AS intentos_sincronizacion_total,
        max(b.intentos_sincronizacion) AS intentos_sincronizacion_max
    FROM modulo3.buffers b
    WHERE b.id_dispositivo = d.id_dispositivo_iot
) buf ON true
LEFT JOIN LATERAL (
    SELECT
        count(*) AS total_telemetrias
    FROM modulo3.telemetrias t
    WHERE t.id_dispositivo_iot = d.id_dispositivo_iot
) tcount ON true
LEFT JOIN LATERAL (
    SELECT
        count(*) AS total_lecturas
    FROM modulo3.lecturas_sensores l
    WHERE l.id_dispositivo_iot = d.id_dispositivo_iot
) lcount ON true
LEFT JOIN LATERAL (
    SELECT
        t.id_telemetria,
        t.id_variable,
        va.nombre AS variable_ambiental,
        COALESCE(t.valor_ajustado, t.valor_crudo) AS valor,
        t.origen,
        t.estado_calidad,
        t.timestamp_captura
    FROM modulo3.telemetrias t
    JOIN modulo9.variables_ambientales va
      ON va.id_variable_ambiental = t.id_variable
    WHERE t.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY t.timestamp_captura DESC, t.id_telemetria DESC
    LIMIT 1
) tel ON true
LEFT JOIN LATERAL (
    SELECT
        t.estado,
        t.intentos,
        t.fecha_transmision
    FROM modulo3.transmiciones_mqqt t
    WHERE t.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY t.fecha_transmision DESC, t.id_transmicion_mqqt DESC
    LIMIT 1
) tm ON true;

-- Vista base de activos biologicos con su valor reciente en la infraestructura asociada.
CREATE OR REPLACE VIEW modulo3.vw_m03_activo_biologico_valor_infraestructura AS
SELECT
    ab.id_activo_biologico,
    ab.identificador AS identificador_activo,
    ab.tipo AS tipo_activo,
    e.nombre AS especie,
    eab.nombre AS estado_biologico,
    ab.id_infraestructura,
    i.nombre AS infraestructura,
    f.id_finca,
    f.nombre AS finca,
    tel.id_telemetria AS id_telemetria_ultima,
    tel.tipo_variable,
    tel.valor AS valor_infraestructura,
    tel.timestamp_captura AS fecha_ultima_captura,
    tel.estado_calidad AS estado_ultima_telemetria
FROM modulo2.activos_biologicos ab
JOIN modulo9.especies e
  ON e.id_especie = ab.id_especie
JOIN modulo2.estados_activos_biologicos eab
  ON eab.id_estado_activo_biologico = ab.id_estado
JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        t.id_telemetria,
        va.nombre AS tipo_variable,
        COALESCE(t.valor_ajustado, t.valor_crudo) AS valor,
        t.timestamp_captura,
        t.estado_calidad
    FROM modulo3.telemetrias t
    JOIN modulo9.dispositivos_iot d
      ON d.id_dispositivo_iot = t.id_dispositivo_iot
    JOIN modulo9.variables_ambientales va
      ON va.id_variable_ambiental = t.id_variable
    WHERE d.id_infraestructura = ab.id_infraestructura
    ORDER BY t.timestamp_captura DESC, t.id_telemetria DESC
    LIMIT 1
) tel ON true;


-- 1) Telemetria + sensor + dispositivo + infraestructura + finca + buffer
CREATE OR REPLACE VIEW modulo3.vw_m03_01_telemetria_sensor AS
SELECT
    nombre_sensor,
    variable_ambiental AS variable,
    origen,
    valor,
    estado_calidad,
    latencia_ms,
    timestamp_captura AS momento_captura,
    infraestructura,
    finca,
    buffer_registros_pendientes,
    buffer_horas_total
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 1.1) Tiempo de latencia y tiempos de captura sobre lectura de sensores
CREATE OR REPLACE VIEW modulo3.vw_m03_01_1_latencia_lecturas AS
SELECT
    id_lectura_sensor,
    nombre_sensor,
    dispositivo_nombre,
    infraestructura,
    finca,
    valor,
    unidad_medida,
    origen_procesamiento,
    estado_lectura,
    latencia_procesamiento_ms,
    latencia_total_ms,
    fecha_captura,
    fecha_recepcion,
    estado_conectividad,
    estado_transmision_mqtt,
    reintentos_mqtt
FROM modulo3.vw_m03_lectura_contextualizada;


-- 2) Infraestructura, dispositivo, conexion, edge records y buffer
CREATE OR REPLACE VIEW modulo3.vw_m03_02_buffer_dispositivo_resumen AS
SELECT
    infraestructura,
    dispositivo_nombre AS nombre_dispositivo,
    estado_conectividad AS conexion,
    total_registros_buffer AS cantidad_registros_edge,
    registros_pendientes,
    ultimo_dato_capturado,
    horas_buffer_total AS capacidad_utilizada_horas,
    dispositivo_serial,
    rssi_dbm,
    snr_db,
    gateway_id
FROM modulo3.vw_m03_dispositivo_operacional;


-- 3) Variable, valor, severidad, origen, estado e intentos de sincronizacion
CREATE OR REPLACE VIEW modulo3.vw_m03_03_variable_severidad_origen_estado AS
SELECT
    id_telemetria,
    nombre_sensor,
    variable_ambiental AS variable,
    valor,
    CASE
        WHEN estado_calidad = 'LECTURA_VALIDA' THEN 'LEVE'
        WHEN estado_calidad = 'FUERA_DE_RANGO' THEN 'MODERADO'
        WHEN estado_calidad = 'ERROR_CALIBRACION' THEN 'CRITICO'
        ELSE NULL
    END AS tipo_severidad,
    origen,
    estado_calidad AS estado,
    buffer_intentos_max AS intentos_sincronizacion,
    infraestructura,
    finca,
    timestamp_captura
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 4) Variable min/max, desviacion, categoria, ventana y estado
CREATE OR REPLACE VIEW modulo3.vw_m03_04_variable_min_max_desviacion AS
SELECT
    id_telemetria,
    nombre_sensor,
    variable_ambiental AS variable,
    valor,
    valor_fisico_min AS valor_min,
    valor_fisico_max AS valor_max,
    CASE
        WHEN valor_fisico_min = 0 OR valor_fisico_max = 0 THEN 'ERROR_CONFIGURACION'
        WHEN valor BETWEEN valor_fisico_min AND valor_fisico_max THEN 'NORMAL'
        WHEN valor < valor_fisico_min THEN
            CASE
                WHEN ROUND(((valor_fisico_min - valor) / NULLIF(valor_fisico_min, 0)) * 100, 2) <= 10 THEN 'LEVE'
                WHEN ROUND(((valor_fisico_min - valor) / NULLIF(valor_fisico_min, 0)) * 100, 2) <= 25 THEN 'MODERADO'
                ELSE 'CRITICO'
            END
        ELSE
            CASE
                WHEN ROUND(((valor - valor_fisico_max) / NULLIF(valor_fisico_max, 0)) * 100, 2) <= 10 THEN 'LEVE'
                WHEN ROUND(((valor - valor_fisico_max) / NULLIF(valor_fisico_max, 0)) * 100, 2) <= 25 THEN 'MODERADO'
                ELSE 'CRITICO'
            END
    END AS nivel_desviacion,
    categoria_variable AS categoria,
    ventana_agregacion,
    estado_calidad AS estado,
    ROUND(
        CASE
            WHEN valor_fisico_min = 0 OR valor_fisico_max = 0 THEN 0
            WHEN valor BETWEEN valor_fisico_min AND valor_fisico_max THEN 0
            WHEN valor < valor_fisico_min THEN ((valor_fisico_min - valor) / NULLIF(valor_fisico_min, 0)) * 100
            ELSE ((valor - valor_fisico_max) / NULLIF(valor_fisico_max, 0)) * 100
        END
    , 2) AS desviacion_pct,
    timestamp_captura
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 5) Nombre del dispositivo, contexto, tipo de variable, registros, severidad, origen, estado, reintentos, estado
CREATE OR REPLACE VIEW modulo3.vw_m03_05_dispositivo_contexto_operacion AS
SELECT
    dispositivo_nombre,
    contexto,
    tipo_variable_ultima AS tipo_variable,
    registros_totales AS registros,
    severidad_ultima AS severidad,
    origen_ultimo AS origen,
    estado_ultimo_dato AS estado_dato,
    reintentos_mqtt AS reintentos,
    estado_conectividad AS estado_conexion,
    estado_transmision_mqtt,
    fecha_ultima_captura,
    fecha_ultima_transmision
FROM modulo3.vw_m03_dispositivo_operacional;


-- 6) Alertas telemetria, nombre de alerta, infraestructura, estado, nivel de criticidad, valor, como se genera, fecha
CREATE OR REPLACE VIEW modulo3.vw_m03_06_alertas_telemetria AS
SELECT
    id_alerta_telemetria,
    nombre_alerta,
    infraestructura,
    estado_alerta,
    nivel_criticidad,
    valor_detectado,
    como_se_genera,
    fecha_alerta,
    finca,
    nombre_sensor,
    dispositivo_nombre
FROM modulo3.vw_m03_alerta_contextualizada;


-- 7) Tipo de variable con su valor de la infraestructura asociada
CREATE OR REPLACE VIEW modulo3.vw_m03_07_variable_valor_infraestructura AS
SELECT
    id_telemetria,
    variable_ambiental AS tipo_variable,
    valor,
    infraestructura,
    finca,
    timestamp_captura,
    estado_calidad
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 8) Estado biologico con su valor de la infraestructura asociada
CREATE OR REPLACE VIEW modulo3.vw_m03_08_estado_biologico_valor_infraestructura AS
SELECT
    id_activo_biologico,
    identificador_activo,
    especie,
    estado_biologico,
    infraestructura,
    tipo_variable,
    valor_infraestructura,
    fecha_ultima_captura,
    estado_ultima_telemetria,
    finca
FROM modulo3.vw_m03_activo_biologico_valor_infraestructura;


-- 9) Historial completo de una variable sobre una infraestructura
CREATE OR REPLACE VIEW modulo3.vw_m03_09_historial_variable_infraestructura AS
SELECT
    id_telemetria,
    nombre_sensor,
    dispositivo_nombre,
    variable_ambiental AS variable,
    valor,
    origen,
    estado_calidad,
    timestamp_captura,
    timestamp_envio,
    timestamp_procesamiento,
    infraestructura,
    finca,
    id_sensor,
    id_dispositivo_iot
FROM modulo3.vw_m03_telemetria_contextualizada;


-- 10) Alertas con nombre del dispositivo IoT
CREATE OR REPLACE VIEW modulo3.vw_m03_10_alertas_dispositivo_iot AS
SELECT
    id_alerta_telemetria,
    nombre_alerta,
    dispositivo_nombre,
    dispositivo_serial,
    infraestructura,
    estado_alerta,
    nivel_criticidad,
    valor_detectado,
    como_se_genera,
    fecha_alerta,
    nombre_sensor,
    finca
FROM modulo3.vw_m03_alerta_contextualizada;


-- 11) Lecturas de sensores, dispositivo IoT, infraestructura, estado y mecanismos
CREATE OR REPLACE VIEW modulo3.vw_m03_11_lecturas_sensores_mecanismos AS
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
    origen_procesamiento AS mecanismo,
    estado_conectividad,
    estado_transmision_mqtt,
    reintentos_mqtt,
    fecha_captura,
    fecha_recepcion,
    latencia_procesamiento_ms,
    latencia_total_ms
FROM modulo3.vw_m03_lectura_contextualizada;


-- 12) Estado del sensor con las lecturas que ha capturado
CREATE OR REPLACE VIEW modulo3.vw_m03_12_estado_sensor_con_lecturas AS
SELECT
    id_lectura_sensor,
    nombre_sensor,
    sensor_activo AS estado_sensor,
    dispositivo_nombre,
    infraestructura,
    finca,
    valor,
    unidad_medida,
    estado_lectura AS estado_lectura,
    origen_procesamiento AS mecanismo,
    fecha_captura,
    fecha_recepcion
FROM modulo3.vw_m03_lectura_contextualizada;


-- 13) Alertas: nivel de alerta, resultado, severidad y tipo de evento
CREATE OR REPLACE VIEW modulo3.vw_m03_13_alertas_nivel_resultado_severidad_evento AS
SELECT
    id_alerta_telemetria,
    nombre_alerta,
    nivel_alerta_raw AS nivel_alerta,
    CASE
        WHEN resultado_evento IS NOT NULL THEN resultado_evento
        WHEN estado_alerta = 'LECTURA_VALIDA' THEN 'EXITOSO'
        ELSE 'FALLIDO'
    END AS resultado,
    nivel_criticidad AS severidad,
    tipo_evento_edge AS tipo_evento,
    fecha_evento,
    dispositivo_nombre,
    infraestructura
FROM modulo3.vw_m03_alerta_contextualizada;


-- Documentacion de vistas del modulo 3.
-- Cada bloque describe la vista justo antes de su definicion.
