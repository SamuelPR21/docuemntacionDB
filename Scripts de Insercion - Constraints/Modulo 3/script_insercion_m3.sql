-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 3
-- ==============================================================
--
-- TABLAS DEL MÓDULO 3 (verificadas contra backup3_2_2.sql):
--   1. reglas_alertas
--   2. lecturas_sensores
--   3. telemetrias
--   4. buffers
--   5. estados_conectividad
--   6. alertas_telemetria
--   7. eventos_edge_computing
--   8. transmiciones_mqqt
--
-- DEPENDENCIAS (verificadas contra DDL):
--   - modulo9.dispositivos_iot  (ids 1-9)   → varios FK
--   - modulo9.sensores          (ids 1-20)   → varios FK
--   - modulo9.fincas            (id 1)       → reglas_alertas.id_finca
--   - modulo9.variables_ambientales (ids 1-8)→ telemetrias.id_variable
--
-- FKs DEL BACKUP (ya válidas, SIN NOT VALID):
--   fk_alerta_telemetria_lectura_sensor → lecturas_sensores
--   fk_alerta_telemetria_regla          → reglas_alertas
--   fk_alertas_telemetria_dispositivo_iot → modulo9.dispositivos_iot (ON DELETE CASCADE)
--   fk_alertas_telemetria_sensor        → modulo9.sensores (ON DELETE CASCADE)
--   fk_dispositivo_iot_id               → modulo9.dispositivos_iot (lecturas)
--   fk_dispositovo_id                   → modulo9.dispositivos_iot (buffers)
--   fk_estado_conectividad_dispositivo_iot → modulo9.dispositivos_iot
--   fk_evento_edge_computing_alerta_telemetria → alertas_telemetria
--   fk_evento_edge_computing_dispositivo_iot   → modulo9.dispositivos_iot
--   fk_lectura_sensor_dispositivo_iot   → modulo9.dispositivos_iot
--   fk_lectura_sensor_id                → modulo9.sensores
--   fk_sensor_id (telemetrias)          → modulo9.sensores
--   fk_sensor_id (buffers)              → modulo9.sensores
--   fk_transmiciones_mqqt_dispositivo_iot → modulo9.dispositivos_iot
--   fk_variable_id                      → modulo9.variables_ambientales
--   fk_regla_alerta_finca               → modulo9.fincas
--
-- ENUMs DEL MÓDULO 3 (verificar antes de ejecutar):
--   [E1] enum_estados_conectividad_estado:
--        SELECT enum_range(NULL::modulo3.enum_estados_conectividad_estado);
--        Valores: 'CONECTADO','DESCONECTADO','ERROR','SUSPENDIDO'
--
--   [E2] enum_eventos_edge_computing_tipo_evento:
--        SELECT enum_range(NULL::modulo3.enum_eventos_edge_computing_tipo_evento);
--        Valores: 'ALERTA_GENERADA','CALIBRACION','SINCRONIZACION',
--                 'DATOS_PROCESADOS','ERROR_PROCESAMIENTO','MANTENIMIENTO'
--
--   [E3] enum_lecturas_sensores_origen_procesamiento:
--        SELECT enum_range(NULL::modulo3.enum_lecturas_sensores_origen_procesamiento);
--        Valores: 'EDGE','CLOUD','GATEWAY','LOCAL'
--
--   [E4] enum_reglas_alertas_nivel_alerta:
--        SELECT enum_range(NULL::modulo3.enum_reglas_alertas_nivel_alerta);
--        Valores: 'INFO','WARNING','CRITICAL','EMERGENCY'
--
--   [E5] enum_reglas_alertas_tipo_sensor:
--        SELECT enum_range(NULL::modulo3.enum_reglas_alertas_tipo_sensor);
--        Valores: 'HUMEDAD','TEMPERATURA','OXIGENO','PH','AMONIACO','SALINIDAD','LUMINOSIDAD'
--
--   [E6] enum_telemetria_estado_calidad:
--        SELECT enum_range(NULL::modulo3.enum_telemetria_estado_calidad);
--        Valores: 'LECTURA_VALIDA','FUERA_DE_RANGO','ERROR_CALIBRACION'
--
--   [E7] enum_telemetria_origen:
--        SELECT enum_range(NULL::modulo3.enum_telemetria_origen);
--        Valores: 'TIEMPO_REAL','BUFFER_LOCAL','EDGE_AGREGADO'
--
--   [E8] enum_transmiciones_mqqt_estado:
--        SELECT enum_range(NULL::modulo3.enum_transmiciones_mqqt_estado);
--        Valores: 'EXITO','FALLIDO','PENDIENTE','REINTENTADO','TIMEOUT'
-- ==============================================================


