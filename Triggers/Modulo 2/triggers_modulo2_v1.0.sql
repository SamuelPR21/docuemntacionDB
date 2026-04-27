-- =============================================================================
-- MÓDULO 2 — GESTIÓN DE ACTIVOS BIOLÓGICOS
-- Archivo: modulo2_triggers.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo2
-- Motor: PostgreSQL
-- Versión: 1.0
-- =============================================================================

-- ÍNDICE
-- TRG-M2-01  Coherencia de tipo de activo (INDIVIDUAL vs POBLACIONAL)
-- TRG-M2-02  Estado inicial forzado a ACTIVO
-- TRG-M2-03  Validación de origen financiero y costo de adquisición
-- TRG-M2-04  Inmutabilidad de campos estructurales del activo
-- TRG-M2-05  Inicialización de métricas del activo poblacional
-- TRG-M2-06  Inmutabilidad de cantidad_inicial del lote
-- TRG-M2-07  Validación de transición de estado del activo biológico
-- TRG-M2-08  Unicidad de estado vigente por activo
-- TRG-M2-09  Bloqueo de modificación de activo en estado BAJA
-- TRG-M2-10  Validación de estado operativo para registro de eventos
-- TRG-M2-11  Coherencia temporal de eventos biológicos
-- TRG-M2-12  Validación de coherencia del evento de crecimiento por tipo de activo
-- TRG-M2-13  Recálculo automático de métricas del lote tras evento de crecimiento
-- TRG-M2-14  Validación de secuencia lógica del ciclo sanitario
-- TRG-M2-15  Validación de secuencia del ciclo reproductivo
-- TRG-M2-16  Prevención de duplicidad en eventos productivos
-- TRG-M2-17  Validación de cantidad de baja en lote
-- TRG-M2-18  Actualización automática de cantidad del lote tras baja
-- TRG-M2-19  Unicidad de fase activa por activo biológico
-- TRG-M2-20  Validación de no solapamiento temporal de fases
-- TRG-M2-21  Bloqueo de cambio de fase en activos no operativos
-- TRG-M2-22  Unicidad de asociación activa sensor-activo (tipo DIRECTA)
-- TRG-M2-23  Inmutabilidad del historial de estados
-- TRG-M2-24  Inmutabilidad de todos los eventos biológicos registrados
-- TRG-M2-25  Fecha de inicio de ciclo productivo válida
-- TRG-M2-26  Protección de eliminación física de activos biológicos

-- =============================================================================
-- TRG-M2-01 — Coherencia de tipo de activo (INDIVIDUAL vs POBLACIONAL)
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_activo_biologico_coherencia_tipo()
RETURNS TRIGGER AS $$
BEGIN
    -- Impedir que ambos campos estén presentes simultáneamente
    IF NEW.indentficador IS NOT NULL AND
       (NEW.atributos_dinamicos->>'cantidad_inicial') IS NOT NULL THEN
        RAISE EXCEPTION 'INVALID_COMBINATION: No se permite registrar identificador y cantidad_inicial simultáneamente. Tipo de activo: %.', NEW.tipo
        USING ERRCODE = 'P0201';
    END IF;

    IF NEW.tipo = 'INDIVIDUAL' THEN
        IF NEW.indentficador IS NULL OR TRIM(NEW.indentficador) = '' THEN
            RAISE EXCEPTION 'MISSING_FIELD: Para activos de tipo INDIVIDUAL el identificador es obligatorio.'
            USING ERRCODE = 'P0202';
        END IF;
        IF (NEW.atributos_dinamicos->>'cantidad_inicial') IS NOT NULL THEN
            RAISE EXCEPTION 'INVALID_COMBINATION: Para activos INDIVIDUAL el campo cantidad_inicial debe ser nulo.'
            USING ERRCODE = 'P0202';
        END IF;

    ELSIF NEW.tipo = 'POBLACIONAL' THEN
        IF (NEW.atributos_dinamicos->>'cantidad_inicial') IS NULL THEN
            RAISE EXCEPTION 'MISSING_FIELD: Para activos de tipo POBLACIONAL la cantidad_inicial es obligatoria.'
            USING ERRCODE = 'P0203';
        END IF;
        IF (NEW.atributos_dinamicos->>'cantidad_inicial')::INTEGER <= 0 THEN
            RAISE EXCEPTION 'INVALID_VALUE: La cantidad_inicial debe ser mayor a cero. Valor recibido: %.', NEW.atributos_dinamicos->>'cantidad_inicial'
            USING ERRCODE = 'P0203';
        END IF;
        IF NEW.indentficador IS NOT NULL THEN
            RAISE EXCEPTION 'INVALID_COMBINATION: Para activos POBLACIONAL el identificador debe ser nulo.'
            USING ERRCODE = 'P0203';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activo_biologico_coherencia_tipo
BEFORE INSERT ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_activo_biologico_coherencia_tipo();

-- =============================================================================
-- TRG-M2-02 — Estado inicial forzado a ACTIVO
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_activo_biologico_estado_inicial()
RETURNS TRIGGER AS $$
DECLARE
    v_id_estado_activo INTEGER;
BEGIN
    SELECT id_estado_activo_biologico INTO v_id_estado_activo
    FROM modulo2.estados_activos_biologicos
    WHERE UPPER(nombre) = 'ACTIVO'
    LIMIT 1;

    IF v_id_estado_activo IS NULL THEN
        RAISE EXCEPTION 'CONFIG_ERROR: El estado ACTIVO no existe en el catálogo de estados del activo biológico.'
        USING ERRCODE = 'P0204';
    END IF;

    NEW.id_estado := v_id_estado_activo;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activo_biologico_estado_inicial
