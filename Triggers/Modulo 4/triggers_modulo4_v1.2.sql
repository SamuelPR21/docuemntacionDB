-- =============================================================================
-- MÓDULO 4 — MODELO DE PREDICCIÓN
-- Archivo: triggers_modulo4_v1_2.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo4
-- Motor: PostgreSQL
-- Versión: 1.2
-- =============================================================================

-- ÍNDICE
-- TGR-M04-01  Inmutabilidad estructural de versiones de modelos (campos fijos, permite estado y notas)
-- TGR-M04-02  Inmutabilidad de predicciones / resultados de inferencia
-- TGR-M04-03  Inmutabilidad estructural de alertas patológicas
-- TGR-M04-04  Inmutabilidad de registros de auditoría de predicciones
-- TGR-M04-05  Unicidad de modelo ACTIVO por tipo_modelo con deprecación automática
-- TGR-M04-06  Validación de hashes SHA-256 del artefacto de modelo (hash_artecfacto y hash_artefacto_sha256)
-- TGR-M04-07  Consistencia entre probabilidad, umbral y flag supera_umbral
-- TGR-M04-08  Validación de fecha de entrenamiento no futura
-- TGR-M04-09  Inmutabilidad de ciclos de entrenamiento completados o cancelados
-- TGR-M04-10  Bloqueo de eliminación física de ciclos de entrenamiento
-- TGR-M04-11  Inmutabilidad de métricas de drift
-- TGR-M04-12  Inmutabilidad de datasets registrados
-- TGR-M04-13  Validación de modelo con estado ACTIVO al generar predicción
-- TGR-M04-14  Validación de rango normalizado [0.0 – 1.0] en métricas del modelo (ampliado)
-- TGR-M04-15  Coherencia de fechas en ciclos de entrenamiento
-- TGR-M04-16  Inmutabilidad de datos clínicos medidos en observaciones
-- TGR-M04-17  Inmutabilidad de resultados de inferencia en tiempo real
-- TGR-M04-18  Inmutabilidad de retroalimentaciones clínicas
-- TGR-M04-19  Obligatoriedad condicional de diagnóstico real en retroalimentación
-- TGR-M04-20  Coherencia temporal entre retroalimentación y resultado de inferencia
-- TGR-M04-21  Inmutabilidad de eventos de auditoría del módulo M04
-- TGR-M04-22  Exclusividad de fuente en eventos de auditoría (id_usuario vs id_sistema)
-- TGR-M04-23  Inmutabilidad del historial del catálogo de patologías
-- TGR-M04-24  Inmutabilidad del historial de estados de modelos
-- TGR-M04-25  Inmutabilidad del historial de eventos diagnósticos
-- TGR-M04-26  Validación de transiciones de estado en versiones de modelos (máquina de estados)
-- TGR-M04-27  Notas de validación obligatorias antes de activar un modelo
-- TGR-M04-28  Coherencia de umbrales y ventana temporal en configuración del motor
-- TGR-M04-29  Validación de pesos del modelo de contagio (suma = 1.0)
-- TGR-M04-30  Inmutabilidad de despliegues OTA completados

-- =============================================================================
-- TGR-M04-01 — Inmutabilidad estructural de versiones de modelos
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE UPDATE OR DELETE
-- Nota:   Permite UPDATE exclusivamente sobre: estado_version, notas_validacion,
--         esta_produccion, fecha_despliegue, fecha_retiro.
--         TGR-M04-26 y TGR-M04-27 complementan este trigger validando
--         la máquina de estados y la obligatoriedad de notas antes de activar.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_MODEL_VERSION: Las versiones de modelos son inmutables (append-only). '
            'No se permite eliminar id_version_modelo=%. '
            'Requerimiento RF-69, Restricción 7 — CA-8.'
            , OLD.id_version_modelo
        USING ERRCODE = 'P0401';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.nombre_version             IS DISTINCT FROM NEW.nombre_version             OR
           OLD.algoritmo                  IS DISTINCT FROM NEW.algoritmo                  OR
           OLD.tipo_modelo                IS DISTINCT FROM NEW.tipo_modelo                OR
           OLD.hash_artecfacto            IS DISTINCT FROM NEW.hash_artecfacto            OR
           OLD.hash_artefacto_sha256      IS DISTINCT FROM NEW.hash_artefacto_sha256      OR
           OLD.dataset_entrenamiento_hash IS DISTINCT FROM NEW.dataset_entrenamiento_hash OR
           OLD.fecha_entrenamiento        IS DISTINCT FROM NEW.fecha_entrenamiento        OR
           OLD.f1_score                   IS DISTINCT FROM NEW.f1_score                   OR
           OLD.recall_modelo              IS DISTINCT FROM NEW.recall_modelo              OR
           OLD.recall_clase_riesgo_alto   IS DISTINCT FROM NEW.recall_clase_riesgo_alto   OR
           OLD.accuracy                   IS DISTINCT FROM NEW.accuracy                   OR
           OLD.precision_modelo           IS DISTINCT FROM NEW.precision_modelo           OR
           OLD.auc_roc                    IS DISTINCT FROM NEW.auc_roc                    OR
           OLD.roc_auc_score              IS DISTINCT FROM NEW.roc_auc_score              OR
           OLD.id_proceso_rf71            IS DISTINCT FROM NEW.id_proceso_rf71            OR
           OLD.formato_artefacto          IS DISTINCT FROM NEW.formato_artefacto          OR
           OLD.tamanio_artefacto_bytes    IS DISTINCT FROM NEW.tamanio_artefacto_bytes    OR
           OLD.compatibilidad_variables   IS DISTINCT FROM NEW.compatibilidad_variables   OR
           OLD.version_referencia         IS DISTINCT FROM NEW.version_referencia         OR
           OLD.matriz_confusion           IS DISTINCT FROM NEW.matriz_confusion           OR
           OLD.recall_por_clase           IS DISTINCT FROM NEW.recall_por_clase
        THEN
            RAISE EXCEPTION
                'IMMUTABLE_MODEL_FIELDS: Los campos estructurales de una versión de modelo son inmutables. '
                'id_version_modelo=%. '
                'Solo se permite modificar: estado_version, notas_validacion, esta_produccion, '
                'fecha_despliegue, fecha_retiro. '
                'Requerimiento RF-69, Restricción 7 — CA-8.'
                , OLD.id_version_modelo
            USING ERRCODE = 'P0401';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_inmutabilidad();

