-- =============================================================================
-- MÓDULO 3 — TELEMETRÍA E IOT CON OPERACIÓN EDGE
-- Archivo: triggers_modulo3_v1_0.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo3
-- Motor: PostgreSQL
-- Versión: 1.0
-- =============================================================================

-- ÍNDICE
-- TRG-M03-01  Inmutabilidad de registros de telemetría (UPDATE y DELETE)
-- TRG-M03-02  Validación de timestamps no futuros en telemetría (INSERT)
-- TRG-M03-03  Validación de estado de calidad persistible en telemetría
-- TRG-M03-04  Coherencia entre calibrado y valor_ajustado
-- TRG-M03-05  Ventana máxima de 72 h para datos de BUFFER_LOCAL en telemetría
-- TRG-M03-06  Valor crudo no nulo en telemetría
-- TRG-M03-07  Inmutabilidad de alertas de telemetría (DELETE)
-- TRG-M03-08  Inmutabilidad de campos históricos de alertas (UPDATE)
-- TRG-M03-09  Timestamps no futuros en alertas de telemetría (INSERT)
-- TRG-M03-10  Coherencia de campos de reconocimiento en alertas
-- TRG-M03-11  Coherencia de umbrales min/max en reglas de alertas
-- TRG-M03-12  Fecha de captura no futura en buffer local (INSERT)
-- TRG-M03-13  Inmutabilidad de datos originales en buffer (UPDATE)
-- TRG-M03-14  Ventana máxima de 72 h y cálculo de horas_buffer (INSERT)
-- TRG-M03-15  Coherencia del estado de sincronización en buffer (UPDATE)
-- TRG-M03-16  Cálculo automático de cumple_sla en eventos Edge (INSERT)
-- TRG-M03-17  Inmutabilidad de eventos de Edge Computing (UPDATE y DELETE)
-- TRG-M03-18  Fecha de registro no futura en estados de conectividad (INSERT)
-- TRG-M03-19  Inmutabilidad del historial de estados de conectividad (UPDATE y DELETE)
-- TRG-M03-20  Validación de intentos de transmisión positivos y dentro del límite
-- TRG-M03-21  Fecha de transmisión MQTT no futura (INSERT)
-- TRG-M03-22  Timestamps coherentes en lecturas de sensores (INSERT)
-- TRG-M03-23  Inmutabilidad de lecturas de sensores (UPDATE y DELETE)

-- =============================================================================
-- TRG-M03-01 — Inmutabilidad de registros de telemetría
-- Tabla:  modulo3.telemetrias
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_telemetria_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Los registros de telemetría son inmutables. No se permite eliminar '
            'lecturas almacenadas. RF-53.'
        USING ERRCODE = 'P0001';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'Los registros de telemetría son inmutables. No se permite modificar '
            'lecturas almacenadas. RF-53.'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_telemetria_inmutable
BEFORE UPDATE OR DELETE ON modulo3.telemetrias
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_telemetria_inmutable();

-- =============================================================================
-- TRG-M03-02 — Validación de timestamps no futuros en telemetría
-- Tabla:  modulo3.telemetrias
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_telemetria_timestamp_no_futuro()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.timestamp_captura > NOW() THEN
        RAISE EXCEPTION
            'El timestamp_captura [%] es posterior a la hora actual del servidor. '
            'Dato rechazado. (ERROR_TIEMPO -- RF-53 Fase 3)',
            NEW.timestamp_captura
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.timestamp_envio > NOW() THEN
        RAISE EXCEPTION
            'El timestamp_envio [%] es posterior a la hora actual del servidor. '
            'Dato rechazado. (RF-53)',
            NEW.timestamp_envio
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_telemetria_timestamp_no_futuro
BEFORE INSERT ON modulo3.telemetrias
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_telemetria_timestamp_no_futuro();

-- =============================================================================
-- TRG-M03-03 — Validación de estado de calidad persistible en telemetría
-- Tabla:  modulo3.telemetrias
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_telemetria_estado_calidad_valido()
RETURNS TRIGGER AS $$
BEGIN
    -- Según RF-53 Fase 9: Solo se persisten en BD principal:
    -- LECTURA_VALIDA, FUERA_DE_RANGO, ERROR_CALIBRACION
    -- Los demás estados se registran ÚNICAMENTE en bitácora.
    IF NEW.estado_calidad NOT IN (
        'LECTURA_VALIDA',
        'FUERA_DE_RANGO',
        'ERROR_CALIBRACION'
    ) THEN
        RAISE EXCEPTION
            'El estado_calidad [%] no puede persistirse en la base de datos principal. '
            'Solo LECTURA_VALIDA, FUERA_DE_RANGO y ERROR_CALIBRACION son persistibles. '
            'Los demás estados van únicamente a bitácora. (RF-53 Fase 9)',
            NEW.estado_calidad
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_telemetria_estado_calidad_valido
BEFORE INSERT ON modulo3.telemetrias
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_telemetria_estado_calidad_valido();

