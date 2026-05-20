-- =============================================================================
-- MÓDULO 5 — GESTIÓN DE SUMINISTROS Y COSTOS PRODUCTIVOS
-- Archivo: triggers_modulo5_v1_1.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, inmutabilidad de registros históricos, cálculos
--              derivados determinísticos, trazabilidad de auditoría y
--              restricciones de negocio que deben ser protegidas a nivel
--              de base de datos.
-- Esquema: modulo5
-- Motor: PostgreSQL
-- Versión: 1.1
-- =============================================================================

-- ÍNDICE
-- TGR-M05-01  Inmutabilidad de registros de consumo de alimento en estado VALIDADO (UPDATE)
-- TGR-M05-02  Inmutabilidad de registros de medicamento en estado VALIDADO / bloqueo re-anulación (UPDATE)
-- TGR-M05-03  Cálculo automático de costo_total en consumo de alimentos (INSERT)
-- TGR-M05-04  Cálculo automático de costo_total_medicamento en registros de medicamentos (INSERT)
-- TGR-M05-05  Protección append-only de registros de consumo de alimentos (DELETE)
-- TGR-M05-06  Protección append-only de registros de medicamentos (DELETE)
-- TGR-M05-07  Protección de registros de reportes de gastos acumulados (DELETE)
-- TGR-M05-08  Protección append-only de registros de costos productivos (DELETE)
-- TGR-M05-09  Validación de fecha de consumo de alimento no futura (INSERT)
-- TGR-M05-10  Validación de fecha de aplicación de medicamento no futura (INSERT)
-- TGR-M05-11  Auditoría automática de operaciones sobre consumo de alimentos (INSERT, UPDATE)
-- TGR-M05-12  Auditoría automática de operaciones sobre registros de medicamentos (INSERT, UPDATE)
-- TGR-M05-13  Auditoría automática de inserción en costos productivos (INSERT)
-- TGR-M05-14  Protección contra UPDATE directo sobre costos productivos (UPDATE)
-- TGR-M05-15  Validación de estado activo del tipo de alimento en el catálogo (INSERT)
-- TGR-M05-16  Consistencia de rango de fechas en reportes de gastos acumulados (INSERT, UPDATE)
-- TGR-M05-17  Inmutabilidad del acumulado de ciclo productivo en estado CERRADO (UPDATE, DELETE)
-- TGR-M05-18  Validación de acumulado_total_ciclo no negativo en acumulado_ciclo (UPDATE)
-- TGR-M05-19  Protección append-only de registro_suministro (UPDATE, DELETE)
-- TGR-M05-20  Validación de costo positivo en registro_suministro (INSERT)
-- TGR-M05-21  Corrección en registro_suministro requiere id_registro_original y motivo (INSERT)
-- TGR-M05-22  Protección append-only de provision_nic41 (UPDATE, DELETE)
-- TGR-M05-23  Versionado correlativo de provision_nic41 (INSERT)
-- TGR-M05-24  Validación de data_quality_score y ca_calculado en resultado_ica (INSERT, UPDATE)
-- TGR-M05-25  Protección append-only de resultado_ica (DELETE)
-- TGR-M05-26  Auditoría automática de inserción en registro_suministro (INSERT)