-- ==============================================================
-- PRECONDICIÓN 0 — VERIFICAR DEPENDENCIAS DE MÓDULO 9
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo9.dispositivos_iot
        WHERE id_dispositivo_iot IN (1,2,3,4,5,6,7,8,9)
        HAVING COUNT(*) = 9
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.dispositivos_iot debe '
            'contener registros con ids 1-9. Ejecute primero el '
            'script de inserción del Módulo 9.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.sensores
        WHERE id_sensores IN (1,2,3,4,5,6,7)
        HAVING COUNT(*) = 7
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.sensores debe contener '
            'registros con ids 1-7. Ejecute primero el script de '
            'inserción del Módulo 9.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.variables_ambientales
        WHERE id_variable_ambiental IN (1,2,3)
        HAVING COUNT(*) = 3
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.variables_ambientales debe '
            'contener al menos 3 registros. Ejecute primero el script '
            'de inserción del Módulo 9.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK):
--   1. reglas_alertas
--   2. lecturas_sensores
--   3. telemetrias
--   4. buffers
--   5. estados_conectividad
--   6. alertas_telemetria        ← depende de lecturas_sensores y reglas_alertas
--   7. eventos_edge_computing    ← depende de alertas_telemetria
--   8. transmiciones_mqqt
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. REGLAS DE ALERTAS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.reglas_alertas
    (nombre, descripcion, tipo_sensor, nivel_alerta,
     umbral_min, umbral_max, id_finca,
     es_activa, tiene_ejecutar_edge, mensaje)
VALUES
-- Temperatura del agua: rangos normales para tilapia (RF-57 FA-5)
('Temperatura agua baja - Tilapia',
 'Temperatura del agua por debajo del rango óptimo para tilapia nilótica (< 25 °C). '
 'Generada por RF-55 para procesamiento Edge.',
 'TEMPERATURA', 'WARNING',
 NULL, 25.0000,
 1, true, true,
 'ADVERTENCIA: temperatura del agua inferior al mínimo operativo para Tilapia (25 °C). '
 'Verifique el sistema de calefacción o la fuente de agua.'),

('Temperatura agua crítica - Tilapia',
 'Temperatura del agua en zona crítica para tilapia nilótica (< 20 °C). '
 'Requiere acción inmediata para evitar mortalidad.',
 'TEMPERATURA', 'CRITICAL',
 NULL, 20.0000,
 1, true, true,
 'CRÍTICO: temperatura del agua inferior al límite crítico para Tilapia (20 °C). '
 'Activar sistema de calefacción de emergencia inmediatamente.'),

('Temperatura agua alta - Tilapia',
 'Temperatura del agua por encima del rango óptimo para tilapia nilótica (> 30 °C). '
 'Riesgo de estrés térmico y reducción de oxígeno disuelto.',
 'TEMPERATURA', 'WARNING',
 30.0000, NULL,
 1, true, true,
 'ADVERTENCIA: temperatura del agua superior al máximo operativo para Tilapia (30 °C). '
 'Activar aireación adicional y verificar sombrado.'),

-- pH del agua: rango óptimo tilapia 6-8 (RF-57 reglas simples)
('pH agua bajo - General',
 'pH del agua por debajo del rango operativo (< 6.0). '
 'Causa acidosis en peces y reduce eficiencia del nitrógeno.',
 'PH', 'WARNING',
 NULL, 6.0000,
 1, true, true,
 'ADVERTENCIA: pH del agua inferior al mínimo operativo (6.0). '
 'Aplicar cal agrícola o bicarbonato de sodio según especie.'),

('pH agua crítico bajo - General',
 'pH del agua en zona crítica (< 5.5). '
 'Riesgo de mortalidad masiva en especie ácido-sensibles.',
 'PH', 'CRITICAL',
 NULL, 5.5000,
 1, true, true,
 'CRÍTICO: pH del agua inferior al límite crítico (5.5). '
 'Suspender alimentación e iniciar corrección de emergencia.'),

('pH agua alto - General',
 'pH del agua por encima del rango operativo (> 8.5). '
 'Aumenta toxicidad del amoniaco y afecta respiración.',
 'PH', 'WARNING',
 8.5000, NULL,
 1, true, true,
 'ADVERTENCIA: pH del agua superior al máximo operativo (8.5). '
 'Incrementar recambio de agua y revisar fuente de alcalinidad.'),

-- Oxígeno disuelto: reglas RF-57 (tilapia mín 5 mg/L)
('Oxígeno disuelto bajo - General',
 'Nivel de oxígeno disuelto por debajo del mínimo operativo (< 5 mg/L). '
 'Genera estrés hipóxico y reduce consumo de alimento.',
 'OXIGENO', 'WARNING',
 NULL, 5.0000,
 1, true, true,
 'ADVERTENCIA: oxígeno disuelto inferior al mínimo operativo (5 mg/L). '
 'Incrementar aireación y revisar densidad de siembra.'),

