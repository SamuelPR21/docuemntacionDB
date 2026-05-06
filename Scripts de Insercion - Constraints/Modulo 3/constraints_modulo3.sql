-- ================================================================
-- CONSTRAINTS — MÓDULO 3
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo se declaran constraints que NO existen en el DDL del
--   backup (backup3_2_2.sql).
--
-- YA EXISTENTES en el backup (NO se re-ejecutan):
--   PKs: alertas_telemetria_pkey, buffers_pkey,
--        estados_conectividad_pkey, eventos_edge_computing_pkey,
--        lecturas_sensores_pkey, reglas_alertas_pkey,
--        telemetrias_pkey, transmiciones_mqqt_pkey
--
--   FKs (SIN NOT VALID — ya activas y válidas):
--     fk_alerta_telemetria_lectura_sensor
--     fk_alerta_telemetria_regla
--     fk_alertas_telemetria_dispositivo_iot (ON DELETE CASCADE)
--     fk_alertas_telemetria_sensor          (ON DELETE CASCADE)
--     fk_dispositivo_iot_id  (lecturas_sensores)
--     fk_dispositovo_id      (buffers — typo en DDL)
--     fk_estado_conectividad_dispositivo_iot
--     fk_evento_edge_computing_alerta_telemetria
--     fk_evento_edge_computing_dispositivo_iot
--     fk_lectura_sensor_dispositivo_iot
--     fk_lectura_sensor_id
--     fk_sensor_id (telemetrias)
--     fk_sensor_id (buffers)
--     fk_transmiciones_mqqt_dispositivo_iot
--     fk_variable_id (telemetrias → modulo9.variables_ambientales)
--     fk_regla_alerta_finca
--
--   UQs: ninguna en el backup
--   CHECKs: ninguno en el backup
--
-- NOTA SOBRE ENUMS (misma regla que módulos anteriores):
--   Las columnas de tipo ENUM en PostgreSQL ya restringen los
--   valores por definición de tipo. Agregar CHECK IN() sobre
--   una columna ENUM es redundante y puede causar errores de
--   compatibilidad de tipos. Dichos checks NO se incluyen.
--   ENUMs del módulo 3:
--     modulo3.enum_estados_conectividad_estado
--     modulo3.enum_eventos_edge_computing_tipo_evento
--     modulo3.enum_lecturas_sensores_origen_procesamiento
--     modulo3.enum_reglas_alertas_nivel_alerta
--     modulo3.enum_reglas_alertas_tipo_sensor
--     modulo3.enum_telemetria_estado_calidad
--     modulo3.enum_telemetria_origen
--     modulo3.enum_transmiciones_mqqt_estado
--
-- Se AGREGAN:
--   PARTE 1 — UQ constraints nuevos
--   PARTE 2 — CHECK constraints directos
--   PARTE 3 — CHECK constraints diferidos (NOT VALID + VALIDATE)
--   PARTE 4 — Índices únicos parciales y de desempeño
-- ================================================================


-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- Ejecutar antes de los índices únicos parciales si la BD ya
-- contiene datos inconsistentes. Descomentar si aplica.
-- ----------------------------------------------------------------

-- [P1] Verificar que no haya umbral_min > umbral_max en reglas_alertas
-- SELECT id_regla_alertas, nombre, umbral_min, umbral_max
--   FROM modulo3.reglas_alertas
--  WHERE umbral_min IS NOT NULL
--    AND umbral_max IS NOT NULL
--    AND umbral_min >= umbral_max;

-- [P2] Verificar coherencia temporal en lecturas_sensores:
-- SELECT id_lectura_sensor, fecha_captura, fecha_recepcion
--   FROM modulo3.lecturas_sensores
--  WHERE fecha_captura > fecha_recepcion;

-- [P3] Verificar coherencia temporal en telemetrias:
-- SELECT id_telemetria
--   FROM modulo3.telemetrias
--  WHERE timestamp_captura > timestamp_envio
--     OR timestamp_envio > timestamp_procesamiento;

-- [P4] Verificar qos válido en transmiciones_mqqt:
-- SELECT id_transmicion_mqqt, qos
--   FROM modulo3.transmiciones_mqqt
--  WHERE qos NOT IN (0, 1, 2);