-- =============================================================================
-- TGR-M05-01 — Inmutabilidad de registros de consumo de alimento en estado VALIDADO
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_consumo_alimento_inmutable_validado()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el registro estaba VALIDADO y sigue VALIDADO, bloquear cualquier edición
    IF OLD.estado_registro = 'VALIDADO' AND NEW.estado_registro = 'VALIDADO' THEN
        RAISE EXCEPTION
            'INMUTABILIDAD_VIOLADA: El registro de consumo con id [%] está en estado '
            'VALIDADO y no puede ser modificado. Solo se permite la transición a ANULADO. '
            '(RF-75 Restricción 5)',
            OLD.id_consumo_alimeto
        USING ERRCODE = 'P0001';
    END IF;

    -- Si el registro pasa de VALIDADO a ANULADO, proteger todos los campos de negocio
    -- Solo los campos propios de la anulación pueden cambiar en esta transición
    -- Incluye los nuevos campos del esquema actualizado: fecha_consumo, hora_suministro, costo_unitario
    IF OLD.estado_registro = 'VALIDADO' AND NEW.estado_registro = 'ANULADO' THEN
        IF NEW.id_activo_biologico        IS DISTINCT FROM OLD.id_activo_biologico        OR
           NEW.id_tipo_alimento           IS DISTINCT FROM OLD.id_tipo_alimento           OR
           NEW.tipo_alimento              IS DISTINCT FROM OLD.tipo_alimento              OR
           NEW.cantidad_suministrada      IS DISTINCT FROM OLD.cantidad_suministrada      OR
           NEW.costo_total                IS DISTINCT FROM OLD.costo_total                OR
           NEW.costo_unitario             IS DISTINCT FROM OLD.costo_unitario             OR
           NEW.fecha_consumo              IS DISTINCT FROM OLD.fecha_consumo              OR
           NEW.hora_suministro            IS DISTINCT FROM OLD.hora_suministro            OR
           NEW.fecha_inicio_periodo       IS DISTINCT FROM OLD.fecha_inicio_periodo       OR
           NEW.fecha_fin_periodo          IS DISTINCT FROM OLD.fecha_fin_periodo          OR
           NEW.consumo_por_individuo_kg   IS DISTINCT FROM OLD.consumo_por_individuo_kg
        THEN
            RAISE EXCEPTION
                'INMUTABILIDAD_VIOLADA: Durante la anulación del registro de consumo [%] '
                'no se pueden modificar campos de negocio. Solo se permite cambiar '
                'el estado y los campos propios de la anulación '
                '(justificacion_anulacion, fecha_hora_anulacion). (RF-75 Restricción 5)',
                OLD.id_consumo_alimeto
            USING ERRCODE = 'P0001';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_consumo_alimento_inmutable_validado
BEFORE UPDATE ON modulo5.registros_consumo_alimentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_consumo_alimento_inmutable_validado();

-- =============================================================================
-- TGR-M05-02 — Inmutabilidad de registros de medicamento en estado VALIDADO
--              y bloqueo de re-anulación sobre registros ya ANULADOS
-- Tabla:  modulo5.registros_medicamentos
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_medicamento_inmutable_validado()
RETURNS TRIGGER AS $$
BEGIN
    -- Bloquear cualquier UPDATE sobre un registro ya ANULADO
    IF OLD.estado_registro = 'ANULADO' THEN
        RAISE EXCEPTION
            'RE_ANULACION_INVALIDA: El registro de medicamento con id [%] ya se '
            'encuentra en estado ANULADO. No es posible anular un registro que ya '
            'fue anulado previamente. (RF-76 Flujo alterno E8)',
            OLD.id_registro_medicamento
        USING ERRCODE = 'P0001';
    END IF;

    -- Si el registro estaba VALIDADO y sigue VALIDADO, bloquear edición
    IF OLD.estado_registro = 'VALIDADO' AND NEW.estado_registro = 'VALIDADO' THEN
        RAISE EXCEPTION
            'INMUTABILIDAD_VIOLADA: El registro de medicamento con id [%] está en '
            'estado VALIDADO y no puede ser modificado. Solo se permite la transición '
            'a ANULADO. (RF-76 Restricción 5)',
            OLD.id_registro_medicamento
        USING ERRCODE = 'P0001';
    END IF;

    -- Durante la transición VALIDADO → ANULADO, proteger todos los campos de negocio
    -- Incluye los nuevos campos del esquema actualizado: hora_aplicacion, motivo_aplicacion
    IF OLD.estado_registro = 'VALIDADO' AND NEW.estado_registro = 'ANULADO' THEN
        IF NEW.id_activo_biologico        IS DISTINCT FROM OLD.id_activo_biologico        OR
           NEW.nombre_medicamento         IS DISTINCT FROM OLD.nombre_medicamento         OR
           NEW.cantidad                   IS DISTINCT FROM OLD.cantidad                   OR
           NEW.fecha_aplicacion           IS DISTINCT FROM OLD.fecha_aplicacion           OR
           NEW.hora_aplicacion            IS DISTINCT FROM OLD.hora_aplicacion            OR
           NEW.costo_unitario_medicamento IS DISTINCT FROM OLD.costo_unitario_medicamento OR
           NEW.costo_total_medicamento    IS DISTINCT FROM OLD.costo_total_medicamento    OR
           NEW.motivo_aplicacion          IS DISTINCT FROM OLD.motivo_aplicacion          OR
           NEW.via_aplicacion             IS DISTINCT FROM OLD.via_aplicacion             OR
           NEW.periodo_retiro_dias        IS DISTINCT FROM OLD.periodo_retiro_dias        OR
           NEW.fecha_fin_retiro           IS DISTINCT FROM OLD.fecha_fin_retiro           OR
           NEW.dosis_por_individuo        IS DISTINCT FROM OLD.dosis_por_individuo
        THEN
            RAISE EXCEPTION
                'INMUTABILIDAD_VIOLADA: Durante la anulación del registro de medicamento [%] '
                'no se pueden modificar campos de negocio. Solo se permite cambiar '
                'el estado y los campos propios de la anulación '
                '(justificacion_anulacion, fecha_hora_anulacion). (RF-76 Restricción 5)',
                OLD.id_registro_medicamento
            USING ERRCODE = 'P0001';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_medicamento_inmutable_validado