('Oxígeno disuelto crítico - General',
 'Nivel de oxígeno disuelto en zona crítica (< 3 mg/L). '
 'Riesgo inminente de mortalidad por hipoxia.',
 'OXIGENO', 'CRITICAL',
 NULL, 3.0000,
 1, true, true,
 'CRÍTICO: oxígeno disuelto inferior al límite crítico (3 mg/L). '
 'Activar aireación de emergencia. Reducir densidad si persiste.'),

-- Amoniaco: NH3 > 25 ppm = LEVE; > 35 ppm = MODERADO (RF-57)
('Amoniaco elevado - General',
 'Concentración de amoniaco total superior al límite operativo (> 1 mg/L). '
 'Tóxico para branquias y sistema nervioso de los peces.',
 'AMONIACO', 'WARNING',
 1.0000, NULL,
 1, true, true,
 'ADVERTENCIA: amoniaco superior al límite operativo (1 mg/L). '
 'Incrementar recambio de agua y reducir carga alimenticia.'),

('Amoniaco crítico - General',
 'Concentración de amoniaco en zona crítica (> 2 mg/L). '
 'Mortalidad inminente sin acción correctiva urgente.',
 'AMONIACO', 'CRITICAL',
 2.0000, NULL,
 1, true, true,
 'CRÍTICO: amoniaco superior al límite crítico (2 mg/L). '
 'Suspender alimentación, aumentar recambio y aplicar zeolita.');


-- ─────────────────────────────────────────────────────────────
-- 2. LECTURAS DE SENSORES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.lecturas_sensores
    (id_sensor, id_dispositivo_iot, valor, unidad_medida,
     origen_procesamiento, latencia_procesamiento_ms,
     fecha_captura, fecha_recepcion, es_valida, metadata)
VALUES
-- Sensor 1 (temperatura BOV-001 / Estanque-01) — LECTURA_VALIDA
(1, 1, 26.5000, '°C', 'EDGE', 42,
 NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours' + INTERVAL '5 seconds',
 true,
 '{"estado_calidad": "LECTURA_VALIDA", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false}'),

-- Sensor 2 (pH Estanque-01) — LECTURA_VALIDA
(2, 1, 7.2000, 'pH', 'EDGE', 38,
 NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours' + INTERVAL '4 seconds',
 true,
 '{"estado_calidad": "LECTURA_VALIDA", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false}'),

-- Sensor 3 (OD Estanque-01) — LECTURA_VALIDA
(3, 1, 6.8000, 'mg/L', 'EDGE', 55,
 NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours' + INTERVAL '6 seconds',
 true,
 '{"estado_calidad": "LECTURA_VALIDA", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false}'),

-- Sensor 4 (temperatura Estanque-02) — LECTURA_VALIDA
(4, 2, 27.3000, '°C', 'EDGE', 45,
 NOW() - INTERVAL '1 hour 30 minutes', NOW() - INTERVAL '1 hour 30 minutes' + INTERVAL '5 seconds',
 true,
 '{"estado_calidad": "LECTURA_VALIDA", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false}'),

-- Sensor 5 (pH Estanque-02) — LECTURA_VALIDA
(5, 2, 6.9000, 'pH', 'EDGE', 40,
 NOW() - INTERVAL '1 hour 30 minutes', NOW() - INTERVAL '1 hour 30 minutes' + INTERVAL '5 seconds',
 true,
 '{"estado_calidad": "LECTURA_VALIDA", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false}'),

-- Sensor 6 (temperatura Alevinera-01) — LECTURA_VALIDA en rango bajo (genera alerta)
(6, 3, 23.1000, '°C', 'EDGE', 62,
 NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour' + INTERVAL '7 seconds',
 true,
 '{"estado_calidad": "LECTURA_VALIDA", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false}'),

-- Sensor 7 (OD Alevinera-01) — FUERA_DE_RANGO (< 5 mg/L crítico)
(7, 3, 2.8000, 'mg/L', 'EDGE', 58,
 NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour' + INTERVAL '7 seconds',
 false,
 '{"estado_calidad": "FUERA_DE_RANGO", "calibrado": true, "latencia_alta": false,
   "frecuencia_anomala": false, "dato_bufferizado": false, "dato_agregado": false,
   "rango_min": 5.0, "rango_max": 12.0, "valor_fuera": true}');

-- ─────────────────────────────────────────────────────────────
-- 3. TELEMETRIAS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.telemetrias
    (id_sensor, id_variable, id_dispositivo_iot,
     valor_crudo, valor_ajustado,
     timestamp_captura, timestamp_envio, timestamp_procesamiento,
     origen, estado_calidad, calibrado,
     latitud, longitud, metadatos)
