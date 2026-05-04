-- ==============================================================================
-- Archivo: procedimientos_modulo2_completo.sql
-- Descripción: Script completo — Funciones y Procedimientos Módulo 2
--              (Gestión de Activos Biológicos — SGP Multiespecie de Precisión)
-- Autor evaluador: Alexander Lozada Caviedes
-- Fecha: 2026-04-26
-- ==============================================================================
-- ORDEN DE CREACIÓN:
--   1. Funciones utilitarias (fn_)         — requeridas por los SPs
--   2. sp_recalcular_metricas_lote         — requerida por sp_registrar_baja
--   3. sp_registrar_activo_biologico       — RF-33
--   4. sp_cambiar_estado_activo            — RF-44 (transversal)
--   5. sp_cambiar_fase_activo              — RF-37
--   6. sp_cerrar_ciclo_productivo          — RF-38
--   7. sp_registrar_baja                   — RF-45
--   8. sp_transferir_activo                — RF-48
--   9. sp_transferencia_interna            — RF-48 (versión existente)
--  10. sp_registrar_evento_biologico       — RF-39
--  11. sp_registrar_evento_sanitario       — RF-41
--  12. sp_registrar_evento_sanitario_con_estado — RF-41
--  13. sp_calcular_indicadores_zootecnicos — RF-51
-- ==============================================================================


-- ==============================================================================
-- SECCIÓN 1: FUNCIONES UTILITARIAS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- fn_obtener_estado_actual_activo
-- RF: RF-44 (utilitaria transversal)
-- Propósito: Retorna el id del estado vigente del activo consultando
--            historicos_estados_activos. Si no hay historial, lee directamente
--            de activos_biologicos. Función de solo lectura.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION modulo2.fn_obtener_estado_actual_activo(
    p_activo_id INT
)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id_estado INT;
BEGIN
    -- Prioridad: último registro en el historial de estados
    SELECT id_estado_nuevo
    INTO   v_id_estado
    FROM   modulo2.historicos_estados_activos
    WHERE  id_activo_biologico = p_activo_id
    ORDER  BY fecha_cambio DESC, id_historico_estado_activo DESC
    LIMIT  1;

    -- Fallback: estado directo en activos_biologicos
    IF v_id_estado IS NULL THEN
        SELECT id_estado
        INTO   v_id_estado
        FROM   modulo2.activos_biologicos
        WHERE  id_activo_biologico = p_activo_id;
    END IF;

    RETURN v_id_estado;
END;
$$;