-- =============================================================================
-- TRG-M03-04 — Coherencia entre calibrado y valor_ajustado
-- Tabla:  modulo3.telemetrias
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_telemetria_calibracion_coherencia()
RETURNS TRIGGER AS $$
BEGIN
    -- Si calibrado = true, valor_ajustado NO puede ser nulo
    IF NEW.calibrado = TRUE AND NEW.valor_ajustado IS NULL THEN
        RAISE EXCEPTION
            'Incoherencia: calibrado = true pero valor_ajustado es NULL. '
            'Si el dato fue calibrado debe tener valor_ajustado. (RF-53 Fase 7)'
        USING ERRCODE = 'P0001';
    END IF;

    -- Si calibrado = false y estado = ERROR_CALIBRACION,
    -- el valor_ajustado debería ser nulo o igual al crudo (no transformado).
    -- Esta validación es informativa: no bloqueamos, solo garantizamos coherencia lógica.
    -- El rechazo completo por ERROR_CALIBRACION es responsabilidad del backend.
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_telemetria_calibracion_coherencia
BEFORE INSERT ON modulo3.telemetrias
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_telemetria_calibracion_coherencia();

-- =============================================================================
-- TRG-M03-05 — Ventana máxima de 72 h para datos de BUFFER_LOCAL en telemetría
-- Tabla:  modulo3.telemetrias
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_telemetria_buffer_ventana_maxima()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo aplica para datos de BUFFER_LOCAL
    IF NEW.origen = 'BUFFER_LOCAL' THEN
        -- Máximo 72 horas de antigüedad en datos de buffer
        IF NEW.timestamp_captura < (NOW() - INTERVAL '72 hours') THEN
            RAISE EXCEPTION
                'Dato de BUFFER_LOCAL rechazado: timestamp_captura [%] supera la ventana máxima '
                'de 72 horas permitida para sincronización diferida. (RF-53 Fase 3.1)',
                NEW.timestamp_captura
            USING ERRCODE = 'P0001';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_telemetria_buffer_ventana_maxima
BEFORE INSERT ON modulo3.telemetrias
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_telemetria_buffer_ventana_maxima();

-- =============================================================================
-- TRG-M03-06 — Valor crudo no nulo en telemetría
-- Tabla:  modulo3.telemetrias
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_telemetria_valor_valido()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.valor_crudo IS NULL THEN
        RAISE EXCEPTION
            'El campo valor_crudo no puede ser nulo en un registro de telemetría. (RF-53)'
        USING ERRCODE = 'P0001';
    END IF;

    -- Para variables que admiten negativos (temperatura ambiente puede ser < 0)
    -- No se bloquea por signo aquí; eso es dominio del catálogo I3P-1 (backend).
    -- Solo garantizamos que el valor sea numérico (ya garantizado por tipo NUMERIC).
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_telemetria_valor_valido
BEFORE INSERT ON modulo3.telemetrias
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_telemetria_valor_valido();

-- =============================================================================
-- TRG-M03-07 — Inmutabilidad de alertas de telemetría (DELETE)
-- Tabla:  modulo3.alertas_telemetria
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_alertas_telemetria_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'Las alertas de telemetría son inmutables. No se permite eliminar registros de alerta. '
        'Solo puede actualizarse el estado. (RF-57 Restricciones)'
    USING ERRCODE = 'P0001';

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alertas_telemetria_inmutable
BEFORE DELETE ON modulo3.alertas_telemetria
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_alertas_telemetria_inmutable();