VALUES
-- Telemetría 1: temperatura estanque-01 (Sensor 1, Variable 1 = Temperatura)
(1, 1, 1,
 26.3000, 26.5000,
 NOW() - INTERVAL '2 hours',
 NOW() - INTERVAL '2 hours' + INTERVAL '3 seconds',
 NOW() - INTERVAL '2 hours' + INTERVAL '5 seconds',
 'TIEMPO_REAL', 'LECTURA_VALIDA', true,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": false, "calibrado": true,
   "version_calibracion": "v1.0",
   "parametros_calibracion": {"offset": 0.2, "ganancia": 1.0}}'),

-- Telemetría 2: pH estanque-01 (Sensor 2, Variable 2 = pH)
(2, 2, 1,
 7.1500, 7.2000,
 NOW() - INTERVAL '2 hours',
 NOW() - INTERVAL '2 hours' + INTERVAL '3 seconds',
 NOW() - INTERVAL '2 hours' + INTERVAL '4 seconds',
 'TIEMPO_REAL', 'LECTURA_VALIDA', true,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": false, "calibrado": true,
   "version_calibracion": "v1.0",
   "parametros_calibracion": {"offset": 0.05, "ganancia": 1.007}}'),

-- Telemetría 3: OD estanque-01 (Sensor 3, Variable 3 = OD)
(3, 3, 1,
 6.9000, 6.8000,
 NOW() - INTERVAL '2 hours',
 NOW() - INTERVAL '2 hours' + INTERVAL '4 seconds',
 NOW() - INTERVAL '2 hours' + INTERVAL '6 seconds',
 'TIEMPO_REAL', 'LECTURA_VALIDA', true,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": false, "calibrado": true,
   "version_calibracion": "v1.0",
   "parametros_calibracion": {"offset": -0.1, "ganancia": 1.0}}'),

-- Telemetría 4: temperatura estanque-02 (Sensor 4, Variable 1)
(4, 1, 2,
 27.3000, 27.3000,
 NOW() - INTERVAL '1 hour 30 minutes',
 NOW() - INTERVAL '1 hour 30 minutes' + INTERVAL '3 seconds',
 NOW() - INTERVAL '1 hour 30 minutes' + INTERVAL '5 seconds',
 'TIEMPO_REAL', 'LECTURA_VALIDA', false,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": false, "calibrado": false,
   "version_calibracion": null,
   "parametros_calibracion": null}'),

-- Telemetría 5: OD alevinera-01 FUERA_DE_RANGO (Sensor 7, Variable 3)
-- valor_ajustado = valor_crudo (sin calibrar por ausencia de parámetros)
(7, 3, 3,
 2.8000, 2.8000,
 NOW() - INTERVAL '1 hour',
 NOW() - INTERVAL '1 hour' + INTERVAL '4 seconds',
 NOW() - INTERVAL '1 hour' + INTERVAL '7 seconds',
 'TIEMPO_REAL', 'FUERA_DE_RANGO', false,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": false, "calibrado": false,
   "alerta_generada": true,
   "causa_fuera_rango": "OD por debajo del mínimo critico de 3 mg/L"}'),

-- Telemetría 6: temperatura Edge-agregado (promedio 5 min Sensor 1)
(1, 1, 1,
 26.4000, 26.6000,
 NOW() - INTERVAL '30 minutes',
 NOW() - INTERVAL '30 minutes' + INTERVAL '2 seconds',
 NOW() - INTERVAL '30 minutes' + INTERVAL '3 seconds',
 'EDGE_AGREGADO', 'LECTURA_VALIDA', true,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": true,
   "ventana_agregacion_min": 5, "calibrado": true,
   "version_calibracion": "v1.0",
   "parametros_calibracion": {"offset": 0.2, "ganancia": 1.0}}'),

-- Telemetría 7: ERROR_CALIBRACION (sin parámetros disponibles)
(5, 2, 2,
 8.9000, 8.9000,
 NOW() - INTERVAL '45 minutes',
 NOW() - INTERVAL '45 minutes' + INTERVAL '3 seconds',
 NOW() - INTERVAL '45 minutes' + INTERVAL '5 seconds',
 'TIEMPO_REAL', 'ERROR_CALIBRACION', false,
 2.927300, -75.281900,
 '{"latencia_alta": false, "frecuencia_anomala": false, "posible_drift": false,
   "dato_bufferizado": false, "dato_agregado": false, "calibrado": false,
   "causa_error": "No existen parametros de calibracion para este sensor en RF-24"}');