-- =============================================================================
-- TGR-M04-02 — Inmutabilidad de predicciones / resultados de inferencia
-- Tabla:  modulo4.predicciones
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_predicciones_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_PREDICTION: Los resultados de inferencia son inmutables (append-only). '
            'No se permite eliminar id_prediccion=%. '
            'Requerimiento RF-66, Restricción 5 — RF-67.'
            , OLD.id_prediccion
        USING ERRCODE = 'P0402';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_PREDICTION: Los resultados de inferencia son inmutables (append-only). '
            'No se permite modificar id_prediccion=%. '
            'Requerimiento RF-66, Restricción 5 — RF-67.'
            , OLD.id_prediccion
        USING ERRCODE = 'P0402';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_predicciones_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.predicciones
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_predicciones_inmutabilidad();

-- =============================================================================
-- TGR-M04-03 — Inmutabilidad estructural de alertas patológicas
-- Tabla:  modulo4.alertas_patologicas
-- Evento: BEFORE UPDATE OR DELETE
-- Nota:   Permite UPDATE sobre campos operativos: estado_alerta,
--         fecha_notificacion, diagnostico_confirmado, es_verdadero, id_usuario.
--         Bloquea modificación de campos estructurales del resultado original.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_alertas_patologicas_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_ALERT: No se permite eliminar alertas patológicas. '
            'id_alerta_patologica=%. '
            'Requerimiento RF-67 — RF-73.'
            , OLD.id_alerta_patologica
        USING ERRCODE = 'P0403';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.id_prediccion       IS DISTINCT FROM NEW.id_prediccion       OR
           OLD.id_activo_biologico IS DISTINCT FROM NEW.id_activo_biologico OR
           OLD.id_finca            IS DISTINCT FROM NEW.id_finca            OR
           OLD.id_patologia        IS DISTINCT FROM NEW.id_patologia        OR
           OLD.probabilidad_pct    IS DISTINCT FROM NEW.probabilidad_pct    OR
           OLD.nivel_criticidad    IS DISTINCT FROM NEW.nivel_criticidad    OR
           OLD.fecha_generacion    IS DISTINCT FROM NEW.fecha_generacion
        THEN
            RAISE EXCEPTION
                'IMMUTABLE_ALERT_FIELDS: Los campos estructurales de la alerta son inmutables. '
                'id_alerta_patologica=%. '
                'Solo se permite actualizar: estado_alerta, fecha_notificacion, '
                'diagnostico_confirmado, es_verdadero, id_usuario. '
                'Requerimiento RF-67 — RF-73.'
                , OLD.id_alerta_patologica
            USING ERRCODE = 'P0403';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_alertas_patologicas_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.alertas_patologicas
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_alertas_patologicas_inmutabilidad();

-- =============================================================================
-- TGR-M04-04 — Inmutabilidad de registros de auditoría de predicciones
-- Tabla:  modulo4.auditorias_predicciones
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_auditorias_predicciones_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_AUDIT: Los registros de auditoría son inmutables (append-only). '
            'No se permite eliminar id_auditoria_prediccion=%. '
            'Requerimiento RF-73, Restricción Inmutabilidad — CA-3.'
            , OLD.id_auditoria_prediccion
        USING ERRCODE = 'P0404';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_AUDIT: Los registros de auditoría son inmutables (append-only). '
            'No se permite modificar id_auditoria_prediccion=%. '
            'Requerimiento RF-73, Restricción Inmutabilidad — CA-3.'
            , OLD.id_auditoria_prediccion
        USING ERRCODE = 'P0404';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_auditorias_predicciones_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.auditorias_predicciones
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_auditorias_predicciones_inmutabilidad();

-- =============================================================================
-- TGR-M04-05 — Unicidad de modelo ACTIVO por tipo_modelo con deprecación automática
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE INSERT OR UPDATE OF estado_version
-- Nota:   Al transicionar una versión a ACTIVO, depreca automáticamente la
--         versión previamente activa del mismo tipo_modelo. Garantiza que en
--         ningún momento coexistan dos versiones ACTIVO del mismo tipo.
--         Reemplaza la lógica anterior basada en esta_produccion y algoritmo.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_unicidad_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.estado_version = 'ACTIVO' THEN
        UPDATE modulo4.versiones_modelos
        SET    estado_version = 'DEPRECADO'
        WHERE  tipo_modelo       = NEW.tipo_modelo
          AND  estado_version    = 'ACTIVO'
          AND  id_version_modelo <> NEW.id_version_modelo;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_unicidad_activo
BEFORE INSERT OR UPDATE OF estado_version
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_unicidad_activo();

-- =============================================================================
-- TGR-M04-06 — Validación de hashes SHA-256 del artefacto de modelo
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE INSERT
-- Nota:   Valida ambos campos de hash presentes en el DDL:
--         hash_artecfacto (campo original) y hash_artefacto_sha256 (campo extendido RF-69).
--         Ambos deben ser SHA-256 válidos: no nulos, exactamente 64 caracteres hexadecimales.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_campos  TEXT[]    := ARRAY['hash_artecfacto', 'hash_artefacto_sha256'];
    v_valores TEXT[]    := ARRAY[NEW.hash_artecfacto, NEW.hash_artefacto_sha256];
    i         INT;