-- ------------------------------------------------------------------------------
-- fn_obtener_fase_activa_activo
-- RF: RF-37, RF-43, RF-47 (utilitaria transversal)
-- Propósito: Retorna la fase productiva activa (es_activa = TRUE) del activo
--            con su id_gestion_fases, id_ciclo_productiva, fechas e indicador
--            de actividad. Función de solo lectura.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION modulo2.fn_obtener_fase_activa_activo(
    p_activo_id INT
)
RETURNS TABLE (
    id_gestion_fases    INT,
    id_ciclo_productiva INT,
    fecha_inicio        TIMETZ,
    fecha_finalizacion  TIMESTAMPTZ,
    es_activa           BOOL
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT gf.id_gestion_fases,
           gf.id_ciclo_productiva,
           gf.fecha_inicio,
           gf.fecha_finalizacion,
           gf.es_activa
    FROM   modulo2.gestiones_fases gf
    WHERE  gf.id_activo_biologico = p_activo_id
      AND  gf.es_activa = TRUE
    LIMIT 1;
END;
$$;


-- ==============================================================================
-- SECCIÓN 2: sp_recalcular_metricas_lote
-- RF: RF-36 (utilitaria interna)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_recalcular_metricas_lote
-- Propósito: Recalcula biomasa_total y densidad de un lote poblacional usando
--            cantidad_actual × peso_promedio y cantidad_actual / superficie
--            de modulo9.infraestructuras. Solo actúa sobre activos POBLACIONAL.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_recalcular_metricas_lote(
    p_activo_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_infra_id        INT;
    v_cantidad_actual INT;
    v_peso_promedio   NUMERIC;
    v_superficie      NUMERIC(10,2);
BEGIN
    -- Obtener infraestructura y verificar que el activo existe y es POBLACIONAL
    SELECT id_infraestructura
    INTO   v_infra_id
    FROM   modulo2.activos_biologicos
    WHERE  id_activo_biologico = p_activo_id
      AND  tipo = 'POBLACIONAL';

    IF v_infra_id IS NULL THEN
        RAISE EXCEPTION
            'El activo ID % no existe o no es de tipo POBLACIONAL.', p_activo_id;
    END IF;

    -- Obtener métricas vigentes del lote
    SELECT cantidad_actual, peso_promedio
    INTO   v_cantidad_actual, v_peso_promedio
    FROM   modulo2.detalles_activos_biologicos_poblacionales
    WHERE  id_activo_biologico = p_activo_id;

    IF v_cantidad_actual IS NULL THEN
        RAISE EXCEPTION
            'No se encontraron detalles poblacionales para el activo ID %.', p_activo_id;
    END IF;

    -- Obtener superficie de la infraestructura
    SELECT superficie
    INTO   v_superficie
    FROM   modulo9.infraestructuras
    WHERE  id_infraestructura = v_infra_id;

    -- Actualizar biomasa_total y densidad
    UPDATE modulo2.detalles_activos_biologicos_poblacionales
    SET
        biomasa_total = v_cantidad_actual * v_peso_promedio,
        densidad      = CASE
                            WHEN v_superficie IS NOT NULL AND v_superficie > 0
                            THEN v_cantidad_actual::NUMERIC / v_superficie
                            ELSE 0
                        END
    WHERE id_activo_biologico = p_activo_id;
END;
$$;


-- ==============================================================================
-- SECCIÓN 3: RF-33 — Registro de Activos Biológicos
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_registrar_activo_biologico
-- RF: RF-33
-- Propósito: Registro completo y atómico de un activo biológico (INDIVIDUAL o
--            POBLACIONAL). Valida tipo, origen financiero, inserta en
--            activos_biologicos, crea el detalle correspondiente y registra
--            auditoría. El estado inicial lo fuerza el trigger
--            trg_activo_biologico_estado_inicial.
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
    p_cantidad_inicial    INT          DEFAULT NULL,
    p_fecha_inicio_ciclo  INT          DEFAULT NULL,
    p_soporte_documental  VARCHAR      DEFAULT NULL,
    p_raza                VARCHAR      DEFAULT NULL,
    p_sexo                VARCHAR      DEFAULT NULL,
    p_fecha_nacimiento    TIMESTAMPTZ  DEFAULT NULL,
    p_peso_inicial        NUMERIC(10,3) DEFAULT NULL,
    p_peso_promedio       NUMERIC(10,3) DEFAULT 0   -- peso promedio inicial del lote
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_activo        INT;
    v_id_estado_activo INT;
    v_atributos        JSONB;
BEGIN
    -- Validaciones por tipo
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
        IF p_sexo IS NULL OR UPPER(p_sexo) NOT IN ('MACHO', 'HEMBRA') THEN
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
            RAISE EXCEPTION
                'Para activos poblacionales, la cantidad inicial es obligatoria y mayor a cero.';
        END IF;
    END IF;

    -- Obtener id del estado ACTIVO (fallback a 1)
    SELECT id_estado_activo_biologico
    INTO   v_id_estado_activo
    FROM   modulo2.estados_activos_biologicos
    WHERE  nombre ILIKE '%ACTIVO%'
    LIMIT  1;

    IF v_id_estado_activo IS NULL THEN
        v_id_estado_activo := 1;
    END IF;

    -- Construir atributos dinámicos según origen financiero
    IF p_origen_financiero IN ('compra', 'donacion') THEN
        v_atributos := jsonb_build_object('soporte_documental', p_soporte_documental);
    ELSE
        v_atributos := '{}'::jsonb;
    END IF;

    -- Para POBLACIONAL, el trigger trg_fn_activo_biologico_coherencia_tipo
    -- busca cantidad_inicial dentro de atributos_dinamicos (JSONB), no como
    -- columna separada. Se debe incluir aquí para que pase la validación.
    IF p_tipo = 'POBLACIONAL' THEN
        v_atributos := v_atributos || jsonb_build_object('cantidad_inicial', p_cantidad_inicial);
    END IF;

    -- Insertar en activos_biologicos
    INSERT INTO modulo2.activos_biologicos (
        id_especie, identificador, id_infraestructura, tipo,
        id_estado, descripcion, origen_financiero, costo_adquisicion,
        fecha_inicio_ciclo, atributos_dinamicos, id_usuario, fecha_creacion
    ) VALUES (
        p_id_especie, p_identificador, p_id_infraestructura, p_tipo,
        v_id_estado_activo, p_descripcion, p_origen_financiero, p_costo_adquisicion,
        p_fecha_inicio_ciclo, v_atributos, p_id_usuario, now()
    )
    RETURNING id_activo_biologico INTO v_id_activo;

    -- Insertar detalle según tipo
    IF p_tipo = 'INDIVIDUAL' THEN
        INSERT INTO modulo2.detalles_activos_individuales (
            id_activo_biologico, raza, sexo, fecha_nacimeinto,
            peso_inicial, fecha_creacion, id_usuario
        ) VALUES (
            v_id_activo, p_raza, p_sexo, p_fecha_nacimiento,
            p_peso_inicial, now()::timetz, p_id_usuario
        );
    ELSIF p_tipo = 'POBLACIONAL' THEN
        INSERT INTO modulo2.detalles_activos_biologicos_poblacionales (
            id_activo_biologico, cantidad_actual, cantidad_inicial,
            peso_promedio, biomasa_total, densidad
        ) VALUES (
            v_id_activo,
            p_cantidad_inicial,
            p_cantidad_inicial,
            COALESCE(p_peso_promedio, 0),
            p_cantidad_inicial * COALESCE(p_peso_promedio, 0),
            0
        );
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


-- ==============================================================================
-- SECCIÓN 4: RF-44 — Cambio de Estado (punto de control centralizado)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_cambiar_estado_activo
-- RF: RF-44
-- Propósito: Único punto de control para cambios de estado. Valida existencia
--            del activo, que no esté en BAJA, que la fecha no sea futura y que
--            el motivo esté presente. Inserta en historicos_estados_activos;
--            los triggers trg_estado_activo_transicion_valida y
--            trg_sincronizar_estado_activo gestionan la validación de la matriz
--            de transiciones y la sincronización con activos_biologicos.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_cambiar_estado_activo(
    p_activo_id     INT,
    p_estado_nuevo  VARCHAR,       -- nombre del estado destino
    p_fecha_cambio  TIMESTAMPTZ,
    p_motivo        TEXT,
    p_usuario_id    INT,
    p_modulo_origen VARCHAR        -- debe ser 'modulo1'…'modulo9'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_actual INT;
    v_id_estado_nuevo  INT;
    v_nombre_actual    VARCHAR(25);
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_activo_id
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Fecha no futura
    IF p_fecha_cambio > now() THEN
        RAISE EXCEPTION
            'La fecha de cambio de estado no puede ser futura.';
    END IF;

    -- Motivo obligatorio
    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        RAISE EXCEPTION
            'El motivo del cambio de estado es obligatorio.';
    END IF;

    -- Validar modulo_origen (restricción CHECK en la tabla)
    IF p_modulo_origen IS NULL OR TRIM(p_modulo_origen) = '' THEN
        RAISE EXCEPTION
            'El campo modulo_origen es obligatorio.';
    END IF;

    -- Obtener estado actual
    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_actual
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    -- Bloquear si ya está en BAJA
    IF UPPER(v_nombre_actual) = 'BAJA' THEN
        RAISE EXCEPTION
            'El activo ID % se encuentra en estado BAJA definitivo. '
            'No se permiten cambios de estado.', p_activo_id;
    END IF;

    -- Resolver id del estado destino
    SELECT id_estado_activo_biologico
    INTO   v_id_estado_nuevo
    FROM   modulo2.estados_activos_biologicos
    WHERE  UPPER(nombre) = UPPER(p_estado_nuevo);

    IF v_id_estado_nuevo IS NULL THEN
        RAISE EXCEPTION
            'El estado "%" no existe en el catálogo de estados.', p_estado_nuevo;
    END IF;

    -- Insertar en historial; el trigger valida la transición y sincroniza
    INSERT INTO modulo2.historicos_estados_activos (
        id_activo_biologico,
        id_estado_nuevo,
        id_estado_anterior,
        fecha_cambio,
        motivo_cambio,
        modulo_origen,
        id_usuario
    ) VALUES (
        p_activo_id,
        v_id_estado_nuevo,
        v_id_estado_actual,
        p_fecha_cambio,
        p_motivo,
        p_modulo_origen,
        p_usuario_id
    );

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_usuario_id, NULL, 2, 'Modulo 2', 'ESTADOS',
        'Cambio de estado activo ' || p_activo_id || ': '
            || v_nombre_actual || ' → ' || p_estado_nuevo,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_activo',       p_activo_id,
            'estado_anterior', v_nombre_actual,
            'estado_nuevo',    p_estado_nuevo,
            'modulo_origen',   p_modulo_origen
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 5: RF-37 — Cambio de Fase Productiva
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_cambiar_fase_activo
-- RF: RF-37
-- Propósito: Gestiona el cambio de fase de forma transaccional. Valida estado
--            operativo del activo, que la fase destino exista en
--            modulo9.ciclos_productivos y sea distinta a la actual. Cierra la
--            fase vigente (es_activa = FALSE, fecha_finalizacion) y crea la
--            nueva fase activa. Usa SELECT FOR UPDATE para control de
--            concurrencia pesimista.
--            Si p_confirmacion_no_estandar = FALSE y la transición no sigue la
--            secuencia natural, se rechaza.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_cambiar_fase_activo(
    p_activo_id                INT,
    p_fase_destino_id          INT,      -- id_ciclo_productivo destino
    p_fecha_cambio             TIMESTAMPTZ,
    p_motivo                   TEXT,
    p_responsable_id           INT,
    p_confirmacion_no_estandar BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_actual INT;
    v_nombre_estado    VARCHAR(25);
    v_fase_actual      RECORD;
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_activo_id
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Validar que la fase destino existe
    IF NOT EXISTS (
        SELECT 1 FROM modulo9.ciclos_productivos
        WHERE id_ciclo_productivo = p_fase_destino_id
    ) THEN
        RAISE EXCEPTION
            'El ciclo productivo (fase) con ID % no existe.', p_fase_destino_id;
    END IF;

    -- Validar estado operativo
    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_estado
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    IF UPPER(v_nombre_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION
            'No se puede cambiar la fase del activo ID % porque está en estado %.', 
            p_activo_id, v_nombre_estado;
    END IF;

    -- Obtener fase activa actual con bloqueo pesimista
    SELECT gf.id_gestion_fases,
           gf.id_ciclo_productiva,
           gf.fecha_inicio
    INTO   v_fase_actual
    FROM   modulo2.gestiones_fases gf
    WHERE  gf.id_activo_biologico = p_activo_id
      AND  gf.es_activa = TRUE
    LIMIT  1
    FOR    UPDATE;

    -- Validar que la fase destino es diferente a la actual
    IF v_fase_actual.id_ciclo_productiva IS NOT NULL
       AND v_fase_actual.id_ciclo_productiva = p_fase_destino_id THEN
        RAISE EXCEPTION
            'La fase destino (ID %) es igual a la fase activa actual del activo.', 
            p_fase_destino_id;
    END IF;

    -- Si hay fase activa, cerrarla
    IF v_fase_actual.id_gestion_fases IS NOT NULL THEN
        UPDATE modulo2.gestiones_fases
        SET    es_activa         = FALSE,
               fecha_finalizacion = p_fecha_cambio
        WHERE  id_gestion_fases = v_fase_actual.id_gestion_fases;
    END IF;

    -- Crear nueva fase activa
    INSERT INTO modulo2.gestiones_fases (
        id_activo_biologico,
        id_ciclo_productiva,
        fecha_inicio,
        es_activa,
        id_usuario
    ) VALUES (
        p_activo_id,
        p_fase_destino_id,
        p_fecha_cambio::timetz,
        TRUE,
        p_responsable_id
    );

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_responsable_id, NULL, 2, 'Modulo 2', 'FASES',
        'Cambio de fase del activo ' || p_activo_id,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_activo',      p_activo_id,
            'fase_anterior',  v_fase_actual.id_ciclo_productiva,
            'fase_nueva',     p_fase_destino_id,
            'motivo',         p_motivo
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 6: RF-38 — Cierre de Ciclo Productivo
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_cerrar_ciclo_productivo
-- RF: RF-38
-- Propósito: Cierre atómico del ciclo productivo. Valida estado operativo,
--            fecha de cierre, existencia de al menos una fase activa y
--            obligatoriedad del motivo. Cierra la fase activa, registra evento
--            de cierre en eventos_activos e invoca sp_cambiar_estado_activo
--            con estado = 'CERRADO'. Rollback completo ante cualquier fallo.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_cerrar_ciclo_productivo(
    p_activo_id      INT,
    p_fecha_cierre   TIMESTAMPTZ,
    p_motivo_cierre  TEXT,
    p_descripcion    TEXT,
    p_responsable_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_actual INT;
    v_nombre_estado    VARCHAR(25);
    v_fase_activa      RECORD;
    v_id_evento        INT;
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_activo_id
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Fecha no futura
    IF p_fecha_cierre > now() THEN
        RAISE EXCEPTION
            'La fecha de cierre del ciclo no puede ser futura.';
    END IF;

    -- Motivo obligatorio
    IF p_motivo_cierre IS NULL OR TRIM(p_motivo_cierre) = '' THEN
        RAISE EXCEPTION
            'El motivo del cierre del ciclo productivo es obligatorio.';
    END IF;

    -- Validar estado operativo
    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_estado
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    IF UPPER(v_nombre_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION
            'El activo ID % ya está en estado %. No se puede cerrar el ciclo.',
            p_activo_id, v_nombre_estado;
    END IF;

    -- Verificar existencia de fase activa
    SELECT gf.id_gestion_fases,
           gf.id_ciclo_productiva
    INTO   v_fase_activa
    FROM   modulo2.gestiones_fases gf
    WHERE  gf.id_activo_biologico = p_activo_id
      AND  gf.es_activa = TRUE
    LIMIT  1;

    IF v_fase_activa.id_gestion_fases IS NULL THEN
        RAISE EXCEPTION
            'El activo ID % no tiene una fase productiva activa. '
            'No se puede cerrar el ciclo.', p_activo_id;
    END IF;

    -- Cerrar la fase activa
    UPDATE modulo2.gestiones_fases
    SET    es_activa          = FALSE,
           fecha_finalizacion  = p_fecha_cierre
    WHERE  id_gestion_fases  = v_fase_activa.id_gestion_fases;

    -- Registrar evento de cierre
    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_activo_id,
        p_fecha_cierre,
        COALESCE(p_descripcion, 'Cierre de ciclo productivo: ' || p_motivo_cierre),
        p_responsable_id
    )
    RETURNING id_eventos INTO v_id_evento;

    -- Cambiar estado a CERRADO (modulo_origen debe estar en el catálogo del CHECK)
    CALL modulo2.sp_cambiar_estado_activo(
        p_activo_id,
        'CERRADO',
        p_fecha_cierre,
        p_motivo_cierre,
        p_responsable_id,
        'modulo2'
    );

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_responsable_id, NULL, 2, 'Modulo 2', 'CICLO',
        'Cierre de ciclo productivo del activo ' || p_activo_id,
        'exitoso', 'CERRADO',
        jsonb_build_object(
            'id_activo',      p_activo_id,
            'id_fase_cerrada', v_fase_activa.id_gestion_fases,
            'id_evento_cierre', v_id_evento,
            'motivo',         p_motivo_cierre
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 7: RF-45 — Registro de Baja
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_registrar_baja
-- RF: RF-45
-- Propósito: Gestiona la baja de forma transaccional.
--   - INDIVIDUAL: registra evento de baja + cambia estado a 'BAJA'.
--   - POBLACIONAL baja total: igual que INDIVIDUAL.
--   - POBLACIONAL baja parcial: descuenta de cantidad_actual sin cambiar estado
--     (el trigger trg_baja_actualizar_cantidad_lote recalcula métricas del lote).
-- Los triggers trg_baja_cantidad_valida y trg_baja_actualizar_cantidad_lote
-- complementan las validaciones y actualizaciones automáticas.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_baja(
    p_activo_id         INT,
    p_tipo_baja         modulo2.enum_evento_bajas_tipo,
    p_fecha_baja        TIMESTAMPTZ,
    p_motivo            TEXT,
    p_cantidad_afectada INT,
    p_usuario_id        INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_actual INT;
    v_nombre_estado    VARCHAR(25);
    v_tipo_activo      modulo2.enum_activo_biologico_tipo;
    v_cantidad_actual  INT;
    v_id_evento        INT;
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_activo_id
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Fecha no futura
    IF p_fecha_baja > now() THEN
        RAISE EXCEPTION
            'La fecha de baja no puede ser futura.';
    END IF;

    -- Motivo obligatorio
    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        RAISE EXCEPTION
            'El motivo de la baja es obligatorio.';
    END IF;

    -- Tipo y estado actual del activo
    SELECT tipo
    INTO   v_tipo_activo
    FROM   modulo2.activos_biologicos
    WHERE  id_activo_biologico = p_activo_id;

    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_estado
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    IF UPPER(v_nombre_estado) = 'BAJA' THEN
        RAISE EXCEPTION
            'El activo ID % ya se encuentra en estado BAJA.', p_activo_id;
    END IF;

    -- Validaciones adicionales para lotes
    IF v_tipo_activo = 'POBLACIONAL' THEN
        IF p_cantidad_afectada IS NULL OR p_cantidad_afectada <= 0 THEN
            RAISE EXCEPTION
                'Para activos poblacionales, la cantidad afectada debe ser mayor a cero.';
        END IF;

        SELECT cantidad_actual
        INTO   v_cantidad_actual
        FROM   modulo2.detalles_activos_biologicos_poblacionales
        WHERE  id_activo_biologico = p_activo_id;

        IF p_cantidad_afectada > v_cantidad_actual THEN
            RAISE EXCEPTION
                'La cantidad a dar de baja (%) supera la cantidad actual del lote (%).',
                p_cantidad_afectada, v_cantidad_actual;
        END IF;
    END IF;

    -- Registrar evento base
    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_activo_id, p_fecha_baja, p_motivo, p_usuario_id
    )
    RETURNING id_eventos INTO v_id_evento;

    -- Insertar evento de baja
    -- (trg_baja_cantidad_valida y trg_baja_actualizar_cantidad_lote actúan aquí)
    INSERT INTO modulo2.eventos_bajas (
        id_evento,
        cantidad_afectada,
        detalles,
        tipo
    ) VALUES (
        v_id_evento,
        COALESCE(p_cantidad_afectada, 1),
        p_motivo,
        p_tipo_baja
    );

    -- INDIVIDUAL → siempre BAJA
    -- POBLACIONAL baja total → BAJA; parcial → sin cambio de estado
    IF v_tipo_activo = 'INDIVIDUAL' THEN
        CALL modulo2.sp_cambiar_estado_activo(
            p_activo_id, 'BAJA', p_fecha_baja, p_motivo, p_usuario_id, 'modulo2'
        );
    ELSIF v_tipo_activo = 'POBLACIONAL'
          AND p_cantidad_afectada >= v_cantidad_actual THEN
        CALL modulo2.sp_cambiar_estado_activo(
            p_activo_id, 'BAJA', p_fecha_baja, p_motivo, p_usuario_id, 'modulo2'
        );
    END IF;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_usuario_id, NULL, 2, 'Modulo 2', 'BAJAS',
        'Baja del activo ' || p_activo_id || ' — tipo: ' || p_tipo_baja::TEXT,
        'exitoso', 'BAJA',
        jsonb_build_object(
            'id_activo',          p_activo_id,
            'tipo_baja',          p_tipo_baja,
            'cantidad_afectada',  p_cantidad_afectada,
            'motivo',             p_motivo
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 8: RF-48 — Transferencia Interna
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_transferir_activo
-- RF: RF-48
-- Propósito: Versión extendida de transferencia. Valida estado operativo del
--            activo, existencia y estado activo de ambas infraestructuras, que
--            el destino sea diferente al origen y que el activo esté ubicado en
--            la infraestructura de origen. Inserta en movimientos, actualiza
--            id_infraestructura en activos_biologicos y registra auditoría.
-- Parámetros: p_tipo_activo se recibe para validación cruzada pero el tipo
--             real se obtiene de la BD.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_transferir_activo(
    p_activo_id               INT,
    p_tipo_activo             modulo2.enum_activo_biologico_tipo,
    p_infraestructura_origen  INT,
    p_infraestructura_destino INT,
    p_fecha_transferencia     TIMESTAMPTZ,
    p_motivo                  TEXT,
    p_responsable_id          INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_real        modulo2.enum_activo_biologico_tipo;
    v_id_estado_actual INT;
    v_nombre_estado    VARCHAR(25);
    v_infra_origen_ok  BOOL;
    v_infra_destino_ok BOOL;
BEGIN
    -- Validar existencia y obtener tipo real del activo
    SELECT tipo
    INTO   v_tipo_real
    FROM   modulo2.activos_biologicos
    WHERE  id_activo_biologico = p_activo_id;

    IF v_tipo_real IS NULL THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Validar coherencia del tipo pasado como parámetro
    IF v_tipo_real <> p_tipo_activo THEN
        RAISE EXCEPTION
            'El tipo declarado (%) no coincide con el tipo registrado (%) '
            'del activo ID %.', p_tipo_activo, v_tipo_real, p_activo_id;
    END IF;

    -- Origen ≠ destino
    IF p_infraestructura_origen = p_infraestructura_destino THEN
        RAISE EXCEPTION
            'La infraestructura de origen y destino no pueden ser la misma.';
    END IF;

    -- Validar estado operativo del activo
    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_estado
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    IF UPPER(v_nombre_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION
            'No se puede transferir el activo ID % porque está en estado %.',
            p_activo_id, v_nombre_estado;
    END IF;

    -- Validar que ambas infraestructuras existen y están activas
    SELECT es_activo
    INTO   v_infra_origen_ok
    FROM   modulo9.infraestructuras
    WHERE  id_infraestructura = p_infraestructura_origen;

    IF v_infra_origen_ok IS NULL THEN
        RAISE EXCEPTION
            'La infraestructura de origen (ID %) no existe.', p_infraestructura_origen;
    END IF;
    IF v_infra_origen_ok = FALSE THEN
        RAISE EXCEPTION
            'La infraestructura de origen (ID %) está inactiva.', p_infraestructura_origen;
    END IF;

    SELECT es_activo
    INTO   v_infra_destino_ok
    FROM   modulo9.infraestructuras
    WHERE  id_infraestructura = p_infraestructura_destino;

    IF v_infra_destino_ok IS NULL THEN
        RAISE EXCEPTION
            'La infraestructura de destino (ID %) no existe.', p_infraestructura_destino;
    END IF;
    IF v_infra_destino_ok = FALSE THEN
        RAISE EXCEPTION
            'La infraestructura de destino (ID %) está inactiva.', p_infraestructura_destino;
    END IF;

    -- Validar que el activo está en la infraestructura de origen
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE  id_activo_biologico = p_activo_id
          AND  id_infraestructura  = p_infraestructura_origen
    ) THEN
        RAISE EXCEPTION
            'El activo ID % no se encuentra en la infraestructura de origen (ID %).',
            p_activo_id, p_infraestructura_origen;
    END IF;

    -- Registrar movimiento
    INSERT INTO modulo2.movimientos (
        id_usuario,
        fecha_transferencia,
        tipo,
        id_activo_biologico,
        id_infraestructura_origen,
        id_infraestructura_destino,
        fecha_registro
    ) VALUES (
        p_responsable_id,
        p_fecha_transferencia,
        'salida',
        p_activo_id,
        p_infraestructura_origen,
        p_infraestructura_destino,
        now()
    );

    -- Actualizar infraestructura del activo
    UPDATE modulo2.activos_biologicos
    SET    id_infraestructura = p_infraestructura_destino
    WHERE  id_activo_biologico = p_activo_id;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_responsable_id, NULL, 4, 'Modulo 2', 'LOGISTICA',
        'Transferencia activo ' || p_activo_id
            || ' de infra ' || p_infraestructura_origen
            || ' a infra ' || p_infraestructura_destino,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_activo',  p_activo_id,
            'origen',     p_infraestructura_origen,
            'destino',    p_infraestructura_destino,
            'motivo',     p_motivo
        )
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- sp_transferencia_interna  (versión existente, se conserva)
-- RF: RF-48
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_transferencia_interna(
    p_id_activo_biologico       INT,
    p_id_infraestructura_origen INT,
    p_id_infraestructura_destino INT,
    p_id_usuario                INT,
    p_motivo                    TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_id_infraestructura_origen = p_id_infraestructura_destino THEN
        RAISE EXCEPTION
            'La infraestructura de origen y destino no pueden ser la misma.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE  id_activo_biologico = p_id_activo_biologico
          AND  id_infraestructura  = p_id_infraestructura_origen
    ) THEN
        RAISE EXCEPTION
            'El activo no se encuentra en la infraestructura de origen indicada.';
    END IF;

    INSERT INTO modulo2.movimientos (
        id_usuario, fecha_transferencia, tipo,
        id_activo_biologico, id_infraestructura_origen,
        id_infraestructura_destino, fecha_registro
    ) VALUES (
        p_id_usuario, CURRENT_TIMESTAMP, 'salida',
        p_id_activo_biologico, p_id_infraestructura_origen,
        p_id_infraestructura_destino, CURRENT_TIMESTAMP
    );

    UPDATE modulo2.activos_biologicos
    SET    id_infraestructura = p_id_infraestructura_destino
    WHERE  id_activo_biologico = p_id_activo_biologico;

    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario, NULL, 4, 'Modulo 2', 'LOGISTICA',
        'Transferencia del activo ' || p_id_activo_biologico
            || ' desde ' || p_id_infraestructura_origen
            || ' hacia ' || p_id_infraestructura_destino,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'origen', p_id_infraestructura_origen,
            'destino', p_id_infraestructura_destino,
            'motivo', p_motivo
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 9: RF-39 — Registro de Evento Biológico (orquestador)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_registrar_evento_biologico
-- RF: RF-39
-- Propósito: Orquesta el registro de cualquier tipo de evento biológico de
--            forma transaccional. Valida estado operativo del activo, fecha y
--            que los datos_evento no sean nulos. Inserta en eventos_activos y
--            delega en la tabla especializada según p_tipo_evento.
--            Los triggers de cada tabla especializada realizan las validaciones
--            de secuencia y coherencia de negocio.
-- Tipos válidos: 'CRECIMIENTO', 'SANITARIO', 'PRODUCTIVO', 'REPRODUCTIVO',
--                'BAJA'
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_evento_biologico(
    p_activo_id      INT,
    p_tipo_evento    TEXT,
    p_fecha_evento   TIMESTAMPTZ,
    p_descripcion    TEXT,
    p_datos_evento   JSONB,
    p_responsable_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_actual INT;
    v_nombre_estado    VARCHAR(25);
    v_id_evento        INT;
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_activo_id
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Fecha no futura
    IF p_fecha_evento > now() THEN
        RAISE EXCEPTION
            'La fecha del evento no puede ser futura.';
    END IF;

    -- Datos del evento obligatorios
    IF p_datos_evento IS NULL THEN
        RAISE EXCEPTION
            'Los datos del evento (p_datos_evento) son obligatorios.';
    END IF;

    -- Validar estado operativo
    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_estado
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    IF UPPER(v_nombre_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION
            'No se pueden registrar eventos sobre el activo ID % en estado %.',
            p_activo_id, v_nombre_estado;
    END IF;

    -- Insertar evento base
    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_activo_id, p_fecha_evento, p_descripcion, p_responsable_id
    )
    RETURNING id_eventos INTO v_id_evento;

    -- Insertar en tabla especializada según tipo
    CASE UPPER(TRIM(p_tipo_evento))

        WHEN 'CRECIMIENTO' THEN
            INSERT INTO modulo2.eventos_crecimeinto (
                id_evento,
                tipo_medicion,
                valor_medicion,
                unidad_medida,
                tipo_agregacion,
                frecuencia
            ) VALUES (
                v_id_evento,
                p_datos_evento->>'tipo_medicion',
                (p_datos_evento->>'valor_medicion')::NUMERIC(10,2),
                p_datos_evento->>'unidad_medida',
                p_datos_evento->>'tipo_agregacion',
                p_datos_evento->>'frecuencia'
            );

        WHEN 'SANITARIO' THEN
            INSERT INTO modulo2.eventos_sanitarios (
                id_evento,
                diagnostico,
                medicamento,
                dosis,
                unidad_dosis,
                frecuencia,
                tipo,
                duracion,
                observaciones
            ) VALUES (
                v_id_evento,
                p_datos_evento->>'diagnostico',
                p_datos_evento->>'medicamento',
                (p_datos_evento->>'dosis')::NUMERIC(10,2),
                p_datos_evento->>'unidad_dosis',
                (p_datos_evento->>'frecuencia')::INT,
                (p_datos_evento->>'tipo')::modulo2.enum_evento_sanitario_tipo,
                (p_datos_evento->>'duracion')::INT,
                p_datos_evento->>'observaciones'
            );

        WHEN 'PRODUCTIVO' THEN
            INSERT INTO modulo2.eventos_productivos (
                id_evento,
                cantidad,
                condiciones,
                id_metrica_produccion,
                id_ciclo_productivo
            ) VALUES (
                v_id_evento,
                (p_datos_evento->>'cantidad')::NUMERIC(12,3),
                p_datos_evento->>'condiciones',
                (p_datos_evento->>'id_metrica_produccion')::INT,
                (p_datos_evento->>'id_ciclo_productivo')::INT
            );

        WHEN 'REPRODUCTIVO' THEN
            INSERT INTO modulo2.eventos_reproductivos (
                id_evento_reproductivo,
                categoria,
                id_padre,
                resultado,
                numero_cria,
                id_madre
            ) VALUES (
                v_id_evento,
                (p_datos_evento->>'categoria')::modulo2.enum_evento_reproductivo_categoria,
                (p_datos_evento->>'id_padre')::INT,
                p_datos_evento->>'resultado',
                COALESCE((p_datos_evento->>'numero_cria')::INT, 0),
                (p_datos_evento->>'id_madre')::INT
            );

        WHEN 'BAJA' THEN
            INSERT INTO modulo2.eventos_bajas (
                id_evento,
                cantidad_afectada,
                detalles,
                tipo
            ) VALUES (
                v_id_evento,
                (p_datos_evento->>'cantidad_afectada')::INT,
                p_datos_evento->>'detalles',
                (p_datos_evento->>'tipo')::modulo2.enum_evento_bajas_tipo
            );

        ELSE
            RAISE EXCEPTION
                'Tipo de evento "%" no reconocido. '
                'Use: CRECIMIENTO, SANITARIO, PRODUCTIVO, REPRODUCTIVO, BAJA.',
                p_tipo_evento;
    END CASE;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_responsable_id, NULL, 1, 'Modulo 2', 'EVENTOS',
        'Registro evento ' || p_tipo_evento || ' — activo ' || p_activo_id,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_evento',   v_id_evento,
            'tipo_evento', p_tipo_evento,
            'id_activo',   p_activo_id
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 10: RF-41 — Evento Sanitario
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_registrar_evento_sanitario
-- RF: RF-41 (versión existente, se conserva)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico INT,
    p_descripcion         TEXT,
    p_id_usuario          INT,
    p_diagnostico         TEXT,
    p_medicamento         VARCHAR  DEFAULT NULL,
    p_dosis               NUMERIC(10,2) DEFAULT NULL,
    p_unidad_dosis        VARCHAR(5)    DEFAULT NULL,
    p_frecuencia          INT           DEFAULT NULL,
    p_tipo                modulo2.enum_evento_sanitario_tipo DEFAULT NULL,
    p_duracion            INT           DEFAULT NULL,
    p_observaciones       TEXT          DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_evento INT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_id_activo_biologico
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_id_activo_biologico;
    END IF;

    IF p_diagnostico IS NULL OR TRIM(p_diagnostico) = '' THEN
        RAISE EXCEPTION 'El diagnóstico es obligatorio.';
    END IF;

    IF p_medicamento IS NOT NULL AND TRIM(p_medicamento) <> '' THEN
        IF p_unidad_dosis IS NULL OR TRIM(p_unidad_dosis) = '' THEN
            RAISE EXCEPTION
                'Se debe especificar la unidad de dosis cuando se administra medicamento.';
        END IF;
        IF p_dosis IS NULL OR p_dosis <= 0 THEN
            RAISE EXCEPTION 'La dosis debe ser un valor positivo.';
        END IF;
    ELSE
        p_unidad_dosis := COALESCE(p_unidad_dosis, '');
    END IF;

    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_id_activo_biologico, CURRENT_TIMESTAMP, p_descripcion, p_id_usuario
    )
    RETURNING id_eventos INTO v_id_evento;

    INSERT INTO modulo2.eventos_sanitarios (
        id_evento, diagnostico, medicamento, dosis,
        unidad_dosis, frecuencia, tipo, duracion, observaciones
    ) VALUES (
        v_id_evento, p_diagnostico, p_medicamento, p_dosis,
        p_unidad_dosis, p_frecuencia, p_tipo, p_duracion, p_observaciones
    );

    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario, NULL, 1, 'Modulo 2', 'SANIDAD',
        'Registro de evento sanitario para activo ID: ' || p_id_activo_biologico,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_evento',   v_id_evento,
            'diagnostico', p_diagnostico,
            'medicamento', p_medicamento,
            'tipo',        p_tipo,
            'duracion',    p_duracion
        )
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- sp_registrar_evento_sanitario_con_estado
-- RF: RF-41
-- Propósito: Registra un evento sanitario y, según el tipo, evalúa si debe
--            generarse un cambio de estado automático:
--              TRATAMIENTO        → EN_TRATAMIENTO
--              CONTROL_PREVENTIVO → AISLADO
--            Invoca sp_cambiar_estado_activo con modulo_origen = 'modulo2'
--            dentro de la misma transacción. Rollback completo si cualquier
--            operación falla.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_registrar_evento_sanitario_con_estado(
    p_activo_id             INT,
    p_tipo_evento_sanitario modulo2.enum_evento_sanitario_tipo,
    p_fecha_evento          TIMESTAMPTZ,
    p_datos                 JSONB,
    p_responsable_id        INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_actual INT;
    v_nombre_estado    VARCHAR(25);
    v_id_evento        INT;
    v_estado_nuevo     VARCHAR(25);
BEGIN
    -- Validar existencia del activo
    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico = p_activo_id
    ) THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Fecha no futura
    IF p_fecha_evento > now() THEN
        RAISE EXCEPTION
            'La fecha del evento sanitario no puede ser futura.';
    END IF;

    -- Validar estado operativo
    v_id_estado_actual := modulo2.fn_obtener_estado_actual_activo(p_activo_id);

    SELECT nombre
    INTO   v_nombre_estado
    FROM   modulo2.estados_activos_biologicos
    WHERE  id_estado_activo_biologico = v_id_estado_actual;

    IF UPPER(v_nombre_estado) IN ('CERRADO', 'BAJA') THEN
        RAISE EXCEPTION
            'No se pueden registrar eventos sanitarios sobre el activo ID % '
            'en estado %.', p_activo_id, v_nombre_estado;
    END IF;

    -- Insertar evento base
    INSERT INTO modulo2.eventos_activos (
        id_activo_biologico, fecha, descripcion, id_usuario
    ) VALUES (
        p_activo_id,
        p_fecha_evento,
        COALESCE(
            p_datos->>'descripcion',
            'Evento sanitario: ' || p_tipo_evento_sanitario::TEXT
        ),
        p_responsable_id
    )
    RETURNING id_eventos INTO v_id_evento;

    -- Insertar detalle sanitario
    -- (trg_evento_sanitario_secuencia valida la secuencia de diagnóstico previo)
    INSERT INTO modulo2.eventos_sanitarios (
        id_evento,
        diagnostico,
        medicamento,
        dosis,
        unidad_dosis,
        frecuencia,
        tipo,
        duracion,
        observaciones
    ) VALUES (
        v_id_evento,
        p_datos->>'diagnostico',
        p_datos->>'medicamento',
        (p_datos->>'dosis')::NUMERIC(10,2),
        p_datos->>'unidad_dosis',
        (p_datos->>'frecuencia')::INT,
        p_tipo_evento_sanitario,
        (p_datos->>'duracion')::INT,
        p_datos->>'observaciones'
    );

    -- Determinar cambio de estado según tipo sanitario
    v_estado_nuevo := CASE p_tipo_evento_sanitario
        WHEN 'TRATAMIENTO'        THEN 'EN_TRATAMIENTO'
        WHEN 'CONTROL_PREVENTIVO' THEN 'AISLADO'
        ELSE NULL
    END;

    -- Aplicar cambio de estado si corresponde y si no es redundante
    IF v_estado_nuevo IS NOT NULL
       AND UPPER(v_nombre_estado) <> UPPER(v_estado_nuevo) THEN
        CALL modulo2.sp_cambiar_estado_activo(
            p_activo_id,
            v_estado_nuevo,
            p_fecha_evento,
            'Cambio automático por evento sanitario: ' || p_tipo_evento_sanitario::TEXT,
            p_responsable_id,
            'modulo2'
        );
    END IF;

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_responsable_id, NULL, 1, 'Modulo 2', 'SANIDAD',
        'Evento sanitario con evaluación de estado — activo ' || p_activo_id,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_evento',         v_id_evento,
            'tipo_sanitario',    p_tipo_evento_sanitario,
            'estado_resultante', COALESCE(v_estado_nuevo, v_nombre_estado)
        )
    );
END;
$$;


-- ==============================================================================
-- SECCIÓN 11: RF-51 — Cálculo de Indicadores Zootécnicos
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- sp_calcular_indicadores_zootecnicos
-- RF: RF-51
-- Propósito: Calcula y persiste los indicadores zootécnicos solicitados.
--   - ganancia_peso        : (peso_final − peso_inicial) / días
--   - tasa_morbilidad      : (eventos_sanitarios / cantidad_base) × 100
--   - tasa_mortalidad      : (bajas por muerte / cantidad_base) × 100
--   - produccion_promedio  : AVG(cantidad) de eventos_productivos en el rango
--   - conversion_alimenticia: consumo_alimento (modulo5) / ganancia_peso
-- Valida suficiencia de datos (≥ 2 mediciones para indicadores de peso) y
-- detecta divisores cero antes de calcular.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE modulo2.sp_calcular_indicadores_zootecnicos(
    p_activo_id      INT,
    p_tipo_indicador modulo2.enum_indicador_zootecnico_tipo,
    p_fecha_inicio   DATE,
    p_fecha_fin      DATE,
    p_parametros     JSONB,
    p_usuario_id     INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_activo     modulo2.enum_activo_biologico_tipo;
    v_dias            INT;
    v_peso_inicial    NUMERIC;
    v_peso_final      NUMERIC;
    v_total_eventos   INT;
    v_cantidad_base   INT;
    v_consumo_total   NUMERIC;
    v_ganancia_total  NUMERIC;
    v_resultado       NUMERIC;
    v_params_calc     JSONB;
BEGIN
    -- Validar existencia del activo y obtener tipo
    SELECT tipo
    INTO   v_tipo_activo
    FROM   modulo2.activos_biologicos
    WHERE  id_activo_biologico = p_activo_id;

    IF v_tipo_activo IS NULL THEN
        RAISE EXCEPTION
            'El activo biológico con ID % no existe.', p_activo_id;
    END IF;

    -- Validar rango de fechas
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE EXCEPTION
            'La fecha de inicio debe ser anterior a la fecha de fin.';
    END IF;

    v_dias := p_fecha_fin - p_fecha_inicio;
    IF v_dias = 0 THEN
        RAISE EXCEPTION
            'El rango de fechas debe ser mayor a un día.';
    END IF;

    -- -----------------------------------------------------------------------
    CASE p_tipo_indicador

        WHEN 'ganancia_peso' THEN
            -- Primer peso registrado en el rango
            SELECT ec.valor_medicion
            INTO   v_peso_inicial
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_crecimeinto ec ON ec.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  UPPER(ec.tipo_medicion) LIKE '%PESO%'
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin
            ORDER  BY ea.fecha ASC
            LIMIT  1;

            -- Último peso registrado en el rango
            SELECT ec.valor_medicion
            INTO   v_peso_final
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_crecimeinto ec ON ec.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  UPPER(ec.tipo_medicion) LIKE '%PESO%'
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin
            ORDER  BY ea.fecha DESC
            LIMIT  1;

            IF v_peso_inicial IS NULL OR v_peso_final IS NULL THEN
                RAISE EXCEPTION
                    'No hay suficientes registros de peso para calcular la ganancia '
                    'en el rango especificado (mínimo 2 mediciones).';
            END IF;

            v_resultado   := (v_peso_final - v_peso_inicial) / v_dias;
            v_params_calc := jsonb_build_object(
                'peso_inicial',   v_peso_inicial,
                'peso_final',     v_peso_final,
                'dias',           v_dias,
                'ganancia_diaria', v_resultado,
                'unidad',         'kg/dia'
            );

        WHEN 'tasa_morbilidad' THEN
            SELECT COUNT(*)
            INTO   v_total_eventos
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_sanitarios es ON es.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin;

            IF v_tipo_activo = 'POBLACIONAL' THEN
                SELECT cantidad_inicial
                INTO   v_cantidad_base
                FROM   modulo2.detalles_activos_biologicos_poblacionales
                WHERE  id_activo_biologico = p_activo_id;
            ELSE
                v_cantidad_base := 1;
            END IF;

            IF v_cantidad_base IS NULL OR v_cantidad_base = 0 THEN
                RAISE EXCEPTION
                    'No se puede calcular la tasa de morbilidad: '
                    'cantidad base es cero o nula.';
            END IF;

            v_resultado   := (v_total_eventos::NUMERIC / v_cantidad_base) * 100;
            v_params_calc := jsonb_build_object(
                'eventos_sanitarios',  v_total_eventos,
                'cantidad_base',       v_cantidad_base,
                'tasa_morbilidad_pct', v_resultado
            );

        WHEN 'tasa_mortalidad' THEN
            SELECT COUNT(*)
            INTO   v_total_eventos
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_bajas eb ON eb.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin
              AND  eb.tipo = 'muerte';

            IF v_tipo_activo = 'POBLACIONAL' THEN
                SELECT cantidad_inicial
                INTO   v_cantidad_base
                FROM   modulo2.detalles_activos_biologicos_poblacionales
                WHERE  id_activo_biologico = p_activo_id;
            ELSE
                v_cantidad_base := 1;
            END IF;

            IF v_cantidad_base IS NULL OR v_cantidad_base = 0 THEN
                RAISE EXCEPTION
                    'No se puede calcular la tasa de mortalidad: '
                    'cantidad base es cero o nula.';
            END IF;

            v_resultado   := (v_total_eventos::NUMERIC / v_cantidad_base) * 100;
            v_params_calc := jsonb_build_object(
                'muertes',            v_total_eventos,
                'cantidad_base',      v_cantidad_base,
                'tasa_mortalidad_pct', v_resultado
            );

        WHEN 'produccion_promedio' THEN
            SELECT COALESCE(AVG(ep.cantidad), 0)
            INTO   v_resultado
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_productivos ep ON ep.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin;

            v_params_calc := jsonb_build_object(
                'produccion_promedio', v_resultado,
                'periodo_inicio',      p_fecha_inicio,
                'periodo_fin',         p_fecha_fin
            );

        WHEN 'conversion_alimenticia' THEN
            -- Ganancia de peso en el rango
            SELECT ec.valor_medicion
            INTO   v_peso_inicial
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_crecimeinto ec ON ec.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  UPPER(ec.tipo_medicion) LIKE '%PESO%'
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin
            ORDER  BY ea.fecha ASC LIMIT 1;

            SELECT ec.valor_medicion
            INTO   v_peso_final
            FROM   modulo2.eventos_activos ea
            JOIN   modulo2.eventos_crecimeinto ec ON ec.id_evento = ea.id_eventos
            WHERE  ea.id_activo_biologico = p_activo_id
              AND  UPPER(ec.tipo_medicion) LIKE '%PESO%'
              AND  DATE(ea.fecha) BETWEEN p_fecha_inicio AND p_fecha_fin
            ORDER  BY ea.fecha DESC LIMIT 1;

            v_ganancia_total := COALESCE(v_peso_final - v_peso_inicial, 0);

            -- Consumo de alimento desde modulo5
            SELECT COALESCE(SUM(rca.cantidad_suministrada), 0)
            INTO   v_consumo_total
            FROM   modulo5.registros_consumo_alimentos rca
            WHERE  rca.id_activo_biologico = p_activo_id
              AND  DATE(rca.fecha_registro) BETWEEN p_fecha_inicio AND p_fecha_fin;

            IF v_ganancia_total = 0 THEN
                RAISE EXCEPTION
                    'La ganancia de peso es cero en el rango especificado. '
                    'No se puede calcular la conversión alimenticia (FCR).';
            END IF;

            v_resultado   := v_consumo_total / v_ganancia_total;
            v_params_calc := jsonb_build_object(
                'consumo_alimento', v_consumo_total,
                'ganancia_peso',    v_ganancia_total,
                'fcr',              v_resultado
            );

    END CASE;
    -- -----------------------------------------------------------------------

    -- Persistir indicador
    INSERT INTO modulo2.indicadores_zootecnicos (
        id_activo_biologico,
        rango_fecha,
        tipo,
        paramtros_calculo
    ) VALUES (
        p_activo_id,
        daterange(p_fecha_inicio, p_fecha_fin, '[]'),
        p_tipo_indicador,
        COALESCE(p_parametros, '{}'::jsonb) || v_params_calc
    );

    -- Auditoría
    CALL modulo1.sp_registrar_auditoria(
        p_usuario_id, NULL, 1, 'Modulo 2', 'INDICADORES',
        'Cálculo indicador ' || p_tipo_indicador::TEXT || ' — activo ' || p_activo_id,
        'exitoso', 'ACTIVO',
        jsonb_build_object(
            'id_activo',      p_activo_id,
            'tipo_indicador', p_tipo_indicador,
            'resultado',      v_params_calc
        )
    );
END;
$$;




--========================== USAR

SELECT modulo2.fn_obtener_estado_actual_activo(10);
SELECT * FROM modulo2.fn_obtener_fase_activa_activo(10);
CALL modulo2.sp_recalcular_metricas_lote(6);
CALL modulo2.sp_registrar_activo_biologico(
    p_id_usuario         => 5,
    p_id_especie         => 3,
    p_identificador      => 'BOV-001-2026',
    p_id_infraestructura => 1,
    p_tipo               => 'INDIVIDUAL',
    p_origen_financiero  => 'compra',
    p_costo_adquisicion  => 150000.5000,
    p_descripcion        => 'Toro reproductor Brahman',
    p_cantidad_inicial   => NULL,
    p_fecha_inicio_ciclo => 2025,
    p_soporte_documental => 'Factura #123456',
    p_raza               => 'Brahman',
    p_sexo               => 'Macho',
    p_fecha_nacimiento   => NOW(),
    p_peso_inicial       => 320.500
);


CALL modulo2.sp_registrar_activo_biologico(
    p_id_usuario         => 5,
    p_id_especie         => 2,
    p_identificador      => NULL,
    p_id_infraestructura => 2,
    p_tipo               => 'POBLACIONAL',
    p_origen_financiero  => 'nacimiento',
    p_costo_adquisicion  => NULL,
    p_descripcion        => 'Lote tilapia estanque 2',
    p_cantidad_inicial   => 500,
    p_fecha_inicio_ciclo => 2025,
    p_soporte_documental => NULL,
    p_peso_promedio      => 0.050  -- peso promedio inicial en kg (puede ser 0)
);

CALL modulo2.sp_cambiar_estado_activo(
    p_activo_id     => 4,
    p_estado_nuevo  => 'INACTIVO',
    p_fecha_cambio  => now(),
    p_motivo        => 'Retiro temporal por revisión veterinaria',
    p_usuario_id    => 5,
    p_modulo_origen => 'modulo2'
);

CALL modulo2.sp_cambiar_fase_activo(
    p_activo_id                => 12,
    p_fase_destino_id          => 3,
    p_fecha_cambio             => now(),
    p_motivo                   => 'Avance a fase de engorde',
    p_responsable_id           => 5,
    p_confirmacion_no_estandar => FALSE
);	

CALL modulo2.sp_cerrar_ciclo_productivo(
    p_activo_id      => 12,
    p_fecha_cierre   => now(),
    p_motivo_cierre  => 'Finalización de ciclo por peso objetivo alcanzado',
    p_descripcion    => 'Cierre formal del ciclo productivo 2025-A',
    p_responsable_id => 5
);

-- INDIVIDUAL
CALL modulo2.sp_registrar_baja(
    p_activo_id         => 10,
    p_tipo_baja         => 'muerte',
    p_fecha_baja        => now(),
    p_motivo            => 'Muerte por complicación respiratoria',
    p_cantidad_afectada => 1,
    p_usuario_id        => 5
);

-- POBLACIONAL

CALL modulo2.sp_registrar_baja(
    p_activo_id         => 12,
    p_tipo_baja         => 'muerte',
    p_fecha_baja        => now(),
    p_motivo            => 'Mortalidad por oxígeno disuelto bajo',
    p_cantidad_afectada => 30,
    p_usuario_id        => 5
);


CALL modulo2.sp_transferir_activo(
    p_activo_id               => 1,
    p_tipo_activo             => 'INDIVIDUAL',
    p_infraestructura_origen  => 1,
    p_infraestructura_destino => 2,
    p_fecha_transferencia     => now(),
    p_motivo                  => 'Reubicación por finalización de cuarentena',
    p_responsable_id          => 5
);

CALL modulo2.sp_transferencia_interna(
    p_id_activo_biologico        => 10,
    p_id_infraestructura_origen  => 1,
    p_id_infraestructura_destino => 2,
    p_id_usuario                 => 5,
    p_motivo                     => 'Reubicación por finalización de cuarentena'
);

CALL modulo2.sp_registrar_evento_biologico(
    p_activo_id      => 1,
    p_tipo_evento    => 'CRECIMIENTO',
    p_fecha_evento   => now(),
    p_descripcion    => 'Control de peso semanal',
    p_datos_evento   => '{"tipo_medicion":"PESO","valor_medicion":340.5,"unidad_medida":"kg","tipo_agregacion":"","frecuencia":"semanal"}',
    p_responsable_id => 5
);


CALL modulo2.sp_registrar_evento_biologico(
    p_activo_id      => 1,
    p_tipo_evento    => 'PRODUCTIVO',
    p_fecha_evento   => now(),
    p_descripcion    => 'Registro de producción diaria',
    p_datos_evento   => '{"cantidad":18.500,"condiciones":"Temperatura óptima","id_metrica_produccion":1,"id_ciclo_productivo":2}',
    p_responsable_id => 5
);

CALL modulo2.sp_registrar_evento_biologico(
    p_activo_id      => 2,
    p_tipo_evento    => 'REPRODUCTIVO',
    p_fecha_evento   => now(),
    p_descripcion    => 'Servicio de monta natural',
    p_datos_evento   => '{"categoria":"servicio","id_padre":10,"resultado":"Exitoso","numero_cria":0,"id_madre":9}',
    p_responsable_id => 5
);

-- Sin medicamento (solo diagnóstico)
CALL modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico => 2,
    p_descripcion         => 'Control de rutina, sin novedad',
    p_id_usuario          => 5,
    p_diagnostico         => 'Sano',
    p_tipo                => 'DIAGNOSTICO'
);

-- Con medicamento
CALL modulo2.sp_registrar_evento_sanitario(
    p_id_activo_biologico => 2,
    p_descripcion         => 'Presenta diarrea y decaimiento',
    p_id_usuario          => 5,
    p_diagnostico         => 'Posible parasitosis gastrointestinal',
    p_medicamento         => 'Albendazol',
    p_dosis               => 10.00,
    p_unidad_dosis        => 'ml',
    p_frecuencia          => 3,
    p_tipo                => 'TRATAMIENTO',
    p_duracion            => 5
);

-- Diagnóstico (sin cambio de estado)
CALL modulo2.sp_registrar_evento_sanitario_con_estado(
    p_activo_id             => 2,
    p_tipo_evento_sanitario => 'DIAGNOSTICO',
    p_fecha_evento          => now(),
    p_datos                 => '{"diagnostico":"Fiebre leve detectada","medicamento":null,"dosis":null,"unidad_dosis":null,"frecuencia":null,"duracion":null,"observaciones":null}',
    p_responsable_id        => 5
);

-- Tratamiento (genera cambio a EN_TRATAMIENTO)
CALL modulo2.sp_registrar_evento_sanitario_con_estado(
    p_activo_id             => 2,
    p_tipo_evento_sanitario => 'TRATAMIENTO',
    p_fecha_evento          => now(),
    p_datos                 => '{"diagnostico":"Parasitosis confirmada","medicamento":"Ivermectina","dosis":5.00,"unidad_dosis":"ml","frecuencia":1,"duracion":3,"observaciones":null}',
    p_responsable_id        => 5
);

-- Ganancia de peso
CALL modulo2.sp_calcular_indicadores_zootecnicos(
    p_activo_id      => 2,
    p_tipo_indicador => 'ganancia_peso',
    p_fecha_inicio   => '2025-01-01',
    p_fecha_fin      => '2025-03-31',
    p_parametros     => '{}',
    p_usuario_id     => 5
);

-- Tasa de morbilidad
CALL modulo2.sp_calcular_indicadores_zootecnicos(
    p_activo_id      => 2,
    p_tipo_indicador => 'tasa_morbilidad',
    p_fecha_inicio   => '2025-01-01',
    p_fecha_fin      => '2025-03-31',
    p_parametros     => '{}',
    p_usuario_id     => 5
);

-- Tasa de mortalidad
CALL modulo2.sp_calcular_indicadores_zootecnicos(
    p_activo_id      => 2,
    p_tipo_indicador => 'tasa_mortalidad',
    p_fecha_inicio   => '2025-01-01',
    p_fecha_fin      => '2025-03-31',
    p_parametros     => '{}',
    p_usuario_id     => 5
);

-- Producción promedio
CALL modulo2.sp_calcular_indicadores_zootecnicos(
    p_activo_id      => 2,
    p_tipo_indicador => 'produccion_promedio',
    p_fecha_inicio   => '2025-01-01',
    p_fecha_fin      => '2025-03-31',
    p_parametros     => '{}',
    p_usuario_id     => 5
);



CALL modulo2.sp_registrar_evento_biologico(
    p_activo_id      => 2,
    p_tipo_evento    => 'CRECIMIENTO',
    p_fecha_evento   => now(),
    p_descripcion    => 'Peso inicial del ciclo',
    p_datos_evento   => '{"tipo_medicion":"PESO","valor_medicion":0.050,"unidad_medida":"kg","tipo_agregacion":"","frecuencia":"semanal"}',
    p_responsable_id => 5
);

CALL modulo2.sp_registrar_evento_biologico(
    p_activo_id      => 2,
    p_tipo_evento    => 'CRECIMIENTO',
    p_fecha_evento   => NOW(),
    p_descripcion    => 'Peso final del ciclo',
    p_datos_evento   => '{"tipo_medicion":"PESO","valor_medicion":0.350,"unidad_medida":"kg","tipo_agregacion":"","frecuencia":"semanal"}',
    p_responsable_id => 5
);


-- Conversión alimenticia (FCR)
CALL modulo2.sp_calcular_indicadores_zootecnicos(
    p_activo_id      => 2,
    p_tipo_indicador => 'conversion_alimenticia',
    p_fecha_inicio   => '2026-05-03 19:44:00.602 -0500',
    p_fecha_fin      => '2026-05-04 19:44:34.715 -0500',
    p_parametros     => '{}',
    p_usuario_id     => 5
);