-- ─────────────────────────────────────────────────────────────
-- 4. BUFFERS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.buffers
    (id_dispositivo, id_sensor, payload_row,
     fecha_captura, es_sincronizado,
     fecha_sincronizacion, intentos_sincronizacion,
     horas_buffer, fecha_creacion)
VALUES
-- Buffer 1: datos de Alevinera-01 durante desconexión (ya sincronizado)
(3, 6,
 '{"sensor_id": 6, "dispositivo_id": 3, "valor": 23.5, "unidad": "°C",
   "tipo_variable": "TEMPERATURA_AMBIENTAL", "categoria": "AMBIENTAL",
   "timestamp_captura": "' || (NOW() - INTERVAL '5 hours')::text || '",
   "origen": "BUFFER_LOCAL", "buffer_sequence_id": 1,
   "estado_conectividad": "OFFLINE",
   "checksum": "a3f5d2e1b7c9"}',
 NOW() - INTERVAL '5 hours',
 true, NOW() - INTERVAL '30 minutes',
 3, 72, NOW() - INTERVAL '5 hours'),

-- Buffer 2: segundo registro del mismo periodo (sincronizado)
(3, 7,
 '{"sensor_id": 7, "dispositivo_id": 3, "valor": 4.2, "unidad": "mg/L",
   "tipo_variable": "OXIGENO_DISUELTO", "categoria": "HIDRICA",
   "timestamp_captura": "' || (NOW() - INTERVAL '4 hours 30 minutes')::text || '",
   "origen": "BUFFER_LOCAL", "buffer_sequence_id": 2,
   "estado_conectividad": "OFFLINE",
   "checksum": "b4e6f3a2c8d0"}',
 NOW() - INTERVAL '4 hours 30 minutes',
 true, NOW() - INTERVAL '30 minutes',
 3, 72, NOW() - INTERVAL '4 hours 30 minutes'),

-- Buffer 3: registro pendiente de sincronización (es_sincronizado = false)
(3, 6,
 '{"sensor_id": 6, "dispositivo_id": 3, "valor": 22.8, "unidad": "°C",
   "tipo_variable": "TEMPERATURA_AMBIENTAL", "categoria": "AMBIENTAL",
   "timestamp_captura": "' || (NOW() - INTERVAL '2 hours')::text || '",
   "origen": "BUFFER_LOCAL", "buffer_sequence_id": 3,
   "estado_conectividad": "OFFLINE",
   "checksum": "c5f7g4b3d9e1"}',
 NOW() - INTERVAL '2 hours',
 false, NULL,
 0, 72, NOW() - INTERVAL '2 hours'),

-- Buffer 4: registro con reintento (estado ERROR previo, reintentando)
(3, 7,
 '{"sensor_id": 7, "dispositivo_id": 3, "valor": 3.1, "unidad": "mg/L",
   "tipo_variable": "OXIGENO_DISUELTO", "categoria": "HIDRICA",
   "timestamp_captura": "' || (NOW() - INTERVAL '1 hour 30 minutes')::text || '",
   "origen": "BUFFER_LOCAL", "buffer_sequence_id": 4,
   "estado_conectividad": "OFFLINE",
   "checksum": "d6g8h5c4e0f2"}',
 NOW() - INTERVAL '1 hour 30 minutes',
 false, NULL,
 2, 72, NOW() - INTERVAL '1 hour 30 minutes');

-- ─────────────────────────────────────────────────────────────
-- 5. ESTADOS DE CONECTIVIDAD
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.estados_conectividad
    (id_dispositivo_iot, estado, rssi_dbm, snr_db,
     gatway_id, fecha_registro, duracion_seg, observaciones)
VALUES
-- Dispositivo 1 (Estanque-01): CONECTADO — operación normal
(1, 'CONECTADO', -78, 8,
 'GW-HLA-001', NOW() - INTERVAL '30 minutes',
 1800,
 'Heartbeat recibido correctamente. Señal LoRaWAN estable. '
 'Nivel de batería: 92%. Todos los sensores operativos.'),

-- Dispositivo 2 (Estanque-02): CONECTADO — operación normal
(2, 'CONECTADO', -82, 7,
 'GW-HLA-001', NOW() - INTERVAL '25 minutes',
 1500,
 'Heartbeat recibido. Señal aceptable. '
 'Nivel de batería: 87%. Todos los sensores operativos.'),

-- Dispositivo 3 (Alevinera-01): DESCONECTADO — operación en buffer
(3, 'DESCONECTADO', NULL, 0,
 NULL, NOW() - INTERVAL '5 hours',
 18000,
 'Dispositivo en modo buffer local (RF-54 activo). '
 'Última señal hace 5 horas. Datos almacenados localmente. '
 'Causa primaria: FALLO_CONECTIVIDAD. Pendiente revisión de gateway.'),