BEFORE UPDATE ON modulo5.registros_medicamentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_medicamento_inmutable_validado();

-- =============================================================================
-- TGR-M05-03 — Cálculo automático de costo_total en consumo de alimentos
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: BEFORE INSERT
-- =============================================================================
-- TGR-M05-03 — Cálculo automático de costo_total en consumo de alimentos
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: BEFORE INSERT
-- Nota:   Absorbe la validación de estado activo del tipo de alimento
--         (equivalente al antiguo TGR-M05-15 independiente). Resuelve
--         costo_unitario desde el campo propio de la fila si viene informado,
--         o desde el catálogo como fallback (fuente de verdad).
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_calcular_costo_total_consumo()
RETURNS TRIGGER AS $$
DECLARE
    v_costo_unitario  modulo5.tipos_alimentos.costo_unitario%TYPE;
    v_estado_alimento modulo5.enum_tipo_alimento_estado;
BEGIN
    -- Validar cantidad positiva como refuerzo de integridad en BD
    IF NEW.cantidad_suministrada <= 0 THEN
        RAISE EXCEPTION
            'CANTIDAD_INVALIDA: La cantidad suministrada debe ser mayor a cero. '
            'Valor recibido: [%]. (RF-75 Restricción 1)',
            NEW.cantidad_suministrada
        USING ERRCODE = 'P0001';
    END IF;

    -- Verificar existencia y estado activo del tipo de alimento
    -- (absorbe la lógica del antiguo TGR-M05-15)
    SELECT estado, costo_unitario
    INTO v_estado_alimento, v_costo_unitario
    FROM modulo5.tipos_alimentos
    WHERE id_tipo_elemento = NEW.id_tipo_alimento;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'TIPO_ALIMENTO_NO_ENCONTRADO: El tipo de alimento con id [%] no existe '
            'en el catálogo. Verifique el identificador. (RF-75 Proceso paso 2)',
            NEW.id_tipo_alimento
        USING ERRCODE = 'P0001';
    END IF;

    IF v_estado_alimento != 'ACTIVO' THEN
        RAISE EXCEPTION
            'TIPO_ALIMENTO_INACTIVO: El tipo de alimento con id [%] está en estado [%] '
            'y no puede usarse para nuevos registros de consumo. Solo los tipos en '
            'estado ACTIVO son válidos. (RF-75 Proceso paso 2)',
            NEW.id_tipo_alimento,
            v_estado_alimento
        USING ERRCODE = 'P0001';
    END IF;

    -- Resolver costo_unitario: usar el informado en la fila si viene,
    -- de lo contrario usar el del catálogo como fuente de verdad
    IF NEW.costo_unitario IS NOT NULL AND NEW.costo_unitario > 0 THEN
        v_costo_unitario := NEW.costo_unitario;
    ELSE
        -- Asignar el del catálogo al campo de la fila para persistirlo
        NEW.costo_unitario := v_costo_unitario;
    END IF;

    -- Calcular y asignar costo_total como fuente de verdad en BD
    NEW.costo_total := NEW.cantidad_suministrada * v_costo_unitario;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_costo_total_consumo
BEFORE INSERT ON modulo5.registros_consumo_alimentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_calcular_costo_total_consumo();

