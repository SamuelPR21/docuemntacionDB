-- ==============================================================================
-- Archivo: procedimientos_modulo2.sql
-- Descripción: Procedimientos almacenados para el Módulo 2 (Gestión de Activos Biológicos)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- RF-33: Registro de Activos Biológicos
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_activo_biologico(
    p_id_usuario          INT,
    p_id_especie          INT,
    p_identificador       VARCHAR,
    p_id_infraestructura  INT,
    p_tipo                modulo2.enum_activo_biologico_tipo,
    p_origen_financiero   modulo2.enum_activo_biologico_origen_financiero,
    p_costo_adquisicion   NUMERIC(18,4),
    p_descripcion         VARCHAR,
    p_cantidad_inicial    INT DEFAULT NULL,
    p_fecha_inicio_ciclo  INT DEFAULT NULL,
    p_soporte_documental  VARCHAR DEFAULT NULL,
    -- Nuevos parámetros para detalles individuales:
    p_raza                VARCHAR DEFAULT NULL,
    p_sexo                VARCHAR DEFAULT NULL,
    p_fecha_nacimiento    TIMESTAMPTZ DEFAULT NULL,
    p_peso_inicial        NUMERIC(10,3) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_activo        INT;
    v_id_estado_activo INT;
    v_atributos        JSONB;
BEGIN
    -- Validaciones de tipo
    IF p_tipo = 'INDIVIDUAL' THEN
        IF p_identificador IS NULL OR TRIM(p_identificador) = '' THEN
            RAISE EXCEPTION 'Para activos individuales, el identificador es obligatorio.';
        END IF;
        IF p_cantidad_inicial IS NOT NULL THEN
            RAISE EXCEPTION 'Para activos individuales, la cantidad inicial debe ser nula.';
        END IF;
        IF p_raza IS NULL OR TRIM(p_raza) = '' THEN
            RAISE EXCEPTION 'La raza es obligatoria para activos individuales.';
        END IF;
        IF p_sexo IS NULL OR UPPER(p_sexo) NOT IN ('MACHO','HEMBRA') THEN
            RAISE EXCEPTION 'El sexo debe ser ''Macho'' o ''Hembra''.';
        END IF;
        IF p_fecha_nacimiento IS NULL THEN
            RAISE EXCEPTION 'La fecha de nacimiento es obligatoria para activos individuales.';
        END IF;
    ELSIF p_tipo = 'POBLACIONAL' THEN
        IF p_identificador IS NOT NULL THEN
            RAISE EXCEPTION 'Para activos poblacionales, el identificador debe ser nulo.';
        END IF;
        IF p_cantidad_inicial IS NULL OR p_cantidad_inicial <= 0 THEN
            RAISE EXCEPTION 'Para activos poblacionales, la cantidad inicial es obligatoria y mayor a cero.';
        END IF;
    END IF;

    -- Obtener estado ACTIVO
    SELECT id_estado_activo_biologico INTO v_id_estado_activo 
    FROM modulo2.estados_activos_biologicos 
    WHERE nombre ILIKE '%ACTIVO%' LIMIT 1;
    IF v_id_estado_activo IS NULL THEN
        v_id_estado_activo := 1;
    END IF;

    -- Construir atributos dinámicos
    IF p_origen_financiero IN ('compra', 'donacion') THEN
        v_atributos := jsonb_build_object('soporte_documental', p_soporte_documental);
    ELSE
        v_atributos := '{}'::jsonb;
    END IF;

    -- Insertar en activos_biologicos
    INSERT INTO modulo2.activos_biologicos (
        id_especie, indentficador, id_infraestructura, tipo, 
        id_estado, descripcion, origen_financiero, costo_adquisicion,
        fecha_inicio_ciclo, atributos_dinamicos, id_usuario, fecha_creacion
    )
    VALUES (
        p_id_especie, p_identificador, p_id_infraestructura, p_tipo, 
        v_id_estado_activo, p_descripcion, p_origen_financiero, p_costo_adquisicion,
        p_fecha_inicio_ciclo, v_atributos, p_id_usuario, now()
    )
    RETURNING id_activo_biologico INTO v_id_activo;

    -- Detalles según tipo
    IF p_tipo = 'INDIVIDUAL' THEN
        INSERT INTO modulo2.detalles_activos_individuales (
            id_activo_biologico,
            raza,
            sexo,
            fecha_nacimeinto,
            peso_inicial,
            fecha_creacion,
            id_usuario
        ) VALUES (
            v_id_activo,
            p_raza,
            p_sexo,
            p_fecha_nacimiento,
            p_peso_inicial,
            now()::time,
            p_id_usuario
        );
    ELSIF p_tipo = 'POBLACIONAL' THEN
        INSERT INTO modulo2.detalles_activos_biologicos_poblacionales
            (id_activo_biologico, cantidad_actual, cantidad_inicial)
        VALUES
            (v_id_activo, p_cantidad_inicial, p_cantidad_inicial);
    END IF;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario, NULL, 1, 'Modulo 2', 'ACTIVOS',
        'Registro activo: ' || COALESCE(p_identificador, 'Poblacional ID ' || v_id_activo),
        'exitoso', 'ACTIVO',
        jsonb_build_object('id_activo', v_id_activo, 'tipo', p_tipo)
    );