BEGIN
    FOR i IN 1..array_length(v_campos, 1) LOOP

        IF v_valores[i] IS NULL OR trim(v_valores[i]) = '' THEN
            RAISE EXCEPTION
                'MISSING_HASH: El campo % es obligatorio y no puede ser nulo o vacío. '
                'Requerimiento RF-69, Restricción 8 — RF-71, Restricción 14.'
                , v_campos[i]
            USING ERRCODE = 'P0406';
        END IF;

        IF length(trim(v_valores[i])) <> 64 THEN
            RAISE EXCEPTION
                'INVALID_HASH_LENGTH: El campo % debe tener exactamente 64 caracteres (SHA-256). '
                'Longitud recibida: %. '
                'Requerimiento RF-69, Restricción 8.'
                , v_campos[i]
                , length(trim(v_valores[i]))
            USING ERRCODE = 'P0406';
        END IF;

        IF trim(v_valores[i]) !~ '^[a-fA-F0-9]{64}$' THEN
            RAISE EXCEPTION
                'INVALID_HASH_FORMAT: El campo % contiene caracteres no hexadecimales. '
                'Solo se aceptan caracteres [0-9, a-f, A-F]. '
                'Requerimiento RF-69, Restricción 8.'
                , v_campos[i]
            USING ERRCODE = 'P0406';
        END IF;

    END LOOP;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_hash_obligatorio
BEFORE INSERT
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_hash_obligatorio();

-- =============================================================================
-- TGR-M04-07 — Consistencia entre probabilidad, umbral y flag supera_umbral
-- Tabla:  modulo4.predicciones
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_predicciones_umbral_consistencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.umbral_usado < 50.00 OR NEW.umbral_usado > 95.00 THEN
        RAISE EXCEPTION
            'INVALID_THRESHOLD: El umbral_usado=% está fuera del rango permitido [50.00 - 95.00]. '
            'Requerimiento RF-65, Restricción 1.'
            , NEW.umbral_usado
        USING ERRCODE = 'P0407';
    END IF;

    -- Corrección automática del flag para garantizar consistencia
    IF NEW.probabilidad_pct >= NEW.umbral_usado THEN
        NEW.supera_umbral := true;
    ELSE
        NEW.supera_umbral := false;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_predicciones_umbral_consistencia
BEFORE INSERT
ON modulo4.predicciones
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_predicciones_umbral_consistencia();

-- =============================================================================
-- TGR-M04-08 — Validación de fecha de entrenamiento no futura
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_fecha_entrenamiento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha_entrenamiento IS NOT NULL AND NEW.fecha_entrenamiento > now() THEN
        RAISE EXCEPTION
            'INVALID_DATE: La fecha_entrenamiento no puede ser una fecha futura. '
            'Valor recibido: %. '
            'Requerimiento RF-69, campo fecha_entrenamiento.'
            , NEW.fecha_entrenamiento
        USING ERRCODE = 'P0408';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_fecha_entrenamiento
BEFORE INSERT
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_fecha_entrenamiento();

-- =============================================================================
-- TGR-M04-09 — Inmutabilidad de ciclos de entrenamiento completados o cancelados
-- Tabla:  modulo4.ciclos_entrenamientos
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_ciclos_entrenamientos_inmutabilidad_completados()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.estado_ciclo IN ('COMPLETADO', 'CANCELADO') THEN
        RAISE EXCEPTION
            'IMMUTABLE_CYCLE: El ciclo de entrenamiento id=% en estado "%" no puede modificarse. '
            'Solo se permite modificar ciclos en estado PLANIFICADO o EN_EJECUCION. '
            'Requerimiento RF-71 RNF-11 — RF-73.'
            , OLD.id_ciclo_entrenamiento
            , OLD.estado_ciclo
        USING ERRCODE = 'P0409';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_ciclos_entrenamientos_inmutabilidad_completados
BEFORE UPDATE
ON modulo4.ciclos_entrenamientos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_ciclos_entrenamientos_inmutabilidad_completados();

-- =============================================================================
-- TGR-M04-10 — Bloqueo de eliminación física de ciclos de entrenamiento
-- Tabla:  modulo4.ciclos_entrenamientos
-- Evento: BEFORE DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_ciclos_entrenamientos_no_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'NO_PHYSICAL_DELETE: No se permite eliminar ciclos de entrenamiento. '
        'El historial de reentrenamiento es append-only. '
        'id_ciclo_entrenamiento=%. '
        'Requerimiento RF-71 RNF-11.'
        , OLD.id_ciclo_entrenamiento
    USING ERRCODE = 'P0410';
    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_ciclos_entrenamientos_no_delete
BEFORE DELETE
ON modulo4.ciclos_entrenamientos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_ciclos_entrenamientos_no_delete();

-- =============================================================================
-- TGR-M04-11 — Inmutabilidad de métricas de drift
-- Tabla:  modulo4.metricas_drift
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_metricas_drift_no_delete_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_DRIFT_METRIC: Las métricas de drift son inmutables. '
            'No se permite eliminar id_metrica_drift=%. '
            'Requerimiento RF-71 RNF-11 — RF-73.'
            , OLD.id_metrica_drift
        USING ERRCODE = 'P0411';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_DRIFT_METRIC: Las métricas de drift son inmutables. '
            'No se permite modificar id_metrica_drift=%. '
            'Requerimiento RF-71 RNF-11 — RF-73.'
            , OLD.id_metrica_drift
        USING ERRCODE = 'P0411';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_metricas_drift_no_delete_update
BEFORE UPDATE OR DELETE
ON modulo4.metricas_drift
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_metricas_drift_no_delete_update();