-- =============================================================================
-- TGR-M05-04 — Cálculo automático de costo_total_medicamento en registros de medicamentos
-- Tabla:  modulo5.registros_medicamentos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_calcular_costo_total_medicamento()
RETURNS TRIGGER AS $$
BEGIN
    -- Validar cantidad (dosis) positiva
    IF NEW.cantidad <= 0 THEN
        RAISE EXCEPTION
            'CANTIDAD_INVALIDA: La dosis aplicada debe ser mayor a cero. '
            'Valor recibido: [%]. (RF-76 Flujo alterno E4)',
            NEW.cantidad
        USING ERRCODE = 'P0001';
    END IF;

    -- Validar costo unitario positivo
    IF NEW.costo_unitario_medicamento <= 0 THEN
        RAISE EXCEPTION
            'COSTO_INVALIDO: El costo unitario del medicamento debe ser mayor a cero. '
            'Valor recibido: [%]. (RF-76 Entradas — costo_unitario)',
            NEW.costo_unitario_medicamento
        USING ERRCODE = 'P0001';
    END IF;

    -- Calcular y asignar costo_total_medicamento como fuente de verdad en BD
    NEW.costo_total_medicamento := NEW.cantidad * NEW.costo_unitario_medicamento;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_costo_total_medicamento
BEFORE INSERT ON modulo5.registros_medicamentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_calcular_costo_total_medicamento();

-- =============================================================================
-- TGR-M05-05 — Protección append-only de registros de consumo de alimentos
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_consumo_alimento_no_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'OPERACION_NO_PERMITIDA: Los registros de consumo de alimentos son append-only '
        'y no pueden eliminarse físicamente. El registro con id [%] debe conservarse '
        'en el historial. Para invalidar un registro utilice la operación de anulación. '
        '(RF-75 Restricción 6 / RF-78 Restricción 6)',
        OLD.id_consumo_alimeto
    USING ERRCODE = 'P0001';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_consumo_alimento_no_delete
BEFORE DELETE ON modulo5.registros_consumo_alimentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_consumo_alimento_no_delete();

-- =============================================================================
-- TGR-M05-06 — Protección append-only de registros de medicamentos
-- Tabla:  modulo5.registros_medicamentos
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_medicamento_no_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'OPERACION_NO_PERMITIDA: Los registros de aplicación de medicamentos son '
        'append-only y no pueden eliminarse físicamente. El registro con id [%] '
        'debe conservarse para trazabilidad sanitaria (ICA / NIC 41). Para invalidar '
        'un registro utilice la operación de anulación. '
        '(RF-76 Trazabilidad / RF-78 Restricción 6)',
        OLD.id_registro_medicamento
    USING ERRCODE = 'P0001';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_medicamento_no_delete
BEFORE DELETE ON modulo5.registros_medicamentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_medicamento_no_delete();

-- =============================================================================
-- TGR-M05-07 — Protección de registros de reportes de gastos acumulados
-- Tabla:  modulo5.reporte_gastos_acumulados
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_reporte_gastos_no_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'OPERACION_NO_PERMITIDA: Los registros de reportes de gastos acumulados no '
        'pueden eliminarse. El registro con id [%] debe conservarse en el historial '
        'de reportes del usuario de forma indefinida. La expiración de 24 horas '
        'aplica únicamente al archivo exportado en storage, no al registro en BD. '
        '(RF-77 Historial de reportes)',
        OLD.id_reporte_gasto_acumulado
    USING ERRCODE = 'P0001';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reporte_gastos_no_delete
BEFORE DELETE ON modulo5.reporte_gastos_acumulados
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_reporte_gastos_no_delete();

-- =============================================================================
-- TGR-M05-08 — Protección append-only de registros de costos productivos
-- Tabla:  modulo5.costos_productivos
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_costos_productivos_no_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'OPERACION_NO_PERMITIDA: Los registros de costos productivos son append-only '
        'bajo política NIC 41 y no pueden eliminarse. El registro con id [%] debe '
        'conservarse como evidencia de inversión del ciclo productivo. Las correcciones '
        'deben realizarse mediante nuevos registros con tipo_operacion = CORRECCION. '
        '(RF-78 Restricción 6)',
        OLD.id_costo_productivo
    USING ERRCODE = 'P0001';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_costos_productivos_no_delete
BEFORE DELETE ON modulo5.costos_productivos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_costos_productivos_no_delete();

