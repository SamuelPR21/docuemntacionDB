-- ==============================================================================
-- Archivo: procedimientos_modulo5.sql
-- Descripción: Procedimientos almacenados para el Módulo 5 (Suministros e ICA)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-75: Registro de Consumo de Alimentos
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo5.sp_registrar_consumo_alimento(
    p_id_usuario INT,
    p_id_activo INT,
    p_id_tipo_alimento INT,
    p_cantidad_suministrada NUMERIC,
    p_costo_unitario NUMERIC,
    p_fecha_inicio TIMESTAMP,
    p_fecha_fin TIMESTAMP,
    p_observacion VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_alimento VARCHAR;
    v_unidad VARCHAR;
    v_costo_total NUMERIC;
BEGIN
    -- 1. Validar existencia de tipo de alimento y obtener metadata
    SELECT nombre, unidad_medida INTO v_tipo_alimento, v_unidad
    FROM modulo5.tipos_alimentos
    WHERE id_tipo_elemento = p_id_tipo_alimento AND estado = 'ACTIVO';

    IF v_tipo_alimento IS NULL THEN
        RAISE EXCEPTION 'Error: El tipo de alimento especificado no existe o no está activo.';
    END IF;

    -- 2. Calcular costo total (cumpliendo con el CHECK de la tabla)
    v_costo_total := p_cantidad_suministrada * p_costo_unitario;

    -- 3. Insertar registro
    INSERT INTO modulo5.registros_consumo_alimentos (
        id_activo_biologico, id_tipo_alimento, tipo_alimento, tipo_unidad,
        cantidad_suministrada, costo_unitario, costo_total, observacion,
        fecha_inicio_periodo, fecha_fin_periodo, id_usuario, fecha_registro
    ) VALUES (
        p_id_activo, p_id_tipo_alimento, v_tipo_alimento, v_unidad,
        p_cantidad_suministrada, p_costo_unitario, v_costo_total, p_observacion,
        p_fecha_inicio, p_fecha_fin, p_id_usuario, CURRENT_TIMESTAMP
    );

    -- 4. Auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 5',
        'SUMINISTROS',
        'Registro de consumo de alimento para activo ID: ' || p_id_activo,
        'EXITOSO',
        'VALIDADO',
        jsonb_build_object(
            'id_activo', p_id_activo,
            'cantidad', p_cantidad_suministrada,
            'costo_total', v_costo_total
        )
    );

    COMMIT;
END;
$$;

-- ------------------------------------------------------------------------------
-- RF-74: Registro de Aplicación de Medicamentos
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo5.sp_registrar_aplicacion_medicamento(
    p_id_usuario INT,
    p_id_activo INT,
    p_id_veterinario INT,
    p_nombre_medicamento VARCHAR,
    p_descripcion_clinica TEXT,
    p_unidad_dosis VARCHAR,
    p_cantidad NUMERIC,
    p_via_aplicacion modulo5.enum_registro_medicamenti_via_aplicacion,
    p_costo_unitario NUMERIC,
    p_fecha_aplicacion DATE,
    p_lote VARCHAR,
    p_vencimiento_lote DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_costo_total NUMERIC;
BEGIN
    -- 1. Calcular costo total
    v_costo_total := p_cantidad * p_costo_unitario;

    -- 2. Insertar registro
    INSERT INTO modulo5.registros_medicamentos (
        id_activo_biologico, nombre_medicamento, descripcion_clinica,
        unidad_dosis, cantidad, via_aplicacion, costo_unitario_medicamento,
        costo_total_medicamento, fecha_aplicacion, lote_medicameto,
        fehca_vencimietno_lote, id_usuario, id_usuario_veterinario, fecha_registro
    ) VALUES (
        p_id_activo, p_nombre_medicamento, p_descripcion_clinica,
        p_unidad_dosis, p_cantidad, p_via_aplicacion, p_costo_unitario,
        v_costo_total, p_fecha_aplicacion, p_lote,
        p_vencimiento_lote, p_id_usuario, p_id_veterinario, CURRENT_TIMESTAMP
    );

    -- 3. Auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 5',
        'SUMINISTROS',
        'Registro de aplicación de medicamento: ' || p_nombre_medicamento,
        'EXITOSO',
        'ACTIVO',
        jsonb_build_object(
            'id_activo', p_id_activo,
            'medicamento', p_nombre_medicamento,
            'costo_total', v_costo_total
        )
    );

    COMMIT;
