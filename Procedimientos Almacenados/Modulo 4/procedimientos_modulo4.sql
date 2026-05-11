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

    -- Registrar auditoría (RF-10)
    CALL modulo1.sp_registrar_auditoria(
        p_id_usuario,
        NULL,
        5, -- OBSERVACION_CLINICA (Asumido)
        'Modulo 4',
        'SANIDAD',
        'Registro de observación clínica para activo ID: ' || p_id_activo_biologico,
        'exitoso',
        'COMPLETADO',
        jsonb_build_object(
            'id_observacion', v_id_observacion,
            'temperatura', p_temperatura_rectal,
            'f_cardiaca', p_frecuencia_cardiaca
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
----


CREATE OR REPLACE FUNCTION modulo4.fn_obtener_modelo_activo_por_especie(
    p_especie VARCHAR
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_algoritmo modulo4.enum_version_modelo_algoritmo;
    v_id INT;
BEGIN
    -- Mapeo simple especie -> algoritmo esperado
    v_algoritmo := CASE p_especie
        WHEN 'pequeña' THEN 'RANDOM_FOREST'::modulo4.enum_version_modelo_algoritmo
        WHEN 'mediana' THEN 'XGBOOST'::modulo4.enum_version_modelo_algoritmo
        WHEN 'grande'  THEN 'RED_BAYESIANA'::modulo4.enum_version_modelo_algoritmo
        ELSE NULL
    END;

    IF v_algoritmo IS NULL THEN
        RAISE EXCEPTION 'Especie no soportada: %', p_especie;
    END IF;

    SELECT id_version_modelo INTO v_id
    FROM modulo4.versiones_modelos
    WHERE algoritmo = v_algoritmo
      AND esta_produccion = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No hay modelo activo para especie %', p_especie;
    END IF;

    RETURN v_id;
END;
$$;

SELECT modulo4.fn_obtener_modelo_activo_por_especie('mediana');


CREATE OR REPLACE FUNCTION modulo4.fn_calcular_probabilidad_contagio(
    p_fs     NUMERIC,   -- factor sanitario
    p_fa     NUMERIC,   -- factor ambiental
    p_fd     NUMERIC,   -- factor densidad
    p_w_fs   NUMERIC DEFAULT 0.4,
    p_w_fa   NUMERIC DEFAULT 0.3,
    p_w_fd   NUMERIC DEFAULT 0.3
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN p_w_fs * p_fs + p_w_fa * p_fa + p_w_fd * p_fd;
END;
$$;


SELECT modulo4.fn_calcular_probabilidad_contagio(0.8, 0.6, 0.9);



CREATE OR REPLACE FUNCTION modulo4.fn_supera_umbral_clasificacion(
    p_probabilidad NUMERIC,
    p_umbral       NUMERIC DEFAULT 70.0
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN p_probabilidad >= p_umbral;
END;
$$;


SELECT modulo4.fn_supera_umbral_clasificacion(85.2);


-- Tipo de retorno
CREATE TYPE modulo4.resultado_validacion AS (
    estado        VARCHAR(20),
    campo_fallido VARCHAR(50)
);



--- ===========================
--- ===========================
CREATE TYPE modulo4.resultado_validacion AS (
    estado        VARCHAR(20),
    campo_fallido VARCHAR(50)
);
CREATE OR REPLACE FUNCTION modulo4.fn_validar_metricas_modelo(
    p_f1_score NUMERIC,
    p_recall   NUMERIC
)
RETURNS modulo4.resultado_validacion
LANGUAGE plpgsql
AS $$
DECLARE
    v_result modulo4.resultado_validacion;
BEGIN
    IF p_f1_score >= 0.80 AND p_recall >= 0.85 THEN
        v_result.estado := 'APROBADO';
        v_result.campo_fallido := NULL;
    ELSE
        v_result.estado := 'RECHAZADO';
        v_result.campo_fallido := CASE
            WHEN p_f1_score < 0.80 THEN 'f1_score'
            ELSE 'recall'
        END;
    END IF;
    RETURN v_result;
END;
$$;

SELECT * FROM modulo4.fn_validar_metricas_modelo(0.82, 0.90);


----=====

CREATE OR REPLACE FUNCTION modulo4.fn_calcular_drift_score(
    p_id_version_modelo    INT,
    p_periodo_referencia   VARCHAR
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_score NUMERIC;
BEGIN
    SELECT MAX(valor_metrica) INTO v_score
    FROM modulo4.metricas_drift
    WHERE id_modelo_version = p_id_version_modelo
      AND supera_umbral_drift = TRUE
      AND periodo_referencia = p_periodo_referencia;

    RETURN COALESCE(v_score, 0.0);
END;
$$;

SELECT modulo4.fn_calcular_drift_score(1, 'S1');


----======
----======
CREATE OR REPLACE FUNCTION modulo4.fn_contar_registros_etiquetados_disponibles(
    p_fecha_inicio DATE,
    p_fecha_fin    DATE,
    p_tipo_modelo  modulo4.enum_version_modelo_algoritmo DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    -- Cuenta observaciones clínicas con signos en el rango de fechas.
    SELECT COUNT(*)
    INTO v_count
    FROM modulo4.observaciones_clinicas oc
    WHERE oc.fecha BETWEEN p_fecha_inicio AND p_fecha_fin
      AND EXISTS (
          SELECT 1 FROM modulo4.detalles_signos
          WHERE id_observaciones = oc.id_observacion_clinica
      );

    RETURN v_count;
END;
$$;

SELECT modulo4.fn_contar_registros_etiquetados_disponibles(
    '2026-01-01', '2026-04-30', 'XGBOOST'
);

----===
----===

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION modulo4.fn_dataset_hash_sha256(
    p_id_dataset INT
)
RETURNS VARCHAR(64)
LANGUAGE plpgsql
AS $$
DECLARE
    v_hash VARCHAR(64);
BEGIN
    SELECT ENCODE(DIGEST(
        nombre ||
        to_char(fecha_inicio_datos, 'YYYY-MM-DD') ||
        to_char(fecha_fin_datos, 'YYYY-MM-DD') ||
        COALESCE(enfermedades_incluidas::TEXT, ''),
        'sha256'
    ), 'hex')
    INTO v_hash
    FROM modulo4.datasets
    WHERE id_dataset = p_id_dataset;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dataset % no encontrado', p_id_dataset;
    END IF;

    RETURN v_hash;
END;
$$;


SELECT modulo4.fn_dataset_hash_sha256(5);


CREATE OR REPLACE FUNCTION modulo4.fn_verificar_integridad_artefacto(
    p_id_version_modelo INT,
    p_hash_calculado   VARCHAR(64)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_hash_almacenado VARCHAR(64);
BEGIN
    SELECT hash_artecfacto INTO v_hash_almacenado
    FROM modulo4.versiones_modelos
    WHERE id_version_modelo = p_id_version_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Modelo % no existe', p_id_version_modelo;
    END IF;

    RETURN p_hash_calculado = v_hash_almacenado;
END;
$$;

SELECT modulo4.fn_verificar_integridad_artefacto(8, '2794d886abafb7d1808a3bea99e4fd702794d886abafb7d1808a3bea99e4fd70');


--===
--===
CREATE OR REPLACE FUNCTION modulo4.fn_obtener_historial_predicciones_paginado(
    p_id_activo    INT,
    p_fecha_inicio TIMESTAMPTZ,
    p_fecha_fin    TIMESTAMPTZ,
    p_id_patologia INT DEFAULT NULL,
    p_cursor       TEXT DEFAULT '',
    p_page_size    INT DEFAULT 20
)
RETURNS TABLE (
    id_prediccion     INT,
    probabilidad_pct  NUMERIC,
    clase_predicha    modulo4.enum_predicciones_clase,
    fecha_prediccion  TIMESTAMPTZ,
    patologia         INT,
    next_cursor       TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cursor_fecha TIMESTAMPTZ;
    v_cursor_id    INT;
BEGIN
    IF p_page_size > 50 THEN
        p_page_size := 50;
    END IF;

    IF p_cursor <> '' THEN
        v_cursor_fecha := split_part(p_cursor, ',', 1)::TIMESTAMPTZ;
        v_cursor_id    := split_part(p_cursor, ',', 2)::INT;
    END IF;

    RETURN QUERY
    WITH base AS (
        SELECT
            p.id_prediccion,
            p.probabilidad_pct,
            p.clase_predicha,
            p.fecha_prediccion,
            p.id_patologia AS patologia
        FROM modulo4.predicciones p
        JOIN modulo4.observaciones_clinicas oc
          ON p.id_observacion = oc.id_observacion_clinica
        WHERE oc.id_activo_biologico = p_id_activo
          AND p.fecha_prediccion BETWEEN p_fecha_inicio AND p_fecha_fin
          AND (p_id_patologia IS NULL OR p.id_patologia = p_id_patologia)
          AND (p_cursor = '' 
               OR (p.fecha_prediccion, p.id_prediccion) < (v_cursor_fecha, v_cursor_id))
        ORDER BY p.fecha_prediccion DESC, p.id_prediccion DESC
        LIMIT p_page_size + 1  -- una fila extra para saber si hay siguiente página
    ),
    paged AS (
        SELECT *, row_number() OVER () AS rn
        FROM base
    ),
    with_cursor AS (
        SELECT
            paged.id_prediccion,
            paged.probabilidad_pct,
            paged.clase_predicha,
            paged.fecha_prediccion,
            paged.patologia,
            CASE
                -- Para la última fila visible (rn = page_size) tomamos el cursor de la siguiente si existe
                WHEN paged.rn = p_page_size THEN
                    (SELECT to_char(next_pred.fecha_prediccion, 'YYYY-MM-DD HH24:MI:SS TZ') || ',' || next_pred.id_prediccion
                     FROM paged next_pred WHERE next_pred.rn = p_page_size + 1)
                ELSE ''  -- filas anteriores llevan cursor vacío
            END AS next_cursor
        FROM paged
        WHERE paged.rn <= p_page_size  -- solo devolvemos las filas de la página
    )
    SELECT * FROM with_cursor;
END;
$$;

SELECT * FROM modulo4.fn_obtener_historial_predicciones_paginado(
    100, '2025-01-01', '2025-06-01', NULL, '', 20
);


--===
--==

CREATE OR REPLACE FUNCTION modulo4.fn_verificar_ventana_retroalimentacion(
    p_id_prediccion INT,
    p_fecha_actual  DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha_prediccion DATE;
BEGIN
    SELECT fecha_prediccion::DATE INTO v_fecha_prediccion
    FROM modulo4.predicciones
    WHERE id_prediccion = p_id_prediccion;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Predicción % no existe', p_id_prediccion;
    END IF;

    RETURN (p_fecha_actual - v_fecha_prediccion) <= 90;
END;
$$;

SELECT modulo4.fn_verificar_ventana_retroalimentacion(6);


--====
--====

CREATE OR REPLACE FUNCTION modulo4.fn_detectar_conflicto_retroalimentacion(
    p_id_prediccion INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_evaluaciones TEXT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT datos_nuevos->>'evaluacion')
    INTO v_evaluaciones
    FROM modulo4.auditorias_predicciones
    WHERE id_prediccion = p_id_prediccion
      AND accion = 'VALIDACION_VET'
      AND datos_nuevos->>'evaluacion' IS NOT NULL;

    RETURN v_evaluaciones IS NOT NULL AND array_length(v_evaluaciones, 1) > 1;
END;
$$;

SELECT modulo4.fn_detectar_conflicto_retroalimentacion(300);



--=====
--=====

CREATE OR REPLACE FUNCTION modulo4.fn_prioridad_etiqueta_retroalimentacion(
    p_ids INT[]
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_best_id INT;
    v_best_rank INT := -1;
    rec RECORD;
    v_rank INT;
    v_eval TEXT;
    v_fuente TEXT;
BEGIN
    FOR rec IN
        SELECT id_auditoria_prediccion,
               datos_nuevos->>'evaluacion' AS evaluacion,
               datos_nuevos->>'fuente_diagnostico' AS fuente
        FROM modulo4.auditorias_predicciones
        WHERE id_auditoria_prediccion = ANY(p_ids)
          AND accion = 'VALIDACION_VET'
    LOOP
        v_eval := rec.evaluacion;
        v_fuente := rec.fuente;
        
        -- Prioridad por severidad
        v_rank := CASE v_eval
            WHEN 'INCORRECTO' THEN 300
            WHEN 'PARCIAL'    THEN 200
            WHEN 'CORRECTO'   THEN 100
            ELSE 0
        END;
        
        -- Ajuste por fuente
        v_rank := v_rank + CASE COALESCE(v_fuente, 'fuente_desconocida')
            WHEN 'LABORATORIO'        THEN 50
            WHEN 'HISTORIAL_CLINICO'  THEN 40
            WHEN 'OBSERVACION_DIRECTA' THEN 30
            WHEN 'OTRO'               THEN 20
            ELSE 10
        END;
        
        IF v_rank > v_best_rank THEN
            v_best_rank := v_rank;
            v_best_id := rec.id_auditoria_prediccion;
        END IF;
    END LOOP;

    RETURN v_best_id;
END;
$$;

SELECT modulo4.fn_prioridad_etiqueta_retroalimentacion(ARRAY[10,11,12]);


--- ===
--- PROCEDIMIENTOS
--- ===
CREATE OR REPLACE PROCEDURE modulo4.sp_evaluar_umbral_y_generar_alerta(
    IN p_id_prediccion    INTEGER,
    IN p_id_finca         INTEGER,
    IN p_id_notificacion  INTEGER
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_prob         NUMERIC(6,3);
    v_umbral       NUMERIC(5,2);
    v_supera       BOOLEAN;
    v_id_activo    INTEGER;
    v_id_patologia INTEGER;
    v_criticidad   VARCHAR(20);
BEGIN
    -- Obtener datos de la predicción y su observación
    SELECT p.probabilidad_pct,
           p.umbral_usado,
           p.id_patologia,
           oc.id_activo_biologico
    INTO   v_prob, v_umbral, v_id_patologia, v_id_activo
    FROM   modulo4.predicciones p
    JOIN   modulo4.observaciones_clinicas oc
           ON p.id_observacion = oc.id_observacion_clinica
    WHERE  p.id_prediccion = p_id_prediccion;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Predicción % no encontrada', p_id_prediccion;
    END IF;

    -- Evaluar umbral
    v_supera := modulo4.fn_supera_umbral_clasificacion(v_prob, v_umbral);

    IF NOT v_supera THEN
        RETURN;
    END IF;

    -- Derivar criticidad desde la probabilidad
    v_criticidad := CASE
        WHEN v_prob >= 90 THEN 'CRITICA'
        WHEN v_prob >= 80 THEN 'ALTA'
        WHEN v_prob >= 70 THEN 'MEDIA'
        ELSE                   'BAJA'
    END;

    -- Insertar alerta
    INSERT INTO modulo4.alertas_patologicas
        (id_prediccion, id_activo_biologico, id_finca, id_patologia,
         probabilidad_pct, nivel_criticidad, estado_alerta, id_notificacion)
    VALUES
        (p_id_prediccion, v_id_activo, p_id_finca, v_id_patologia,
         v_prob, v_criticidad, 'PENDIENTE', p_id_notificacion);

    -- Auditoría
    INSERT INTO modulo4.auditorias_predicciones
        (id_prediccion, accion, datos_nuevos)
    VALUES
        (p_id_prediccion,
         'ALERTA_ACTIVADA',
         jsonb_build_object(
             'nivel_criticidad', v_criticidad,
             'probabilidad_pct', v_prob
         ));
END;
$procedure$;


-- CALL
CALL modulo4.sp_evaluar_umbral_y_generar_alerta(
    p_id_prediccion   := 1,
    p_id_finca        := 1,
    p_id_notificacion := 5
);


----

CREATE OR REPLACE PROCEDURE modulo4.sp_actualizar_estado_alerta(
    IN p_id_alerta_patologica  INTEGER,
    IN p_nuevo_estado          modulo4.enum_alerta_patologia_estado,
    IN p_id_usuario            INTEGER,
    IN p_diagnostico_confirmado TEXT    DEFAULT NULL,
    IN p_es_verdadero           BOOLEAN DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_estado_actual modulo4.enum_alerta_patologia_estado;
BEGIN
    SELECT estado_alerta
    INTO   v_estado_actual
    FROM   modulo4.alertas_patologicas
    WHERE  id_alerta_patologica = p_id_alerta_patologica;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alerta % no encontrada', p_id_alerta_patologica;
    END IF;

    -- No permitir retroceder a PENDIENTE
    IF p_nuevo_estado = 'PENDIENTE' THEN
        RAISE EXCEPTION
            'No se permite regresar al estado PENDIENTE. Estado actual: %',
            v_estado_actual;
    END IF;

    -- Campos mutables según trigger de inmutabilidad
    UPDATE modulo4.alertas_patologicas
    SET
        estado_alerta          = p_nuevo_estado,
        fecha_notificacion     = now(),
        id_usuario             = p_id_usuario,
        diagnostico_confirmado = COALESCE(p_diagnostico_confirmado, diagnostico_confirmado),
        es_verdadero           = COALESCE(p_es_verdadero, es_verdadero)
    WHERE id_alerta_patologica = p_id_alerta_patologica;
END;
$procedure$;


-- CALL
CALL modulo4.sp_actualizar_estado_alerta(
    p_id_alerta_patologica   := 1,
    p_nuevo_estado           := 'ATENDIDA',
    p_id_usuario             := 1,
    p_diagnostico_confirmado := 'Mastitis confirmada por laboratorio',
    p_es_verdadero           := true
);



-----

CREATE OR REPLACE PROCEDURE modulo4.sp_registrar_version_modelo(
    IN  p_nombre_version          VARCHAR(40),
    IN  p_algoritmo               modulo4.enum_version_modelo_algoritmo,
    IN  p_descripcion             TEXT,
    IN  p_fecha_entrenamiento     TIMESTAMPTZ,
    IN  p_accuracy                NUMERIC(5,4),
    IN  p_auc_roc                 NUMERIC(5,4),
    IN  p_f1_score                NUMERIC(5,4),
    IN  p_precision_modelo        NUMERIC(5,4),
    IN  p_recall_modelo           NUMERIC(5,4),
    IN  p_umbral_clasificacion    NUMERIC(5,4),
    IN  p_ruta_artefacto          TEXT,
    IN  p_hash_artecfacto         VARCHAR(64),
    IN  p_id_usuario              INTEGER,
    -- Parámetros dataset
    IN  p_nombre_dataset          VARCHAR(120),
    IN  p_fecha_inicio_datos      DATE,
    IN  p_fecha_fin_datos         DATE,
    IN  p_total_registros         INTEGER,
    IN  p_registros_positivos     INTEGER,
    IN  p_registros_negativos     INTEGER,
    IN  p_enfermedades_incluidas  JSON,
    IN  p_descripcion_dataset     TEXT,
    IN  p_porcentaje_train        NUMERIC(20),
    IN  p_porcentaje_test         NUMERIC(20),
    IN  p_tiene_variables_amb     BOOLEAN,
    IN  p_semestre_huila          modulo4.enum_datset_semestre,
    OUT p_id_version_modelo       INTEGER,
    OUT p_id_dataset              INTEGER
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_validacion modulo4.resultado_validacion;
BEGIN
    -- Validar métricas mínimas
    v_validacion := modulo4.fn_validar_metricas_modelo(p_f1_score, p_recall_modelo);

    IF v_validacion.estado = 'RECHAZADO' THEN
        RAISE EXCEPTION
            'VERSION_RECHAZADA: Métricas insuficientes. Campo fallido: %. '
            'f1_score=%, recall=%',
            v_validacion.campo_fallido,
            p_f1_score,
            p_recall_modelo
        USING ERRCODE = 'P0420';
    END IF;

    -- Insertar versión del modelo
    INSERT INTO modulo4.versiones_modelos
        (nombre_version, algoritmo, descripcion, fecha_entrenamiento,
         accuracy, auc_roc, f1_score, precision_modelo, recall_modelo,
         umbral_clasificacion, ruta_artefacto, hash_artecfacto,
         esta_produccion, id_usuario)
    VALUES
        (p_nombre_version, p_algoritmo, p_descripcion, p_fecha_entrenamiento,
         p_accuracy, p_auc_roc, p_f1_score, p_precision_modelo, p_recall_modelo,
         p_umbral_clasificacion, p_ruta_artefacto, p_hash_artecfacto,
         false, p_id_usuario)
    RETURNING id_version_modelo INTO p_id_version_modelo;

    -- Insertar dataset asociado
    INSERT INTO modulo4.datasets
        (id_version_modelo, nombre, fecha_inicio_datos, fecha_fin_datos,
         total_resgistros, registros_positivos, registros_negativos,
         enfermedades_incluidas, descripcion, porcentaje_train, porcentaje_test,
         tiene_variables_ambientales, semestre_huila)
    VALUES
        (p_id_version_modelo, p_nombre_dataset, p_fecha_inicio_datos, p_fecha_fin_datos,
         p_total_registros, p_registros_positivos, p_registros_negativos,
         p_enfermedades_incluidas, p_descripcion_dataset, p_porcentaje_train, p_porcentaje_test,
         p_tiene_variables_amb, p_semestre_huila)
    RETURNING id_dataset INTO p_id_dataset;
END;
$procedure$;


-- CALL
DO $$
DECLARE
    v_id_version INTEGER;
    v_id_dataset INTEGER;
BEGIN
    CALL modulo4.sp_registrar_version_modelo(
        p_nombre_version         := 'modelo_rf_v2_2025_s1',
        p_algoritmo              := 'RANDOM_FOREST',
        p_descripcion            := 'Modelo semestral S1 2025 para bovinos Huila',
        p_fecha_entrenamiento    := '2025-06-01 08:00:00+00',
        p_accuracy               := 0.8900,
        p_auc_roc                := 0.9100,
        p_f1_score               := 0.8500,
        p_precision_modelo       := 0.8700,
        p_recall_modelo          := 0.8600,
        p_umbral_clasificacion   := 0.7000,
        p_ruta_artefacto         := '/models/m04/rf_v2_2025_s1.pkl',
        p_hash_artecfacto        := 'a3f1c2e4b5d6789012345678901234567890abcdef1234567890abcdef123456',
        p_id_usuario             := 3,
        p_nombre_dataset         := 'dataset_bovinos_huila_s1_2025',
        p_fecha_inicio_datos     := '2024-12-01',
        p_fecha_fin_datos        := '2025-05-31',
        p_total_registros        := 1200,
        p_registros_positivos    := 480,
        p_registros_negativos    := 720,
        p_enfermedades_incluidas := '["mastitis","pododermatitis","fiebre_leche"]',
        p_descripcion_dataset    := 'Datos clínicos bovinos S1 2025 región Huila',
        p_porcentaje_train       := 80,
        p_porcentaje_test        := 20,
        p_tiene_variables_amb    := true,
        p_semestre_huila         := 'S1',
        p_id_version_modelo      := v_id_version,
        p_id_dataset             := v_id_dataset
    );
    RAISE NOTICE 'Versión registrada: %, Dataset: %', v_id_version, v_id_dataset;
END;
$$;


----- 

CREATE OR REPLACE PROCEDURE modulo4.sp_aprobar_y_activar_version_modelo(
    IN p_id_version_modelo  INTEGER,
    IN p_id_usuario         INTEGER
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_en_produccion  BOOLEAN;
    v_f1_score       NUMERIC(5,4);
    v_recall_modelo  NUMERIC(5,4);
    v_validacion     modulo4.resultado_validacion;
BEGIN
    SELECT esta_produccion, f1_score, recall_modelo
    INTO   v_en_produccion, v_f1_score, v_recall_modelo
    FROM   modulo4.versiones_modelos
    WHERE  id_version_modelo = p_id_version_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Versión de modelo % no encontrada',
            p_id_version_modelo;
    END IF;

    -- Validar que no esté ya en producción
    IF v_en_produccion = true THEN
        RAISE EXCEPTION
            'VERSION_YA_ACTIVA: El modelo % ya está en producción.',
            p_id_version_modelo
        USING ERRCODE = 'P0421';
    END IF;

    -- Validar que las métricas hayan sido evaluadas
    IF v_f1_score IS NULL OR v_recall_modelo IS NULL THEN
        RAISE EXCEPTION
            'METRICAS_PENDIENTES: El modelo % no tiene métricas evaluadas. '
            'Debe pasar primero por sp_registrar_version_modelo.',
            p_id_version_modelo
        USING ERRCODE = 'P0422';
    END IF;

    -- Revalidar métricas mínimas antes de activar
    v_validacion := modulo4.fn_validar_metricas_modelo(v_f1_score, v_recall_modelo);

    IF v_validacion.estado = 'RECHAZADO' THEN
        RAISE EXCEPTION
            'VERSION_RECHAZADA: El modelo % no cumple métricas mínimas para producción. '
            'Campo fallido: %.',
            p_id_version_modelo,
            v_validacion.campo_fallido
        USING ERRCODE = 'P0420';
    END IF;

    -- Activar modelo — el trigger trg_fn_versiones_modelos_unicidad_produccion
    -- desactiva automáticamente el modelo anterior del mismo algoritmo
    UPDATE modulo4.versiones_modelos
    SET
        esta_produccion  = true,
        fecha_despliegue = now()
    WHERE id_version_modelo = p_id_version_modelo;
END;
$procedure$;

-- CALL
CALL modulo4.sp_aprobar_y_activar_version_modelo(
    p_id_version_modelo := 28,
    p_id_usuario        := 1
);



------

CREATE OR REPLACE PROCEDURE modulo4.sp_registrar_retroalimentacion_clinica(
    IN p_id_prediccion    INTEGER,
    IN p_id_usuario       INTEGER,
    IN p_evaluacion       VARCHAR(20),   -- CORRECTO | PARCIAL | INCORRECTO | SIN_EVENTO
    IN p_fuente           VARCHAR(40),   -- LABORATORIO | HISTORIAL_CLINICO | OBSERVACION_DIRECTA | OTRO
    IN p_diagnostico_real TEXT    DEFAULT NULL,
    IN p_notas            TEXT    DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_dentro_ventana  BOOLEAN;
    v_hay_conflicto   BOOLEAN;
    v_ya_existe       BOOLEAN;
BEGIN
    -- Validar que la predicción exista
    IF NOT EXISTS (
        SELECT 1 FROM modulo4.predicciones
        WHERE id_prediccion = p_id_prediccion
    ) THEN
        RAISE EXCEPTION
            'PREDICCION_NO_ENCONTRADA: La predicción % no existe.',
            p_id_prediccion
        USING ERRCODE = 'P0430';
    END IF;

    -- Validar dominio de evaluacion
    IF p_evaluacion NOT IN ('CORRECTO', 'PARCIAL', 'INCORRECTO', 'SIN_EVENTO') THEN
        RAISE EXCEPTION
            'EVALUACION_INVALIDA: El valor "%" no pertenece al dominio permitido. '
            'Use: CORRECTO, PARCIAL, INCORRECTO, SIN_EVENTO.',
            p_evaluacion
        USING ERRCODE = 'P0431';
    END IF;

    -- Validar que no exista retroalimentación previa del mismo usuario
    SELECT EXISTS (
        SELECT 1 FROM modulo4.auditorias_predicciones
        WHERE id_prediccion = p_id_prediccion
          AND id_usuario    = p_id_usuario
          AND accion        = 'VALIDACION_VET'
    ) INTO v_ya_existe;

    IF v_ya_existe THEN
        RAISE EXCEPTION
            'RETROALIMENTACION_DUPLICADA: El usuario % ya registró retroalimentación '
            'para la predicción %.',
            p_id_usuario,
            p_id_prediccion
        USING ERRCODE = 'P0432';
    END IF;

    -- Validar ventana temporal (90 días)
    v_dentro_ventana := modulo4.fn_verificar_ventana_retroalimentacion(p_id_prediccion);

    IF NOT v_dentro_ventana THEN
        RAISE EXCEPTION
            'VENTANA_EXPIRADA: La predicción % supera los 90 días permitidos '
            'para registrar retroalimentación.',
            p_id_prediccion
        USING ERRCODE = 'P0433';
    END IF;

    -- Insertar retroalimentación
    INSERT INTO modulo4.auditorias_predicciones
        (id_prediccion, accion, id_usuario, datos_nuevos)
    VALUES
        (p_id_prediccion,
         'VALIDACION_VET',
         p_id_usuario,
         jsonb_build_object(
             'evaluacion',       p_evaluacion,
             'fuente_diagnostico', p_fuente,
             'diagnostico_real', p_diagnostico_real,
             'notas',            p_notas
         ));

    -- Detectar conflicto con retroalimentaciones previas
    v_hay_conflicto := modulo4.fn_detectar_conflicto_retroalimentacion(p_id_prediccion);

    IF v_hay_conflicto THEN
        INSERT INTO modulo4.auditorias_predicciones
            (id_prediccion, accion, id_usuario, datos_nuevos)
        VALUES
            (p_id_prediccion,
             'VALIDACION_VET',
             p_id_usuario,
             jsonb_build_object(
                 'evento',       'CONFLICTO_RETROALIMENTACION',
                 'id_prediccion', p_id_prediccion
             ));
    END IF;
END;
$procedure$;

-- CALL
CALL modulo4.sp_registrar_retroalimentacion_clinica(
    p_id_prediccion   := 1,
    p_id_usuario      := 1,
    p_evaluacion      := 'CORRECTO',
    p_fuente          := 'LABORATORIO',
    p_diagnostico_real := 'Mastitis clínica grado II confirmada',
    p_notas            := 'Cultivo positivo a Staphylococcus aureus'
);


-----

CREATE OR REPLACE PROCEDURE modulo4.sp_iniciar_ciclo_reentrenamiento(
    IN  p_trigger_reentrenamiento  VARCHAR(20),
    IN  p_semestre                 VARCHAR(10),
    IN  p_fecha_inicio_planificada DATE,
    IN  p_fecha_final_planificada  DATE,
    IN  p_id_modelo_anterior       INTEGER,
    IN  p_id_usuario               INTEGER,
    IN  p_notas                    TEXT,
    OUT p_id_ciclo_entrenamiento   INTEGER
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_tipo_ciclo   modulo4.enum_ciclo_entrenamiento_tipo;
    v_count        INTEGER;
    v_drift_score  NUMERIC(5,4);
BEGIN
    v_tipo_ciclo := CASE p_trigger_reentrenamiento
        WHEN 'PROGRAMADO'  THEN 'SEMESTRAL'::modulo4.enum_ciclo_entrenamiento_tipo
        WHEN 'DEGRADACION' THEN 'DRIFT_DETECTADO'::modulo4.enum_ciclo_entrenamiento_tipo
        WHEN 'MANUAL'      THEN 'MANUAL'::modulo4.enum_ciclo_entrenamiento_tipo
        ELSE NULL
    END;

    IF v_tipo_ciclo IS NULL THEN
        RAISE EXCEPTION
            'TRIGGER_INVALIDO: "%" no es un trigger válido. '
            'Use: PROGRAMADO, MANUAL, DEGRADACION.',
            p_trigger_reentrenamiento
        USING ERRCODE = 'P0440';
    END IF;

    v_count := modulo4.fn_contar_registros_etiquetados_disponibles(
        p_fecha_inicio_planificada,
        p_fecha_final_planificada
    );

    IF v_count < 500 THEN
        RAISE EXCEPTION
            'DATASET_INSUFICIENTE: Se encontraron % registros etiquetados. '
            'Se requieren mínimo 500. Rango: % → %.',
            v_count,
            p_fecha_inicio_planificada,
            p_fecha_final_planificada
        USING ERRCODE = 'P0441';
    END IF;

    IF v_tipo_ciclo = 'DRIFT_DETECTADO' THEN
        v_drift_score := modulo4.fn_calcular_drift_score(
            p_id_modelo_anterior,
            p_semestre
        );
    END IF;

    INSERT INTO modulo4.ciclos_entrenamientos
        (id_modelo_version_anterior, semestre, estado_ciclo,
         fecha_inicio_planificada, fecha_final_planificada,
         inicio_planificada, tipo, drift_score,
         id_usuario_aprobado, notas)
    VALUES
        (p_id_modelo_anterior, p_semestre, 'PLANIFICADO',
         p_fecha_inicio_planificada, p_fecha_final_planificada,
         now(), v_tipo_ciclo, v_drift_score,
         p_id_usuario, p_notas)
    RETURNING id_ciclo_entrenamiento INTO p_id_ciclo_entrenamiento;

    UPDATE modulo4.ciclos_entrenamientos
    SET
        estado_ciclo = 'EN_PROCESO',
        inicio_real  = now()
    WHERE id_ciclo_entrenamiento = p_id_ciclo_entrenamiento;
END;
$procedure$;


-- CALL
DO $$
DECLARE
    v_id_ciclo INTEGER;
BEGIN
    CALL modulo4.sp_iniciar_ciclo_reentrenamiento(
        p_trigger_reentrenamiento  := 'PROGRAMADO',
        p_semestre                 := '2026-S4',
        p_fecha_inicio_planificada := '2025-06-01',
        p_fecha_final_planificada  := '2025-06-30',
        p_id_modelo_anterior       :=31,
        p_id_usuario               := 3,
        p_notas                    := 'Ciclo semestral automático S1 2025',
        p_id_ciclo_entrenamiento   := v_id_ciclo
    );
    RAISE NOTICE 'Ciclo iniciado: %', v_id_ciclo;
END;
$$;


-- 1. Insertar observaciones clínicas de prueba
INSERT INTO modulo4.observaciones_clinicas
    (id_activo_biologico, id_usuario, fecha, temperatura_rectal,
     frecuencia_cardiaca, frecuencia_respiratoria, condicion_corporal, fuente_datos)
SELECT
    1,                                          -- id_activo_biologico (debe existir en modulo2)
    1,                                          -- id_usuario (debe existir en modulo1)
    '2025-06-01'::date + (n || ' hours')::interval,
    38.5 + (random() * 2)::numeric(4,1),
    65 + (random() * 20)::int,
    25 + (random() * 10)::int,
    3.0 + (random())::numeric(3,1),
    'manual'
FROM generate_series(1, 600) AS n;

-- 2. Insertar detalles de signos para cada observación
INSERT INTO modulo4.detalles_signos
    (id_observaciones, id_signo_clinico, es_presente, intensidad)
SELECT
    oc.id_observacion_clinica,
    1,   -- id_signo_clinico (debe existir en signos_clinicos)
    true,
    3
FROM modulo4.observaciones_clinicas oc
WHERE oc.fecha BETWEEN '2025-06-01' AND '2025-06-30'
  AND NOT EXISTS (
      SELECT 1 FROM modulo4.detalles_signos ds
      WHERE ds.id_observaciones = oc.id_observacion_clinica
  );



----

CREATE OR REPLACE PROCEDURE modulo4.sp_evaluar_degradacion_modelo(
    IN p_id_version_modelo  INTEGER,
    IN p_semestre           VARCHAR(10),
    IN p_id_usuario         INTEGER
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_f1_score          NUMERIC(5,4);
    v_algoritmo         modulo4.enum_version_modelo_algoritmo;
    v_en_produccion     BOOLEAN;
    v_drift_score       NUMERIC(5,4);
    v_count_verificados INTEGER;
    v_fecha_inicio      DATE := CURRENT_DATE - INTERVAL '30 days';
    v_fecha_fin         DATE := CURRENT_DATE;
    v_id_ciclo          INTEGER;
BEGIN
    -- Obtener datos del modelo
    SELECT esta_produccion, f1_score, algoritmo
    INTO   v_en_produccion, v_f1_score, v_algoritmo
    FROM   modulo4.versiones_modelos
    WHERE  id_version_modelo = p_id_version_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'MODELO_NO_ENCONTRADO: La versión % no existe.',
            p_id_version_modelo
        USING ERRCODE = 'P0450';
    END IF;

    IF v_en_produccion = false THEN
        RAISE EXCEPTION
            'MODELO_NO_ACTIVO: La versión % no está en producción.',
            p_id_version_modelo
        USING ERRCODE = 'P0451';
    END IF;

    -- Calcular drift score últimos 30 días
    v_drift_score := modulo4.fn_calcular_drift_score(
        p_id_version_modelo,
        p_semestre
    );

    -- Contar registros verificados últimos 30 días
    v_count_verificados := modulo4.fn_contar_registros_etiquetados_disponibles(
        v_fecha_inicio,
        v_fecha_fin
    );

    -- Evaluar degradación
    IF v_f1_score < 0.80 THEN

        IF v_count_verificados < 100 THEN
            -- Insuficientes registros verificados — posponer
            RAISE NOTICE
                'DEGRADACION_DETECTADA_POSPUESTA: Modelo % con f1_score=%. '
                'Solo % registros verificados disponibles (mínimo 100). '
                'Notifique al administrador.',
                p_id_version_modelo,
                v_f1_score,
                v_count_verificados;
            RETURN;
        END IF;

        -- Suficientes registros — iniciar reentrenamiento
        CALL modulo4.sp_iniciar_ciclo_reentrenamiento(
            p_trigger_reentrenamiento  := 'DEGRADACION',
            p_semestre                 := p_semestre,
            p_fecha_inicio_planificada := v_fecha_inicio,
            p_fecha_final_planificada  := v_fecha_fin,
            p_id_modelo_anterior       := p_id_version_modelo,
            p_id_usuario               := p_id_usuario,
            p_notas                    :=
                'Reentrenamiento por degradación. f1_score=' ||
                v_f1_score::TEXT ||
                ' drift_score=' || v_drift_score::TEXT,
            p_id_ciclo_entrenamiento   := v_id_ciclo
        );

        RAISE NOTICE
            'DEGRADACION_DETECTADA: Ciclo de reentrenamiento % iniciado '
            'para modelo % por f1_score=% < 0.80.',
            v_id_ciclo,
            p_id_version_modelo,
            v_f1_score;
    ELSE
        RAISE NOTICE
            'MODELO_ESTABLE: Modelo % con f1_score=% >= 0.80. '
            'No se requiere reentrenamiento.',
            p_id_version_modelo,
            v_f1_score;
    END IF;
END;
$procedure$;


-- CALL
CALL modulo4.sp_evaluar_degradacion_modelo(
    p_id_version_modelo := 29,
    p_semestre          := '2026-S1',
    p_id_usuario        := 3
);

--

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
CALL modulo4.sp_distribuir_modelo_ota(
    p_id_version_modelo := 29,
    p_hash_calculado    := 'a3f1c2e4b5d6789012345678901234567890abcdef1234567890abcdef123456',
    p_dispositivos      := ARRAY[101, 102, 103]
);