-- =============================================================================
-- TGR-M05-09 — Validación de fecha de consumo de alimento no futura
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: BEFORE INSERT
-- Nota:   Valida el nuevo campo canónico fecha_consumo (tipo date) como primera
--         línea, y fecha_inicio_periodo (tipo timestamp) como validación auxiliar.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_consumo_alimento_fecha_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    -- Validar campo canónico fecha_consumo (tipo date, campo nuevo del esquema)
    IF NEW.fecha_consumo IS NOT NULL AND NEW.fecha_consumo > CURRENT_DATE THEN
        RAISE EXCEPTION
            'FECHA_FUTURA_NO_PERMITIDA: La fecha de consumo [%] es posterior a la '
            'fecha actual del sistema [%]. No se permiten registros de consumo con '
            'fechas futuras. (RF-75 Restricción 2)',
            NEW.fecha_consumo,
            CURRENT_DATE
        USING ERRCODE = 'P0001';
    END IF;

    -- Validar también fecha_inicio_periodo si está presente (campo auxiliar de período)
    IF NEW.fecha_inicio_periodo IS NOT NULL AND NEW.fecha_inicio_periodo > NOW() THEN
        RAISE EXCEPTION
            'FECHA_FUTURA_NO_PERMITIDA: La fecha_inicio_periodo [%] es posterior a la '
            'fecha actual del sistema [%]. No se permiten registros de consumo con '
            'fechas futuras. (RF-75 Restricción 2)',
            NEW.fecha_inicio_periodo,
            NOW()
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_consumo_alimento_fecha_no_futura
BEFORE INSERT ON modulo5.registros_consumo_alimentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_consumo_alimento_fecha_no_futura();

-- =============================================================================
-- TGR-M05-10 — Validación de fecha de aplicación de medicamento no futura
-- Tabla:  modulo5.registros_medicamentos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_medicamento_fecha_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_aplicacion > CURRENT_DATE THEN
        RAISE EXCEPTION
            'FECHA_FUTURA_NO_PERMITIDA: La fecha de aplicación del medicamento [%] '
            'es posterior a la fecha actual del sistema [%]. No se permiten registros '
            'de medicamentos con fechas futuras. (RF-76 Flujo alterno E2)',
            NEW.fecha_aplicacion,
            CURRENT_DATE
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_medicamento_fecha_no_futura
BEFORE INSERT ON modulo5.registros_medicamentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_medicamento_fecha_no_futura();