-- =============================================================================
-- TGR-M04-12 — Inmutabilidad de datasets registrados
-- Tabla:  modulo4.datasets
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_datasets_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_DATASET: Los datasets son inmutables una vez registrados. '
            'No se permite eliminar id_dataset=%. '
            'Requerimiento RF-71, Restricción 8 — RNF-08.'
            , OLD.id_dataset
        USING ERRCODE = 'P0412';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_DATASET: Los datasets son inmutables una vez registrados. '
            'No se permite modificar id_dataset=%. '
            'Requerimiento RF-71, Restricción 8 — RNF-08.'
            , OLD.id_dataset
        USING ERRCODE = 'P0412';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_datasets_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.datasets
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_datasets_inmutabilidad();

-- =============================================================================
-- TGR-M04-13 — Validación de modelo con estado ACTIVO al generar predicción
-- Tabla:  modulo4.predicciones
-- Evento: BEFORE INSERT
-- Nota:   Reemplaza la validación anterior basada en esta_produccion = true.
--         Ahora verifica estado_version = 'ACTIVO' conforme al ciclo de vida
--         de RF-69 y al campo real del DDL actualizado.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_predicciones_version_modelo_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado modulo4.enum_estado_version_modelo;
BEGIN
    SELECT estado_version
    INTO   v_estado
    FROM   modulo4.versiones_modelos
    WHERE  id_version_modelo = NEW.id_version_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'MODEL_NOT_FOUND: La versión de modelo id_version_modelo=% no existe. '
            'Requerimiento RF-66, Restricción 2.'
            , NEW.id_version_modelo
        USING ERRCODE = 'P0413';
    END IF;

    IF v_estado <> 'ACTIVO' THEN
        RAISE EXCEPTION
            'MODEL_NOT_ACTIVE: Solo se pueden generar predicciones con modelos en estado ACTIVO. '
            'id_version_modelo=% tiene estado=%. '
            'Requerimiento RF-66, Restricción 2 — RF-69.'
            , NEW.id_version_modelo
            , v_estado
        USING ERRCODE = 'P0413';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_predicciones_version_modelo_activo
BEFORE INSERT
ON modulo4.predicciones
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_predicciones_version_modelo_activo();

-- =============================================================================
-- TGR-M04-14 — Validación de rango normalizado [0.0 – 1.0] en métricas del modelo
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE INSERT
-- Nota:   Versión ampliada respecto a v1.0. Incorpora los campos nuevos del DDL:
--         recall_clase_riesgo_alto y roc_auc_score, requeridos por RF-69 y RF-71.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_metricas_rango()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_campos  TEXT[]    := ARRAY[
        'accuracy', 'auc_roc', 'f1_score', 'precision_modelo',
        'recall_modelo', 'recall_clase_riesgo_alto', 'roc_auc_score'
    ];
    v_valores NUMERIC[] := ARRAY[
        NEW.accuracy, NEW.auc_roc, NEW.f1_score, NEW.precision_modelo,
        NEW.recall_modelo, NEW.recall_clase_riesgo_alto, NEW.roc_auc_score
    ];
    i         INT;
BEGIN
    FOR i IN 1..array_length(v_campos, 1) LOOP
        IF v_valores[i] IS NOT NULL AND (v_valores[i] < 0.0 OR v_valores[i] > 1.0) THEN
            RAISE EXCEPTION
                'METRIC_OUT_OF_RANGE: El campo %=% está fuera del rango [0.0 - 1.0]. '
                'Requerimiento RF-69, Entradas — rango obligatorio.'
                , v_campos[i]
                , v_valores[i]
            USING ERRCODE = 'P0414';
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_metricas_rango
BEFORE INSERT
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_metricas_rango();

-- =============================================================================
-- TGR-M04-15 — Coherencia de fechas en ciclos de entrenamiento
-- Tabla:  modulo4.ciclos_entrenamientos
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_ciclos_entrenamientos_fechas_coherencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha_inicio_planificada >= NEW.fecha_final_planificada THEN
        RAISE EXCEPTION
            'INVALID_DATE_RANGE: La fecha_inicio_planificada debe ser anterior a fecha_final_planificada. '
            'Recibido: inicio=%, fin=%. '
            'Requerimiento RF-71, Entradas — campo fecha_inicio_datos.'
            , NEW.fecha_inicio_planificada
            , NEW.fecha_final_planificada
        USING ERRCODE = 'P0415';
    END IF;

    IF NEW.inicio_real IS NOT NULL AND NEW.inicio_real > now() THEN
        RAISE EXCEPTION
            'INVALID_DATE_FUTURE: El campo inicio_real no puede ser una fecha futura. '
            'Valor recibido: %. '
            'Requerimiento RF-71.'
            , NEW.inicio_real
        USING ERRCODE = 'P0415';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_ciclos_entrenamientos_fechas_coherencia
BEFORE INSERT OR UPDATE
ON modulo4.ciclos_entrenamientos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_ciclos_entrenamientos_fechas_coherencia();

-- =============================================================================
-- TGR-M04-16 — Inmutabilidad de datos clínicos medidos en observaciones
-- Tabla:  modulo4.observaciones_clinicas
-- Evento: BEFORE UPDATE OR DELETE
-- Nota:   Permite UPDATE solo sobre el campo observacion (nota libre del veterinario).
--         Bloquea modificación de todos los campos de medición clínica.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_observaciones_clinicas_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'NO_PHYSICAL_DELETE: No se permite eliminar observaciones clínicas. '
            'id_observacion_clinica=%. '
            'Requerimiento RF-67 — RF-73.'
            , OLD.id_observacion_clinica
        USING ERRCODE = 'P0416';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.id_activo_biologico     IS DISTINCT FROM NEW.id_activo_biologico     OR
           OLD.fecha                   IS DISTINCT FROM NEW.fecha                   OR
           OLD.temperatura_rectal      IS DISTINCT FROM NEW.temperatura_rectal      OR
           OLD.frecuencia_cardiaca     IS DISTINCT FROM NEW.frecuencia_cardiaca     OR
           OLD.frecuencia_respiratoria IS DISTINCT FROM NEW.frecuencia_respiratoria OR
           OLD.condicion_corporal      IS DISTINCT FROM NEW.condicion_corporal      OR
           OLD.fuente_datos            IS DISTINCT FROM NEW.fuente_datos
        THEN
            RAISE EXCEPTION
                'IMMUTABLE_CLINICAL_DATA: Los datos clínicos medidos son inmutables. '
                'id_observacion_clinica=%. '
                'Solo se permite modificar el campo observacion (nota libre). '
                'Requerimiento RF-67 — RF-73.'
                , OLD.id_observacion_clinica
            USING ERRCODE = 'P0416';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_observaciones_clinicas_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.observaciones_clinicas
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_observaciones_clinicas_inmutabilidad();