-- =============================================================================
-- TRG-M03-08 — Inmutabilidad de campos históricos de alertas
-- Tabla:  modulo3.alertas_telemetria
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_alertas_campos_historicos_inmutables()
RETURNS TRIGGER AS $$
BEGIN
    -- Campos históricos que NO pueden modificarse
    IF NEW.id_regla_alerta   <> OLD.id_regla_alerta   OR
       NEW.id_lectura_sensor <> OLD.id_lectura_sensor  OR
       NEW.id_sensor         <> OLD.id_sensor          OR
       NEW.id_dispositivo_iot <> OLD.id_dispositivo_iot OR
       NEW.valor_detectado   <> OLD.valor_detectado    OR
       NEW.mensaje           <> OLD.mensaje            OR
       NEW.es_generada_edge  <> OLD.es_generada_edge   OR
       NEW.fecha_creacion    <> OLD.fecha_creacion
    THEN
        RAISE EXCEPTION
            'El contenido histórico de la alerta es inmutable. Solo se permite '
            'actualizar el estado, reconocida_por y fecha_reconocimiento. (RF-57 Restricciones)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alertas_campos_historicos_inmutables
BEFORE UPDATE ON modulo3.alertas_telemetria
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_alertas_campos_historicos_inmutables();

-- =============================================================================
-- TRG-M03-09 — Timestamps no futuros en alertas de telemetría
-- Tabla:  modulo3.alertas_telemetria
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_alertas_timestamp_no_futuro()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_creacion > NOW() THEN
        RAISE EXCEPTION
            'La fecha_creacion de la alerta [%] no puede ser futura. (RF-57)',
            NEW.fecha_creacion
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.fecha_reconocimeinot IS NOT NULL AND NEW.fecha_reconocimeinot > NOW() THEN
        RAISE EXCEPTION
            'La fecha_reconocimiento de la alerta [%] no puede ser futura. (RF-57)',
            NEW.fecha_reconocimeinot
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alertas_timestamp_no_futuro
BEFORE INSERT ON modulo3.alertas_telemetria
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_alertas_timestamp_no_futuro();

-- =============================================================================
-- TRG-M03-10 — Coherencia de campos de reconocimiento en alertas
-- Tabla:  modulo3.alertas_telemetria
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_alertas_reconocimiento_coherencia()
RETURNS TRIGGER AS $$
BEGIN
    -- Si se reconoce, debe haber fecha
    IF NEW.reconocida_por IS NOT NULL AND NEW.fecha_reconocimeinot IS NULL THEN
        RAISE EXCEPTION
            'Si reconocida_por está definido, fecha_reconocimiento es obligatoria. (RF-57 Fase 9)'
        USING ERRCODE = 'P0001';
    END IF;

    -- Si hay fecha, debe haber responsable
    IF NEW.fecha_reconocimeinot IS NOT NULL AND NEW.reconocida_por IS NULL THEN
        RAISE EXCEPTION
            'Si fecha_reconocimiento está definida, reconocida_por es obligatorio. (RF-57 Fase 9)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alertas_reconocimiento_coherencia
BEFORE INSERT OR UPDATE ON modulo3.alertas_telemetria
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_alertas_reconocimiento_coherencia();

-- =============================================================================
-- TRG-M03-11 — Coherencia de umbrales min/max en reglas de alertas
-- Tabla:  modulo3.reglas_alertas
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_reglas_alertas_umbral_coherencia()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.umbral_min IS NOT NULL
       AND NEW.umbral_max IS NOT NULL
       AND NEW.umbral_min >= NEW.umbral_max THEN
        RAISE EXCEPTION
            'umbral_min [%] debe ser estrictamente menor que umbral_max [%] en la regla de alerta. '
            '(RF-57 Fase 5)',
            NEW.umbral_min, NEW.umbral_max
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reglas_alertas_umbral_coherencia
BEFORE INSERT OR UPDATE ON modulo3.reglas_alertas
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_reglas_alertas_umbral_coherencia();

-- =============================================================================
-- TRG-M03-12 — Fecha de captura no futura en buffer local
-- Tabla:  modulo3.buffers
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_buffer_fecha_captura_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_captura > NOW() THEN
        RAISE EXCEPTION
            'La fecha_captura del dato en buffer [%] no puede ser futura. '
            '(RF-54 / RF-53 Fase 3)',
            NEW.fecha_captura
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_buffer_fecha_captura_no_futura
BEFORE INSERT ON modulo3.buffers
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_buffer_fecha_captura_no_futura();

