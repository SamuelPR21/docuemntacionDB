-- ==============================================================================
-- Archivo: procedimientos_modulo3.sql
-- Descripción: Procedimientos almacenados para el Módulo 3 (IoT y Edge Computing)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-53: Ingesta de Telemetría
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo3.sp_ingestar_telemetria(
    p_id_sensor INT,
    p_id_variable INT,
    p_id_dispositivo_iot INT,
    p_valor_crudo NUMERIC(10,4),
    p_valor_ajustado NUMERIC(10,4),
    p_timestamp_captura TIMESTAMP WITH TIME ZONE,
    p_timestamp_envio TIMESTAMP WITH TIME ZONE,
    p_origen modulo3.enum_telemetria_origen,
    p_estado_calidad modulo3.enum_telemetria_estado_calidad,
    p_calibrado BOOLEAN,
    p_latitud NUMERIC(9,6),
    p_longitud NUMERIC(9,6),
    p_metadatos JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_telemetria INT;
BEGIN
    -- Regla de Coherencia Temporal: no puede ser futuro
    IF p_timestamp_captura > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Inconsistencia temporal: El timestamp de captura es superior a la hora actual del servidor.';
    END IF;

    -- Regla de Duplicidad de Datos
    IF EXISTS (
        SELECT 1 FROM modulo3.telemetrias 
        WHERE id_sensor = p_id_sensor
          AND id_variable = p_id_variable
          AND timestamp_captura = p_timestamp_captura
          AND origen = p_origen
    ) THEN
        -- Se registra en bitácora (en un sistema real se llama a auditoría)
        RAISE NOTICE 'DUPLICATE_EVENT: El datagrama (sensor %, variable %, captura %) ya existe.', p_id_sensor, p_id_variable, p_timestamp_captura;
        RETURN; -- Simplemente se descarta y no se persiste
    END IF;

    -- Si estado_calidad es ERROR_CALIBRACION, se guarda como diagnóstico
    -- Si es FUERA_DE_RANGO, se guarda pero no desencadena alertas automáticas
    
    -- Inserción de la telemetría validada
    INSERT INTO modulo3.telemetrias (
        id_sensor, id_variable, id_dispositivo_iot, valor_crudo, valor_ajustado,
        timestamp_captura, timestamp_envio, timestamp_procesamiento, origen,
        estado_calidad, calibrado, latitud, longitud, metadatos
    ) VALUES (
        p_id_sensor, p_id_variable, p_id_dispositivo_iot, p_valor_crudo, COALESCE(p_valor_ajustado, p_valor_crudo),
        p_timestamp_captura, p_timestamp_envio, CURRENT_TIMESTAMP, p_origen,
        p_estado_calidad, p_calibrado, p_latitud, p_longitud, p_metadatos
    ) RETURNING id_telemetria INTO v_id_telemetria;

    -- En este punto, un trigger o el motor de alertas procesará reglas de negocio
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-55: Registro de Eventos Edge Computing
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo3.sp_registrar_evento_edge(
    p_id_dispositivo_iot INT,
    p_tipo_evento VARCHAR,
    p_descripcion TEXT,
    p_severidad VARCHAR,
    p_datos_contexto JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Inserción del evento técnico
    INSERT INTO modulo3.eventos_edge_computing (
        id_dispositivo_iot, tipo_evento, descripcion, severidad,
        fecha_ocurrencia, fecha_recepcion, datos_contexto
    ) VALUES (
        p_id_dispositivo_iot, p_tipo_evento, p_descripcion, p_severidad,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, p_datos_contexto
    );

    -- Registrar auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        NULL, -- El sistema Edge usualmente no tiene un ID de usuario humano directo
        NULL,
        6, -- EVENTO_SISTEMA (Asumido)
        'Modulo 3',
        'TECNICO',
        'Evento Edge detectado: ' || p_tipo_evento || ' en dispositivo ' || p_id_dispositivo_iot,
        'EXITOSO',
        'ACTIVO',
        jsonb_build_object(
            'tipo', p_tipo_evento,
            'severidad', p_severidad,
            'contexto', p_datos_contexto
        )
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
