-- ================================================================
-- CONSTRAINTS — MÓDULO 4
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo se declaran constraints que NO existen en el DDL del
--   backup (backup4_0_0.sql).
--
-- YA EXISTENTES en el backup (NO se re-ejecutan):
--
--   PKs (11): alertas_patologicas_pkey, auditorias_predicciones_pkey,
--     ciclos_entrenamientos_pkey, datasets_pkey, detalles_signos_pkey,
--     metricas_drift_pkey, observaciones_clinicas_pkey,
--     patologias_signos_pkey, predicciones_pkey,
--     signos_clinicos_pkey, versiones_modelos_pkey
--
--   CHECKs inline en DDL (ya activos):
--     chk_criticidad     → alertas_patologicas.nivel_criticidad
--                          IN ('CRITICA','ALTA','MEDIA','BAJA')
--     chk_fechas_ciclo   → ciclos_entrenamientos: fecha_final >= fecha_inicio
--     chk_fechas_ds      → datasets: fecha_fin >= fecha_inicio
--     chk_split_ds       → datasets: porcentaje_train + porcentaje_test = 100
--     chk_intensidad     → detalles_signos: intensidad BETWEEN 1 AND 5
--     chk_bcs            → observaciones_clinicas: BCS BETWEEN 1.0 AND 5.0
--     chk_temp_rectal    → observaciones_clinicas: temp BETWEEN 35 AND 43
--     chk_sensibilidad   → patologias_signos: sensibilidad BETWEEN 0 AND 1
--     chk_umbral_alerta  → patologias_signos: peso_relativo BETWEEN 0 AND 1
--     chk_probabilidad   → predicciones: probabilidad_pct BETWEEN 0 AND 100
--     chk_umbral_pred    → predicciones: umbral_usado BETWEEN 0 AND 100
--     chk_auc            → versiones_modelos: auc_roc BETWEEN 0 AND 1
--     chk_umbral_version → versiones_modelos: umbral_clasificacion BETWEEN 0 AND 100
--
--   FKs CON NOT VALID (se validan en PARTE 1):
--     fk_alerta_patologica_prediccion
--     fk_auditoria_prediccion_id
--     fk_ciclo_entrenamiento_modelo_anterior
--     fk_ciclo_entrenamiento_modelo_nuevo
--     fk_dataset_version_modelo
--     fk_detalle_signo_clinico
--     fk_detalle_signo_observacion
--     fk_metrica_drift_modelo_version
--     fk_patologia_signo_clinico
--     fk_prediciones_observacion_clinicas
--     fk_prediciones_observacion_modelo
--
--   NOTA SOBRE FKs ELIMINADAS EN MIGRACIÓN:
--     Las siguientes FKs aparecen como DROP en el backup, lo que
--     indica que fueron eliminadas en una migración. NO se recrean
--     automáticamente; se agregan como FKs genuinamente faltantes
--     solo las de ámbito interno del módulo 4. Las externas
--     (modulo1, modulo2, modulo9) quedaron eliminadas por decisión
--     arquitectónica (referencias lógicas sin constraint formal).
--     FKs internas faltantes: fk_prediciones_patologia
--     (predicciones.id_patologia → modulo9.patologias.id_patologias
--      fue eliminada — es referencia lógica al catálogo M9).
--
--   NOTA SOBRE ENUMS:
--     Las columnas de tipo ENUM de PostgreSQL restringen los valores
--     por definición de tipo. CHECK IN() sobre columnas ENUM es
--     redundante y puede causar errores de compatibilidad.
--     ENUMs del módulo 4 no se incluyen en CHECKs:
--       enum_alerta_patologia_estado, enum_auditoria_prediccion_accion,
--       enum_ciclo_entrenamiento_estado_ciclo, enum_ciclo_entrenamiento_tipo,
--       enum_datset_semestre, enum_metrica_drifft_tipo,
--       enum_metrica_drifft_accion_tomada, enum_predicciones_clase,
--       enum_signo_clinico_tipo, enum_version_modelo_algoritmo
--
-- Se AGREGAN:
--   PARTE 1 — VALIDATE FKs NOT VALID existentes
--   PARTE 2 — UNIQUE constraints nuevos
--   PARTE 3 — CHECK constraints directos
--   PARTE 4 — CHECK constraints diferidos (NOT VALID + VALIDATE)
--   PARTE 5 — Índices únicos parciales y de desempeño
-- ================================================================