-- =============================================================================
-- TRG-M03-13 — Inmutabilidad de datos originales en buffer
-- Tabla:  modulo3.buffers
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_buffer_registro_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    -- Los campos del dato original son inmutables
    IF NEW.id_dispositivo   <> OLD.id_dispositivo   OR
       NEW.id_sensor        <> OLD.id_sensor         OR
       NEW.payload_row::text <> OLD.payload_row::text OR
       NEW.fecha_captura    <> OLD.fecha_captura     OR
       NEW.fecha_creacion   <> OLD.fecha_creacion
    THEN
        RAISE EXCEPTION
            'Los datos originales almacenados en buffer son inmutables. '
            'Solo se permite actualizar es_sincronizado, fecha_sincronizacion '
            'e intentos_sincronizacion. (RF-54)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_buffer_registro_inmutable
BEFORE UPDATE ON modulo3.buffers
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_buffer_registro_inmutable();

-- =============================================================================
-- TRG-M03-14 — Ventana máxima de 72 h y cálculo de horas_buffer en buffer
-- Tabla:  modulo3.buffers
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_buffer_ventana_maxima_72h()
RETURNS TRIGGER AS $$
DECLARE
    v_horas_diferencia NUMERIC;
BEGIN
    v_horas_diferencia := EXTRACT(EPOCH FROM (NOW() - NEW.fecha_captura)) / 3600.0;

    -- El campo horas_buffer se calcula y valida
    NEW.horas_buffer := FLOOR(v_horas_diferencia);

    -- Datos con más de 72 horas no pueden almacenarse en buffer (ya son inválidos)
    IF v_horas_diferencia > 72 THEN
        RAISE EXCEPTION
            'Dato rechazado: la antigüedad del dato [% horas] supera la ventana máxima '
            'de 72 horas de buffer permitida. (RF-54 / RF-53 Fase 3.1)',
            ROUND(v_horas_diferencia::numeric, 2)
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_buffer_ventana_maxima_72h
BEFORE INSERT ON modulo3.buffers
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_buffer_ventana_maxima_72h();

-- =============================================================================
-- TRG-M03-15 — Coherencia del estado de sincronización en buffer
-- Tabla:  modulo3.buffers
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_buffer_sincronizacion_coherencia()
RETURNS TRIGGER AS $$
BEGIN
    -- Si se marca como sincronizado, debe tener fecha de sincronización
    IF NEW.es_sincronizado = TRUE AND NEW.fecha_sincronizacion IS NULL THEN
        RAISE EXCEPTION
            'Si es_sincronizado = true, fecha_sincronizacion es obligatoria. (RF-54)'
        USING ERRCODE = 'P0001';
    END IF;

    -- Si se revierte el estado de sincronizado a no sincronizado, no está permitido
    IF OLD.es_sincronizado = TRUE AND NEW.es_sincronizado = FALSE THEN
        RAISE EXCEPTION
            'No se puede revertir el estado de sincronización de TRUE a FALSE. '
            'La sincronización es un estado final e irreversible. (RF-54)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_buffer_sincronizacion_coherencia
BEFORE UPDATE ON modulo3.buffers
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_buffer_sincronizacion_coherencia();

-- =============================================================================
-- TRG-M03-16 — Cálculo automático de cumple_sla en eventos Edge Computing
-- Tabla:  modulo3.eventos_edge_computing
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_eventos_edge_sla_automatico()
RETURNS TRIGGER AS $$
BEGIN
    -- Calcular automáticamente cumple_sla basado en latencia
    IF NEW.latencia_ms IS NOT NULL THEN
        NEW.cumple_sla := (NEW.latencia_ms <= 500);
    ELSE
        -- Si no hay latencia registrada, se considera no evaluable
        NEW.cumple_sla := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_eventos_edge_sla_automatico
BEFORE INSERT ON modulo3.eventos_edge_computing
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_eventos_edge_sla_automatico();

-- =============================================================================
-- TRG-M03-17 — Inmutabilidad de eventos de Edge Computing
-- Tabla:  modulo3.eventos_edge_computing
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_eventos_edge_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Los eventos de Edge Computing son inmutables y no pueden eliminarse. '
            '(RF-55 / RF-63)'
        USING ERRCODE = 'P0001';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'Los eventos de Edge Computing son inmutables y no pueden modificarse. '
            '(RF-55 / RF-63)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_eventos_edge_inmutable
BEFORE UPDATE OR DELETE ON modulo3.eventos_edge_computing
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_eventos_edge_inmutable();