-- =============================================================================
-- TGR-M04-17 — Inmutabilidad de resultados de inferencia en tiempo real
-- Tabla:  modulo4.resultados_inferencia
-- Evento: BEFORE UPDATE OR DELETE
-- Nota:   Tabla principal del motor RF-66 en el DDL actualizado.
--         Complementa TGR-M04-02 que cubre la tabla legacy predicciones.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_resultados_inferencia_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_INFERENCE_RESULT: Los resultados de inferencia son inmutables (append-only). '
            'No se permite eliminar id_resultado_inferencia=%. '
            'Requerimiento RF-66, Restricción 5 — RF-67.'
            , OLD.id_resultado_inferencia
        USING ERRCODE = 'P0417';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_INFERENCE_RESULT: Los resultados de inferencia son inmutables (append-only). '
            'No se permite modificar id_resultado_inferencia=%. '
            'Requerimiento RF-66, Restricción 5 — RF-67.'
            , OLD.id_resultado_inferencia
        USING ERRCODE = 'P0417';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_resultados_inferencia_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.resultados_inferencia
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_resultados_inferencia_inmutabilidad();

-- =============================================================================
-- TGR-M04-18 — Inmutabilidad de retroalimentaciones clínicas
-- Tabla:  modulo4.retroalimentaciones_clinicas
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_retroalimentaciones_clinicas_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_FEEDBACK: Las retroalimentaciones clínicas son inmutables (append-only). '
            'No se permite eliminar id_retroalimentacion=%. '
            'Requerimiento RF-72, Restricciones — RNF-04.'
            , OLD.id_retroalimentacion
        USING ERRCODE = 'P0418';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_FEEDBACK: Las retroalimentaciones clínicas son inmutables (append-only). '
            'No se permite modificar id_retroalimentacion=%. '
            'Requerimiento RF-72, Restricciones — RNF-04.'
            , OLD.id_retroalimentacion
        USING ERRCODE = 'P0418';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_retroalimentaciones_clinicas_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.retroalimentaciones_clinicas
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_retroalimentaciones_clinicas_inmutabilidad();

-- =============================================================================
-- TGR-M04-19 — Obligatoriedad condicional de diagnóstico real en retroalimentación
-- Tabla:  modulo4.retroalimentaciones_clinicas
-- Evento: BEFORE INSERT
-- Nota:   Si estado_retroalimentacion es PARCIAL o INCORRECTO, diagnosticos_reales
--         es obligatorio y debe contener entre 1 y 3 elementos.
--         El primer elemento del array es la patología principal (RF-72).
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_retroalimentaciones_diagnostico_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.estado_retroalimentacion IN ('PARCIAL', 'INCORRECTO') THEN

        IF NEW.diagnosticos_reales IS NULL OR array_length(NEW.diagnosticos_reales, 1) IS NULL THEN
            RAISE EXCEPTION
                'MISSING_DIAGNOSIS: diagnosticos_reales es obligatorio cuando '
                'estado_retroalimentacion=%. '
                'Requerimiento RF-72, Restricciones — Obligatoriedad condicional del diagnóstico real.'
                , NEW.estado_retroalimentacion
            USING ERRCODE = 'P0419';
        END IF;

        IF array_length(NEW.diagnosticos_reales, 1) > 3 THEN
            RAISE EXCEPTION
                'TOO_MANY_DIAGNOSES: diagnosticos_reales no puede tener más de 3 patologías. '
                'Recibido: % elementos. '
                'Requerimiento RF-72, Entradas.'
                , array_length(NEW.diagnosticos_reales, 1)
            USING ERRCODE = 'P0419';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_retroalimentaciones_diagnostico_obligatorio
BEFORE INSERT
ON modulo4.retroalimentaciones_clinicas
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_retroalimentaciones_diagnostico_obligatorio();

-- =============================================================================
-- TGR-M04-20 — Coherencia temporal entre retroalimentación y resultado de inferencia
-- Tabla:  modulo4.retroalimentaciones_clinicas
-- Evento: BEFORE INSERT
-- Nota:   Valida que fecha_retroalimentacion sea posterior a fecha_inferencia
--         del resultado al que está vinculada. También verifica existencia
--         del resultado de inferencia referenciado.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_retroalimentaciones_timestamp_coherencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha_inferencia TIMESTAMP WITH TIME ZONE;
BEGIN
    SELECT fecha_inferencia
    INTO   v_fecha_inferencia
    FROM   modulo4.resultados_inferencia
    WHERE  id_resultado_inferencia = NEW.id_resultado_inferencia;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'INFERENCE_NOT_FOUND: El resultado de inferencia id=% no existe. '
            'Requerimiento RF-72, Flujo alterno E1.'
            , NEW.id_resultado_inferencia
        USING ERRCODE = 'P0420';
    END IF;

    IF NEW.fecha_retroalimentacion <= v_fecha_inferencia THEN
        RAISE EXCEPTION
            'INVALID_FEEDBACK_TIMESTAMP: fecha_retroalimentacion (%) debe ser posterior '
            'a fecha_inferencia (%). '
            'Requerimiento RF-72, Restricciones — Consistencia temporal, Flujo alterno E7.'
            , NEW.fecha_retroalimentacion
            , v_fecha_inferencia
        USING ERRCODE = 'P0420';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_retroalimentaciones_timestamp_coherencia