-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- Ejecutar antes de los índices únicos si la BD tiene datos previos.
-- ----------------------------------------------------------------

-- [P1] Verificar que no haya más de una versión en producción
-- SELECT COUNT(*) FROM modulo4.versiones_modelos WHERE esta_produccion = true;
-- Si retorna > 1, corregir antes de crear uix_una_version_en_produccion:
-- UPDATE modulo4.versiones_modelos SET esta_produccion = false
--   WHERE esta_produccion = true
--   AND id_version_modelo != (
--       SELECT id_version_modelo FROM modulo4.versiones_modelos
--       WHERE esta_produccion = true
--       ORDER BY fecha_despliegue DESC NULLS LAST LIMIT 1);

-- [P2] Verificar duplicados en detalles_signos (obs + signo)
-- SELECT id_observaciones, id_signo_clinico, COUNT(*)
--   FROM modulo4.detalles_signos
--  GROUP BY id_observaciones, id_signo_clinico
--  HAVING COUNT(*) > 1;

-- [P3] Verificar coherencia supera_umbral en predicciones
-- SELECT id_prediccion FROM modulo4.predicciones
--  WHERE (supera_umbral = true  AND probabilidad_pct < umbral_usado)
--     OR (supera_umbral = false AND probabilidad_pct >= umbral_usado);

-- [P4] Verificar drift_score fuera de rango [0,1] en ciclos_entrenamientos
-- SELECT id_ciclo_entrenamiento, drift_score
--   FROM modulo4.ciclos_entrenamientos
--  WHERE drift_score IS NOT NULL
--    AND (drift_score < 0 OR drift_score > 1);


-- ================================================================
-- PARTE 1 — VALIDACIÓN DE FKs EXISTENTES (NOT VALID)
-- ================================================================

ALTER TABLE modulo4.alertas_patologicas
    VALIDATE CONSTRAINT fk_alerta_patologica_prediccion;

ALTER TABLE modulo4.auditorias_predicciones
    VALIDATE CONSTRAINT fk_auditoria_prediccion_id;

ALTER TABLE modulo4.ciclos_entrenamientos
    VALIDATE CONSTRAINT fk_ciclo_entrenamiento_modelo_anterior;

ALTER TABLE modulo4.ciclos_entrenamientos
    VALIDATE CONSTRAINT fk_ciclo_entrenamiento_modelo_nuevo;

ALTER TABLE modulo4.datasets
    VALIDATE CONSTRAINT fk_dataset_version_modelo;

ALTER TABLE modulo4.detalles_signos
    VALIDATE CONSTRAINT fk_detalle_signo_clinico;

ALTER TABLE modulo4.detalles_signos
    VALIDATE CONSTRAINT fk_detalle_signo_observacion;

ALTER TABLE modulo4.metricas_drift
    VALIDATE CONSTRAINT fk_metrica_drift_modelo_version;

ALTER TABLE modulo4.patologias_signos
    VALIDATE CONSTRAINT fk_patologia_signo_clinico;

ALTER TABLE modulo4.predicciones
    VALIDATE CONSTRAINT fk_prediciones_observacion_clinicas;

ALTER TABLE modulo4.predicciones
    VALIDATE CONSTRAINT fk_prediciones_observacion_modelo;


-- ================================================================
-- PARTE 2 — UNIQUE CONSTRAINTS NUEVOS
-- ================================================================

-- [RF-68] Nombre de versión de modelo único (trazabilidad del versionado)
ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT uq_version_modelo_nombre
        UNIQUE (nombre_version);

-- [RF-64] Nombre de signo clínico único en el catálogo
ALTER TABLE modulo4.signos_clinicos
    ADD CONSTRAINT uq_signo_clinico_nombre
        UNIQUE (nombre);