-- Dispositivo 4 (Canal-Trucha-01): CONECTADO
(4, 'CONECTADO', -75, 10,
 'GW-VLC-001', NOW() - INTERVAL '20 minutes',
 1200,
 'Heartbeat recibido. Señal buena. '
 'Nivel de batería: 95%. Todos los sensores operativos.'),

-- Dispositivo 5 (Canal-Trucha-02): ERROR — señal degradada
(5, 'ERROR', -112, 2,
 'GW-VLC-001', NOW() - INTERVAL '15 minutes',
 900,
 'Señal LoRaWAN degradada (RSSI: -112 dBm, SNR: 2 dB). '
 'Por debajo del umbral mínimo operativo. '
 'Alerta SEÑAL_DEGRADADA generada al ingeniero de campo.'),

-- Dispositivo 6 (Piscina-Cam-01): CONECTADO
(6, 'CONECTADO', -80, 6,
 'GW-COR-001', NOW() - INTERVAL '10 minutes',
 600,
 'Heartbeat recibido. Señal LoRaWAN aceptable. '
 'Nivel de batería: 78%. Todos los sensores operativos.'),

-- Dispositivo 9 (Estanque-Moj-01): SUSPENDIDO — en mantenimiento
(9, 'SUSPENDIDO', NULL, 0,
 NULL, NOW() - INTERVAL '2 hours',
 7200,
 'Dispositivo suspendido por mantenimiento programado. '
 'Calibración de sensores pH y temperatura. '
 'Ingeniero de campo responsable: usuario id=1. ETA: 1 hora.');

-- ─────────────────────────────────────────────────────────────
-- 6. ALERTAS DE TELEMETRÍA
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.alertas_telemetria
    (id_regla_alerta, id_lectura_sensor, id_sensor,
     id_dispositivo_iot, nivel, estado,
     valor_detectado, mensaje, es_generada_edge,
     latencia_generacion_ms, reconocida_por,
     fecha_reconocimeinot, fecha_creacion)
VALUES
-- Alerta 1: OD crítico en Alevinera-01 (Sensor 7, lectura 7, regla 8)
-- Lectura FUERA_DE_RANGO → genera alerta operativa (RF-57 CA-3 excepción:
-- datos FUERA_DE_RANGO SÍ generan alerta si el valor es crítico para el activo)
(8,  -- regla: Oxígeno disuelto crítico
 7,  -- lectura: OD 2.8 mg/L Alevinera-01
 7,  -- sensor: OD Alevinera-01
 3,  -- dispositivo: IOT-ALE01-HLA-003
 'CRITICAL', 'FUERA_DE_RANGO',
 2.8000,
 'CRITICO: oxígeno disuelto en 2.8 mg/L, inferior al límite crítico de 3 mg/L '
 'en Alevinera-01. Riesgo inminente de mortalidad por hipoxia. '
 'Activar aireación de emergencia inmediatamente.',
 true, 285,
 NULL, NULL,
 NOW() - INTERVAL '58 minutes'),

-- Alerta 2: Temperatura baja en Alevinera-01 (Sensor 6, lectura 6, regla 1)
-- temperatura 23.1 < 25 °C (umbral WARNING)
(1,  -- regla: Temperatura agua baja - Tilapia
 6,  -- lectura: temperatura 23.1 Alevinera-01
 6,  -- sensor: temperatura Alevinera-01
 3,  -- dispositivo: IOT-ALE01-HLA-003
 'WARNING', 'LECTURA_VALIDA',
 23.1000,
 'ADVERTENCIA: temperatura del agua en 23.1 °C en Alevinera-01. '
 'Por debajo del mínimo operativo de 25 °C para la fase larval de Tilapia. '
 'Verifique el sistema de calefacción o la fuente de agua de entrada.',
 true, 310,
 'Ingeniero Campo - usuario 1', NOW() - INTERVAL '30 minutes',
 NOW() - INTERVAL '1 hour'),

-- Alerta 3: pH alto en Estanque-02 (Sensor 5, lectura 5, regla 6)
-- pH 8.9 > 8.5 (umbral WARNING) — ya reconocida
(6,  -- regla: pH agua alto - General
 5,  -- lectura: pH 8.9
 5,  -- sensor: pH Estanque-02
 2,  -- dispositivo: IOT-EST02-HLA-002
 'WARNING', 'ERROR_CALIBRACION',
 8.9000,
 'ADVERTENCIA: pH del agua en 8.9 en Estanque-02. '
 'Por encima del máximo operativo de 8.5. '
 'El dato presenta ERROR_CALIBRACION; verificar calibración del sensor. '
 'Incrementar recambio de agua y revisar fuente de alcalinidad.',
 false, 420,
 NULL, NULL,
 NOW() - INTERVAL '45 minutes');

