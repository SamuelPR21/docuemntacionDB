-- ==============================================================================
-- Archivo: procedimientos_modulo8.sql
-- Descripción: Procedimientos almacenados para el Módulo 8 (Analítica, Reportes y Dashboards)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Registro de Snapshot de KPI
-- ------------------------------------------------------------------------------
-- Lógica explícita: Se guarda una fotografía (snapshot) del estado de un KPI.
-- Se valida estrictamente que la fecha del cálculo no sea futura (esto también 
-- está respaldado por el constraint chk_snapshot_fecha_calculo_no_futura).
-- Esta restricción previene corrupciones temporales en los dashboards y métricas
-- históricas. Para validar en el futuro, se puede agregar que los IDs de activo 
-- e infraestructura sean congruentes (es decir, el activo debe estar ubicado en 
-- esa infraestructura en esa fecha específica).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo8.sp_registrar_snapshot_kpi(
    p_id_usuario         INT,
    p_id_indicador_kpi   INT,
    p_id_activo_biologico INT,
    p_id_infraestructura INT,
    p_estado_semaforo    modulo8.snapshots_kpi_estado_semaforo,
    p_fecha_calculo      TIMESTAMPTZ,
    p_metadatos          JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_snapshot INT;
BEGIN
    -- Validar fecha de cálculo
    IF p_fecha_calculo > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'La fecha de cálculo del KPI no puede ser futura.';
    END IF;

    -- Inserción del snapshot
    INSERT INTO modulo8.snapshots_kpi (
        id_indicador_kpi, id_activo_biologico, id_infraestructura,
        estado_semaforo, fecha_calculo, metadatos
    ) VALUES (
        p_id_indicador_kpi, p_id_activo_biologico, p_id_infraestructura,
        p_estado_semaforo, p_fecha_calculo, p_metadatos
    ) RETURNING id_snapshot_kpi INTO v_id_snapshot;

    -- Auditoría centralizada
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 8',
        'ANALITICA',
        'Registro de Snapshot KPI ' || p_id_indicador_kpi || ' para activo ' || p_id_activo_biologico,
        'exitoso',
        'ACTIVO',
        jsonb_build_object(
            'id_snapshot', v_id_snapshot,
            'estado_semaforo', p_estado_semaforo
        )
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- Registro de Retroalimentación de Feedback (Machine Learning / Analítica)
-- ------------------------------------------------------------------------------
-- Lógica explícita: Alimenta la base de datos con correcciones manuales hechas 
-- por los usuarios sobre los reportes o pronósticos (historiales predictivos).
-- Es obligatorio vincular el usuario y el historial. El campo "tiene_conflicto"
-- se establece explícitamente y servirá para procesos asíncronos que re-entrenan 
-- el modelo.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo8.sp_registrar_retroalimentacion_feedback(
    p_id_historial_clinico INT,
    p_id_usuario           INT,
    p_estado               modulo8.retroalimentacion_feedback_estado,
    p_tiene_conflicto      BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_feedback INT;
BEGIN
    -- Inserción de la retroalimentación
    INSERT INTO modulo8.retroalimentacion_feedback (
        id_historial_clinico, id_usuario, estado, tiene_conflicto, fecha_registro
    ) VALUES (
        p_id_historial_clinico, p_id_usuario, p_estado, p_tiene_conflicto, CURRENT_TIMESTAMP
    ) RETURNING id_retroalimentacion_feedback INTO v_id_feedback;

    -- Auditoría centralizada
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 8',
        'ANALITICA',
        'Feedback ingresado para historial clínico ' || p_id_historial_clinico,
        'exitoso',
        'ACTIVO',
        jsonb_build_object(
            'id_feedback', v_id_feedback,
            'tiene_conflicto', p_tiene_conflicto
        )
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