BEFORE INSERT ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_activo_biologico_estado_inicial();

-- =============================================================================
-- TRG-M2-03 — Validación de origen financiero y costo de adquisición
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_activo_biologico_origen_financiero()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.origen_financiero IN ('COMPRA', 'DONACION') THEN
        IF NEW.costo_adquisicion IS NULL OR NEW.costo_adquisicion <= 0 THEN
            RAISE EXCEPTION 'FINANCIAL_RULE: El origen financiero % exige un costo_adquisicion mayor a cero. Valor recibido: %.', NEW.origen_financiero, NEW.costo_adquisicion
            USING ERRCODE = 'P0205';
        END IF;
        IF (NEW.atributos_dinamicos->>'soporte_documental') IS NULL
           OR TRIM(NEW.atributos_dinamicos->>'soporte_documental') = '' THEN
            RAISE EXCEPTION 'FINANCIAL_RULE: El origen financiero % exige soporte documental registrado.', NEW.origen_financiero
            USING ERRCODE = 'P0205';
        END IF;

    ELSIF NEW.origen_financiero = 'NACIMIENTO' THEN
        IF NEW.costo_adquisicion IS NOT NULL THEN
            RAISE EXCEPTION 'FINANCIAL_RULE: Para origen NACIMIENTO el costo_adquisicion debe ser nulo. Valor recibido: %.', NEW.costo_adquisicion
            USING ERRCODE = 'P0206';
        END IF;
        IF (NEW.atributos_dinamicos->>'soporte_documental') IS NOT NULL THEN
            RAISE EXCEPTION 'FINANCIAL_RULE: Para origen NACIMIENTO el soporte_documental debe ser nulo.'
            USING ERRCODE = 'P0206';
        END IF;

    ELSIF NEW.origen_financiero = 'TRANSFERENCIA_INTERNA' THEN
        IF NEW.costo_adquisicion IS NOT NULL AND NEW.costo_adquisicion <= 0 THEN
            RAISE EXCEPTION 'FINANCIAL_RULE: Si se registra costo_adquisicion en TRANSFERENCIA_INTERNA debe ser mayor a cero. Valor recibido: %.', NEW.costo_adquisicion
            USING ERRCODE = 'P0207';
        END IF;
        IF NEW.costo_adquisicion IS NOT NULL
           AND ((NEW.atributos_dinamicos->>'soporte_documental') IS NULL
                OR TRIM(NEW.atributos_dinamicos->>'soporte_documental') = '') THEN
            RAISE EXCEPTION 'FINANCIAL_RULE: Si se registra costo_adquisicion en TRANSFERENCIA_INTERNA el soporte_documental es obligatorio.'
            USING ERRCODE = 'P0207';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activo_biologico_origen_financiero
BEFORE INSERT ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_activo_biologico_origen_financiero();

-- =============================================================================
-- TRG-M2-04 — Inmutabilidad de campos estructurales del activo
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_activo_biologico_inmutabilidad()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo <> OLD.tipo THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El campo tipo del activo biológico no puede modificarse después del registro. Valor original: %.', OLD.tipo
        USING ERRCODE = 'P0208';
    END IF;

    IF NEW.id_especie <> OLD.id_especie THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: La especie del activo biológico no puede modificarse después del registro.'
        USING ERRCODE = 'P0208';
    END IF;

    IF NEW.origen_financiero <> OLD.origen_financiero THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El campo origen_financiero no puede modificarse después del registro. Es base para la valoración contable.'
        USING ERRCODE = 'P0208';
    END IF;

    IF (NEW.costo_adquisicion IS DISTINCT FROM OLD.costo_adquisicion) THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El campo costo_adquisicion es inmutable. Representa el costo histórico pagado y es base de RF-82.'
        USING ERRCODE = 'P0208';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activo_biologico_inmutabilidad
BEFORE UPDATE ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_activo_biologico_inmutabilidad();

-- =============================================================================
-- TRG-M2-05 — Inicialización de métricas del activo poblacional
-- Tabla:  modulo2.detalles_activos_biologicos_poblacionales
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_poblacional_inicializar_metricas()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad_inicial <= 0 THEN
        RAISE EXCEPTION 'INVALID_VALUE: La cantidad_inicial del lote debe ser mayor a cero. Valor recibido: %.', NEW.cantidad_inicial
        USING ERRCODE = 'P0209';
    END IF;

    -- Forzar cantidad_actual = cantidad_inicial en el registro inicial
    NEW.cantidad_actual := NEW.cantidad_inicial;

    IF NEW.cantidad_actual < 0 THEN
        RAISE EXCEPTION 'INVALID_VALUE: La cantidad_actual no puede ser negativa.'
        USING ERRCODE = 'P0209';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_poblacional_inicializar_metricas
BEFORE INSERT ON modulo2.detalles_activos_biologicos_poblacionales
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_poblacional_inicializar_metricas();

-- =============================================================================
-- TRG-M2-06 — Inmutabilidad de cantidad_inicial del lote
-- Tabla:  modulo2.detalles_activos_biologicos_poblacionales
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_poblacional_cantidad_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad_inicial <> OLD.cantidad_inicial THEN
        RAISE EXCEPTION 'IMMUTABLE_FIELD: El campo cantidad_inicial es inmutable y no puede modificarse después del registro del lote. Valor original: %.', OLD.cantidad_inicial
        USING ERRCODE = 'P0210';
    END IF;

    IF NEW.cantidad_actual < 0 THEN
        RAISE EXCEPTION 'INVALID_VALUE: La cantidad_actual del lote no puede ser negativa. Valor intentado: %.', NEW.cantidad_actual
        USING ERRCODE = 'P0210';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_poblacional_cantidad_inmutable