-- ================================================================
-- PARTE 1 — UNIQUE CONSTRAINTS NUEVOS
-- ================================================================

-- [RF-57] Nombre de regla de alerta único dentro del sistema
-- No deben existir dos reglas con el mismo nombre para evitar
-- ambigüedad en el motor de evaluación de alertas.
ALTER TABLE modulo3.reglas_alertas
    ADD CONSTRAINT uq_regla_alerta_nombre
        UNIQUE (nombre);


-- ================================================================
-- PARTE 2 — CHECK CONSTRAINTS DIRECTOS
-- (sin riesgo de fallo con datos previos en seed limpio)
-- ================================================================

-- ──────────────────────────────────────────────────────────────
-- TABLA: reglas_alertas
-- ──────────────────────────────────────────────────────────────

-- [RF-57] Cuando ambos umbrales están definidos, mín < máx
-- Restricción explícita RF-57: "Los umbrales deben configurarse
-- con coherencia: mínimo estrictamente menor que máximo."
ALTER TABLE modulo3.reglas_alertas
    ADD CONSTRAINT chk_regla_umbral_coherente
        CHECK (
            umbral_min IS NULL
            OR umbral_max IS NULL
            OR umbral_min < umbral_max
        );

-- [RF-57] Al menos un umbral debe estar definido para que la
-- regla sea evaluable. No tiene sentido una regla sin umbral.
ALTER TABLE modulo3.reglas_alertas
    ADD CONSTRAINT chk_regla_tiene_al_menos_un_umbral
        CHECK (umbral_min IS NOT NULL OR umbral_max IS NOT NULL);

-- ──────────────────────────────────────────────────────────────
-- TABLA: lecturas_sensores
-- ──────────────────────────────────────────────────────────────

-- [RF-53] El valor medido por el sensor no puede ser NULL;
-- es una medición física real. numeric NOT NULL ya está en DDL,
-- pero se refuerza la no-negatividad para magnitudes físicas
-- que no admiten valores negativos en sensores acuícolas.
-- Se usa NOT VALID para no fallar con datos previos.
ALTER TABLE modulo3.lecturas_sensores
    ADD CONSTRAINT chk_lectura_valor_no_negativo
        CHECK (valor >= 0)
        NOT VALID;
ALTER TABLE modulo3.lecturas_sensores
    VALIDATE CONSTRAINT chk_lectura_valor_no_negativo;

-- [RF-53] fecha_captura debe ser anterior o igual a fecha_recepcion
-- (coherencia temporal — Fase 3 de RF-53)
ALTER TABLE modulo3.lecturas_sensores
    ADD CONSTRAINT chk_lectura_fechas_coherentes
        CHECK (fecha_captura <= fecha_recepcion);

-- [RF-53] Unidad de medida no puede ser cadena vacía
ALTER TABLE modulo3.lecturas_sensores
    ADD CONSTRAINT chk_lectura_unidad_no_vacia
        CHECK (char_length(trim(unidad_medida)) > 0);