-- [RF-70] Semestre único en ciclos de entrenamiento
-- Un mismo semestre no puede tener más de un ciclo de entrenamiento
ALTER TABLE modulo4.ciclos_entrenamientos
    ADD CONSTRAINT uq_ciclo_semestre
        UNIQUE (semestre);

-- [RF-65] Un signo clínico no puede registrarse dos veces
-- en la misma observación clínica
ALTER TABLE modulo4.detalles_signos
    ADD CONSTRAINT uq_det_obs_signo
        UNIQUE (id_observaciones, id_signo_clinico);

-- [RF-64] Par (patología, signo) único en la tabla de asociación
-- Evita duplicar la misma relación patología-signo
ALTER TABLE modulo4.patologias_signos
    ADD CONSTRAINT uq_patologia_signo
        UNIQUE (id_patologia, id_signo_clinico);


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS DIRECTOS
-- ================================================================

-- ──────────────────────────────────────────────────────────────
-- TABLA: versiones_modelos
-- ──────────────────────────────────────────────────────────────

-- [RF-68] Métricas del modelo: accuracy, f1, precision, recall ∈ [0, 1]
-- El DDL ya tiene chk_auc y chk_umbral_version; faltan el resto.
ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_accuracy_rango
        CHECK (accuracy IS NULL OR (accuracy >= 0 AND accuracy <= 1));

ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_f1_rango
        CHECK (f1_score IS NULL OR (f1_score >= 0 AND f1_score <= 1));

ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_precision_rango
        CHECK (precision_modelo IS NULL
               OR (precision_modelo >= 0 AND precision_modelo <= 1));

ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_recall_rango
        CHECK (recall_modelo IS NULL
               OR (recall_modelo >= 0 AND recall_modelo <= 1));

-- [RF-68] Coherencia temporal: despliegue posterior al entrenamiento
ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_version_fechas_coherentes
        CHECK (
            fecha_despliegue IS NULL
            OR fecha_entrenamiento IS NULL
            OR fecha_despliegue >= fecha_entrenamiento
        );

-- [RF-68] fecha_retiro posterior al despliegue
ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_version_retiro_posterior_despliegue
        CHECK (
            fecha_retiro IS NULL
            OR fecha_despliegue IS NULL
            OR fecha_retiro >= fecha_despliegue
        );

-- [RF-68] Modelo en producción no puede tener fecha de retiro
ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_version_produccion_sin_retiro
        CHECK (
            esta_produccion = false
            OR fecha_retiro IS NULL
        );

-- [RF-68] hash_artecfacto exactamente 64 caracteres (SHA-256 hex)
-- cuando está definido
ALTER TABLE modulo4.versiones_modelos
    ADD CONSTRAINT chk_hash_artefacto_longitud
        CHECK (hash_artecfacto IS NULL
               OR char_length(hash_artecfacto) = 64);

-- ──────────────────────────────────────────────────────────────
-- TABLA: datasets
-- ──────────────────────────────────────────────────────────────

-- [RF-70] total_registros >= registros_positivos + registros_negativos
ALTER TABLE modulo4.datasets
    ADD CONSTRAINT chk_ds_registros_coherentes
        CHECK (
            total_resgistros IS NULL
            OR registros_positivos IS NULL
            OR registros_negativos IS NULL
            OR total_resgistros >= (registros_positivos + registros_negativos)
        );

-- [RF-70] Totales de registros no negativos
ALTER TABLE modulo4.datasets
    ADD CONSTRAINT chk_ds_registros_no_negativos
        CHECK (
            (total_resgistros IS NULL OR total_resgistros >= 0)
            AND (registros_positivos IS NULL OR registros_positivos >= 0)
            AND (registros_negativos IS NULL OR registros_negativos >= 0)
        );

