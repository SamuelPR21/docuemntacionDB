-- ==============================================================================
-- Archivo: procedimientos_modulo7.sql
-- Descripción: Procedimientos almacenados para el Módulo 7 (Integraciones y APIs)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Registro de Cliente Externo (API Consumer)
-- ------------------------------------------------------------------------------
-- Lógica explícita: Este procedimiento registra a los sistemas/clientes externos 
-- (ej. AgroFusión) que tienen permitido consumir la API del puente de integración (M07).
-- Se valida que el código y nombre no estén vacíos. A futuro, este procedimiento 
-- se debe usar en conjunto con una validación de unicidad (el código debería ser único)
-- para asegurar trazabilidad perfecta. También se asume que IP permitida puede ser nula
-- si el cliente se conecta desde IPs dinámicas, pero preferiblemente en producción 
-- debería forzarse una lista blanca (whitelist).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo7.sp_registrar_cliente_externo(
    p_id_usuario    INT,
    p_codigo        VARCHAR(50),
    p_nombre        VARCHAR(150),
    p_tipo          VARCHAR(20),
    p_estado        modulo7.enum_cliente_externo_tipo,
    p_ip_permitida  INET DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_cliente INT;
BEGIN
    -- Validación estricta de código
    IF p_codigo IS NULL OR TRIM(p_codigo) = '' THEN
        RAISE EXCEPTION 'El código de identificación del cliente externo no puede estar vacío.';
    END IF;

    -- Validación estricta de nombre
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre del cliente externo es obligatorio.';
    END IF;

    -- Inserción del cliente
    INSERT INTO modulo7.clientes_externos (
        codigo, nombre, tipo, estado, ip_permitida
    ) VALUES (
        p_codigo, p_nombre, p_tipo, p_estado, p_ip_permitida
    ) RETURNING id_cliente_externo INTO v_id_cliente;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1, -- CREACION
        'Modulo 7',
        'API_AUTH',
        'Registro de nuevo cliente externo API: ' || p_codigo,
        'exitoso',
        'ACTIVO',
        jsonb_build_object(
            'id_cliente', v_id_cliente,
            'ip_configurada', p_ip_permitida
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
-- Registro de Solicitud de Integración
-- ------------------------------------------------------------------------------
-- Lógica explícita: Cada vez que un sistema externo llama al Gateway, se debe registrar
-- la solicitud. Se requiere que la duración (duracion_ms) sea positiva (0 o mayor).
-- Además, se exige validar que la fecha finalización no sea menor a la fecha de inicio.
-- Esto asegura que los analíticos de rendimiento de la API en el Módulo 7 sean consistentes.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo7.sp_registrar_solicitud_integracion(
    p_id_cliente_externo   INT,
    p_id_usuario           INT,
    p_id_periodo_contable  INT,
    p_id_version_contrato  INT,
    p_estado               modulo7.enum_integraciones_solicitudes_estado,
    p_fecha_comienzoo      TIMESTAMPTZ,
    p_fecha_finalizacion   TIMESTAMPTZ,
    p_duracion_ms          INT,
    p_correlacion_id       UUID,
    p_id_error             INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_solicitud INT;
BEGIN
    -- Validar tiempos y duración
    IF p_fecha_finalizacion < p_fecha_comienzoo THEN
        RAISE EXCEPTION 'La fecha de finalización de la integración no puede ser anterior a su comienzo.';
    END IF;

    IF p_duracion_ms IS NOT NULL AND p_duracion_ms < 0 THEN
        RAISE EXCEPTION 'La duración en milisegundos de la petición no puede ser negativa.';
    END IF;

    -- Inserción de la solicitud
    INSERT INTO modulo7.integraciones_solicitudes (
        id_cliente_externo, id_usuario, id_periodo_contable,
        id_version_contrato, estado, fecha_comienzoo,
        fecha_finalizacion, duracion_ms, correlacion_id, id_error
    ) VALUES (
        p_id_cliente_externo, p_id_usuario, p_id_periodo_contable,
        p_id_version_contrato, p_estado, p_fecha_comienzoo,
        p_fecha_finalizacion, p_duracion_ms, p_correlacion_id, p_id_error
    ) RETURNING id_integracion_solicitud INTO v_id_solicitud;

    -- Auditoría (se evita para integraciones altamente recurrentes a menos que sea fallo,
    -- pero se incluye para mantener trazabilidad homologada con el resto de módulos).
    -- Optimizamos auditando solo si hay error, para no saturar el log si hay miles por hora.
    IF p_id_error IS NOT NULL THEN
        CALL modulo1.sp_registrar_auditoria(
            p_id_usuario,
            NULL,
            6, -- EVENTO SISTEMA/FALLO
            'Modulo 7',
            'API_GATEWAY',
            'Fallo en solicitud de integración. Correlación: ' || p_correlacion_id,
            'fallido',
            'ACTIVO',
            jsonb_build_object(
                'id_solicitud', v_id_solicitud,
                'id_error', p_id_error
            )
        );
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
