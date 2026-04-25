-- ==============================================================================
-- Archivo: procedimientos_modulo4.sql
-- Descripción: Procedimientos almacenados para el Módulo 4 (Inteligencia Artificial y Predicciones)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-60: Registro de Observaciones Clínicas
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo4.sp_registrar_observacion_clinica(
    p_id_activo_biologico INT,
    p_id_usuario INT,
    p_temperatura_rectal NUMERIC(4,1),
    p_frecuencia_cardiaca SMALLINT,
    p_frecuencia_respiratoria SMALLINT,
    p_condicion_corporal NUMERIC(3,1)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_observacion INT;
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (SELECT 1 FROM modulo2.activos_biologicos WHERE id_activo_biologico = p_id_activo_biologico) THEN
        RAISE EXCEPTION 'El activo biológico no se encuentra registrado en el sistema.';
    END IF;

    -- Validar rangos biológicos básicos (ejemplo)
    IF p_temperatura_rectal IS NOT NULL AND (p_temperatura_rectal < 30 OR p_temperatura_rectal > 45) THEN
        RAISE EXCEPTION 'La temperatura rectal ingresada está fuera del rango biológico posible.';
    END IF;

    -- Registrar observación
    INSERT INTO modulo4.observaciones_clinicas (
        id_activo_biologico, id_usuario, fecha,
        temperatura_rectal, frecuencia_cardiaca, frecuencia_respiratoria, condicion_corporal
    ) VALUES (
        p_id_activo_biologico, p_id_usuario, CURRENT_TIMESTAMP,
        p_temperatura_rectal, p_frecuencia_cardiaca, p_frecuencia_respiratoria, p_condicion_corporal
    ) RETURNING id_observacion_clinica INTO v_id_observacion;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;


-- ------------------------------------------------------------------------------
-- RF-65: Registro de Predicción Sanitaria
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo4.sp_registrar_prediccion(
    p_id_observacion INT,
    p_id_patologia INT,
    p_id_version_modelo INT,
    p_probabilidad_pct NUMERIC(6,3),
    p_umbral_usado NUMERIC(5,2),
    p_clase_predicha modulo4.enum_predicciones_clase
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_supera_umbral BOOLEAN;
BEGIN
    -- Validar probabilidad
    IF p_probabilidad_pct < 0 OR p_probabilidad_pct > 100 THEN
        RAISE EXCEPTION 'La probabilidad debe estar entre 0 y 100.';
    END IF;

    -- Determinar si supera el umbral
    v_supera_umbral := p_probabilidad_pct >= p_umbral_usado;

    -- Insertar predicción
    INSERT INTO modulo4.predicciones (
        id_observacion, id_patologia, id_version_modelo,
        probabilidad_pct, supera_umbral, umbral_usado_, clase_predicha
    ) VALUES (
        p_id_observacion, p_id_patologia, p_id_version_modelo,
        p_probabilidad_pct, v_supera_umbral, p_umbral_usado, p_clase_predicha
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