BEFORE INSERT
ON modulo4.retroalimentaciones_clinicas
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_retroalimentaciones_timestamp_coherencia();

-- =============================================================================
-- TGR-M04-21 — Inmutabilidad de eventos de auditoría del módulo M04
-- Tabla:  modulo4.eventos_auditoria_m04
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_eventos_auditoria_m04_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_AUDIT_EVENT: Los eventos de auditoría M04 son inmutables (append-only). '
            'No se permite eliminar id_evento=%. '
            'Requerimiento RF-73, Restricciones — CA-3.'
            , OLD.id_evento
        USING ERRCODE = 'P0421';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_AUDIT_EVENT: Los eventos de auditoría M04 son inmutables (append-only). '
            'No se permite modificar id_evento=%. '
            'Requerimiento RF-73, Restricciones — CA-3.'
            , OLD.id_evento
        USING ERRCODE = 'P0421';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_eventos_auditoria_m04_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.eventos_auditoria_m04
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_eventos_auditoria_m04_inmutabilidad();

-- =============================================================================
-- TGR-M04-22 — Exclusividad de fuente en eventos de auditoría
-- Tabla:  modulo4.eventos_auditoria_m04
-- Evento: BEFORE INSERT
-- Nota:   Aplica la regla de exclusividad entre id_usuario e id_sistema:
--           tipo_actor = USUARIO      → id_usuario obligatorio, id_sistema nulo
--           tipo_actor = SISTEMA      → id_sistema obligatorio, id_usuario nulo
--           tipo_actor = DISPOSITIVO_EDGE → id_sistema obligatorio, id_usuario nulo
--         No se permite que ambos sean nulos simultáneamente.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_eventos_auditoria_m04_fuente_exclusiva()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.tipo_actor = 'USUARIO' THEN

        IF NEW.id_usuario IS NULL THEN
            RAISE EXCEPTION
                'MISSING_USER_SOURCE: Para tipo_actor=USUARIO, id_usuario es obligatorio. '
                'Requerimiento RF-73, Restricciones — CA-13.'
            USING ERRCODE = 'P0422';
        END IF;

        IF NEW.id_sistema IS NOT NULL THEN
            RAISE EXCEPTION
                'EXCLUSIVE_SOURCE_VIOLATION: Para tipo_actor=USUARIO, id_sistema debe ser nulo. '
                'Requerimiento RF-73, Restricciones — CA-13.'
            USING ERRCODE = 'P0422';
        END IF;

    ELSIF NEW.tipo_actor IN ('SISTEMA', 'DISPOSITIVO_EDGE') THEN

        IF NEW.id_sistema IS NULL THEN
            RAISE EXCEPTION
                'MISSING_SYSTEM_SOURCE: Para tipo_actor=%, id_sistema es obligatorio. '
                'Requerimiento RF-73, Restricciones — CA-13.'
                , NEW.tipo_actor
            USING ERRCODE = 'P0422';
        END IF;

        IF NEW.id_usuario IS NOT NULL THEN
            RAISE EXCEPTION
                'EXCLUSIVE_SOURCE_VIOLATION: Para tipo_actor=%, id_usuario debe ser nulo. '
                'Requerimiento RF-73, Restricciones — CA-13.'
                , NEW.tipo_actor
            USING ERRCODE = 'P0422';
        END IF;

    ELSE

        IF NEW.id_usuario IS NULL AND NEW.id_sistema IS NULL THEN
            RAISE EXCEPTION
                'MISSING_EVENT_SOURCE: Todo evento debe tener al menos una fuente identificada '
                '(id_usuario o id_sistema). '
                'Requerimiento RF-73, Restricciones — Exclusividad entre id_usuario e id_sistema.'
            USING ERRCODE = 'P0422';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_eventos_auditoria_m04_fuente_exclusiva
BEFORE INSERT
ON modulo4.eventos_auditoria_m04
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_eventos_auditoria_m04_fuente_exclusiva();

-- =============================================================================
-- TGR-M04-23 — Inmutabilidad del historial del catálogo de patologías
-- Tabla:  modulo4.historial_catalogo_patologias
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_historial_catalogo_patologias_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_PATHOLOGY_CATALOG_HISTORY: El historial del catálogo de patologías '
            'es inmutable (append-only). '
            'No se permite eliminar id_historial_catalogo=%. '
            'Requerimiento RF-64, Restricciones 10 y 11 — RF-73.'
            , OLD.id_historial_catalogo
        USING ERRCODE = 'P0423';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_PATHOLOGY_CATALOG_HISTORY: El historial del catálogo de patologías '
            'es inmutable (append-only). '
            'No se permite modificar id_historial_catalogo=%. '
            'Requerimiento RF-64, Restricciones 10 y 11 — RF-73.'
            , OLD.id_historial_catalogo
        USING ERRCODE = 'P0423';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_historial_catalogo_patologias_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.historial_catalogo_patologias
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_historial_catalogo_patologias_inmutabilidad();

-- =============================================================================
-- TGR-M04-24 — Inmutabilidad del historial de estados de modelos
-- Tabla:  modulo4.historial_estados_modelos
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_historial_estados_modelos_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_MODEL_STATE_HISTORY: El historial de estados de modelos '
            'es inmutable (append-only). '
            'No se permite eliminar id_historial_estado_modelo=%. '
            'Requerimiento RF-69, Restricción 7 — RF-73.'
            , OLD.id_historial_estado_modelo
        USING ERRCODE = 'P0424';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_MODEL_STATE_HISTORY: El historial de estados de modelos '
            'es inmutable (append-only). '
            'No se permite modificar id_historial_estado_modelo=%. '
            'Requerimiento RF-69, Restricción 7 — RF-73.'
            , OLD.id_historial_estado_modelo
        USING ERRCODE = 'P0424';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_historial_estados_modelos_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.historial_estados_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_historial_estados_modelos_inmutabilidad();