-- [RF-53] Latencia de procesamiento no negativa cuando está definida
ALTER TABLE modulo3.lecturas_sensores
    ADD CONSTRAINT chk_lectura_latencia_no_negativa
        CHECK (latencia_procesamiento_ms IS NULL
               OR latencia_procesamiento_ms >= 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: telemetrias
-- ──────────────────────────────────────────────────────────────

-- [RF-53] Coherencia temporal: captura → envío → procesamiento
-- Restricción explícita RF-53 Fase 3: "timestamp_captura ≤ timestamp_envio"
ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_timestamps_coherentes
        CHECK (timestamp_captura <= timestamp_envio
               AND timestamp_envio <= timestamp_procesamiento);

-- [RF-53] valor_crudo no negativo (magnitudes físicas acuícolas)
ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_valor_crudo_no_negativo
        CHECK (valor_crudo >= 0)
        NOT VALID;
ALTER TABLE modulo3.telemetrias
    VALIDATE CONSTRAINT chk_telemetria_valor_crudo_no_negativo;

-- [RF-53] valor_ajustado no negativo
ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_valor_ajustado_no_negativo
        CHECK (valor_ajustado >= 0)
        NOT VALID;
ALTER TABLE modulo3.telemetrias
    VALIDATE CONSTRAINT chk_telemetria_valor_ajustado_no_negativo;

-- [RF-53] Coherencia entre calibrado y valor_ajustado:
-- Si calibrado = false, valor_ajustado debe igualar valor_crudo
-- (sin corrección aplicada — Fase 7 de RF-53)
ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_calibrado_coherente
        CHECK (
            calibrado = true
            OR valor_ajustado = valor_crudo
        );

-- [RF-53] Coordenadas geográficas dentro de rangos físicos válidos
ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_latitud_valida
        CHECK (latitud BETWEEN -90 AND 90);

ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_longitud_valida
        CHECK (longitud BETWEEN -180 AND 180);

-- ──────────────────────────────────────────────────────────────
-- TABLA: buffers
-- ──────────────────────────────────────────────────────────────

-- [RF-54] Coherencia: si es_sincronizado = true entonces
-- fecha_sincronizacion no puede ser NULL (RF-54 Fase 9)
ALTER TABLE modulo3.buffers
    ADD CONSTRAINT chk_buffer_sincronizacion_coherente
        CHECK (
            es_sincronizado = false
            OR fecha_sincronizacion IS NOT NULL
        );

-- [RF-54] Si es_sincronizado = false, fecha_sincronizacion = NULL
ALTER TABLE modulo3.buffers
    ADD CONSTRAINT chk_buffer_no_sincronizado_sin_fecha
        CHECK (
            es_sincronizado = true
            OR fecha_sincronizacion IS NULL
        );

-- [RF-54] intentos_sincronizacion no puede ser negativo
ALTER TABLE modulo3.buffers
    ADD CONSTRAINT chk_buffer_intentos_no_negativos
        CHECK (intentos_sincronizacion >= 0);

-- [RF-54] horas_buffer positivo cuando está definido
-- (capacidad mínima: 72 horas según RF-54)
ALTER TABLE modulo3.buffers
    ADD CONSTRAINT chk_buffer_horas_positivas
        CHECK (horas_buffer IS NULL OR horas_buffer > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: estados_conectividad
-- ──────────────────────────────────────────────────────────────

-- [RF-60] snr_db: relación señal-ruido en rango físico plausible
-- LoRaWAN SNR típico: -20 a +10 dB (valores fuera son errores de sensor)
ALTER TABLE modulo3.estados_conectividad
    ADD CONSTRAINT chk_conectividad_snr_rango
        CHECK (snr_db BETWEEN -30 AND 20);

-- [RF-60] duracion_seg no negativa cuando está definida
ALTER TABLE modulo3.estados_conectividad
    ADD CONSTRAINT chk_conectividad_duracion_no_negativa
        CHECK (duracion_seg IS NULL OR duracion_seg >= 0);

-- [RF-60] rssi_dbm en rango físico válido para LoRaWAN
-- Rango típico: -150 a 0 dBm (positivo sería físicamente imposible)
ALTER TABLE modulo3.estados_conectividad
    ADD CONSTRAINT chk_conectividad_rssi_rango
        CHECK (rssi_dbm IS NULL OR rssi_dbm BETWEEN -150 AND 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: alertas_telemetria
-- ──────────────────────────────────────────────────────────────

-- [RF-57] valor_detectado no negativo (magnitud física)
ALTER TABLE modulo3.alertas_telemetria
    ADD CONSTRAINT chk_alerta_valor_no_negativo
        CHECK (valor_detectado >= 0);

-- [RF-57] latencia_generacion_ms no negativa cuando está definida
ALTER TABLE modulo3.alertas_telemetria
    ADD CONSTRAINT chk_alerta_latencia_no_negativa
        CHECK (latencia_generacion_ms IS NULL
               OR latencia_generacion_ms >= 0);

-- [RF-57] Coherencia reconocimiento:
-- si reconocida_por está definido, la fecha también debe estarlo
ALTER TABLE modulo3.alertas_telemetria
    ADD CONSTRAINT chk_alerta_reconocimiento_coherente
        CHECK (
            (reconocida_por IS NULL AND fecha_reconocimeinot IS NULL)
            OR (reconocida_por IS NOT NULL AND fecha_reconocimeinot IS NOT NULL)
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: eventos_edge_computing
-- ──────────────────────────────────────────────────────────────

-- [RF-55] Latencia de procesamiento no negativa
ALTER TABLE modulo3.eventos_edge_computing
    ADD CONSTRAINT chk_edge_latencia_no_negativa
        CHECK (latencia_ms IS NULL OR latencia_ms >= 0);

-- [RF-55] SLA de Edge: latencia ≤ 500 ms (Restricción explícita RF-55)
-- "El procesamiento de cada medición debe ejecutarse en ≤ 500 ms"
-- Se declara NOT VALID para no rechazar datos históricos que
-- pudieran haberse generado fuera de condiciones normales.
ALTER TABLE modulo3.eventos_edge_computing
    ADD CONSTRAINT chk_edge_cumple_sla_500ms
        CHECK (latencia_ms IS NULL OR latencia_ms <= 500)
        NOT VALID;
ALTER TABLE modulo3.eventos_edge_computing
    VALIDATE CONSTRAINT chk_edge_cumple_sla_500ms;

-- [RF-55] Coherencia entre cumple_sla y latencia_ms
ALTER TABLE modulo3.eventos_edge_computing
    ADD CONSTRAINT chk_edge_sla_coherente
        CHECK (
            latencia_ms IS NULL
            OR cumple_sla IS NULL
            OR (cumple_sla = true  AND latencia_ms <= 500)
            OR (cumple_sla = false AND latencia_ms > 500)
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: transmiciones_mqqt
-- ──────────────────────────────────────────────────────────────

-- [RF-53] QoS MQTT: solo valores 0, 1 o 2 (estándar MQTT)
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_qos_valido
        CHECK (qos IN (0, 1, 2));

-- [RF-53] Payload no puede ser de tamaño negativo
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_payload_no_negativo
        CHECK (payloads_bytes IS NULL OR payloads_bytes >= 0);

-- [RF-53] intentos >= 1 (al menos un intento de envío)
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_intentos_positivos
        CHECK (intentos >= 1);

-- [RF-53] rssi_dbm en rango físico válido
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_rssi_rango
        CHECK (rssi_dbm IS NULL OR rssi_dbm BETWEEN -150 AND 0);

-- [RF-53] snr_db en rango físico válido
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_snr_rango
        CHECK (snr_db IS NULL OR snr_db BETWEEN -30 AND 20);

-- [RF-53] frecuencia_mhz en rango LoRaWAN válido para Colombia
-- Banda ISM 863-870 MHz (ITU Región 1)
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_frecuencia_lorawan
        CHECK (frecuencia_mhz IS NULL
               OR frecuencia_mhz BETWEEN 863.0 AND 870.0);

-- [RF-53] spreading_factor en rango LoRaWAN (SF7-SF12)
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_spreading_factor_valido
        CHECK (spreading_factor IS NULL
               OR spreading_factor BETWEEN 7 AND 12);

-- [RF-53] Coherencia estado/error:
-- estado EXITO no debe tener error_descripcion
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_exito_sin_error
        CHECK (
            estado IS NULL
            OR estado != 'EXITO'
            OR error_descripcion IS NULL
        );

-- [RF-53] topic no puede ser cadena vacía
ALTER TABLE modulo3.transmiciones_mqqt
    ADD CONSTRAINT chk_mqtt_topic_no_vacio
        CHECK (char_length(trim(topic)) > 0);


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS DIFERIDOS (NOT VALID + VALIDATE)
-- Pueden fallar con datos previos; se crean diferidos.
-- ================================================================

-- [RF-53, Fase 3] Timestamp de captura no debe ser futuro
-- "timestamp_captura ≤ hora actual del servidor"
ALTER TABLE modulo3.lecturas_sensores
    ADD CONSTRAINT chk_lectura_captura_no_futura
        CHECK (fecha_captura <= NOW())
        NOT VALID;
ALTER TABLE modulo3.lecturas_sensores
    VALIDATE CONSTRAINT chk_lectura_captura_no_futura;

-- [RF-53] Timestamp de captura de telemetría no futuro
ALTER TABLE modulo3.telemetrias
    ADD CONSTRAINT chk_telemetria_captura_no_futura
        CHECK (timestamp_captura <= NOW())
        NOT VALID;
ALTER TABLE modulo3.telemetrias
    VALIDATE CONSTRAINT chk_telemetria_captura_no_futura;

-- [RF-54] fecha_sincronizacion no puede ser anterior a fecha_captura
-- (un dato no puede sincronizarse antes de ser capturado)
ALTER TABLE modulo3.buffers
    ADD CONSTRAINT chk_buffer_sync_posterior_captura
        CHECK (
            fecha_sincronizacion IS NULL
            OR fecha_sincronizacion >= fecha_captura
        )
        NOT VALID;
ALTER TABLE modulo3.buffers
    VALIDATE CONSTRAINT chk_buffer_sync_posterior_captura;

-- [RF-60] fecha_registro de conectividad no futura
ALTER TABLE modulo3.estados_conectividad
    ADD CONSTRAINT chk_conectividad_fecha_no_futura
        CHECK (fecha_registro <= NOW())
        NOT VALID;
ALTER TABLE modulo3.estados_conectividad
    VALIDATE CONSTRAINT chk_conectividad_fecha_no_futura;

-- [RF-57] fecha_creacion de alerta no futura
ALTER TABLE modulo3.alertas_telemetria
    ADD CONSTRAINT chk_alerta_fecha_no_futura
        CHECK (fecha_creacion <= NOW())
        NOT VALID;
ALTER TABLE modulo3.alertas_telemetria
    VALIDATE CONSTRAINT chk_alerta_fecha_no_futura;

-- [RF-57] fecha_reconocimeinot posterior a fecha_creacion
ALTER TABLE modulo3.alertas_telemetria
    ADD CONSTRAINT chk_alerta_reconocimiento_posterior_creacion
        CHECK (
            fecha_reconocimeinot IS NULL
            OR fecha_reconocimeinot >= fecha_creacion
        )
        NOT VALID;
ALTER TABLE modulo3.alertas_telemetria
    VALIDATE CONSTRAINT chk_alerta_reconocimiento_posterior_creacion;


-- ================================================================
-- PARTE 4 — ÍNDICES ÚNICOS PARCIALES Y DE DESEMPEÑO
-- ================================================================

-- [RF-53] Detección de duplicados: clave única de idempotencia
-- Restricción explícita RF-53 Fase 6:
-- "Se considera duplicado cuando coincide (sensor_id, timestamp_captura)"
-- Índice parcial: solo sobre lecturas válidas para no bloquear errores
CREATE UNIQUE INDEX IF NOT EXISTS uix_lectura_sensor_unicidad
    ON modulo3.lecturas_sensores (id_sensor, fecha_captura)
    WHERE es_valida = true;

-- [RF-53] Detección de duplicados en telemetrias:
-- "(sensor_id, tipo_variable, timestamp_captura, origen)" de RF-53 Fase 6
-- La variable se resuelve a través de id_variable
CREATE UNIQUE INDEX IF NOT EXISTS uix_telemetria_idempotencia
    ON modulo3.telemetrias (id_sensor, id_variable, timestamp_captura, origen)
    WHERE estado_calidad IN ('LECTURA_VALIDA', 'FUERA_DE_RANGO', 'ERROR_CALIBRACION');

-- [RF-57] Solo puede existir una regla activa por tipo_sensor y nivel
-- para una misma finca (evita duplicidad de reglas activas)
CREATE UNIQUE INDEX IF NOT EXISTS uix_regla_activa_sensor_nivel_finca
    ON modulo3.reglas_alertas (tipo_sensor, nivel_alerta, id_finca)
    WHERE es_activa = true AND id_finca IS NOT NULL;

-- Índice de desempeño: consulta de lecturas por sensor y fecha (RF-59)
CREATE INDEX IF NOT EXISTS idx_lecturas_sensor_fecha
    ON modulo3.lecturas_sensores (id_sensor, fecha_captura DESC);

-- Índice de desempeño: consulta de telemetrías por sensor y timestamp (RF-59)
CREATE INDEX IF NOT EXISTS idx_telemetrias_sensor_timestamp
    ON modulo3.telemetrias (id_sensor, timestamp_captura DESC);

-- Índice de desempeño: consulta de alertas activas por dispositivo (RF-58)
CREATE INDEX IF NOT EXISTS idx_alertas_dispositivo_nivel
    ON modulo3.alertas_telemetria (id_dispositivo_iot, nivel, fecha_creacion DESC)
    WHERE reconocida_por IS NULL;

-- Índice de desempeño: estado de conectividad por dispositivo (RF-60)
CREATE INDEX IF NOT EXISTS idx_conectividad_dispositivo_fecha
    ON modulo3.estados_conectividad (id_dispositivo_iot, fecha_registro DESC);

-- Índice de desempeño: buffers pendientes de sincronización (RF-54)
CREATE INDEX IF NOT EXISTS idx_buffers_pendientes
    ON modulo3.buffers (id_dispositivo, fecha_captura ASC)
    WHERE es_sincronizado = false;

-- Índice de desempeño: eventos Edge por dispositivo y tipo (RF-55)
CREATE INDEX IF NOT EXISTS idx_edge_dispositivo_tipo_fecha
    ON modulo3.eventos_edge_computing (id_dispositivo_iot, tipo_evento, fecha_registro DESC);

-- Índice de desempeño: transmisiones por dispositivo y estado (RF-53)
CREATE INDEX IF NOT EXISTS idx_transmisiones_dispositivo_estado
    ON modulo3.transmiciones_mqqt (id_dispositivo_iot, estado, fecha_transmision DESC);


-- ================================================================
-- REFERENCIA: CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (no se re-ejecutan; listados para consulta)
-- ================================================================
--
-- Claves Primarias (ya en backup):
--   alertas_telemetria_pkey
--   buffers_pkey
--   estados_conectividad_pkey
--   eventos_edge_computing_pkey
--   lecturas_sensores_pkey
--   reglas_alertas_pkey
--   telemetrias_pkey
--   transmiciones_mqqt_pkey
--
-- Claves Foráneas (ya en backup — SIN NOT VALID, ya activas):
--   fk_alerta_telemetria_lectura_sensor
--     alertas_telemetria(id_lectura_sensor) → lecturas_sensores
--   fk_alerta_telemetria_regla
--     alertas_telemetria(id_regla_alerta) → reglas_alertas
--   fk_alertas_telemetria_dispositivo_iot (ON DELETE CASCADE)
--     alertas_telemetria(id_dispositivo_iot) → modulo9.dispositivos_iot
--   fk_alertas_telemetria_sensor (ON DELETE CASCADE)
--     alertas_telemetria(id_sensor) → modulo9.sensores
--   fk_dispositivo_iot_id
--     lecturas_sensores(id_dispositivo_iot) → modulo9.dispositivos_iot
--   fk_dispositovo_id (typo en DDL)
--     buffers(id_dispositivo) → modulo9.dispositivos_iot
--   fk_estado_conectividad_dispositivo_iot
--     estados_conectividad(id_dispositivo_iot) → modulo9.dispositivos_iot
--   fk_evento_edge_computing_alerta_telemetria
--     eventos_edge_computing(id_alerta_telemetria) → alertas_telemetria
--   fk_evento_edge_computing_dispositivo_iot
--     eventos_edge_computing(id_dispositivo_iot) → modulo9.dispositivos_iot
--   fk_lectura_sensor_dispositivo_iot
--     lecturas_sensores(id_dispositivo_iot) → modulo9.dispositivos_iot
--   fk_lectura_sensor_id
--     lecturas_sensores(id_sensor) → modulo9.sensores
--   fk_sensor_id (telemetrias)
--     telemetrias(id_sensor) → modulo9.sensores
--   fk_sensor_id (buffers)
--     buffers(id_sensor) → modulo9.sensores
--   fk_transmiciones_mqqt_dispositivo_iot
--     transmiciones_mqqt(id_dispositivo_iot) → modulo9.dispositivos_iot
--   fk_variable_id
--     telemetrias(id_variable) → modulo9.variables_ambientales
--   fk_regla_alerta_finca
--     reglas_alertas(id_finca) → modulo9.fincas
--
-- UQs (ya en backup): ninguna
-- CHECKs (ya en backup): ninguno
-- ================================================================