-- =============================================================================
-- TGR-M05-11 — Auditoría automática de operaciones sobre consumo de alimentos
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: AFTER INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_auditoria_consumo_alimento()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_op modulo5.enum_auditoria_suministro_tipo_operacion;
    v_datos_ant json := NULL;
    v_datos_nue json := NULL;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_tipo_op   := 'REGISTRO';
        v_datos_nue := row_to_json(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_tipo_op   := 'ANULACION';
        v_datos_ant := row_to_json(OLD);
        v_datos_nue := row_to_json(NEW);
    END IF;

    INSERT INTO modulo5.auditorias_suministros (
        entidad_afectada,
        tipo_operacion,
        datos_anteriores,
        datos_nuevos,
        id_usuario,
        ip_origen,
        fecha_evento,
        resultado
    ) VALUES (
        'registros_consumo_alimentos',
        v_tipo_op,
        v_datos_ant,
        v_datos_nue,
        COALESCE(NEW.id_usuario, OLD.id_usuario),
        NULL,   -- IP gestionada por sesión de backend
        NOW(),
        'EXITOSO'
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_consumo_alimento
AFTER INSERT OR UPDATE ON modulo5.registros_consumo_alimentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_auditoria_consumo_alimento();

-- =============================================================================
-- TGR-M05-12 — Auditoría automática de operaciones sobre registros de medicamentos
-- Tabla:  modulo5.registros_medicamentos
-- Evento: AFTER INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_auditoria_medicamento()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_op modulo5.enum_auditoria_suministro_tipo_operacion;
    v_datos_ant json := NULL;
    v_datos_nue json := NULL;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_tipo_op   := 'REGISTRO';
        v_datos_nue := row_to_json(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_tipo_op   := 'ANULACION';
        v_datos_ant := row_to_json(OLD);
        v_datos_nue := row_to_json(NEW);
    END IF;

    INSERT INTO modulo5.auditorias_suministros (
        entidad_afectada,
        tipo_operacion,
        datos_anteriores,
        datos_nuevos,
        id_usuario,
        ip_origen,
        fecha_evento,
        resultado
    ) VALUES (
        'registros_medicamentos',
        v_tipo_op,
        v_datos_ant,
        v_datos_nue,
        COALESCE(NEW.id_usuario, OLD.id_usuario),
        NULL,   -- IP gestionada por sesión de backend
        NOW(),
        'EXITOSO'
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_medicamento
AFTER INSERT OR UPDATE ON modulo5.registros_medicamentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_auditoria_medicamento();

-- =============================================================================
-- TGR-M05-13 — Auditoría automática de inserción en costos productivos
-- Tabla:  modulo5.costos_productivos
-- Evento: AFTER INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_auditoria_costos_productivos()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO modulo5.auditorias_suministros (
        entidad_afectada,
        tipo_operacion,
        datos_anteriores,
        datos_nuevos,
        id_usuario,
        ip_origen,
        fecha_evento,
        resultado
    ) VALUES (
        'costos_productivos',
        'ACUMULACION',
        NULL,
        row_to_json(NEW),
        NEW.id_usuario,
        NULL,   -- IP gestionada por sesión de backend
        NOW(),
        'EXITOSO'
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_costos_productivos
AFTER INSERT ON modulo5.costos_productivos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_auditoria_costos_productivos();

-- =============================================================================
-- TGR-M05-14 — Protección contra UPDATE directo sobre costos productivos
-- Tabla:  modulo5.costos_productivos
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_costos_productivos_no_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'OPERACION_NO_PERMITIDA: Los registros de costos productivos son inmutables '
        '(append-only, NIC 41). No se permite modificar el registro con id [%]. '
        'Para realizar una corrección inserte un nuevo registro con '
        'tipo_operacion = CORRECCION referenciando el id del registro original. '
        '(RF-78 Restricción 6)',
        OLD.id_costo_productivo
    USING ERRCODE = 'P0001';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_costos_productivos_no_update
BEFORE UPDATE ON modulo5.costos_productivos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_costos_productivos_no_update();

-- =============================================================================
-- TGR-M05-15 — Validación de estado activo del tipo de alimento en el catálogo
-- Tabla:  modulo5.registros_consumo_alimentos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_tipo_alimento_debe_estar_activo()
RETURNS TRIGGER AS $$
DECLARE
    v_estado modulo5.enum_tipo_alimento_estado;
BEGIN
    SELECT estado
    INTO v_estado
    FROM modulo5.tipos_alimentos
    WHERE id_tipo_elemento = NEW.id_tipo_alimento;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'TIPO_ALIMENTO_NO_ENCONTRADO: El tipo de alimento con id [%] no existe '
            'en el catálogo. Verifique el identificador antes de registrar el consumo. '
            '(RF-75 Proceso paso 2)',
            NEW.id_tipo_alimento
        USING ERRCODE = 'P0001';
    END IF;

    IF v_estado != 'ACTIVO' THEN
        RAISE EXCEPTION
            'TIPO_ALIMENTO_INACTIVO: El tipo de alimento con id [%] se encuentra en '
            'estado [%] y no puede usarse para nuevos registros de consumo. Solo los '
            'tipos de alimento en estado ACTIVO son válidos para nuevos registros. '
            '(RF-75 Proceso paso 2)',
            NEW.id_tipo_alimento,
            v_estado
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tipo_alimento_debe_estar_activo
BEFORE INSERT ON modulo5.registros_consumo_alimentos
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_tipo_alimento_debe_estar_activo();

-- =============================================================================
-- TGR-M05-16 — Consistencia de rango de fechas en reportes de gastos acumulados
-- Tabla:  modulo5.reporte_gastos_acumulados
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo5.fn_trg_reporte_gastos_fechas_coherentes()
RETURNS TRIGGER AS $$
BEGIN
    -- Fecha de inicio no puede ser posterior a la fecha de fin
    IF NEW.fecha_incio_reporte > NEW.fecha_fin_report THEN
        RAISE EXCEPTION
            'RANGO_FECHAS_INVALIDO: La fecha de inicio del reporte [%] no puede ser '
            'posterior a la fecha de fin [%]. (RF-77 Flujo alterno E2)',
            NEW.fecha_incio_reporte,
            NEW.fecha_fin_report
        USING ERRCODE = 'P0001';
    END IF;

    -- Fecha de fin no puede ser futura
    IF NEW.fecha_fin_report > CURRENT_DATE THEN
        RAISE EXCEPTION
            'FECHA_FUTURA_NO_PERMITIDA: La fecha de fin del reporte [%] es posterior '
            'a la fecha actual del sistema [%]. Los reportes no pueden cubrir períodos '
            'futuros. (RF-77 Restricción 2)',
            NEW.fecha_fin_report,
            CURRENT_DATE
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reporte_gastos_fechas_coherentes
BEFORE INSERT OR UPDATE ON modulo5.reporte_gastos_acumulados
FOR EACH ROW
EXECUTE FUNCTION modulo5.fn_trg_reporte_gastos_fechas_coherentes();

-- =============================================================================
-- Total de funciones de trigger: 16
-- Total de triggers registrados: 16
-- =============================================================================