-- =============================================================================
-- TGR-M04-25 — Inmutabilidad del historial de eventos diagnósticos
-- Tabla:  modulo4.historial_diagnostico_eventos
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_historial_diagnostico_eventos_inmutabilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_DIAGNOSTIC_EVENT: El historial de eventos diagnósticos '
            'es inmutable (append-only). '
            'No se permite eliminar id_evento=%. '
            'Requerimiento RF-67, Restricciones — Inmutabilidad.'
            , OLD.id_evento
        USING ERRCODE = 'P0425';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            'IMMUTABLE_DIAGNOSTIC_EVENT: El historial de eventos diagnósticos '
            'es inmutable (append-only). '
            'No se permite modificar id_evento=%. '
            'Requerimiento RF-67, Restricciones — Inmutabilidad.'
            , OLD.id_evento
        USING ERRCODE = 'P0425';
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_historial_diagnostico_eventos_inmutabilidad
BEFORE UPDATE OR DELETE
ON modulo4.historial_diagnostico_eventos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_historial_diagnostico_eventos_inmutabilidad();

-- =============================================================================
-- TGR-M04-26 — Validación de transiciones de estado en versiones de modelos
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE UPDATE OF estado_version
-- Nota:   Máquina de estados cerrada definida en RF-69:
--           EN_VALIDACION → APROBADO | RECHAZADO   (automático)
--           APROBADO      → ACTIVO | DEPRECADO      (ACTIVO = manual; DEPRECADO = automático vía TGR-M04-05)
--           ACTIVO        → DEPRECADO               (automático)
--           DEPRECADO     → (bloqueado)
--           RECHAZADO     → (bloqueado)
--         Se ejecuta antes de TGR-M04-01 por orden alfabético de nombres de trigger,
--         lo que es correcto: la validación de transición ocurre antes del bloqueo
--         de campos estructurales, que ahora permite estado_version.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_transicion_estado_valida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Sin cambio de estado: permitir sin validación adicional
    IF OLD.estado_version = NEW.estado_version THEN
        RETURN NEW;
    END IF;

    -- DEPRECADO y RECHAZADO son estados terminales irreversibles
    IF OLD.estado_version IN ('DEPRECADO', 'RECHAZADO') THEN
        RAISE EXCEPTION
            'INVALID_STATE_TRANSITION: Los modelos en estado % no pueden cambiar de estado. '
            'id_version_modelo=%. '
            'Requerimiento RF-69, Restricción 6 — Descripción: transiciones válidas.'
            , OLD.estado_version
            , OLD.id_version_modelo
        USING ERRCODE = 'P0426';
    END IF;

    -- Validar que la transición esté dentro del conjunto permitido
    IF NOT (
        (OLD.estado_version = 'EN_VALIDACION' AND NEW.estado_version IN ('APROBADO', 'RECHAZADO')) OR
        (OLD.estado_version = 'APROBADO'      AND NEW.estado_version IN ('ACTIVO', 'DEPRECADO'))   OR
        (OLD.estado_version = 'ACTIVO'        AND NEW.estado_version = 'DEPRECADO')
    ) THEN
        RAISE EXCEPTION
            'INVALID_STATE_TRANSITION: Transición de estado inválida: % → %. '
            'id_version_modelo=%. '
            'Requerimiento RF-69, Descripción — Transiciones válidas.'
            , OLD.estado_version
            , NEW.estado_version
            , OLD.id_version_modelo
        USING ERRCODE = 'P0426';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_transicion_estado_valida
BEFORE UPDATE OF estado_version
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_transicion_estado_valida();

-- =============================================================================
-- TGR-M04-27 — Notas de validación obligatorias antes de activar un modelo
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE UPDATE OF estado_version
-- Nota:   Bloquea la activación (→ ACTIVO) si notas_validacion es nulo o vacío.
--         Garantiza que ningún modelo entre a producción sin evaluación clínica
--         documentada por el Veterinario o Administrador (RF-69, Fase 4).
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_notas_requeridas_activacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.estado_version = 'ACTIVO' AND OLD.estado_version <> 'ACTIVO' THEN
        IF NEW.notas_validacion IS NULL OR trim(NEW.notas_validacion) = '' THEN
            RAISE EXCEPTION
                'MISSING_VALIDATION_NOTES: No se puede activar la versión id=% sin notas_validacion. '
                'El Veterinario o Administrador debe registrar la evaluación clínica antes de activar. '
                'Requerimiento RF-69, CA-13 — Fase 4.'
                , OLD.id_version_modelo
            USING ERRCODE = 'P0427';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_notas_requeridas_activacion
BEFORE UPDATE OF estado_version
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_notas_requeridas_activacion();

