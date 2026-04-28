-- =============================================================================
-- MÓDULO 4 — MODELO DE PREDICCIÓN 
-- Archivo: triggers_modulo4_v1_0.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo4
-- Motor: PostgreSQL
-- Versión: 1.0
-- =============================================================================

-- ÍNDICE
-- TGR-M04-01  Inmutabilidad de versiones de modelos (bloqueo UPDATE y DELETE)
-- TGR-M04-02  Inmutabilidad de predicciones / resultados de inferencia
-- TGR-M04-03  Inmutabilidad estructural de alertas patológicas
-- TGR-M04-04  Inmutabilidad de registros de auditoría de predicciones
-- TGR-M04-05  Unicidad de modelo en producción por tipo de algoritmo
-- TGR-M04-06  Validación de hash SHA-256 del artefacto de modelo
-- TGR-M04-07  Consistencia entre probabilidad, umbral y flag supera_umbral
-- TGR-M04-08  Validación de fecha de entrenamiento no futura
-- TGR-M04-09  Inmutabilidad de ciclos de entrenamiento completados o cancelados
-- TGR-M04-10  Bloqueo de eliminación física de ciclos de entrenamiento
-- TGR-M04-11  Inmutabilidad de métricas de drift
-- TGR-M04-12  Inmutabilidad de datasets registrados
-- TGR-M04-13  Validación de modelo en producción al generar predicción
-- TGR-M04-14  Validación de rango normalizado [0.0 – 1.0] en métricas del modelo
-- TGR-M04-15  Coherencia de fechas en ciclos de entrenamiento
-- TGR-M04-16  Inmutabilidad de datos clínicos medidos en observaciones

-- =============================================================================
-- TGR-M04-01 — Inmutabilidad de versiones de modelos (bloqueo UPDATE y DELETE)
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE UPDATE OR DELETE
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
        RAISE EXCEPTION
            'IMMUTABLE_MODEL_VERSION: Las versiones de modelos son inmutables (append-only). '
            'No se permite modificar id_version_modelo=%. '
            'Requerimiento RF-69, Restricción 7 — CA-8.'
            , OLD.id_version_modelo
        USING ERRCODE = 'P0401';
    END IF;

    RETURN NULL;
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
-- TGR-M04-05 — Unicidad de modelo en producción por tipo de algoritmo
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE INSERT OR UPDATE OF esta_produccion
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_unicidad_produccion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.esta_produccion = true THEN
        UPDATE modulo4.versiones_modelos
        SET    esta_produccion = false
        WHERE  algoritmo        = NEW.algoritmo
          AND  esta_produccion  = true
          AND  id_version_modelo <> NEW.id_version_modelo;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_versiones_modelos_unicidad_produccion
BEFORE INSERT OR UPDATE OF esta_produccion
ON modulo4.versiones_modelos
FOR EACH ROW EXECUTE FUNCTION modulo4.trg_fn_versiones_modelos_unicidad_produccion();

-- =============================================================================
-- TGR-M04-06 — Validación de hash SHA-256 del artefacto de modelo
-- Tabla:  modulo4.versiones_modelos
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.hash_artecfacto IS NULL OR trim(NEW.hash_artecfacto) = '' THEN
        RAISE EXCEPTION
            'MISSING_HASH: El hash del artefacto del modelo es obligatorio. '
            'No se permite registrar versiones sin hash_artecfacto. '
            'Requerimiento RF-69, Restricción 8.'
        USING ERRCODE = 'P0406';
    END IF;

    IF length(trim(NEW.hash_artecfacto)) <> 64 THEN
        RAISE EXCEPTION
            'INVALID_HASH_LENGTH: El hash_artecfacto debe tener exactamente 64 caracteres (SHA-256). '
            'Longitud recibida: %. '
            'Requerimiento RF-69, Restricción 8.'
            , length(trim(NEW.hash_artecfacto))
        USING ERRCODE = 'P0406';
    END IF;

    IF trim(NEW.hash_artecfacto) !~ '^[a-fA-F0-9]{64}$' THEN
        RAISE EXCEPTION
            'INVALID_HASH_FORMAT: El hash_artecfacto contiene caracteres no hexadecimales. '
            'Solo se aceptan caracteres [0-9, a-f, A-F]. '
            'Requerimiento RF-69, Restricción 8.'
        USING ERRCODE = 'P0406';
    END IF;

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
-- TGR-M04-13 — Validación de modelo en producción al generar predicción
-- Tabla:  modulo4.predicciones
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_predicciones_version_modelo_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_en_produccion BOOLEAN;
BEGIN
    SELECT esta_produccion
    INTO   v_en_produccion
    FROM   modulo4.versiones_modelos
    WHERE  id_version_modelo = NEW.id_version_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'MODEL_NOT_FOUND: La versión de modelo id_version_modelo=% no existe. '
            'Requerimiento RF-66, Restricción 2.'
            , NEW.id_version_modelo
        USING ERRCODE = 'P0413';
    END IF;

    IF v_en_produccion IS FALSE THEN
        RAISE EXCEPTION
            'MODEL_NOT_ACTIVE: Solo se pueden generar predicciones con modelos en producción. '
            'La versión id_version_modelo=% no está activa (esta_produccion = false). '
            'Requerimiento RF-66, Restricción 2 — RF-69.'
            , NEW.id_version_modelo
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
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo4.trg_fn_versiones_modelos_metricas_rango()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.accuracy IS NOT NULL AND (NEW.accuracy < 0.0 OR NEW.accuracy > 1.0) THEN
        RAISE EXCEPTION
            'METRIC_OUT_OF_RANGE: El campo accuracy=% está fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-69, Entradas — rango obligatorio.'
            , NEW.accuracy
        USING ERRCODE = 'P0414';
    END IF;

    IF NEW.auc_roc IS NOT NULL AND (NEW.auc_roc < 0.0 OR NEW.auc_roc > 1.0) THEN
        RAISE EXCEPTION
            'METRIC_OUT_OF_RANGE: El campo auc_roc=% está fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-69, Entradas — rango obligatorio.'
            , NEW.auc_roc
        USING ERRCODE = 'P0414';
    END IF;

    IF NEW.f1_score IS NOT NULL AND (NEW.f1_score < 0.0 OR NEW.f1_score > 1.0) THEN
        RAISE EXCEPTION
            'METRIC_OUT_OF_RANGE: El campo f1_score=% está fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-69, Entradas — rango obligatorio.'
            , NEW.f1_score
        USING ERRCODE = 'P0414';
    END IF;

    IF NEW.precision_modelo IS NOT NULL AND (NEW.precision_modelo < 0.0 OR NEW.precision_modelo > 1.0) THEN
        RAISE EXCEPTION
            'METRIC_OUT_OF_RANGE: El campo precision_modelo=% está fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-69, Entradas — rango obligatorio.'
            , NEW.precision_modelo
        USING ERRCODE = 'P0414';
    END IF;

    IF NEW.recall_modelo IS NOT NULL AND (NEW.recall_modelo < 0.0 OR NEW.recall_modelo > 1.0) THEN
        RAISE EXCEPTION
            'METRIC_OUT_OF_RANGE: El campo recall_modelo=% está fuera del rango [0.0 - 1.0]. '
            'Requerimiento RF-69, Entradas — rango obligatorio.'
            , NEW.recall_modelo
        USING ERRCODE = 'P0414';
    END IF;

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
-- Total de funciones de trigger : 16
-- Total de triggers registrados  : 16
-- =============================================================================