BEFORE UPDATE ON modulo2.detalles_activos_biologicos_poblacionales
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_poblacional_cantidad_inmutable();

-- =============================================================================
-- TRG-M2-07 — Validación de transición de estado del activo biológico
-- Tabla:  modulo2.historicos_estados_activos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_estado_activo_transicion_valida()
RETURNS TRIGGER AS $$
DECLARE
    v_nombre_anterior VARCHAR(25);
    v_nombre_nuevo    VARCHAR(25);
BEGIN
    SELECT nombre INTO v_nombre_anterior
    FROM modulo2.estados_activos_biologicos
    WHERE id_estado_activo_biologico = NEW.id_estado_anterior;

    SELECT nombre INTO v_nombre_nuevo
    FROM modulo2.estados_activos_biologicos
    WHERE id_estado_activo_biologico = NEW.id_estado_nuevo;

    -- Desde BAJA no se permite ninguna transición
    IF UPPER(v_nombre_anterior) = 'BAJA' THEN
        RAISE EXCEPTION 'INVALID_TRANSITION: El activo está en estado BAJA. No se permite ninguna transición desde este estado final irreversible.'
        USING ERRCODE = 'P0211';
    END IF;

    -- Cambio redundante
    IF NEW.id_estado_anterior = NEW.id_estado_nuevo THEN
        RAISE EXCEPTION 'REDUNDANT_TRANSITION: El estado nuevo es igual al estado actual. No se realizó ningún cambio.'
        USING ERRCODE = 'P0211';
    END IF;

    -- Validar matriz de transiciones definida en RF-44
    IF NOT (
        (UPPER(v_nombre_anterior) = 'ACTIVO'          AND UPPER(v_nombre_nuevo) IN ('INACTIVO','EN_TRATAMIENTO','AISLADO','CERRADO','BAJA'))
        OR (UPPER(v_nombre_anterior) = 'INACTIVO'     AND UPPER(v_nombre_nuevo) IN ('ACTIVO','EN_TRATAMIENTO','CERRADO','BAJA'))
        OR (UPPER(v_nombre_anterior) = 'EN_TRATAMIENTO' AND UPPER(v_nombre_nuevo) IN ('ACTIVO','INACTIVO','AISLADO','CERRADO','BAJA'))
        OR (UPPER(v_nombre_anterior) = 'AISLADO'      AND UPPER(v_nombre_nuevo) IN ('ACTIVO','INACTIVO','EN_TRATAMIENTO','CERRADO','BAJA'))
        OR (UPPER(v_nombre_anterior) = 'CERRADO'      AND UPPER(v_nombre_nuevo) IN ('BAJA'))
    ) THEN
        RAISE EXCEPTION 'INVALID_TRANSITION: La transición de "%" a "%" no está permitida por la matriz de estados del sistema.', v_nombre_anterior, v_nombre_nuevo
        USING ERRCODE = 'P0211';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estado_activo_transicion_valida
BEFORE INSERT ON modulo2.historicos_estados_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_estado_activo_transicion_valida();

-- =============================================================================
-- TRG-M2-08 — Unicidad de estado vigente por activo
-- Tabla:  modulo2.historicos_estados_activos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_estado_activo_unico_vigente()
RETURNS TRIGGER AS $$
DECLARE
    v_ultimo_estado INTEGER;
BEGIN
    SELECT id_estado_nuevo INTO v_ultimo_estado
    FROM modulo2.historicos_estados_activos
    WHERE id_activo_biologico = NEW.id_activo_biologico
    ORDER BY fecha_cambio DESC
    LIMIT 1;

    -- El estado anterior declarado debe coincidir con el último estado registrado
    IF v_ultimo_estado IS NOT NULL AND v_ultimo_estado <> NEW.id_estado_anterior THEN
        RAISE EXCEPTION 'STATE_INCONSISTENCY: El estado anterior declarado (ID %) no coincide con el último estado registrado para el activo (ID %). El historial de estados está desincronizado.', NEW.id_estado_anterior, v_ultimo_estado
        USING ERRCODE = 'P0212';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estado_activo_unico_vigente
BEFORE INSERT ON modulo2.historicos_estados_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_estado_activo_unico_vigente();

-- =============================================================================
-- TRG-M2-09 — Bloqueo de modificación de activo en estado BAJA
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_estado_activo_no_baja_modify()
RETURNS TRIGGER AS $$
DECLARE
    v_ultimo_estado VARCHAR(25);
BEGIN
    SELECT e.nombre INTO v_ultimo_estado
    FROM modulo2.historicos_estados_activos h
    JOIN modulo2.estados_activos_biologicos e
        ON e.id_estado_activo_biologico = h.id_estado_nuevo
    WHERE h.id_activo_biologico = OLD.id_activo_biologico
    ORDER BY h.fecha_cambio DESC
    LIMIT 1;

    IF UPPER(v_ultimo_estado) = 'BAJA' THEN
        RAISE EXCEPTION 'FINAL_STATE: El activo biológico ID % se encuentra en estado BAJA definitivo. No se permiten modificaciones sobre activos dados de baja.', OLD.id_activo_biologico
        USING ERRCODE = 'P0213';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estado_activo_no_baja_modify
BEFORE UPDATE ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_estado_activo_no_baja_modify();

-- =============================================================================
-- TRG-M2-10 — Validación de estado operativo para registro de eventos
-- Tabla:  modulo2.eventos_activos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_activo_estado_valido()
RETURNS TRIGGER AS $$
DECLARE
    v_ultimo_estado VARCHAR(25);
