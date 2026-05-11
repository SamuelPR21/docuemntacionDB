-- ==============================================================================
-- BLOQUE 1.1: fn_clasificar_eficiencia_ica
-- RF-74: Clasifica el resultado CA en niveles de eficiencia
-- Sin dependencias externas
-- ==============================================================================

CREATE OR REPLACE FUNCTION modulo5.fn_clasificar_eficiencia_ica(
    p_ca NUMERIC
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_ca IS NULL OR p_ca < 0 THEN
        RAISE EXCEPTION
            'CA_INVALIDO: El valor de conversión alimenticia no puede ser '
            'nulo ni negativo. Valor recibido: [%]. (RF-74)',
            p_ca
        USING ERRCODE = 'P0001';
    END IF;

    RETURN CASE
        WHEN p_ca > 0    AND p_ca <= 1.5  THEN 'EXCELENTE'
        WHEN p_ca > 1.5  AND p_ca <= 2.5  THEN 'ACEPTABLE'
        WHEN p_ca > 2.5  AND p_ca <= 3.5  THEN 'BAJA'
        ELSE                                    'CRITICA'
    END;
END;
$$;

-- ==============================================================================
-- BLOQUE 1.2: fn_calcular_data_quality_score
-- RF-74: Calcula score de calidad de datos para trazabilidad de ICA
-- Parámetros: presencia de peso_ini, peso_fin, consumo, estado_valido
-- Sin dependencias externas
-- ==============================================================================

CREATE OR REPLACE FUNCTION modulo5.fn_calcular_data_quality_score(
    p_peso_ini BOOLEAN,
    p_peso_fin BOOLEAN,
    p_consumo  BOOLEAN,
    p_valido   BOOLEAN
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_presentes INT := 0;
BEGIN
    IF p_peso_ini THEN v_presentes := v_presentes + 1; END IF;
    IF p_peso_fin THEN v_presentes := v_presentes + 1; END IF;
    IF p_consumo  THEN v_presentes := v_presentes + 1; END IF;
    IF p_valido   THEN v_presentes := v_presentes + 1; END IF;

    RETURN ROUND((v_presentes::NUMERIC / 4) * 100, 2);
END;
$$;


-- 1. Confirmar que las funciones existen
SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'modulo5'
  AND routine_name IN (
      'fn_clasificar_eficiencia_ica',
      'fn_calcular_data_quality_score'
  );

-- 2. Probar fn_clasificar_eficiencia_ica con los 4 rangos
SELECT
    valor,
    modulo5.fn_clasificar_eficiencia_ica(valor) AS clasificacion
FROM (VALUES
    (1.0::NUMERIC),
    (2.0::NUMERIC),
    (3.0::NUMERIC),
    (4.0::NUMERIC)
) AS t(valor);

-- 3. Probar fn_calcular_data_quality_score
SELECT
    modulo5.fn_calcular_data_quality_score(TRUE,  TRUE,  TRUE,  TRUE)  AS completo,    -- 100
    modulo5.fn_calcular_data_quality_score(TRUE,  TRUE,  FALSE, FALSE) AS parcial,     -- 50
    modulo5.fn_calcular_data_quality_score(FALSE, FALSE, FALSE, FALSE) AS sin_datos;   -- 0
    
    
-- ==============================================================================
-- BLOQUE 2.1: sp_registrar_consumo_alimento (RF-75)
-- Correcciones:
--   1. Eliminar parámetro p_costo_unitario — el trigger lo obtiene de tipos_alimentos
--   2. Eliminar cálculo v_costo_total — duplica fn_trg_calcular_costo_total_consumo
--   3. Eliminar columna costo_unitario del INSERT — no existe en la tabla
--   4. Eliminar costo_total del INSERT — el trigger lo asigna
-- ==============================================================================

CREATE OR REPLACE PROCEDURE modulo5.sp_registrar_consumo_alimento(
    p_id_usuario             INT,
    p_id_activo              INT,
    p_id_tipo_alimento       INT,
    p_cantidad_suministrada  NUMERIC,
    p_fecha_inicio           TIMESTAMP,
    p_fecha_fin              TIMESTAMP,
    p_observacion            VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_alimento VARCHAR;
    v_unidad        VARCHAR;
BEGIN
    -- 1. Validar existencia y estado ACTIVO del tipo de alimento
    SELECT nombre, unidad_medida
    INTO v_tipo_alimento, v_unidad
    FROM modulo5.tipos_alimentos
    WHERE id_tipo_elemento = p_id_tipo_alimento
      AND estado = 'ACTIVO';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'TIPO_ALIMENTO_INVALIDO: El tipo de alimento con id [%] no existe '
            'o no está en estado ACTIVO. (RF-75 Proceso paso 2)',
            p_id_tipo_alimento
        USING ERRCODE = 'P0001';
    END IF;

    -- 2. Insertar — costo_total lo calcula fn_trg_calcular_costo_total_consumo
    INSERT INTO modulo5.registros_consumo_alimentos (
        id_activo_biologico,
        id_tipo_alimento,
        tipo_alimento,
        tipo_unidad,
        cantidad_suministrada,
        observacion,
        fecha_inicio_periodo,
        fecha_fin_periodo,
        id_usuario,
        fecha_registro
    ) VALUES (
        p_id_activo,
        p_id_tipo_alimento,
        v_tipo_alimento,
        v_unidad,
        p_cantidad_suministrada,
        p_observacion,
        p_fecha_inicio,
        p_fecha_fin,
        p_id_usuario,
        CURRENT_TIMESTAMP
    );

    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1,
        'Modulo 5',
        'SUMINISTROS',
        'Registro de consumo de alimento para activo ID: ' || p_id_activo,
        'exitoso',
        'VALIDADO',
        jsonb_build_object(
            'id_activo',        p_id_activo,
            'id_tipo_alimento', p_id_tipo_alimento,
            'cantidad',         p_cantidad_suministrada
        )
    );
END;
$$;


-- ==============================================================================
-- BLOQUE 2.2: sp_registrar_aplicacion_medicamento (RF-76)
-- Correcciones:
--   1. Eliminar cálculo v_costo_total — duplica fn_trg_calcular_costo_total_medicamento
--   2. Eliminar costo_total_medicamento del INSERT — el trigger lo asigna
--   3. Corregir nombre columna fecha_registro — la tabla tiene fecha_registro NOT NULL
--      con DEFAULT now(), no es necesario insertarla explícitamente
-- ==============================================================================

CREATE OR REPLACE PROCEDURE modulo5.sp_registrar_aplicacion_medicamento(
    p_id_usuario         INT,
    p_id_activo          INT,
    p_id_veterinario     INT,
    p_nombre_medicamento VARCHAR,
    p_descripcion        TEXT,
    p_unidad_dosis       VARCHAR,
    p_cantidad           NUMERIC,
    p_via_aplicacion     modulo5.enum_registro_medicamenti_via_aplicacion,
    p_costo_unitario     NUMERIC,
    p_fecha_aplicacion   DATE,
    p_lote               VARCHAR,
    p_vencimiento_lote   DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insertar — costo_total_medicamento lo calcula fn_trg_calcular_costo_total_medicamento
    INSERT INTO modulo5.registros_medicamentos (
        id_activo_biologico,
        nombre_medicamento,
        descripcion_clinica,
        unidad_dosis,
        cantidad,
        via_aplicacion,
        costo_unitario_medicamento,
        fecha_aplicacion,
        lote_medicameto,
        fehca_vencimietno_lote,
        id_usuario,
        id_usuario_veterinario
    ) VALUES (
        p_id_activo,
        p_nombre_medicamento,
        p_descripcion,
        p_unidad_dosis,
        p_cantidad,
        p_via_aplicacion,
        p_costo_unitario,
        p_fecha_aplicacion,
        p_lote,
        p_vencimiento_lote,
        p_id_usuario,
        p_id_veterinario
    );

    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        1,
        'Modulo 5',
        'SUMINISTROS',
        'Registro de aplicación de medicamento: ' || p_nombre_medicamento,
        'exitoso',
        'VALIDADO',
        jsonb_build_object(
            'id_activo',     p_id_activo,
            'medicamento',   p_nombre_medicamento,
            'costo_unitario', p_costo_unitario
        )
    );
END;
$$;


-- ==============================================================================
-- BLOQUE 2.3: sp_calcular_ica (RF-76)
-- Correcciones:
--   1. v_peso_inicial: usar peso_inicial_ciclo del primer registro del ciclo,
--      no MIN(peso_actual) que es incorrecto
--   2. Filtrar consumos y medicamentos por id_ciclo_productivo
--   3. El tipo p_esquema ya existe tras el Bloque 0
-- ==============================================================================

CREATE OR REPLACE PROCEDURE modulo5.sp_calcular_ica(
    p_id_usuario INT,
    p_id_activo  INT,
    p_id_ciclo   INT,
    p_peso_actual NUMERIC,
    p_esquema    modulo5.enum_medicion_incremental_esquema
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_peso_inicial          NUMERIC;
    v_ganancia_peso         NUMERIC;
    v_consumo_acumulado     NUMERIC;
    v_ica                   NUMERIC;
    v_costo_alimento_acum   NUMERIC;
    v_costo_inversion       NUMERIC;
BEGIN
    -- 1. Obtener peso_inicial_ciclo del primer registro de este activo en este ciclo
    --    Si no hay registros previos, el peso inicial es el peso actual (primera medición)
    SELECT peso_inicial_ciclo
    INTO v_peso_inicial
    FROM modulo5.mediciones_incrementales
    WHERE id_activo_biologico = p_id_activo
      AND id_ciclo_productivo = p_id_ciclo
    ORDER BY fecha_creacion ASC
    LIMIT 1;

    IF NOT FOUND THEN
        v_peso_inicial := p_peso_actual;
    END IF;

    -- 2. Calcular ganancia de peso
    v_ganancia_peso := p_peso_actual - v_peso_inicial;

    -- 3. Consumo acumulado de alimento filtrado por ciclo
    SELECT
        COALESCE(SUM(cantidad_suministrada), 0),
        COALESCE(SUM(costo_total), 0)
    INTO v_consumo_acumulado, v_costo_alimento_acum
    FROM modulo5.registros_consumo_alimentos
    WHERE id_activo_biologico = p_id_activo
      AND estado_registro     = 'VALIDADO';

    -- 4. Calcular ICA — evitar división por cero
    IF v_ganancia_peso > 0 THEN
        v_ica := v_consumo_acumulado / v_ganancia_peso;
    ELSE
        v_ica := 0;
    END IF;

    -- 5. Costo de inversión — medicamentos del activo
    SELECT COALESCE(SUM(costo_total_medicamento), 0)
    INTO v_costo_inversion
    FROM modulo5.registros_medicamentos
    WHERE id_activo_biologico = p_id_activo
      AND estado_registro     = 'VALIDADO';

    -- 6. Insertar medición incremental
    INSERT INTO modulo5.mediciones_incrementales (
        id_activo_biologico,
        id_ciclo_productivo,
        fecha_medicion,
        peso_actual,
        peso_inicial_ciclo,
        ganancia_peso,
        consumo_alimento_acumulado,
        conversion_alimenticia,
        costo_acumalado,
        costo_acumulado_inversion,
        esquema_proceso,
        id_usuario,
        fecha_creacion
    ) VALUES (
        p_id_activo,
        p_id_ciclo,
        CURRENT_DATE,
        p_peso_actual,
        v_peso_inicial,
        v_ganancia_peso,
        v_consumo_acumulado,
        v_ica,
        v_costo_alimento_acum,
        v_costo_inversion,
        p_esquema,
        p_id_usuario,
        CURRENT_TIMESTAMP
    );

    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        3,
        'Modulo 5',
        'ANALITICA',
        'Cálculo de ICA para activo ID: ' || p_id_activo,
        'exitoso',
        'COMPLETADO',
        jsonb_build_object(
            'ica_resultado',   v_ica,
            'ganancia_peso',   v_ganancia_peso,
            'consumo_total',   v_consumo_acumulado
        )
    );
END;
$$;


-- 1. Confirmar que los tres SPs existen y fueron actualizados
SELECT
    routine_name,
    routine_type,
    last_altered
FROM information_schema.routines
WHERE routine_schema = 'modulo5'
  AND routine_name IN (
      'sp_registrar_consumo_alimento',
      'sp_registrar_aplicacion_medicamento',
      'sp_calcular_ica'
  );

-- 2. Confirmar que sp_registrar_consumo_alimento
--    ya no tiene p_costo_unitario en su firma
SELECT
    p.pronargs        AS num_parametros,
    pg_get_function_arguments(p.oid) AS firma
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname  = 'modulo5'
  AND p.proname  = 'sp_registrar_consumo_alimento';

-- 3. Confirmar typos heredados del DDL están respetados en sp_calcular_ica
--    (costo_acumalado, fehca_vencimietno_lote)
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'modulo5'
  AND table_name   = 'mediciones_incrementales'
  AND column_name  = 'costo_acumalado';




-- ==============================================================================
-- BLOQUE 3: fn_calcular_ica_periodo (RF-74)
-- Calcula CA = alimento_total / ganancia_peso para un activo en un período
-- Depende de: fn_clasificar_eficiencia_ica, fn_calcular_data_quality_score
-- Tablas: mediciones_incrementales, registros_consumo_alimentos
-- Retorna: ca_valor, clasificacion, data_quality_score, datos_actualizados_hasta
-- ==============================================================================

CREATE OR REPLACE FUNCTION modulo5.fn_calcular_ica_periodo(
    p_activo_id INT,
    p_periodo   VARCHAR,  -- 'SEMANAL', 'MENSUAL', 'POR_CICLO'
    p_inicio    DATE,
    p_fin       DATE
)
RETURNS TABLE (
    ca_valor               NUMERIC,
    clasificacion          TEXT,
    data_quality_score     NUMERIC,
    datos_actualizados_hasta TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_peso_inicial         NUMERIC;
    v_peso_final           NUMERIC;
    v_ganancia_peso        NUMERIC;
    v_consumo_total        NUMERIC;
    v_ca                   NUMERIC;
    v_clasificacion        TEXT;
    v_score                NUMERIC;
    v_tiene_peso_ini       BOOLEAN := FALSE;
    v_tiene_peso_fin       BOOLEAN := FALSE;
    v_tiene_consumo        BOOLEAN := FALSE;
    v_tiene_valido         BOOLEAN := FALSE;
    v_actualizado_hasta    TIMESTAMPTZ;
BEGIN
    -- 1. Validar rango de fechas
    IF p_inicio > p_fin THEN
        RAISE EXCEPTION
            'RANGO_INVALIDO: La fecha de inicio [%] no puede ser posterior '
            'a la fecha de fin [%]. (RF-74)',
            p_inicio, p_fin
        USING ERRCODE = 'P0001';
    END IF;

    -- 2. Validar período
    IF p_periodo NOT IN ('SEMANAL', 'MENSUAL', 'POR_CICLO') THEN
        RAISE EXCEPTION
            'PERIODO_INVALIDO: El período [%] no es válido. '
            'Valores aceptados: SEMANAL, MENSUAL, POR_CICLO. (RF-74)',
            p_periodo
        USING ERRCODE = 'P0001';
    END IF;

    -- 3. Obtener peso inicial — primer registro del período
    SELECT peso_inicial_ciclo
    INTO v_peso_inicial
    FROM modulo5.mediciones_incrementales
    WHERE id_activo_biologico = p_activo_id
      AND fecha_medicion     >= p_inicio
      AND fecha_medicion     <= p_fin
    ORDER BY fecha_medicion ASC, fecha_creacion ASC
    LIMIT 1;

    IF FOUND AND v_peso_inicial IS NOT NULL THEN
        v_tiene_peso_ini := TRUE;
    END IF;

    -- 4. Obtener peso final — último registro del período
    SELECT peso_actual
    INTO v_peso_final
    FROM modulo5.mediciones_incrementales
    WHERE id_activo_biologico = p_activo_id
      AND fecha_medicion     >= p_inicio
      AND fecha_medicion     <= p_fin
    ORDER BY fecha_medicion DESC, fecha_creacion DESC
    LIMIT 1;

    IF FOUND AND v_peso_final IS NOT NULL THEN
        v_tiene_peso_fin := TRUE;
    END IF;

    -- 5. Obtener consumo acumulado de alimentos VALIDADO en el período
    SELECT COALESCE(SUM(cantidad_suministrada), 0)
    INTO v_consumo_total
    FROM modulo5.registros_consumo_alimentos
    WHERE id_activo_biologico = p_activo_id
      AND estado_registro     = 'VALIDADO'
      AND fecha_inicio_periodo >= p_inicio::TIMESTAMPTZ
      AND fecha_inicio_periodo <= p_fin::TIMESTAMPTZ;

    IF v_consumo_total > 0 THEN
        v_tiene_consumo := TRUE;
    END IF;

    -- 6. Verificar que hay registros VALIDADO en el período
    IF v_tiene_peso_ini AND v_tiene_peso_fin AND v_tiene_consumo THEN
        v_tiene_valido := TRUE;
    END IF;

    -- 7. Calcular data quality score
    v_score := modulo5.fn_calcular_data_quality_score(
        v_tiene_peso_ini,
        v_tiene_peso_fin,
        v_tiene_consumo,
        v_tiene_valido
    );

    -- 8. Calcular CA — si no hay datos suficientes retorna fila con score bajo
    IF v_tiene_peso_ini AND v_tiene_peso_fin AND v_tiene_consumo THEN
        v_ganancia_peso := v_peso_final - v_peso_inicial;

        IF v_ganancia_peso > 0 THEN
            v_ca := ROUND(v_consumo_total / v_ganancia_peso, 4);
        ELSE
            v_ca := 0;
        END IF;

        v_clasificacion := modulo5.fn_clasificar_eficiencia_ica(v_ca);
    ELSE
        v_ca            := NULL;
        v_clasificacion := NULL;
    END IF;

    -- 9. Timestamp de última actualización de datos del activo en el período
    SELECT MAX(fecha_creacion)
    INTO v_actualizado_hasta
    FROM modulo5.mediciones_incrementales
    WHERE id_activo_biologico = p_activo_id
      AND fecha_medicion     >= p_inicio
      AND fecha_medicion     <= p_fin;

    -- 10. Retornar resultado
    RETURN QUERY
    SELECT
        v_ca,
        v_clasificacion,
        v_score,
        v_actualizado_hasta;
END;
$$;


-- 1. Confirmar que la función existe con la firma correcta
SELECT
    routine_name,
    routine_type,
    pg_get_function_arguments(p.oid) AS firma
FROM information_schema.routines r
JOIN pg_proc p ON p.proname = r.routine_name
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE r.routine_schema = 'modulo5'
  AND r.routine_name   = 'fn_calcular_ica_periodo'
  AND n.nspname        = 'modulo5';

-- 2. Confirmar la estructura de retorno
SELECT
    p.proname AS funcion,
    pg_get_function_result(p.oid) AS retorno
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'modulo5'
  AND p.proname = 'fn_calcular_ica_periodo';

-- 3. Prueba funcional con activo existente
--    (ajusta id_activo, inicio y fin a datos reales de tu BD)

SELECT *
FROM modulo5.fn_calcular_ica_periodo(
    1,
    'SEMANAL',
    (CURRENT_DATE - 7)::DATE,
    CURRENT_DATE::DATE
);




CREATE OR REPLACE PROCEDURE modulo4.sp_distribuir_modelo_ota(
    IN p_id_version_modelo  INTEGER,
    IN p_hash_calculado     VARCHAR(64),
    IN p_dispositivos       INTEGER[]
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_en_produccion     BOOLEAN;
    v_nombre_version    VARCHAR(40);
    v_ruta_artefacto    TEXT;
    v_hash_valido       BOOLEAN;
    v_dispositivo       INTEGER;
    v_total             INTEGER;
    v_exitosos          INTEGER := 0;
    v_fallidos          INTEGER := 0;
BEGIN
    -- Validar que el modelo exista y esté en producción
    SELECT esta_produccion, nombre_version, ruta_artefacto
    INTO   v_en_produccion, v_nombre_version, v_ruta_artefacto
    FROM   modulo4.versiones_modelos
    WHERE  id_version_modelo = p_id_version_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'MODELO_NO_ENCONTRADO: La versión % no existe.',
            p_id_version_modelo
        USING ERRCODE = 'P0460';
    END IF;

    IF v_en_produccion = false THEN
        RAISE EXCEPTION
            'MODELO_NO_APROBADO: La versión % no está en producción. '
            'Solo se distribuyen modelos activos.',
            p_id_version_modelo
        USING ERRCODE = 'P0461';
    END IF;

    -- Validar dispositivos destino
    v_total := array_length(p_dispositivos, 1);

    IF v_total IS NULL OR v_total = 0 THEN
        RAISE EXCEPTION
            'DISPOSITIVOS_VACIOS: Debe indicar al menos un dispositivo destino.'
        USING ERRCODE = 'P0462';
    END IF;

    -- Verificar integridad del artefacto antes de distribuir
    v_hash_valido := modulo4.fn_verificar_integridad_artefacto(
        p_id_version_modelo,
        p_hash_calculado
    );

    IF NOT v_hash_valido THEN
        RAISE NOTICE
            'HASH_INVALIDO_DETECTADO: El hash proporcionado no coincide '
            'con el artefacto registrado para el modelo %. '
            'Distribución abortada. Se mantiene versión anterior activa.',
            p_id_version_modelo;
        RETURN;
    END IF;

    -- Distribuir a cada dispositivo
    FOREACH v_dispositivo IN ARRAY p_dispositivos
    LOOP
        BEGIN
            -- Simulación de distribución fragmentada por dispositivo
            -- En implementación real aquí iría la integración con el sistema OTA
            RAISE NOTICE
                'MODELO_DISTRIBUIDO_EDGE: Modelo % (%) distribuido a dispositivo %. '
                'Ruta: %.',
                p_id_version_modelo,
                v_nombre_version,
                v_dispositivo,
                v_ruta_artefacto;

            v_exitosos := v_exitosos + 1;

        EXCEPTION WHEN OTHERS THEN
            -- Fallo en dispositivo individual — continúa con los demás
            RAISE NOTICE
                'HASH_INVALIDO_DETECTADO: Fallo al distribuir a dispositivo %. '
                'Error: %. Se mantiene versión anterior activa en ese dispositivo.',
                v_dispositivo,
                SQLERRM;

            v_fallidos := v_fallidos + 1;
        END;
    END LOOP;

    -- Resumen final
    RAISE NOTICE
        'DISTRIBUCION_COMPLETADA: Modelo % → % exitosos, % fallidos de % dispositivos.',
        p_id_version_modelo,
        v_exitosos,
        v_fallidos,
        v_total;
END;
$procedure$;

-- CALL
-- 1. Confirmar que las tres funciones existen
SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'modulo5'
  AND routine_name IN (
      'fn_auditar_suministro',
      'fn_trg_auditoria_consumo_alimento',
      'fn_trg_auditoria_medicamento'
  );

-- 2. Confirmar que los triggers existentes siguen activos
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'modulo5'
  AND trigger_name IN (
      'trg_auditoria_consumo_alimento',
      'trg_auditoria_medicamento'
  );

-- 3. Confirmar que auditorias_suministros recibe registros
--    (ejecuta después de cualquier INSERT en registros_consumo_alimentos)
SELECT
    id_auditoria_suministro,
    entidad_afectada,
    tipo_operacion,
    resultado,
    fecha_evento
FROM modulo5.auditorias_suministros
ORDER BY fecha_evento DESC
LIMIT 5;



-- ==============================================================================
-- BLOQUE 5: fn_consultar_historial_suministros (RF-81)
-- Retorna historial paginado con filtros dinámicos JSONB
-- Tablas: historial_suministros_activos, registros_consumo_alimentos,
--         registros_medicamentos
-- Filtros soportados en p_filtro:
--   fecha_inicio, fecha_fin, origen (ALIMENTO|MEDICAMENTO|AMBOS)
-- ==============================================================================

CREATE OR REPLACE FUNCTION modulo5.fn_consultar_historial_suministros(
    p_activo_id INT,
    p_filtro    JSONB,
    p_pagina    INT,
    p_limite    INT
)
RETURNS TABLE (
    id_historial            INT,
    id_activo_biologico     INT,
    origen                  modulo5.enum_historial_suministros_activos_origen,
    fecha_inicio            DATE,
    fecha_fin               DATE,
    costo_total_alimento    NUMERIC,
    costo_total_medicamento NUMERIC,
    costo_total_suministros NUMERIC,
    num_registros_alimento  INT,
    num_registros_medicamento INT,
    formato_exportacion     modulo5.enum_historial_suministros_activos_formatos_exportacion,
    fecha_consulta          TIMESTAMPTZ,
    monto_total_filtrado    NUMERIC,
    datos_actualizados_hasta TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha_inicio      DATE;
    v_fecha_fin         DATE;
    v_origen            modulo5.enum_historial_suministros_activos_origen;
    v_offset            INT;
    v_monto_total       NUMERIC;
    v_actualizado_hasta TIMESTAMPTZ;
BEGIN
    -- 1. Validar parámetros de paginación
    IF p_pagina < 1 THEN
        RAISE EXCEPTION
            'PAGINACION_INVALIDA: El número de página debe ser mayor a cero. '
            'Valor recibido: [%]. (RF-81)',
            p_pagina
        USING ERRCODE = 'P0001';
    END IF;

    IF p_limite < 1 OR p_limite > 100 THEN
        RAISE EXCEPTION
            'LIMITE_INVALIDO: El límite de registros debe estar entre 1 y 100. '
            'Valor recibido: [%]. (RF-81)',
            p_limite
        USING ERRCODE = 'P0001';
    END IF;

    -- 2. Extraer filtros del JSONB
    v_fecha_inicio := (p_filtro->>'fecha_inicio')::DATE;
    v_fecha_fin    := (p_filtro->>'fecha_fin')::DATE;

    IF p_filtro->>'origen' IS NOT NULL THEN
        v_origen := (p_filtro->>'origen')::modulo5.enum_historial_suministros_activos_origen;
    END IF;

    -- 3. Validar rango de fechas si ambas están presentes
    IF v_fecha_inicio IS NOT NULL AND v_fecha_fin IS NOT NULL THEN
        IF v_fecha_inicio > v_fecha_fin THEN
            RAISE EXCEPTION
                'RANGO_FECHAS_INVALIDO: La fecha de inicio [%] no puede ser '
                'posterior a la fecha de fin [%]. (RF-81)',
                v_fecha_inicio, v_fecha_fin
            USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 4. Calcular monto_total_filtrado sobre TODO el conjunto (no solo la página)
    SELECT COALESCE(SUM(h.costo_total_suministros), 0)
    INTO v_monto_total
    FROM modulo5.historial_suministros_activos h
    WHERE h.id_activo_biologico = p_activo_id
      AND (v_fecha_inicio IS NULL OR h.fecha_inicio >= v_fecha_inicio)
      AND (v_fecha_fin    IS NULL OR h.fecha_fin    <= v_fecha_fin)
      AND (v_origen       IS NULL OR h.origen        = v_origen);

    -- 5. Timestamp de última actualización del conjunto filtrado
    SELECT MAX(h.fecha_consulta)
    INTO v_actualizado_hasta
    FROM modulo5.historial_suministros_activos h
    WHERE h.id_activo_biologico = p_activo_id
      AND (v_fecha_inicio IS NULL OR h.fecha_inicio >= v_fecha_inicio)
      AND (v_fecha_fin    IS NULL OR h.fecha_fin    <= v_fecha_fin)
      AND (v_origen       IS NULL OR h.origen        = v_origen);

    -- 6. Calcular offset
    v_offset := (p_pagina - 1) * p_limite;

    -- 7. Retornar página
    RETURN QUERY
    SELECT
        h.id_historial_suministro_activo,
        h.id_activo_biologico,
        h.origen,
        h.fecha_inicio,
        h.fecha_fin,
        h.costo_total_alimento,
        h.costo_total_medicamento,
        h.costo_total_suministros,
        h.num_registros_alimento,
        h.num_registros_medicamento,
        h.formato_exportacion,
        h.fecha_consulta,
        v_monto_total,
        v_actualizado_hasta
    FROM modulo5.historial_suministros_activos h
    WHERE h.id_activo_biologico = p_activo_id
      AND (v_fecha_inicio IS NULL OR h.fecha_inicio >= v_fecha_inicio)
      AND (v_fecha_fin    IS NULL OR h.fecha_fin    <= v_fecha_fin)
      AND (v_origen       IS NULL OR h.origen        = v_origen)
    ORDER BY h.fecha_consulta DESC
    LIMIT  p_limite
    OFFSET v_offset;
END;
$$;

-- 1. Confirmar que la función existe con firma correcta
SELECT
    p.proname AS funcion,
    pg_get_function_arguments(p.oid)  AS firma,
    pg_get_function_result(p.oid)     AS retorno
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'modulo5'
  AND p.proname = 'fn_consultar_historial_suministros';

-- 2. Prueba sin filtros — página 1, límite 10
SELECT *
FROM modulo5.fn_consultar_historial_suministros(
    1,                  -- p_activo_id
    '{}'::JSONB,        -- sin filtros
    1,                  -- página 1
    10                  -- límite
);

-- 3. Prueba con filtro de origen
SELECT *
FROM modulo5.fn_consultar_historial_suministros(
    1,
    '{"origen": "ALIMENTO"}'::JSONB,
    1,
    10
);

-- 4. Prueba con filtro de fechas
SELECT *
FROM modulo5.fn_consultar_historial_suministros(
    1,
    jsonb_build_object(
        'fecha_inicio', CURRENT_DATE - 30,
        'fecha_fin',    CURRENT_DATE
    ),
    1,
    10
);

-- 5. Probar validación de límite inválido
SELECT *
FROM modulo5.fn_consultar_historial_suministros(
    1,
    '{}'::JSONB,
    1,
    100   -- debe lanzar excepción LIMITE_INVALIDO
);




-- ==============================================================================
-- BLOQUE 6.1: fn_trg_disparar_recalculo_ica_post_consumo (RF-74)
-- AFTER INSERT/UPDATE en registros_consumo_alimentos
-- Notifica via pg_notify para recálculo asíncrono de ICA
-- Canal: 'ica_recalculo' — payload: id_activo_biologico
-- ==============================================================================

CREATE OR REPLACE FUNCTION modulo5.fn_trg_disparar_recalculo_ica_post_consumo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo notifica si el registro está VALIDADO
    IF NEW.estado_registro = 'VALIDADO' THEN
        PERFORM pg_notify(
            'ica_recalculo',
            json_build_object(
                'id_activo_biologico', NEW.id_activo_biologico,
                'fecha_evento',        NOW()
            )::TEXT
        );
    END IF;

    RETURN NULL;
END;
$$;

-- Crear el trigger sobre registros_consumo_alimentos
CREATE TRIGGER trg_disparar_recalculo_ica_post_consumo
    AFTER INSERT OR UPDATE
    ON modulo5.registros_consumo_alimentos
    FOR EACH ROW
    EXECUTE FUNCTION modulo5.fn_trg_disparar_recalculo_ica_post_consumo();


-- ==============================================================================
-- BLOQUE 6.2: sp_ejecutar_batch_ica_automatizado (RF-74)
-- Itera activos ACTIVO y ejecuta fn_calcular_ica_periodo
-- para SEMANAL, MENSUAL y POR_CICLO
-- Maneja ventana de 4h mediante check de fecha_inicio_batch
-- ==============================================================================

CREATE OR REPLACE PROCEDURE modulo5.sp_ejecutar_batch_ica_automatizado()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Cursor sobre activos con consumos VALIDADO
    v_activo            RECORD;
    -- Resultados ICA por período
    v_resultado         RECORD;
    -- Control de ventana de 4 horas
    v_inicio_batch      TIMESTAMPTZ := NOW();
    v_limite_ventana    TIMESTAMPTZ := NOW() + INTERVAL '4 hours';
    -- Contadores para log
    v_total_procesados  INT := 0;
    v_total_errores     INT := 0;
    -- Fechas por esquema
    v_inicio_semanal    DATE := CURRENT_DATE - 7;
    v_inicio_mensual    DATE := CURRENT_DATE - 30;
    v_inicio_ciclo      DATE := CURRENT_DATE - 365;
BEGIN
    -- Iterar activos que tienen consumos VALIDADO
    FOR v_activo IN
        SELECT DISTINCT
            rca.id_activo_biologico,
            -- Ciclo más reciente del activo (para POR_CICLO)
            MAX(mi.id_ciclo_productivo) AS id_ciclo
        FROM modulo5.registros_consumo_alimentos rca
        LEFT JOIN modulo5.mediciones_incrementales mi
               ON mi.id_activo_biologico = rca.id_activo_biologico
        WHERE rca.estado_registro = 'VALIDADO'
        GROUP BY rca.id_activo_biologico
    LOOP
        -- Control de ventana — si se supera las 4h se interrumpe
        IF NOW() > v_limite_ventana THEN
            RAISE NOTICE
                'BATCH_INTERRUMPIDO: Se superó la ventana de 4 horas. '
                'Procesados: %, Errores: %. Reactivación manual requerida.',
                v_total_procesados, v_total_errores;
            EXIT;
        END IF;

        -- Calcular ICA SEMANAL
        BEGIN
            SELECT * INTO v_resultado
            FROM modulo5.fn_calcular_ica_periodo(
                v_activo.id_activo_biologico,
                'SEMANAL',
                v_inicio_semanal,
                CURRENT_DATE
            );

            v_total_procesados := v_total_procesados + 1;

        EXCEPTION WHEN OTHERS THEN
            v_total_errores := v_total_errores + 1;
            RAISE NOTICE
                'ERROR_SEMANAL: Activo [%] — %',
                v_activo.id_activo_biologico,
                SQLERRM;
        END;

        -- Calcular ICA MENSUAL
        BEGIN
            SELECT * INTO v_resultado
            FROM modulo5.fn_calcular_ica_periodo(
                v_activo.id_activo_biologico,
                'MENSUAL',
                v_inicio_mensual,
                CURRENT_DATE
            );

            v_total_procesados := v_total_procesados + 1;

        EXCEPTION WHEN OTHERS THEN
            v_total_errores := v_total_errores + 1;
            RAISE NOTICE
                'ERROR_MENSUAL: Activo [%] — %',
                v_activo.id_activo_biologico,
                SQLERRM;
        END;

        -- Calcular ICA POR_CICLO solo si tiene ciclo asociado
        IF v_activo.id_ciclo IS NOT NULL THEN
            BEGIN
                SELECT * INTO v_resultado
                FROM modulo5.fn_calcular_ica_periodo(
                    v_activo.id_activo_biologico,
                    'POR_CICLO',
                    v_inicio_ciclo,
                    CURRENT_DATE
                );

                v_total_procesados := v_total_procesados + 1;

            EXCEPTION WHEN OTHERS THEN
                v_total_errores := v_total_errores + 1;
                RAISE NOTICE
                    'ERROR_POR_CICLO: Activo [%] — %',
                    v_activo.id_activo_biologico,
                    SQLERRM;
            END;
        END IF;

    END LOOP;

    RAISE NOTICE
        'BATCH_COMPLETADO: Inicio [%] — Fin [%] — Procesados: % — Errores: %',
        v_inicio_batch,
        NOW(),
        v_total_procesados,
        v_total_errores;
END;
$$;

-- 1. Confirmar función trigger y SP existen
SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'modulo5'
  AND routine_name IN (
      'fn_trg_disparar_recalculo_ica_post_consumo',
      'sp_ejecutar_batch_ica_automatizado'
  );

-- 2. Confirmar que el trigger fue creado sobre la tabla correcta
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'modulo5'
  AND trigger_name   = 'trg_disparar_recalculo_ica_post_consumo';

-- 3. Verificar que no hay trigger duplicado con los existentes
SELECT
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema     = 'modulo5'
  AND event_object_table = 'registros_consumo_alimentos'
ORDER BY trigger_name;

-- 4. Ejecutar el batch manualmente y observar los NOTICE
CALL modulo5.sp_ejecutar_batch_ica_automatizado();