-- =============================================================================
-- TGR-M04-28 — Coherencia de umbrales y ventana temporal en configuración del motor
-- Tabla:  modulo4.configuraciones_motor_ia
-- Evento: BEFORE INSERT OR UPDATE
-- Nota:   Valida tres condiciones de RF-65:
--           1. umbral_riesgo_alto ∈ [0.50, 0.95]
--           2. umbral_alerta_critica ∈ [0.50, 0.95]
--           3. umbral_alerta_critica >= umbral_riesgo_alto
--           4. ventana_temporal_min ∈ [5, 15]
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_configuraciones_motor_umbrales_coherencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.umbral_riesgo_alto < 0.500 OR NEW.umbral_riesgo_alto > 0.950 THEN
        RAISE EXCEPTION
            'INVALID_THRESHOLD_RANGE: umbral_riesgo_alto=% fuera del rango [0.50 - 0.95]. '
            'Requerimiento RF-65, Restricción 1 — Flujo alterno E1.'
            , NEW.umbral_riesgo_alto
        USING ERRCODE = 'P0428';
    END IF;

    IF NEW.umbral_alerta_critica < 0.500 OR NEW.umbral_alerta_critica > 0.950 THEN
        RAISE EXCEPTION
            'INVALID_THRESHOLD_RANGE: umbral_alerta_critica=% fuera del rango [0.50 - 0.95]. '
            'Requerimiento RF-65, Restricción 1 — Flujo alterno E1.'
            , NEW.umbral_alerta_critica
        USING ERRCODE = 'P0428';
    END IF;

    IF NEW.umbral_alerta_critica < NEW.umbral_riesgo_alto THEN
        RAISE EXCEPTION
            'THRESHOLD_COHERENCE_ERROR: umbral_alerta_critica (%) debe ser >= umbral_riesgo_alto (%). '
            'Requerimiento RF-65, Restricción 6 — CA-7, Flujo alterno E4.'
            , NEW.umbral_alerta_critica
            , NEW.umbral_riesgo_alto
        USING ERRCODE = 'P0428';
    END IF;

    IF NEW.ventana_temporal_min < 5 OR NEW.ventana_temporal_min > 15 THEN
        RAISE EXCEPTION
            'INVALID_WINDOW_RANGE: ventana_temporal_min=% fuera del rango [5 - 15] minutos. '
            'Requerimiento RF-65, Restricción 2.'
            , NEW.ventana_temporal_min
        USING ERRCODE = 'P0428';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_configuraciones_motor_umbrales_coherencia
BEFORE INSERT OR UPDATE
ON modulo4.configuraciones_motor_ia
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_configuraciones_motor_umbrales_coherencia();

-- =============================================================================
-- TGR-M04-29 — Validación de pesos del modelo de contagio (suma = 1.0)
-- Tabla:  modulo4.configuraciones_motor_ia
-- Evento: BEFORE INSERT OR UPDATE
-- Nota:   Garantiza que W_fs + W_fa + W_fd = 1.0 (tolerancia ±0.001 por precisión
--         numérica de tipo NUMERIC). Si los pesos no suman 1.0, la fórmula
--         P_contagio = W_fs*Fs + W_fa*Fa + W_fd*Fd produce resultados fuera de [0,1].
--         Cada peso individual también debe estar en el rango [0.0, 1.0].
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_configuraciones_motor_pesos_contagio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_suma NUMERIC;
BEGIN
    IF NEW.w_factor_sanitario < 0.0 OR NEW.w_factor_sanitario > 1.0 THEN
        RAISE EXCEPTION
            'INVALID_WEIGHT_RANGE: w_factor_sanitario=% fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-68, Descripción — Definición del modelo de cálculo.'
            , NEW.w_factor_sanitario
        USING ERRCODE = 'P0429';
    END IF;

    IF NEW.w_factor_ambiental < 0.0 OR NEW.w_factor_ambiental > 1.0 THEN
        RAISE EXCEPTION
            'INVALID_WEIGHT_RANGE: w_factor_ambiental=% fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-68, Descripción — Definición del modelo de cálculo.'
            , NEW.w_factor_ambiental
        USING ERRCODE = 'P0429';
    END IF;

    IF NEW.w_factor_densidad < 0.0 OR NEW.w_factor_densidad > 1.0 THEN
        RAISE EXCEPTION
            'INVALID_WEIGHT_RANGE: w_factor_densidad=% fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-68, Descripción — Definición del modelo de cálculo.'
            , NEW.w_factor_densidad
        USING ERRCODE = 'P0429';
    END IF;

    v_suma := NEW.w_factor_sanitario + NEW.w_factor_ambiental + NEW.w_factor_densidad;

    IF abs(v_suma - 1.0) > 0.001 THEN
        RAISE EXCEPTION
            'INVALID_WEIGHT_SUM: La suma de pesos del modelo de contagio debe ser 1.0. '
            'Suma actual: % (W_fs=%, W_fa=%, W_fd=%). '
            'Requerimiento RF-68, Descripción — Reglas: W_fs + W_fa + W_fd = 1.0.'
            , v_suma
            , NEW.w_factor_sanitario
            , NEW.w_factor_ambiental
            , NEW.w_factor_densidad
        USING ERRCODE = 'P0429';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_configuraciones_motor_pesos_contagio
BEFORE INSERT OR UPDATE
ON modulo4.configuraciones_motor_ia
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_configuraciones_motor_pesos_contagio();

-- =============================================================================
-- TGR-M04-30 — Inmutabilidad de despliegues OTA completados
-- Tabla:  modulo4.despliegues_ota
-- Evento: BEFORE UPDATE OR DELETE
-- Nota:   Bloquea DELETE de forma incondicional.
--         Bloquea UPDATE solo sobre registros con estado terminal (EXITOSO o FALLIDO).
--         Permite UPDATE sobre despliegues en estados activos: PENDIENTE, EN_PROCESO,
--         SIN_CAMBIOS, para soportar actualización de progreso durante la descarga.
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_despliegues_ota_inmutabilidad_completados()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'NO_PHYSICAL_DELETE: No se permite eliminar registros de despliegue OTA. '
            'id_despliegue_ota=%. '
            'Requerimiento RF-70, Postcondiciones — RF-73.'
            , OLD.id_despliegue_ota
        USING ERRCODE = 'P0430';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.estado_despliegue IN ('EXITOSO', 'FALLIDO') THEN
        RAISE EXCEPTION
            'IMMUTABLE_OTA_DEPLOYMENT: Los despliegues OTA en estado % son inmutables. '
            'id_despliegue_ota=%. '
            'Requerimiento RF-70, Postcondiciones — RF-73.'
            , OLD.estado_despliegue
            , OLD.id_despliegue_ota
        USING ERRCODE = 'P0430';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_despliegues_ota_inmutabilidad_completados
BEFORE UPDATE OR DELETE
ON modulo4.despliegues_ota
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_despliegues_ota_inmutabilidad_completados();

-- =============================================================================
-- Total de funciones de trigger : 30
-- Total de triggers registrados  : 30
-- =============================================================================