END;
$$;
-- ------------------------------------------------------------------------------
-- RF-38: Registrar Evento Sanitario
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico INT,
    p_id_usuario          INT,
    p_descripcion         TEXT,
    p_diagnostico         TEXT,
    p_medicamento         VARCHAR DEFAULT NULL,
    p_dosis               NUMERIC(10,2) DEFAULT NULL,
    p_unidad_dosis        VARCHAR(5) DEFAULT NULL,
    p_frecuencia          INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_evento INT;
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (SELECT 1 FROM modulo2.activos_biologicos WHERE id_activo_biologico = p_id_activo_biologico) THEN
        RAISE EXCEPTION 'El activo biológico con ID % no existe.', p_id_activo_biologico;
    END IF;

    -- Validar datos sanitarios obligatorios
    IF p_diagnostico IS NULL OR TRIM(p_diagnostico) = '' THEN
        RAISE EXCEPTION 'El diagnóstico es obligatorio.';
    END IF;

    -- Si hay medicamento, la unidad de dosis y la dosis son obligatorias
    IF p_medicamento IS NOT NULL AND TRIM(p_medicamento) <> '' THEN
        IF p_unidad_dosis IS NULL OR TRIM(p_unidad_dosis) = '' THEN
            RAISE EXCEPTION 'Se debe especificar la unidad de dosis cuando se administra medicamento.';
        END IF;
        IF p_dosis IS NULL OR p_dosis <= 0 THEN
            RAISE EXCEPTION 'La dosis debe ser un valor positivo.';
        END IF;
    ELSE
        -- Si no hay medicamento, la unidad de dosis puede dejarse con un valor por defecto (requerida por NOT NULL en la tabla)
        p_unidad_dosis := COALESCE(p_unidad_dosis, '');
    END IF;

    -- Insertar evento base
    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_id_activo_biologico, CURRENT_TIMESTAMP, p_descripcion, p_id_usuario
    ) RETURNING id_eventos INTO v_id_evento;

    -- Insertar detalle sanitario
    INSERT INTO modulo2.eventos_sanitarios (
        id_evento,
        diagnostico,
        medicamento,
        dosis,
        unidad_dosis,
        frecuencia
    ) VALUES (
        v_id_evento,
        p_diagnostico,
        p_medicamento,
        p_dosis,
        p_unidad_dosis,
        p_frecuencia
    );

    -- Auditoría (sin COMMIT/ROLLBACK)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- Tipo evento: CREACION
        'Modulo 2',
        'SANIDAD',
        'Registro de evento sanitario para activo ID: ' || p_id_activo_biologico,
        'exitoso',          -- ¡minúsculas obligatorio!
        'ACTIVO',
        jsonb_build_object(
            'id_evento', v_id_evento,
            'diagnostico', p_diagnostico,
            'medicamento', p_medicamento
        )
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- RF-48: Transferencia Interna (Movimientos)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_transferencia_interna(
    p_id_activo_biologico      INT,
    p_id_infraestructura_origen INT,
    p_id_infraestructura_destino INT,
    p_id_usuario               INT,
    p_motivo                   TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar que origen y destino sean diferentes
    IF p_id_infraestructura_origen = p_id_infraestructura_destino THEN
        RAISE EXCEPTION 'La infraestructura de origen y destino no pueden ser la misma.';
    END IF;

    -- Validar que el activo existe y está en el origen
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos 
        WHERE id_activo_biologico = p_id_activo_biologico 
          AND id_infraestructura = p_id_infraestructura_origen
    ) THEN
        RAISE EXCEPTION 'El activo no se encuentra en la infraestructura de origen indicada.';
    END IF;

    -- Insertar el movimiento (un solo registro)
    INSERT INTO modulo2.movimientos (
        id_usuario,
        fecha_transferencia,
        tipo,
        id_activo_biologico,
        id_infraestructura_origen,
        id_infraestructura_destino,
        fecha_registro
    ) VALUES (
        p_id_usuario,
        CURRENT_TIMESTAMP,
        'salida',                     -- El tipo podría ser también 'entrada', según criterio de negocio
        p_id_activo_biologico,
        p_id_infraestructura_origen,
        p_id_infraestructura_destino,
        CURRENT_TIMESTAMP
    );

    -- Actualizar la infraestructura del activo al destino
    UPDATE modulo2.activos_biologicos
    SET id_infraestructura = p_id_infraestructura_destino
    WHERE id_activo_biologico = p_id_activo_biologico;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        4,                       -- MOVIMIENTO (ajusta según tu catálogo de tipos)
        'Modulo 2',
        'LOGISTICA',
        'Transferencia del activo ' || p_id_activo_biologico ||
        ' desde ' || p_id_infraestructura_origen || ' hacia ' || p_id_infraestructura_destino,
        'exitoso',               -- minúsculas obligatorio
        'ACTIVO',
        jsonb_build_object(
            'origen', p_id_infraestructura_origen,
            'destino', p_id_infraestructura_destino,
            'motivo', p_motivo
        )
    );