-- =============================================================================
-- TRG-M03-18 — Fecha de registro no futura en estados de conectividad
-- Tabla:  modulo3.estados_conectividad
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_estados_conectividad_fecha_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_registro > NOW() THEN
        RAISE EXCEPTION
            'La fecha_registro del estado de conectividad [%] no puede ser futura. (RF-60)',
            NEW.fecha_registro
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estados_conectividad_fecha_no_futura
BEFORE INSERT ON modulo3.estados_conectividad
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_estados_conectividad_fecha_no_futura();

-- =============================================================================
-- TRG-M03-19 — Inmutabilidad del historial de estados de conectividad
-- Tabla:  modulo3.estados_conectividad
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_estados_conectividad_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'El historial de estados de conectividad es inmutable y no puede eliminarse. '
            '(RF-60 Restricciones)'
        USING ERRCODE = 'P0001';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'El historial de estados de conectividad es inmutable y no puede modificarse. '
            '(RF-60 Restricciones)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estados_conectividad_inmutable
BEFORE UPDATE OR DELETE ON modulo3.estados_conectividad
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_estados_conectividad_inmutable();

-- =============================================================================
-- TRG-M03-20 — Validación de intentos de transmisión positivos y dentro del límite
-- Tabla:  modulo3.transmiciones_mqqt
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_transmisiones_intentos_positivos()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.intentos < 0 THEN
        RAISE EXCEPTION
            'El número de intentos de transmisión no puede ser negativo. Valor: %. (RF-56)',
            NEW.intentos
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.intentos > 5 THEN
        RAISE EXCEPTION
            'El número de intentos de transmisión supera el máximo permitido de 5. '
            'Valor: %. Si se superan 5 intentos, el paquete debe almacenarse en buffer '
            '(RF-54). (RF-56 Restricciones)',
            NEW.intentos
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transmisiones_intentos_positivos
BEFORE INSERT OR UPDATE ON modulo3.transmiciones_mqqt
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_transmisiones_intentos_positivos();

-- =============================================================================
-- TRG-M03-21 — Fecha de transmisión MQTT no futura
-- Tabla:  modulo3.transmiciones_mqqt
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_transmisiones_fecha_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_transmision > NOW() THEN
        RAISE EXCEPTION
            'La fecha_transmision [%] no puede ser futura. (RF-56 Restricciones)',
            NEW.fecha_transmision
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transmisiones_fecha_no_futura
BEFORE INSERT ON modulo3.transmiciones_mqqt
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_transmisiones_fecha_no_futura();

-- =============================================================================
-- TRG-M03-22 — Timestamps coherentes en lecturas de sensores
-- Tabla:  modulo3.lecturas_sensores
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_lecturas_sensores_timestamp_no_futuro()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_captura > NOW() THEN
        RAISE EXCEPTION
            'La fecha_captura de la lectura del sensor [%] no puede ser futura. '
            '(RF-53 Fase 3)',
            NEW.fecha_captura
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.fecha_recepcion > NOW() THEN
        RAISE EXCEPTION
            'La fecha_recepcion de la lectura del sensor [%] no puede ser futura. (RF-53)',
            NEW.fecha_recepcion
        USING ERRCODE = 'P0001';
    END IF;

    -- La fecha_recepcion debe ser posterior o igual a fecha_captura
    IF NEW.fecha_recepcion < NEW.fecha_captura THEN
        RAISE EXCEPTION
            'La fecha_recepcion [%] no puede ser anterior a la fecha_captura [%]. (RF-53)',
            NEW.fecha_recepcion, NEW.fecha_captura
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lecturas_sensores_timestamp_no_futuro
BEFORE INSERT ON modulo3.lecturas_sensores
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_lecturas_sensores_timestamp_no_futuro();

-- =============================================================================
-- TRG-M03-23 — Inmutabilidad de lecturas de sensores
-- Tabla:  modulo3.lecturas_sensores
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo3.fn_trg_lecturas_sensores_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Las lecturas de sensores son inmutables y no pueden eliminarse. '
            '(RF-53 Restricciones)'
        USING ERRCODE = 'P0001';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'Las lecturas de sensores son inmutables y no pueden modificarse. '
            '(RF-53 Restricciones)'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lecturas_sensores_inmutable
BEFORE UPDATE OR DELETE ON modulo3.lecturas_sensores
FOR EACH ROW
EXECUTE FUNCTION modulo3.fn_trg_lecturas_sensores_inmutable();

-- =============================================================================
-- Total de funciones de trigger: 23
-- Total de triggers registrados: 23
-- =============================================================================