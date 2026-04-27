-- ==============================================================================
-- Archivo: procedimientos_modulo2.sql
-- Descripción: Procedimientos almacenados para el Módulo 2 (Gestión de Activos Biológicos)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-33: Registro de Activos Biológicos
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_activo_biologico(
    p_id_usuario INT, -- Requerido para auditoría
    p_id_especie INT,
    p_identificador VARCHAR,
    p_id_infraestructura INT,
    p_tipo modulo2.enum_activo_biologico_tipo,
    p_origen_financiero modulo2.enum_activo_biologico_origen_financiero,
    p_costo_adquisicion NUMERIC(18,4),
    p_descripcion VARCHAR,
    p_cantidad_inicial INT DEFAULT NULL -- Sólo para tipo poblacional
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_activo INT;
    v_id_estado_activo INT;
BEGIN
    -- Validar exclusividad de campos según el tipo
    IF p_tipo = 'INDIVIDUAL' THEN
        IF p_identificador IS NULL OR TRIM(p_identificador) = '' THEN
            RAISE EXCEPTION 'Para activos individuales, el identificador es obligatorio.';
        END IF;
        IF p_cantidad_inicial IS NOT NULL THEN
            RAISE EXCEPTION 'Para activos individuales, la cantidad inicial debe ser nula.';
        END IF;
    ELSIF p_tipo = 'POBLACIONAL' THEN
        IF p_identificador IS NOT NULL THEN
            RAISE EXCEPTION 'Para activos poblacionales, el identificador debe ser nulo.';
        END IF;
        IF p_cantidad_inicial IS NULL OR p_cantidad_inicial <= 0 THEN
            RAISE EXCEPTION 'Para activos poblacionales, la cantidad inicial es obligatoria y mayor a cero.';
        END IF;
    END IF;

    -- Validaciones de costo según origen
    IF p_origen_financiero IN ('compra', 'donacion') THEN
        IF p_costo_adquisicion IS NULL OR p_costo_adquisicion <= 0 THEN
            RAISE EXCEPTION 'El costo de adquisición es obligatorio y mayor a cero para compras o donaciones.';
        END IF;
    ELSIF p_origen_financiero = 'nacimiento' THEN
        IF p_costo_adquisicion IS NOT NULL THEN
            RAISE EXCEPTION 'El costo de adquisición debe ser nulo para origen nacimiento.';
        END IF;
    END IF;

    -- Obtener el ID del estado 'ACTIVO' (o similar)
    -- Asumiendo que la tabla es estados_activos_biologicos
    SELECT id_estado INTO v_id_estado_activo 
    FROM modulo2.estados_activos_biologicos 
    WHERE nombre ILIKE '%ACTIVO%' LIMIT 1;

    IF v_id_estado_activo IS NULL THEN
        v_id_estado_activo := 1; -- Fallback
    END IF;

    -- Insertar en activos_biologicos
    INSERT INTO modulo2.activos_biologicos (
        id_especie, indentficador, id_infraestructura, tipo, 
        id_estado, descripcion, origen_financiero, costo_adquisicion
    ) VALUES (
        p_id_especie, p_identificador, p_id_infraestructura, p_tipo, 
        v_id_estado_activo, p_descripcion, p_origen_financiero, p_costo_adquisicion
    ) RETURNING id_activo_biologico INTO v_id_activo;

    -- Registrar en tabla de detalles correspondientes según el tipo (Asumiendo que existen las tablas de detalle)
    IF p_tipo = 'INDIVIDUAL' THEN
        INSERT INTO modulo2.detalles_activos_individuales (
            id_activo_biologico
        ) VALUES (v_id_activo);
    ELSIF p_tipo = 'POBLACIONAL' THEN
        INSERT INTO modulo2.detalles_activos_biologicos_poblacionales (
            id_activo_biologico, cantidad_actual, cantidad_inicial
        ) VALUES (
            v_id_activo, p_cantidad_inicial, p_cantidad_inicial
        );
    END IF;

    -- 4. Registrar en auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL, -- id_sesion
        1, -- CREACION
        'Modulo 2',
        'ACTIVOS',
        'Registro de nuevo activo: ' || COALESCE(p_identificador, 'Poblacional ID ' || v_id_activo),
        'EXITOSO',
        'ACTIVO',
        jsonb_build_object(
            'id_activo', v_id_activo,
            'tipo', p_tipo,
            'infraestructura', p_id_infraestructura
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
-- RF-38: Registrar Evento Sanitario
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico INT,
    p_id_usuario INT,
    p_descripcion TEXT,
    p_diagnostico TEXT,
    p_medicamento VARCHAR,
    p_dosis NUMERIC(10,2),
    p_unidad_dosis VARCHAR(5),
    p_frecuencia INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_evento INT;
BEGIN
    -- Validar que el activo biológico existe
    IF NOT EXISTS (SELECT 1 FROM modulo2.activos_biologicos WHERE id_activo_biologico = p_id_activo_biologico) THEN
        RAISE EXCEPTION 'El activo biológico no existe.';
    END IF;

    -- Insertar el evento base
    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_id_activo_biologico, CURRENT_TIMESTAMP, p_descripcion, p_id_usuario
    ) RETURNING id_eventos INTO v_id_evento;

    -- Registrar auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 2',
        'SANIDAD',
        'Registro de evento sanitario para activo ID: ' || p_id_activo_biologico,
        'EXITOSO',
        'ACTIVO',
        jsonb_build_object(
            'id_evento', v_id_evento,
            'diagnostico', p_diagnostico,
            'medicamento', p_medicamento
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
-- RF-48: Transferencia Interna (Movimientos)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_transferencia_interna(
    p_id_activo_biologico INT,
    p_id_infraestructura_origen INT,
    p_id_infraestructura_destino INT,
    p_id_usuario INT,
    p_motivo TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar que orígen y destino sean diferentes
    IF p_id_infraestructura_origen = p_id_infraestructura_destino THEN
        RAISE EXCEPTION 'La infraestructura de origen y destino no pueden ser la misma.';
    END IF;

    -- Validar que el activo biológico existe y está en el origen correcto
    IF NOT EXISTS (SELECT 1 FROM modulo2.activos_biologicos 
                   WHERE id_activo_biologico = p_id_activo_biologico 
                   AND id_infraestructura = p_id_infraestructura_origen) THEN
        RAISE EXCEPTION 'El activo biológico no se encuentra en la infraestructura de origen indicada.';
    END IF;

    -- Registrar movimiento de SALIDA
    INSERT INTO modulo2.movimientos (
        id_activo_biologico, id_infraestructura, tipo_movimiento, fecha, id_usuario, motivo
    ) VALUES (
        p_id_activo_biologico, p_id_infraestructura_origen, 'salida', CURRENT_TIMESTAMP, p_id_usuario, p_motivo
    );

    -- Registrar movimiento de ENTRADA
    INSERT INTO modulo2.movimientos (
        id_activo_biologico, id_infraestructura, tipo_movimiento, fecha, id_usuario, motivo
    ) VALUES (
        p_id_activo_biologico, p_id_infraestructura_destino, 'entrada', CURRENT_TIMESTAMP, p_id_usuario, p_motivo
    );

    -- Registrar auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        4, -- MOVIMIENTO
        'Modulo 2',
        'LOGISTICA',
        'Transferencia de activo ID ' || p_id_activo_biologico || ' de ' || p_id_infraestructura_origen || ' a ' || p_id_infraestructura_destino,
        'EXITOSO',
        'ACTIVO',
        jsonb_build_object(
            'origen', p_id_infraestructura_origen,
            'destino', p_id_infraestructura_destino,
            'motivo', p_motivo
        )
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