END;
$$;



BEGIN;
CALL modulo2.sp_registrar_activo_biologico(
    p_id_usuario          => 5,
    p_id_especie          => 3,
    p_identificador       => 'BOV-001-2025',
    p_id_infraestructura  => 1,
    p_tipo                => 'INDIVIDUAL',
    p_origen_financiero   => 'compra',
    p_costo_adquisicion   => 150000.5000,
    p_descripcion         => 'Toro reproductor Brahman',
    p_cantidad_inicial    => NULL,
    p_fecha_inicio_ciclo  => 2025,
    p_soporte_documental  => 'Factura #12345',
    p_raza                => 'Brahman',
    p_sexo                => 'Macho',
    p_fecha_nacimiento    => '2024-06-15 10:00:00-05',
    p_peso_inicial        => 320.500
);
COMMIT;



CALL modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico => 10,
    p_id_usuario          => 5,
    p_descripcion         => 'Control de rutina, sin novedad',
    p_diagnostico         => 'Sano',
    p_medicamento         => NULL,   -- o simplemente no lo pasas, ya que tiene DEFAULT NULL
    p_dosis               => NULL,
    p_unidad_dosis        => NULL,   -- se convierte en '' internamente
    p_frecuencia          => NULL
);

CALL modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico => 10,
    p_id_usuario          => 5,
    p_descripcion         => 'Presenta diarrea y decaimiento',
    p_diagnostico         => 'Posible parasitosis gastrointestinal',
    p_medicamento         => 'Albendazol',
    p_dosis               => 10.00,
    p_unidad_dosis        => 'ml',
    p_frecuencia          => 3
);



CALL modulo2.sp_transferencia_interna(
    p_id_activo_biologico       => 10,
    p_id_infraestructura_origen => 2,
    p_id_infraestructura_destino => 1,
    p_id_usuario               => 5,
    p_motivo                   => 'Reubicación por finalización de cuarentena'
);