-- ─────────────────────────────────────────────────────────────
-- 7. EVENTOS EDGE COMPUTING
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.eventos_edge_computing
    (id_dispositivo_iot, tipo_evento, descripcion,
     latencia_ms, cumple_sla,
     payload_entrada, resultado,
     fecha_registro, id_alerta_telemetria)
VALUES
-- Evento 1: ALERTA_GENERADA — OD crítico Alevinera-01 (Alerta 1)
(3, 'ALERTA_GENERADA',
 'Procesamiento Edge RF-55: detección de desviación crítica en Oxígeno Disuelto. '
 'Sensor 7 reportó 2.8 mg/L, por debajo del umbral crítico de 3 mg/L. '
 'Clasificación: DESVIACION_SIMPLE, severidad CRITICO. '
 'Tiempo de procesamiento: 285 ms (cumple SLA < 500 ms).',
 285, true,
 '{"sensor_id": 7, "variable": "OXIGENO_DISUELTO", "valor": 2.8,
   "unidad": "mg/L", "umbral_critico_min": 3.0,
   "timestamp_captura": "' || (NOW() - INTERVAL '1 hour')::text || '",
   "origen": "TIEMPO_REAL", "estado_conectividad": "ONLINE"}',
 '{"tipo_resultado": "DESVIACION_SIMPLE", "severidad": "CRITICO",
   "variables_involucradas": ["OXIGENO_DISUELTO"],
   "regla_aplicada": "Oxigeno disuelto critico - General",
   "accion_sugerida": "Activar aeracion de emergencia",
   "alerta_generada": true, "id_alerta": 1}',
 NOW() - INTERVAL '58 minutes',
 1),

-- Evento 2: ALERTA_GENERADA — Temperatura baja Alevinera-01 (Alerta 2)
(3, 'ALERTA_GENERADA',
 'Procesamiento Edge RF-55: detección de temperatura por debajo del rango operativo. '
 'Sensor 6 reportó 23.1 °C, por debajo del umbral mínimo de 25 °C para tilapia. '
 'Clasificación: DESVIACION_SIMPLE, severidad WARNING. '
 'Tiempo de procesamiento: 310 ms (cumple SLA < 500 ms).',
 310, true,
 '{"sensor_id": 6, "variable": "TEMPERATURA_AMBIENTAL", "valor": 23.1,
   "unidad": "°C", "umbral_warning_min": 25.0,
   "timestamp_captura": "' || (NOW() - INTERVAL '1 hour')::text || '",
   "origen": "TIEMPO_REAL", "estado_conectividad": "ONLINE"}',
 '{"tipo_resultado": "DESVIACION_SIMPLE", "severidad": "WARNING",
   "variables_involucradas": ["TEMPERATURA_AMBIENTAL"],
   "regla_aplicada": "Temperatura agua baja - Tilapia",
   "accion_sugerida": "Verificar sistema de calefaccion",
   "alerta_generada": true, "id_alerta": 2}',
 NOW() - INTERVAL '1 hour',
 2),

-- Evento 3: DATOS_PROCESADOS — agregación de temperatura Estanque-01
(1, 'DATOS_PROCESADOS',
 'Procesamiento Edge RF-55.2: agregación de temperatura en ventana de 5 minutos. '
 'Promedio calculado a partir de 5 lecturas. '
 'Valor crudo individual: 26.3 °C → Promedio 5 min: 26.4 °C. '
 'Dato enviado como EDGE_AGREGADO para reducción de tráfico LoRaWAN.',
 95, true,
 '{"sensor_id": 1, "variable": "TEMPERATURA_AMBIENTAL",
   "lecturas_base": [26.2, 26.3, 26.4, 26.5, 26.6],
   "ventana_min": 5, "tipo_agregacion": "promedio",
   "timestamp_inicio": "' || (NOW() - INTERVAL '35 minutes')::text || '",
   "timestamp_fin": "' || (NOW() - INTERVAL '30 minutes')::text || '"}',
 '{"tipo_resultado": "NORMAL", "severidad": null,
   "valor_agregado": 26.4, "unidad": "°C",
   "n_lecturas": 5, "dentro_rango": true,
   "transmitido_como": "EDGE_AGREGADO"}',
 NOW() - INTERVAL '30 minutes',
 3),