-- [RF-70] porcentaje_train y porcentaje_test no negativos
ALTER TABLE modulo4.datasets
    ADD CONSTRAINT chk_ds_split_positivos
        CHECK (porcentaje_train >= 0 AND porcentaje_test >= 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: ciclos_entrenamientos
-- ──────────────────────────────────────────────────────────────

-- [RF-70] drift_score ∈ [0, 1] cuando está definido
ALTER TABLE modulo4.ciclos_entrenamientos
    ADD CONSTRAINT chk_ciclo_drift_score_rango
        CHECK (drift_score IS NULL
               OR (drift_score >= 0 AND drift_score <= 1));

-- [RF-70] metrica_comparacion_auc ∈ [0, 1]
ALTER TABLE modulo4.ciclos_entrenamientos
    ADD CONSTRAINT chk_ciclo_auc_rango
        CHECK (metrica_comparacion_auc IS NULL
               OR (metrica_comparacion_auc >= 0 AND metrica_comparacion_auc <= 1));

-- [RF-70] El modelo anterior y nuevo deben ser distintos
ALTER TABLE modulo4.ciclos_entrenamientos
    ADD CONSTRAINT chk_ciclo_modelos_distintos
        CHECK (
            id_modelo_version_anterior IS NULL
            OR id_modelo_version_nueva IS NULL
            OR id_modelo_version_anterior != id_modelo_version_nueva
        );

-- [RF-70] Solo puede aprobarse si hay modelo nuevo asignado
ALTER TABLE modulo4.ciclos_entrenamientos
    ADD CONSTRAINT chk_ciclo_aprobacion_requiere_modelo
        CHECK (
            es_aprobado_despliegue IS NULL
            OR id_modelo_version_nueva IS NOT NULL
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: observaciones_clinicas
-- ──────────────────────────────────────────────────────────────

-- [RF-65] frecuencia_cardiaca positiva y en rango fisiológico
-- (el DDL no tiene CHECKs para FC ni FR)
ALTER TABLE modulo4.observaciones_clinicas
    ADD CONSTRAINT chk_obs_fc_rango
        CHECK (frecuencia_cardiaca IS NULL
               OR (frecuencia_cardiaca >= 20 AND frecuencia_cardiaca <= 200));

-- [RF-65] frecuencia_respiratoria en rango fisiológico bovino
ALTER TABLE modulo4.observaciones_clinicas
    ADD CONSTRAINT chk_obs_fr_rango
        CHECK (frecuencia_respiratoria IS NULL
               OR (frecuencia_respiratoria >= 5 AND frecuencia_respiratoria <= 100));

-- [RF-65] fuente_datos dentro del vocabulario válido
ALTER TABLE modulo4.observaciones_clinicas
    ADD CONSTRAINT chk_obs_fuente_valida
        CHECK (fuente_datos IN ('manual', 'iot', 'mixta'));

-- ──────────────────────────────────────────────────────────────
-- TABLA: predicciones
-- ──────────────────────────────────────────────────────────────

-- [RF-65] supera_umbral debe ser coherente con probabilidad y umbral
-- Si probabilidad >= umbral → supera_umbral = true, y viceversa
ALTER TABLE modulo4.predicciones
    ADD CONSTRAINT chk_pred_supera_umbral_coherente
        CHECK (
            (supera_umbral = true  AND probabilidad_pct >= umbral_usado)
            OR (supera_umbral = false AND probabilidad_pct < umbral_usado)
        );

-- [RF-65] confianza_modelo ∈ [0, 1]
ALTER TABLE modulo4.predicciones
    ADD CONSTRAINT chk_pred_confianza_rango
        CHECK (confianza_modelo IS NULL
               OR (confianza_modelo >= 0 AND confianza_modelo <= 1));

-- [RF-65] tiempo_proceso_ms: positivo y dentro del SLA (2000 ms)
-- Restricción explícita RF-65: "La latencia de inferencia no debe
-- superar 2 segundos desde la recepción hasta la salida."
ALTER TABLE modulo4.predicciones
    ADD CONSTRAINT chk_pred_latencia_no_negativa
        CHECK (tiempo_proceso_ms IS NULL OR tiempo_proceso_ms >= 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: alertas_patologicas
-- ──────────────────────────────────────────────────────────────

-- [RF-65, RF-67] probabilidad_pct ∈ [0, 100]
ALTER TABLE modulo4.alertas_patologicas
    ADD CONSTRAINT chk_alerta_probabilidad_rango
        CHECK (probabilidad_pct >= 0 AND probabilidad_pct <= 100);

-- [RF-67] Coherencia entre nivel_criticidad y probabilidad_pct:
--   CRITICA  → probabilidad >= 90
--   ALTA     → probabilidad >= 75
--   MEDIA    → probabilidad >= 60
--   BAJA     → probabilidad < 60
ALTER TABLE modulo4.alertas_patologicas
    ADD CONSTRAINT chk_alerta_criticidad_coherente
        CHECK (
            (nivel_criticidad = 'CRITICA' AND probabilidad_pct >= 90)
            OR (nivel_criticidad = 'ALTA'   AND probabilidad_pct >= 75
                                             AND probabilidad_pct < 90)
            OR (nivel_criticidad = 'MEDIA'  AND probabilidad_pct >= 60
                                             AND probabilidad_pct < 75)
            OR (nivel_criticidad = 'BAJA'   AND probabilidad_pct < 60)
        );

-- [RF-67] fecha_notificacion posterior a fecha_generacion
ALTER TABLE modulo4.alertas_patologicas
    ADD CONSTRAINT chk_alerta_notificacion_posterior
        CHECK (
            fecha_notificacion IS NULL
            OR fecha_notificacion >= fecha_generacion
        );

-- [RF-67] es_verdadero solo puede tener valor si la alerta fue ATENDIDA
-- (retroalimentación veterinaria requiere que el caso haya sido revisado)
ALTER TABLE modulo4.alertas_patologicas
    ADD CONSTRAINT chk_alerta_retroalimentacion_coherente
        CHECK (
            es_verdadero IS NULL
            OR estado_alerta IN ('ATENDIDA', 'FALSO_POSITIVO', 'CERRADA')
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: metricas_drift
-- ──────────────────────────────────────────────────────────────

-- [RF-70] valor_metrica no negativo (PSI, KL y demás son >= 0)
ALTER TABLE modulo4.metricas_drift
    ADD CONSTRAINT chk_drift_valor_no_negativo
        CHECK (valor_metrica >= 0);

-- [RF-70] umbral_alerta_drift no negativo y positivo
ALTER TABLE modulo4.metricas_drift
    ADD CONSTRAINT chk_drift_umbral_positivo
        CHECK (umbral_alerta_drift > 0);

-- [RF-70] supera_umbral_drift coherente con valor y umbral
ALTER TABLE modulo4.metricas_drift
    ADD CONSTRAINT chk_drift_supera_coherente
        CHECK (
            (supera_umbral_drift = true  AND valor_metrica > umbral_alerta_drift)
            OR (supera_umbral_drift = false AND valor_metrica <= umbral_alerta_drift)
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: detalles_signos
-- ──────────────────────────────────────────────────────────────

-- [RF-65] valor_numerico no negativo cuando está definido
-- (las magnitudes clínicas son no negativas)
ALTER TABLE modulo4.detalles_signos
    ADD CONSTRAINT chk_detalle_valor_no_negativo
        CHECK (valor_numerico IS NULL OR valor_numerico >= 0);

-- [RF-65] Si el signo no está presente, no debería tener intensidad alta
-- (intensidad refuerza la presencia, no la ausencia)
ALTER TABLE modulo4.detalles_signos
    ADD CONSTRAINT chk_detalle_intensidad_coherente
        CHECK (
            es_presente = true
            OR intensidad IS NULL
        );


-- ================================================================
-- PARTE 4 — CHECK CONSTRAINTS DIFERIDOS (NOT VALID + VALIDATE)
-- ================================================================

-- [RF-65, RF-66] Predicciones: fecha_prediccion no futura
ALTER TABLE modulo4.predicciones
    ADD CONSTRAINT chk_pred_fecha_no_futura
        CHECK (fecha_prediccion <= NOW())
        NOT VALID;
ALTER TABLE modulo4.predicciones
    VALIDATE CONSTRAINT chk_pred_fecha_no_futura;

-- [RF-65] SLA de latencia de inferencia <= 2000 ms (RF-65 restricción 1)
-- NOT VALID para tolerar datos históricos capturados en condiciones de carga
ALTER TABLE modulo4.predicciones
    ADD CONSTRAINT chk_pred_latencia_sla
        CHECK (tiempo_proceso_ms IS NULL OR tiempo_proceso_ms <= 2000)
        NOT VALID;
ALTER TABLE modulo4.predicciones
    VALIDATE CONSTRAINT chk_pred_latencia_sla;

-- [RF-67] Alertas: fecha_generacion no futura
ALTER TABLE modulo4.alertas_patologicas
    ADD CONSTRAINT chk_alerta_fecha_no_futura
        CHECK (fecha_generacion <= NOW())
        NOT VALID;
ALTER TABLE modulo4.alertas_patologicas
    VALIDATE CONSTRAINT chk_alerta_fecha_no_futura;

-- [RF-66] Observaciones clínicas: fecha no futura
ALTER TABLE modulo4.observaciones_clinicas
    ADD CONSTRAINT chk_obs_fecha_no_futura
        CHECK (fecha <= NOW())
        NOT VALID;
ALTER TABLE modulo4.observaciones_clinicas
    VALIDATE CONSTRAINT chk_obs_fecha_no_futura;

-- [RF-70] Datasets: fecha_inicio_datos no futura
ALTER TABLE modulo4.datasets
    ADD CONSTRAINT chk_ds_fecha_inicio_no_futura
        CHECK (fecha_inicio_datos <= CURRENT_DATE)
        NOT VALID;
ALTER TABLE modulo4.datasets
    VALIDATE CONSTRAINT chk_ds_fecha_inicio_no_futura;

-- [RF-72] Auditorías: fecha_accion no futura
ALTER TABLE modulo4.auditorias_predicciones
    ADD CONSTRAINT chk_auditoria_fecha_no_futura
        CHECK (fecha_accion <= NOW())
        NOT VALID;
ALTER TABLE modulo4.auditorias_predicciones
    VALIDATE CONSTRAINT chk_auditoria_fecha_no_futura;

-- [RF-70] Métricas drift: fecha_calculo no futura
ALTER TABLE modulo4.metricas_drift
    ADD CONSTRAINT chk_drift_fecha_no_futura
        CHECK (fecha_calculo <= NOW())
        NOT VALID;
ALTER TABLE modulo4.metricas_drift
    VALIDATE CONSTRAINT chk_drift_fecha_no_futura;


-- ================================================================
-- PARTE 5 — ÍNDICES ÚNICOS PARCIALES Y DE DESEMPEÑO
-- ================================================================

-- [RF-68, RF-69] Solo puede haber UNA versión del modelo en producción.
-- Restricción explícita RF-69: "despliegue OTA activa una versión a la vez."
-- EJECUTAR BLOQUE 0 [P1] si hay múltiples versiones en producción.
CREATE UNIQUE INDEX IF NOT EXISTS uix_una_version_en_produccion
    ON modulo4.versiones_modelos (esta_produccion)
    WHERE esta_produccion = true;

-- [RF-66] Índice de desempeño: historial diagnóstico por activo biológico
-- Optimiza RF-66: consulta del historial de predicciones por activo
CREATE INDEX IF NOT EXISTS idx_predicciones_observacion_fecha
    ON modulo4.predicciones (id_observacion, fecha_prediccion DESC);

-- [RF-67] Índice de desempeño: alertas activas por finca y criticidad
-- Optimiza el dashboard de alertas pendientes/críticas
CREATE INDEX IF NOT EXISTS idx_alertas_finca_estado_criticidad
    ON modulo4.alertas_patologicas (id_finca, estado_alerta, nivel_criticidad)
    WHERE estado_alerta IN ('PENDIENTE', 'NOTIFICADA');

-- [RF-67] Índice: alertas por activo biológico y patología
CREATE INDEX IF NOT EXISTS idx_alertas_activo_patologia
    ON modulo4.alertas_patologicas (id_activo_biologico, id_patologia, fecha_generacion DESC);

-- [RF-70] Índice: métricas de drift por modelo y tipo (detección de degradación)
CREATE INDEX IF NOT EXISTS idx_drift_modelo_tipo_fecha
    ON modulo4.metricas_drift (id_modelo_version, tipo_metrica, fecha_calculo DESC);

-- [RF-66] Índice: observaciones clínicas por activo y fecha
CREATE INDEX IF NOT EXISTS idx_obs_activo_fecha
    ON modulo4.observaciones_clinicas (id_activo_biologico, fecha DESC);

-- [RF-72] Índice: auditorías por predicción y acción (trazabilidad)
CREATE INDEX IF NOT EXISTS idx_auditoria_prediccion_accion
    ON modulo4.auditorias_predicciones (id_prediccion, accion, fecha_accion DESC);


-- ================================================================
-- REFERENCIA: CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (no se re-ejecutan; listados para consulta)
-- ================================================================
--
-- CHECKs inline en el DDL (ya activos, no se re-ejecutan):
--   chk_criticidad (alertas_patologicas):
--     nivel_criticidad IN ('CRITICA','ALTA','MEDIA','BAJA')
--   chk_fechas_ciclo (ciclos_entrenamientos):
--     fecha_final_planificada >= fecha_inicio_planificada
--   chk_fechas_ds (datasets):
--     fecha_fin_datos >= fecha_inicio_datos
--   chk_split_ds (datasets):
--     porcentaje_train + porcentaje_test = 100
--   chk_intensidad (detalles_signos):
--     intensidad BETWEEN 1 AND 5
--   chk_bcs (observaciones_clinicas):
--     condicion_corporal BETWEEN 1.0 AND 5.0
--   chk_temp_rectal (observaciones_clinicas):
--     temperatura_rectal BETWEEN 35 AND 43
--   chk_sensibilidad (patologias_signos):
--     sensibilidad BETWEEN 0 AND 1
--   chk_umbral_alerta (patologias_signos):
--     peso_relativo BETWEEN 0 AND 1
--   chk_probabilidad (predicciones):
--     probabilidad_pct BETWEEN 0 AND 100
--   chk_umbral_pred (predicciones):
--     umbral_usado BETWEEN 0 AND 100
--   chk_auc (versiones_modelos):
--     auc_roc BETWEEN 0 AND 1
--   chk_umbral_version (versiones_modelos):
--     umbral_clasificacion BETWEEN 0 AND 100
--
-- FKs con NOT VALID (activadas en PARTE 1):
--   fk_alerta_patologica_prediccion
--   fk_auditoria_prediccion_id
--   fk_ciclo_entrenamiento_modelo_anterior
--   fk_ciclo_entrenamiento_modelo_nuevo
--   fk_dataset_version_modelo
--   fk_detalle_signo_clinico
--   fk_detalle_signo_observacion
--   fk_metrica_drift_modelo_version
--   fk_patologia_signo_clinico
--   fk_prediciones_observacion_clinicas
--   fk_prediciones_observacion_modelo
--
-- FKs ELIMINADAS EN MIGRACIÓN (sin FK formal — referencias lógicas):
--   fk_alerta_patologica_activo_biologico → modulo2.activos_biologicos
--   fk_alerta_patologica_finca            → modulo9.fincas
--   fk_alerta_patologica_patologia        → modulo9.patologias
--   fk_alerta_patologica_usuario          → modulo1.usuarios
--   fk_auditoria_prediccion_usuario       → modulo1.usuarios
--   fk_ciclo_entrenamiento_usuario_aprobador → modulo1.usuarios
--   fk_observacion_clinica_activo_biologico  → modulo2.activos_biologicos
--   fk_observacion_clinica_usuario           → modulo1.usuarios
--   fk_patologia_signo_patologia             → modulo9.patologias
--   fk_prediciones_patologia                 → modulo9.patologias
--   fk_versione_modelo_usuario               → modulo1.usuarios
-- ================================================================
