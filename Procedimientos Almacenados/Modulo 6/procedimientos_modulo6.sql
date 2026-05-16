-- ==============================================================================
-- Archivo: procedimientos_modulo6.sql
-- Descripción: Procedimientos almacenados para el Módulo 6 (Gestión Financiera y Costos)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Registro de Cotizaciones
-- ------------------------------------------------------------------------------
-- Lógica explícita: Este procedimiento maneja la inserción de cotizaciones financieras.
-- Se incluye la validación estricta de fechas (la emisión no puede ser futura respecto al registro,
-- y el vencimiento debe ser posterior a la emisión) para garantizar coherencia contable.
-- También se valida que los montos financieros no sean negativos.
-- Para futuras validaciones, se recomienda cruzar id_periodo_contable con la tabla de periodos 
-- para verificar que el periodo esté "ABIERTO".
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo6.sp_registrar_cotizacion(
    p_id_usuario                INT,
    p_fecha_emision             DATE,
    p_id_periodo_contable       INT,
    p_activos_cotizados         INT[],
    p_valor_razonable_referencia NUMERIC(18,4),
    p_valor_cotizacion_propuesto NUMERIC(18,4),
    p_condiciones               TEXT,
    p_estado                    modulo6.enum_cotizaciones_estado_cotizacion,
    p_fecha_vencimiento         DATE,
    p_accounting_account        VARCHAR(20)[],
    p_line_type                 VARCHAR(60),
    p_type_code                 CHAR DEFAULT '4',
    p_motivo_anulacion          TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_cotizacion INT;
BEGIN
    -- Validar fechas de cotización
    IF p_fecha_emision > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de emisión de la cotización no puede ser futura.';
    END IF;

    IF p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento < p_fecha_emision THEN
        RAISE EXCEPTION 'La fecha de vencimiento no puede ser anterior a la fecha de emisión.';
    END IF;

    -- Validar montos financieros
    IF p_valor_razonable_referencia < 0 OR p_valor_cotizacion_propuesto < 0 THEN
        RAISE EXCEPTION 'Los valores financieros de la cotización no pueden ser negativos.';
    END IF;

    -- Validar motivo de anulación (Constraint: chk_anulacion_requiere_motivo)
    IF p_estado = 'ANULADA' AND (p_motivo_anulacion IS NULL OR TRIM(p_motivo_anulacion) = '') THEN
        RAISE EXCEPTION 'Es obligatorio proporcionar un motivo de anulación si el estado es ANULADA.';
    END IF;

    -- Inserción de la cotización
    INSERT INTO modulo6.cotizaciones (
        fecha_emision, id_periodo_contable, activos_cotizados,
        valor_razonable_referencia, "valor_cotizacion_propuesto ", -- Respeta el espacio en la columna
        condiciones, estado, fecha_vencimiento, accounting_account,
        line_type, type_code, id_usuario, motivo_anulacion
    ) VALUES (
        p_fecha_emision, p_id_periodo_contable, p_activos_cotizados,
        p_valor_razonable_referencia, p_valor_cotizacion_propuesto,
        p_condiciones, p_estado, p_fecha_vencimiento, p_accounting_account,
        p_line_type, p_type_code, p_id_usuario, p_motivo_anulacion
    ) RETURNING id_cotizacion INTO v_id_cotizacion;

    -- Registro de auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 6',
        'FINANZAS',
        'Registro de cotización financiera ID: ' || v_id_cotizacion,
        'exitoso',
        'ACTIVO',
        jsonb_build_object(
            'id_cotizacion', v_id_cotizacion,
            'valor_propuesto', p_valor_cotizacion_propuesto
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
-- Registro de Costos
-- ------------------------------------------------------------------------------
-- Lógica explícita: Inserta en modulo6.registros_costos. Se exige justificación
-- para auditorías. Se valida que el monto del costo sea estrictamente positivo (>0)
-- dado que no tiene sentido registrar un costo nulo o negativo contablemente.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo6.sp_registrar_costo_financiero(
    p_id_usuario             INT,
    p_naturaleza_costo       modulo6.enum_registros_costos_naturaleza_costo,
    p_subtipo_costo          modulo6.enum_registros_costos_subtipo_costo,
    p_id_activo_biologico    INT,
    p_monto_costo            NUMERIC(18,4),
    p_accounting_account     VARCHAR(20)[],
    p_line_type              VARCHAR(60),
    p_exportable_aaef        BOOLEAN,
    p_politica_capitalizacion modulo6.enum_registros_costos_politica_capitalizacion,
    p_estado                 modulo6.enum_registros_costos_estado_costo,
    p_justificacion          TEXT,
    p_id_periodo_contable    INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_registro_costo INT;
BEGIN
    -- Validar monto de costo
    IF p_monto_costo <= 0 THEN
        RAISE EXCEPTION 'El monto del costo debe ser mayor a cero.';
    END IF;

    -- Validar justificación
    IF p_justificacion IS NULL OR TRIM(p_justificacion) = '' THEN
        RAISE EXCEPTION 'Es obligatorio proporcionar una justificación para el registro del costo.';
    END IF;

    -- Inserción del costo
    INSERT INTO modulo6.registros_costos (
        naturaleza_costo, subtipo_costo, id_activo_biologico,
        monto_costo, accounting_account, line_type,
        exportable_aaef, politica_capitalizacion, estado,
        justificacion, id_periodo_contable, id_usuario
    ) VALUES (
        p_naturaleza_costo, p_subtipo_costo, p_id_activo_biologico,
        p_monto_costo, p_accounting_account, p_line_type,
        p_exportable_aaef, p_politica_capitalizacion, p_estado,
        p_justificacion, p_id_periodo_contable, p_id_usuario
    ) RETURNING id_registro_costo INTO v_id_registro_costo;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 6',
        'COSTOS',
        'Registro de costo para activo ID: ' || p_id_activo_biologico,
        'exitoso',
        'ACTIVO',
        jsonb_build_object(
            'id_registro_costo', v_id_registro_costo,
            'monto', p_monto_costo
        )
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