END;
$$;

-- ------------------------------------------------------------------------------
-- RF-76: Cálculo de Índice de Conversión Alimenticia (ICA/CA)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo5.sp_calcular_ica(
    p_id_usuario INT,
    p_id_activo INT,
    p_id_ciclo INT,
    p_peso_actual NUMERIC,
    p_esquema modulo5.enum_medicion_incremental_esquema
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_peso_inicial NUMERIC;
    v_ganancia_peso NUMERIC;
    v_consumo_acumulado NUMERIC;
    v_ica NUMERIC;
    v_costo_alimento_acum NUMERIC;
    v_costo_inversion NUMERIC;
BEGIN
    -- 1. Obtener peso inicial del ciclo (podría venir de un pesaje inicial o del registro de siembra)
    -- Asumimos que el peso inicial se obtiene del primer pesaje o se registra al inicio del ciclo
    SELECT COALESCE(MIN(peso_actual), 0) INTO v_peso_inicial 
    FROM modulo5.mediciones_incrementales 
    WHERE id_activo_biologico = p_id_activo AND id_ciclo_productivo = p_id_ciclo;

    -- Si no hay registros previos, el peso inicial es el actual (primer registro)
    IF v_peso_inicial = 0 THEN
        v_peso_inicial := p_peso_actual;
    END IF;

    -- 2. Calcular Ganancia de Peso
    v_ganancia_peso := p_peso_actual - v_peso_inicial;

    -- 3. Obtener Consumo Acumulado de Alimento para el activo en este ciclo
    SELECT SUM(cantidad_suministrada), SUM(costo_total)
    INTO v_consumo_acumulado, v_costo_alimento_acum
    FROM modulo5.registros_consumo_alimentos
    WHERE id_activo_biologico = p_id_activo;

    -- 4. Calcular ICA (Food / Weight Gain)
    -- Evitar división por cero
    IF v_ganancia_peso > 0 THEN
        v_ica := v_consumo_acumulado / v_ganancia_peso;
    ELSE
        v_ica := 0;
    END IF;

    -- 5. Obtener Costo de Inversión (Suma de medicamentos + otros costos si aplica)
    SELECT SUM(costo_total_medicamento) INTO v_costo_inversion
    FROM modulo5.registros_medicamentos
    WHERE id_activo_biologico = p_id_activo;

    -- 6. Insertar en mediciones_incrementales
    INSERT INTO modulo5.mediciones_incrementales (
        id_activo_biologico, id_ciclo_productivo, fecha_medicion,
        peso_actual, peso_inicial_ciclo, ganancia_peso,
        consumo_alimento_acumulado, conversion_alimenticia,
        costo_acumalado, costo_acumulado_inversion, esquema_proceso,
        id_usuario, fecha_creacion
    ) VALUES (
        p_id_activo, p_id_ciclo, CURRENT_DATE,
        p_peso_actual, v_peso_inicial, v_ganancia_peso,
        COALESCE(v_consumo_acumulado, 0), v_ica,
        COALESCE(v_costo_alimento_acum, 0), COALESCE(v_costo_inversion, 0),
        p_esquema, p_id_usuario, CURRENT_TIMESTAMP
    );

    -- 7. Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        3, -- CALCULO (Asumido)
        'Modulo 5',
        'ANALITICA',
        'Cálculo de ICA para activo ID: ' || p_id_activo,
        'EXITOSO',
        'COMPLETADO',
        jsonb_build_object(
            'ica_resultado', v_ica,
            'ganancia_peso', v_ganancia_peso,
            'consumo_total', v_consumo_acumulado
        )
    );

    COMMIT;
END;
$$;