-- Evento 4: CALIBRACION — Sensor 1 Estanque-01 recalibrado
(1, 'CALIBRACION',
 'Evento de calibración registrado para Sensor 1 (temperatura Estanque-01). '
 'Parámetros actualizados: offset=0.2, ganancia=1.0. '
 'Verificación con patrón de referencia certificado NIST. '
 'Próxima calibración programada en 30 días.',
 180, true,
 '{"sensor_id": 1, "tipo_calibracion": "offset_ganancia",
   "valor_referencia": 25.0,
   "valor_sensor_antes": 24.8,
   "offset_anterior": 0.0, "ganancia_anterior": 1.0}',
 '{"offset_nuevo": 0.2, "ganancia_nueva": 1.0,
   "error_corregido": 0.2,
   "estado": "CALIBRACION_EXITOSA",
   "certificado": "NIST-2024-001"}',
 NOW() - INTERVAL '3 hours',
 3),

-- Evento 5: SINCRONIZACION — Alevinera-01 sincronizando buffer
(3, 'SINCRONIZACION',
 'Sincronización de buffer local iniciada en Alevinera-01 tras recuperación de conectividad. '
 'Total de registros pendientes: 2 (buffer_sequence_id 1 y 2). '
 'Procesados en orden FIFO por timestamp_captura.',
 210, true,
 '{"dispositivo_id": 3, "registros_pendientes": 2,
   "timestamp_inicio_buffer": "' || (NOW() - INTERVAL '5 hours')::text || '",
   "politica_buffer": "POLITICA_RECHAZO",
   "capacidad_buffer": "72h"}',
 '{"registros_sincronizados": 2, "registros_fallidos": 0,
   "duplicados_detectados": 0, "estado_final": "SYNC_SUCCESS",
   "duracion_ms": 210}',
 NOW() - INTERVAL '30 minutes',
 1);


-- ─────────────────────────────────────────────────────────────
-- 8. TRANSMISIONES MQTT
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo3.transmiciones_mqqt
    (id_dispositivo_iot, topic, qos, payloads_bytes,
     estado, gatway_id, rssi_dbm, snr_db,
     frecuencia_mhz, spreading_factor,
     intentos, error_descripcion, fecha_transmision)
VALUES
-- Transmisión 1: Estanque-01 → backend (EXITO)
(1,
 'pecuaria/finca/1/estanque/01/telemetria',
 1, 312,
 'EXITO', 'GW-HLA-001', -78, 8.50,
 868.100, 9,
 1, NULL,
 NOW() - INTERVAL '2 hours'),

-- Transmisión 2: Estanque-01 → backend temperatura agregada (EXITO)
(1,
 'pecuaria/finca/1/estanque/01/edge/agregado',
 1, 198,
 'EXITO', 'GW-HLA-001', -79, 8.20,
 868.100, 9,
 1, NULL,
 NOW() - INTERVAL '30 minutes'),

-- Transmisión 3: Estanque-02 → backend (EXITO)
(2,
 'pecuaria/finca/1/estanque/02/telemetria',
 1, 287,
 'EXITO', 'GW-HLA-001', -82, 7.10,
 868.300, 9,
 1, NULL,
 NOW() - INTERVAL '1 hour 30 minutes'),

-- Transmisión 4: Alevinera-01 → backend (TIMEOUT — dispositivo en buffer)
(3,
 'pecuaria/finca/1/alevinera/01/telemetria',
 1, 0,
 'TIMEOUT', NULL, NULL, NULL,
 NULL, NULL,
 3,
 'Timeout en 3 intentos consecutivos. Gateway no responde. '
 'Dispositivo cambió a modo buffer local (RF-54 activado). '
 'Datos almacenados localmente para sincronización posterior.',
 NOW() - INTERVAL '5 hours'),

-- Transmisión 5: Alevinera-01 → backend sincronización exitosa
(3,
 'pecuaria/finca/1/alevinera/01/buffer/sync',
 1, 487,
 'EXITO', 'GW-HLA-001', -85, 6.30,
 868.100, 10,
 1, NULL,
 NOW() - INTERVAL '30 minutes'),

-- Transmisión 6: Dispositivo 5 (Canal-Trucha-02) señal degradada (REINTENTADO)
(5,
 'pecuaria/finca/2/canal/trucha/02/telemetria',
 1, 0,
 'REINTENTADO', 'GW-VLC-001', -112, 2.10,
 867.500, 12,
 2,
 'Primera transmisión fallida por señal degradada (RSSI: -112 dBm). '
 'Reintento con spreading_factor=12 para mayor alcance. '
 'Alerta SEÑAL_DEGRADADA notificada al ingeniero de campo.',
 NOW() - INTERVAL '15 minutes'),

-- Transmisión 7: Dispositivo 6 (Piscina-Cam-01) alerta crítica (EXITO, QoS 2)
(6,
 'pecuaria/finca/3/piscina/cam/01/alertas/critical',
 2, 524,
 'EXITO', 'GW-COR-001', -80, 6.80,
 867.900, 9,
 1, NULL,
 NOW() - INTERVAL '10 minutes');