BEGIN
    SELECT e.nombre INTO v_ultimo_estado
    FROM modulo2.historicos_estados_activos h
    JOIN modulo2.estados_activos_biologicos e
        ON e.id_estado_activo_biologico = h.id_estado_nuevo
    WHERE h.id_activo_biologico = NEW.id_activo_biologico
    ORDER BY h.fecha_cambio DESC
    LIMIT 1;

    -- Si no hay historial, leer el estado directo del activo
    IF v_ultimo_estado IS NULL THEN
        SELECT e.nombre INTO v_ultimo_estado
        FROM modulo2.activos_biologicos a
        JOIN modulo2.estados_activos_biologicos e
            ON e.id_estado_activo_biologico = a.id_estado
        WHERE a.id_activo_biologico = NEW.id_activo_biologico;
    END IF;

    IF UPPER(v_ultimo_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION 'INVALID_STATE: No es posible registrar eventos sobre el activo ID %. El activo se encuentra en estado %, el cual no permite nuevos registros. Estados válidos: ACTIVO, EN_TRATAMIENTO, AISLADO.', NEW.id_activo_biologico, v_ultimo_estado
        USING ERRCODE = 'P0214';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_activo_estado_valido
BEFORE INSERT ON modulo2.eventos_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_activo_estado_valido();

-- =============================================================================
-- TRG-M2-11 — Coherencia temporal de eventos biológicos
-- Tabla:  modulo2.eventos_activos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_fecha_coherente()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha_creacion TIMESTAMPTZ;
BEGIN
    IF NEW.fecha > now() THEN
        RAISE EXCEPTION 'INVALID_DATE: La fecha del evento (%) no puede ser futura. Fecha actual del sistema: %.', NEW.fecha, now()
        USING ERRCODE = 'P0215';
    END IF;

    SELECT fecha_creacion INTO v_fecha_creacion
    FROM modulo2.activos_biologicos
    WHERE id_activo_biologico = NEW.id_activo_biologico;

    IF v_fecha_creacion IS NOT NULL AND NEW.fecha < v_fecha_creacion THEN
        RAISE EXCEPTION 'INVALID_DATE: La fecha del evento (%) no puede ser anterior a la fecha de registro del activo (%).', NEW.fecha, v_fecha_creacion
        USING ERRCODE = 'P0215';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_fecha_coherente
BEFORE INSERT ON modulo2.eventos_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_fecha_coherente();

-- =============================================================================
-- TRG-M2-12 — Validación de coherencia del evento de crecimiento por tipo de activo
-- Tabla:  modulo2.eventos_crecimeinto
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_crecimiento_tipo_activo()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_activo   modulo2.enum_activo_biologico_tipo;
    v_tipo_medicion VARCHAR(55);
    v_unidad        VARCHAR(5);
BEGIN
    SELECT a.tipo INTO v_tipo_activo
    FROM modulo2.activos_biologicos a
    JOIN modulo2.eventos_activos ev ON ev.id_activo_biologico = a.id_activo_biologico
    WHERE ev.id_eventos = NEW.id_evento;

    v_tipo_medicion := UPPER(TRIM(NEW.tipo_medicion));
    v_unidad        := LOWER(TRIM(NEW.unidad_medida));

    -- Validar tipo_agregacion según tipo de activo
    IF v_tipo_activo = 'INDIVIDUAL' THEN
        IF NEW.tipo_agregacion IS NOT NULL AND TRIM(NEW.tipo_agregacion) <> '' THEN
            RAISE EXCEPTION 'INVALID_FIELD: Para activos INDIVIDUALES el campo tipo_agregacion debe ser nulo o vacío.'
            USING ERRCODE = 'P0216';
        END IF;
    ELSIF v_tipo_activo = 'POBLACIONAL' THEN
        IF NEW.tipo_agregacion IS NULL OR TRIM(NEW.tipo_agregacion) = '' THEN
            RAISE EXCEPTION 'MISSING_FIELD: Para activos LOTE (POBLACIONAL) el campo tipo_agregacion es obligatorio.'
            USING ERRCODE = 'P0216';
        END IF;
    END IF;

    -- Validar valor positivo
    IF NEW.valor_medicion <= 0 THEN
        RAISE EXCEPTION 'INVALID_VALUE: El valor de medición debe ser positivo y mayor a cero. Valor recibido: %.', NEW.valor_medicion
        USING ERRCODE = 'P0217';
    END IF;

    -- Validar coherencia unidad / tipo de medición
    IF v_tipo_medicion = 'PESO' AND v_unidad NOT IN ('kg', 'g', 'lb') THEN
        RAISE EXCEPTION 'UNIT_MISMATCH: Para medición de PESO solo se permiten unidades: kg, g, lb. Unidad recibida: %.', NEW.unidad_medida
        USING ERRCODE = 'P0218';
    END IF;

    IF v_tipo_medicion IN ('TALLA', 'LONGITUD', 'ALTURA') AND v_unidad NOT IN ('cm', 'm') THEN
        RAISE EXCEPTION 'UNIT_MISMATCH: Para medición de TALLA/LONGITUD/ALTURA solo se permiten unidades: cm, m. Unidad recibida: %.', NEW.unidad_medida
        USING ERRCODE = 'P0218';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_crecimiento_tipo_activo
BEFORE INSERT ON modulo2.eventos_crecimeinto
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_crecimiento_tipo_activo();

-- =============================================================================
-- TRG-M2-13 — Recálculo automático de métricas del lote tras evento de crecimiento
-- Tabla:  modulo2.eventos_crecimeinto
-- Evento: AFTER INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_crecimiento_recalcular_metricas()
RETURNS TRIGGER AS $$
DECLARE
    v_activo_id   INTEGER;
    v_tipo_activo modulo2.enum_activo_biologico_tipo;
    v_infra_id    INTEGER;
    v_superficie  NUMERIC(10,2);
    v_cantidad    INTEGER;
BEGIN
    SELECT a.id_activo_biologico, a.tipo, a.id_infraestructura
    INTO v_activo_id, v_tipo_activo, v_infra_id
    FROM modulo2.activos_biologicos a
    JOIN modulo2.eventos_activos ev ON ev.id_activo_biologico = a.id_activo_biologico
    WHERE ev.id_eventos = NEW.id_evento;

    -- Solo aplica para lotes POBLACIONALES
    IF v_tipo_activo <> 'POBLACIONAL' THEN
        RETURN NEW;
    END IF;

    SELECT superficie INTO v_superficie
    FROM modulo9.infraestructuras
    WHERE id_infraestructura = v_infra_id;

    SELECT cantidad_actual INTO v_cantidad
    FROM modulo2.detalles_activos_biologicos_poblacionales
    WHERE id_activo_biologico = v_activo_id;

    -- Recalcular solo cuando el evento registra peso promedio del lote
    IF UPPER(NEW.tipo_medicion) = 'PESO' AND UPPER(NEW.tipo_agregacion) = 'PROMEDIO' THEN
        UPDATE modulo2.detalles_activos_biologicos_poblacionales
        SET peso_promedio = NEW.valor_medicion,
            biomasa_total = v_cantidad * NEW.valor_medicion,
            densidad      = CASE
                                WHEN v_superficie IS NOT NULL AND v_superficie > 0
                                THEN v_cantidad::NUMERIC / v_superficie
                                ELSE 0
                            END
        WHERE id_activo_biologico = v_activo_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_crecimiento_recalcular_metricas
AFTER INSERT ON modulo2.eventos_crecimeinto
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_crecimiento_recalcular_metricas();

-- =============================================================================
-- TRG-M2-14 — Validación de secuencia lógica del ciclo sanitario
-- Tabla:  modulo2.eventos_sanitarios
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_sanitario_secuencia()
RETURNS TRIGGER AS $$
DECLARE
    v_activo_id         INTEGER;
    v_tiene_diagnostico INTEGER;
BEGIN
    SELECT id_activo_biologico INTO v_activo_id
    FROM modulo2.eventos_activos
    WHERE id_eventos = NEW.id_evento;

    -- Si el evento tiene medicamento y dosis es TRATAMIENTO o VACUNACION:
    -- requiere DIAGNOSTICO previo (evento sanitario sin medicamento con diagnóstico)
    IF NEW.medicamento IS NOT NULL AND TRIM(NEW.medicamento) <> ''
       AND NEW.dosis IS NOT NULL AND NEW.dosis > 0 THEN

        SELECT COUNT(*) INTO v_tiene_diagnostico
        FROM modulo2.eventos_sanitarios es_prev
        JOIN modulo2.eventos_activos ea_prev ON ea_prev.id_eventos = es_prev.id_evento
        WHERE ea_prev.id_activo_biologico = v_activo_id
          AND es_prev.diagnostico IS NOT NULL
          AND TRIM(es_prev.diagnostico) <> ''
          AND es_prev.medicamento IS NULL
          AND ea_prev.fecha < (
              SELECT fecha FROM modulo2.eventos_activos WHERE id_eventos = NEW.id_evento
          );

        IF v_tiene_diagnostico = 0 THEN
            RAISE EXCEPTION 'SEQUENCE_VIOLATION: No se puede registrar TRATAMIENTO o VACUNACION sin un evento de DIAGNOSTICO previo para el activo ID %.', v_activo_id
            USING ERRCODE = 'P0219';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_sanitario_secuencia
BEFORE INSERT ON modulo2.eventos_sanitarios
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_sanitario_secuencia();

-- =============================================================================
-- TRG-M2-15 — Validación de secuencia del ciclo reproductivo
-- Tabla:  modulo2.eventos_reproductivos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_reproductivo_secuencia()
RETURNS TRIGGER AS $$
DECLARE
    v_activo_id   INTEGER;
    v_tipo_activo modulo2.enum_activo_biologico_tipo;
    v_count_previo INTEGER;
BEGIN
    SELECT a.id_activo_biologico, a.tipo
    INTO v_activo_id, v_tipo_activo
    FROM modulo2.activos_biologicos a
    JOIN modulo2.eventos_activos ev ON ev.id_activo_biologico = a.id_activo_biologico
    WHERE ev.id_eventos = NEW.id_evento_reproductivo;

    -- Para LOTE: solo se permite NACIMIENTO
    IF v_tipo_activo = 'POBLACIONAL' AND NEW.categoria NOT IN ('NACIMIENTO') THEN
        RAISE EXCEPTION 'TYPE_RESTRICTION: Para activos de tipo LOTE (POBLACIONAL) solo se permite el evento reproductivo NACIMIENTO. Categoría recibida: %.', NEW.categoria
        USING ERRCODE = 'P0220';
    END IF;

    IF v_tipo_activo = 'INDIVIDUAL' THEN
        -- PARTO requiere DIAGNOSTICO_GESTACION positivo previo
        IF NEW.categoria = 'PARTO' THEN
            SELECT COUNT(*) INTO v_count_previo
            FROM modulo2.eventos_reproductivos er
            JOIN modulo2.eventos_activos ea ON ea.id_eventos = er.id_evento_reproductivo
            WHERE ea.id_activo_biologico = v_activo_id
              AND er.categoria = 'DIAGNOSTICO_GESTACION'
              AND UPPER(er.resultado) LIKE '%POSITIV%';

            IF v_count_previo = 0 THEN
                RAISE EXCEPTION 'SEQUENCE_VIOLATION: No se puede registrar PARTO sin un evento previo de DIAGNOSTICO_GESTACION positivo para el activo ID %.', v_activo_id
                USING ERRCODE = 'P0221';
            END IF;
        END IF;

        -- NACIMIENTO requiere PARTO previo
        IF NEW.categoria = 'NACIMIENTO' THEN
            SELECT COUNT(*) INTO v_count_previo
            FROM modulo2.eventos_reproductivos er
            JOIN modulo2.eventos_activos ea ON ea.id_eventos = er.id_evento_reproductivo
            WHERE ea.id_activo_biologico = v_activo_id
              AND er.categoria = 'PARTO';

            IF v_count_previo = 0 THEN
                RAISE EXCEPTION 'SEQUENCE_VIOLATION: No se puede registrar NACIMIENTO sin un evento previo de PARTO para el activo ID %.', v_activo_id
                USING ERRCODE = 'P0221';
            END IF;
        END IF;

        -- Número de crías en parto o nacimiento debe ser >= 1
        IF NEW.categoria IN ('PARTO', 'NACIMIENTO') AND NEW.numero_cria < 1 THEN
            RAISE EXCEPTION 'INVALID_VALUE: El número de crías en un evento de % debe ser mayor o igual a 1. Valor recibido: %.', NEW.categoria, NEW.numero_cria
            USING ERRCODE = 'P0222';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_reproductivo_secuencia
BEFORE INSERT ON modulo2.eventos_reproductivos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_reproductivo_secuencia();

-- =============================================================================
-- TRG-M2-16 — Prevención de duplicidad en eventos productivos
-- Tabla:  modulo2.eventos_productivos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_evento_productivo_duplicado()
RETURNS TRIGGER AS $$
DECLARE
    v_activo_id    INTEGER;
    v_fecha_evento TIMESTAMPTZ;
    v_count        INTEGER;
BEGIN
    SELECT ea.id_activo_biologico, ea.fecha
    INTO v_activo_id, v_fecha_evento
    FROM modulo2.eventos_activos ea
    WHERE ea.id_eventos = NEW.id_evento;

    SELECT COUNT(*) INTO v_count
    FROM modulo2.eventos_productivos ep
    JOIN modulo2.eventos_activos ea ON ea.id_eventos = ep.id_evento
    WHERE ea.id_activo_biologico = v_activo_id
      AND ep.id_metrica_produccion = NEW.id_metrica_produccion
      AND DATE(ea.fecha) = DATE(v_fecha_evento);

    IF v_count > 0 THEN
        RAISE EXCEPTION 'DUPLICATE_EVENT: Ya existe un evento productivo para la misma métrica (ID %) en el activo ID % en la fecha %. No se permiten registros duplicados.', NEW.id_metrica_produccion, v_activo_id, DATE(v_fecha_evento)
        USING ERRCODE = 'P0223';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evento_productivo_duplicado
BEFORE INSERT ON modulo2.eventos_productivos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_evento_productivo_duplicado();

-- =============================================================================
-- TRG-M2-17 — Validación de cantidad de baja en lote
-- Tabla:  modulo2.eventos_bajas
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_baja_cantidad_valida()
RETURNS TRIGGER AS $$
DECLARE
    v_activo_id      INTEGER;
    v_tipo_activo    modulo2.enum_activo_biologico_tipo;
    v_cantidad_actual INTEGER;
BEGIN
    SELECT a.id_activo_biologico, a.tipo
    INTO v_activo_id, v_tipo_activo
    FROM modulo2.activos_biologicos a
    JOIN modulo2.eventos_activos ea ON ea.id_activo_biologico = a.id_activo_biologico
    WHERE ea.id_eventos = NEW.id_evento;

    IF v_tipo_activo = 'POBLACIONAL' THEN
        IF NEW.cantidad_afectada IS NULL OR NEW.cantidad_afectada <= 0 THEN
            RAISE EXCEPTION 'INVALID_VALUE: Para bajas en lotes la cantidad_afectada debe ser mayor a cero. Valor recibido: %.', NEW.cantidad_afectada
            USING ERRCODE = 'P0224';
        END IF;

        SELECT cantidad_actual INTO v_cantidad_actual
        FROM modulo2.detalles_activos_biologicos_poblacionales
        WHERE id_activo_biologico = v_activo_id;

        IF NEW.cantidad_afectada > v_cantidad_actual THEN
            RAISE EXCEPTION 'INVENTORY_INCONSISTENCY: La cantidad a dar de baja (%) es superior a la existencia actual del lote (%). Activo ID %.', NEW.cantidad_afectada, v_cantidad_actual, v_activo_id
            USING ERRCODE = 'P0225';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_baja_cantidad_valida
BEFORE INSERT ON modulo2.eventos_bajas
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_baja_cantidad_valida();

-- =============================================================================
-- TRG-M2-18 — Actualización automática de cantidad del lote tras baja
-- Tabla:  modulo2.eventos_bajas
-- Evento: AFTER INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_baja_actualizar_cantidad_lote()
RETURNS TRIGGER AS $$
DECLARE
    v_activo_id   INTEGER;
    v_tipo_activo modulo2.enum_activo_biologico_tipo;
    v_infra_id    INTEGER;
    v_superficie  NUMERIC(10,2);
BEGIN
    SELECT a.id_activo_biologico, a.tipo, a.id_infraestructura
    INTO v_activo_id, v_tipo_activo, v_infra_id
    FROM modulo2.activos_biologicos a
    JOIN modulo2.eventos_activos ea ON ea.id_activo_biologico = a.id_activo_biologico
    WHERE ea.id_eventos = NEW.id_evento;

    IF v_tipo_activo <> 'POBLACIONAL' THEN
        RETURN NEW;
    END IF;

    SELECT superficie INTO v_superficie
    FROM modulo9.infraestructuras
    WHERE id_infraestructura = v_infra_id;

    UPDATE modulo2.detalles_activos_biologicos_poblacionales
    SET cantidad_actual = GREATEST(0, cantidad_actual - NEW.cantidad_afectada),
        biomasa_total   = GREATEST(0, cantidad_actual - NEW.cantidad_afectada) * peso_promedio,
        densidad        = CASE
                              WHEN v_superficie IS NOT NULL AND v_superficie > 0
                              THEN GREATEST(0, cantidad_actual - NEW.cantidad_afectada)::NUMERIC / v_superficie
                              ELSE 0
                          END
    WHERE id_activo_biologico = v_activo_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_baja_actualizar_cantidad_lote
AFTER INSERT ON modulo2.eventos_bajas
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_baja_actualizar_cantidad_lote();

-- =============================================================================
-- TRG-M2-19 — Unicidad de fase activa por activo biológico
-- Tabla:  modulo2.gestiones_fases
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_fase_unica_activa()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NEW.es_activa = TRUE THEN
        SELECT COUNT(*) INTO v_count
        FROM modulo2.gestiones_fases
        WHERE id_activo_biologico = NEW.id_activo_biologico
          AND es_activa           = TRUE;

        IF v_count > 0 THEN
            RAISE EXCEPTION 'UNIQUE_ACTIVE_PHASE: El activo biológico ID % ya tiene una fase productiva activa. Finalice la fase actual antes de iniciar una nueva.', NEW.id_activo_biologico
            USING ERRCODE = 'P0226';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fase_unica_activa
BEFORE INSERT ON modulo2.gestiones_fases
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_fase_unica_activa();

-- =============================================================================
-- TRG-M2-20 — Validación de no solapamiento temporal de fases
-- Tabla:  modulo2.gestiones_fases
-- Evento: BEFORE INSERT
-- Nota:   gestiones_fases.fecha_inicio es 'time with time zone' en el DDL
--         actual; debería ser 'timestamptz'. El trigger castea para operar
--         correctamente. Se recomienda corregir el tipo de dato en el DDL.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_fase_solapamiento()
RETURNS TRIGGER AS $$
DECLARE
    v_ultima_fecha_fin TIMESTAMPTZ;
BEGIN
    SELECT fecha_finalizacion INTO v_ultima_fecha_fin
    FROM modulo2.gestiones_fases
    WHERE id_activo_biologico = NEW.id_activo_biologico
      AND es_activa           = FALSE
      AND fecha_finalizacion IS NOT NULL
    ORDER BY fecha_finalizacion DESC
    LIMIT 1;

    IF v_ultima_fecha_fin IS NOT NULL
       AND NEW.fecha_inicio::TIMESTAMPTZ < v_ultima_fecha_fin THEN
        RAISE EXCEPTION 'PHASE_OVERLAP: La fecha de inicio de la nueva fase (%) es anterior a la fecha de finalización de la fase anterior (%). No se permiten solapamientos.', NEW.fecha_inicio, v_ultima_fecha_fin
        USING ERRCODE = 'P0227';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fase_solapamiento
BEFORE INSERT ON modulo2.gestiones_fases
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_fase_solapamiento();

-- =============================================================================
-- TRG-M2-21 — Bloqueo de cambio de fase en activos no operativos
-- Tabla:  modulo2.gestiones_fases
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_fase_activo_estado_valido()
RETURNS TRIGGER AS $$
DECLARE
    v_ultimo_estado VARCHAR(25);
BEGIN
    SELECT e.nombre INTO v_ultimo_estado
    FROM modulo2.historicos_estados_activos h
    JOIN modulo2.estados_activos_biologicos e
        ON e.id_estado_activo_biologico = h.id_estado_nuevo
    WHERE h.id_activo_biologico = NEW.id_activo_biologico
    ORDER BY h.fecha_cambio DESC
    LIMIT 1;

    -- Fallback al estado directo del activo si no hay historial
    IF v_ultimo_estado IS NULL THEN
        SELECT e.nombre INTO v_ultimo_estado
        FROM modulo2.activos_biologicos a
        JOIN modulo2.estados_activos_biologicos e
            ON e.id_estado_activo_biologico = a.id_estado
        WHERE a.id_activo_biologico = NEW.id_activo_biologico;
    END IF;

    IF UPPER(v_ultimo_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION 'INVALID_STATE: No se puede registrar o cambiar una fase en el activo ID % porque se encuentra en estado %. Solo se permiten cambios de fase en activos operativos.', NEW.id_activo_biologico, v_ultimo_estado
        USING ERRCODE = 'P0228';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fase_activo_estado_valido
BEFORE INSERT ON modulo2.gestiones_fases
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_fase_activo_estado_valido();

-- =============================================================================
-- TRG-M2-22 — Unicidad de asociación activa sensor-activo (tipo DIRECTA)
-- Tabla:  modulo2.asociaciones_activos_sensores
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_asociacion_sensor_activo_unica()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NEW.tipo = 'DIRECTA' THEN
        SELECT COUNT(*) INTO v_count
        FROM modulo2.asociaciones_activos_sensores
        WHERE id_sensor  = NEW.id_sensor
          AND fecha_fin  > now()
          AND tipo       = 'DIRECTA';

        IF v_count > 0 THEN
            RAISE EXCEPTION 'SENSOR_CONFLICT: El sensor ID % ya tiene una asociación DIRECTA activa con otro activo individual. Desactive la asociación existente antes de crear una nueva.', NEW.id_sensor
            USING ERRCODE = 'P0229';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_asociacion_sensor_activo_unica
BEFORE INSERT ON modulo2.asociaciones_activos_sensores
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_asociacion_sensor_activo_unica();

-- =============================================================================
-- TRG-M2-23 — Inmutabilidad del historial de estados
-- Tabla:  modulo2.historicos_estados_activos
-- Evento: BEFORE UPDATE / BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_historial_estados_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: El historial de estados del activo biológico es inmutable. Operación % bloqueada. El historial es append-only.', TG_OP
    USING ERRCODE = 'P0230';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_historial_estados_inmutable_update
BEFORE UPDATE ON modulo2.historicos_estados_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_historial_estados_inmutable();

CREATE TRIGGER trg_historial_estados_inmutable_delete
BEFORE DELETE ON modulo2.historicos_estados_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_historial_estados_inmutable();

-- =============================================================================
-- TRG-M2-24 — Inmutabilidad de todos los eventos biológicos registrados
-- Tablas: modulo2.eventos_activos, eventos_crecimeinto, eventos_sanitarios,
--         eventos_reproductivos, eventos_productivos, eventos_bajas
-- Evento: BEFORE UPDATE / BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_eventos_activos_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: Los eventos biológicos son inmutables una vez registrados. Operación % sobre tabla % bloqueada.', TG_OP, TG_TABLE_NAME
    USING ERRCODE = 'P0231';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_eventos_activos_inmutable_update
BEFORE UPDATE ON modulo2.eventos_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_activos_inmutable_delete
BEFORE DELETE ON modulo2.eventos_activos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_crecimiento_inmutable_update
BEFORE UPDATE ON modulo2.eventos_crecimeinto
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_crecimiento_inmutable_delete
BEFORE DELETE ON modulo2.eventos_crecimeinto
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_sanitarios_inmutable_update
BEFORE UPDATE ON modulo2.eventos_sanitarios
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_sanitarios_inmutable_delete
BEFORE DELETE ON modulo2.eventos_sanitarios
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_reproductivos_inmutable_update
BEFORE UPDATE ON modulo2.eventos_reproductivos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_reproductivos_inmutable_delete
BEFORE DELETE ON modulo2.eventos_reproductivos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_productivos_inmutable_update
BEFORE UPDATE ON modulo2.eventos_productivos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_productivos_inmutable_delete
BEFORE DELETE ON modulo2.eventos_productivos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_bajas_inmutable_update
BEFORE UPDATE ON modulo2.eventos_bajas
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

CREATE TRIGGER trg_eventos_bajas_inmutable_delete
BEFORE DELETE ON modulo2.eventos_bajas
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_eventos_activos_inmutable();

-- =============================================================================
-- TRG-M2-25 — Fecha de inicio de ciclo productivo válida
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE INSERT
-- Nota:   fecha_inicio_ciclo está declarado como INTEGER en el DDL actual.
--         Debería ser DATE. El trigger valida el campo con su tipo actual
--         (días desde epoch Unix). Se recomienda corregir el tipo en el DDL.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_activo_fecha_inicio_valida()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_inicio_ciclo IS NULL THEN
        RAISE EXCEPTION 'MISSING_FIELD: El campo fecha_inicio_ciclo es obligatorio.'
        USING ERRCODE = 'P0232';
    END IF;

    -- Valor negativo = anterior a 1970-01-01
    IF NEW.fecha_inicio_ciclo < 0 THEN
        RAISE EXCEPTION 'INVALID_DATE: La fecha_inicio_ciclo no puede ser anterior a 1970-01-01.'
        USING ERRCODE = 'P0232';
    END IF;

    -- Valor futuro: epoch en días mayor al día actual
    IF NEW.fecha_inicio_ciclo > EXTRACT(EPOCH FROM now())::INTEGER / 86400 THEN
        RAISE EXCEPTION 'INVALID_DATE: La fecha_inicio_ciclo no puede ser posterior a la fecha actual del sistema.'
        USING ERRCODE = 'P0232';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activo_fecha_inicio_valida
BEFORE INSERT ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_activo_fecha_inicio_valida();

-- =============================================================================
-- TRG-M2-26 — Protección de eliminación física de activos biológicos
-- Tabla:  modulo2.activos_biologicos
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo2.trg_fn_activo_biologico_no_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'NO_PHYSICAL_DELETE: Los activos biológicos no pueden eliminarse físicamente. Use la gestión de estados (BAJA) para retirar un activo del sistema. Activo ID: %.', OLD.id_activo_biologico
    USING ERRCODE = 'P0233';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activo_biologico_no_delete
BEFORE DELETE ON modulo2.activos_biologicos
FOR EACH ROW EXECUTE FUNCTION modulo2.trg_fn_activo_biologico_no_delete();

-- =============================================================================
-- Total de funciones de trigger: 26
-- Total de triggers registrados: 40
--   TRG-M2-23 crea 2 triggers con 1 función (update + delete)
--   TRG-M2-24 crea 12 triggers con 1 función (update + delete × 6 tablas)
-- =============================================================================