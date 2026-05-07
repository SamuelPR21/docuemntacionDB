-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 4
-- ==============================================================
--
-- TABLAS DEL MÓDULO 4 (verificadas contra backup4_0_0.sql):
--   1. signos_clinicos
--   2. versiones_modelos
--   3. datasets
--   4. patologias_signos
--   5. ciclos_entrenamientos
--   6. observaciones_clinicas
--   7. predicciones
--   8. alertas_patologicas
--   9. auditorias_predicciones
--  10. metricas_drift
--  11. detalles_signos
--
-- DEPENDENCIAS EXTERNAS (sin FK formal en el backup — referencias lógicas):
--   - modulo1.usuarios          → id_usuario en varias tablas
--   - modulo2.activos_biologicos → id_activo_biologico
--   - modulo9.patologias         → id_patologia
--   - modulo9.fincas             → id_finca
--   - modulo1.notificaciones     → id_notificacion
--
-- NOTA: Las FKs hacia módulos externos (modulo1, modulo2, modulo9)
--   aparecen como DROP CONSTRAINT en el backup, lo que indica que
--   fueron eliminadas en una migración. Las referencias cruzadas
--   existen como dependencias lógicas (sin FK formal activa).
--   Las FKs internas de módulo 4 SÍ existen con NOT VALID.
--
-- ENUMs DEL MÓDULO 4 (verificar antes de ejecutar):
--   [E1] enum_alerta_patologia_estado:
--        SELECT enum_range(NULL::modulo4.enum_alerta_patologia_estado);
--        Valores: 'PENDIENTE','NOTIFICADA','ATENDIDA','FALSO_POSITIVO','CERRADA'
--
--   [E2] enum_auditoria_prediccion_accion:
--        SELECT enum_range(NULL::modulo4.enum_auditoria_prediccion_accion);
--        Valores: 'INSERT','UPDATE','ALERTA_ACTIVADA','VALIDACION_VET'
--
--   [E3] enum_ciclo_entrenamiento_estado_ciclo:
--        SELECT enum_range(NULL::modulo4.enum_ciclo_entrenamiento_estado_ciclo);
--        Valores: 'PLANIFICADO','EN_PROCESO','COMPLETADO','FALLIDO','CANCELADO'
--
--   [E4] enum_ciclo_entrenamiento_tipo:
--        SELECT enum_range(NULL::modulo4.enum_ciclo_entrenamiento_tipo);
--        Valores: 'SEMESTRAL','DRIFT_DETECTADO','MANUAL'
--
--   [E5] enum_datset_semestre:
--        SELECT enum_range(NULL::modulo4.enum_datset_semestre);
--        Valores: 'S1','S2'
--
--   [E6] enum_metrica_drifft_tipo:
--        SELECT enum_range(NULL::modulo4.enum_metrica_drifft_tipo);
--        Valores: 'PSI','KL_DIVERGENCE','ACCURACY_DRIFT','DISTRIBUCION_FEATURE'
--
--   [E7] enum_metrica_drifft_accion_tomada:
--        SELECT enum_range(NULL::modulo4.enum_metrica_drifft_accion_tomada);
--        Valores: 'NINGUNA','ALERTA_GENERADA','REENTRENAMIENTO_INICIADO'
--
--   [E8] enum_predicciones_clase:
--        SELECT enum_range(NULL::modulo4.enum_predicciones_clase);
--        Valores: 'POSITIVO','NEGATIVO','INDETERMINADO'
--
--   [E9] enum_signo_clinico_tipo:
--        SELECT enum_range(NULL::modulo4.enum_signo_clinico_tipo);
--        Valores: 'FISICO','COMPORTAMENTAL','METABOLICO','PODAL'
--
--   [E10] enum_version_modelo_algoritmo:
--        SELECT enum_range(NULL::modulo4.enum_version_modelo_algoritmo);
--        Valores: 'RANDOM_FOREST','XGBOOST','RED_BAYESIANA','MLP'
-- ==============================================================


-- ==============================================================
-- PRECONDICIÓN 0 — VERIFICAR DEPENDENCIAS EXTERNAS
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo1.usuarios
        WHERE id_usuario IN (1, 2)
        HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo1.usuarios debe contener '
            'usuarios con id=1 e id=2. Ejecute primero M1.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.patologias
        WHERE id_patologias IN (1, 2, 3)
        HAVING COUNT(*) = 3
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.patologias debe contener '
            'al menos 3 registros. Ejecute primero M9.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico IN (1, 2, 3)
        HAVING COUNT(*) = 3
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo2.activos_biologicos debe '
            'contener al menos 3 registros. Ejecute primero M2.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK internas):
--   1. signos_clinicos
--   2. versiones_modelos
--   3. datasets                ← depende de versiones_modelos
--   4. patologias_signos       ← depende de signos_clinicos
--   5. ciclos_entrenamientos   ← depende de versiones_modelos
--   6. observaciones_clinicas  ← depende de activos (modulo2)
--   7. predicciones            ← depende de observaciones y versiones
--   8. alertas_patologicas     ← depende de predicciones
--   9. auditorias_predicciones ← depende de predicciones
--  10. metricas_drift          ← depende de versiones_modelos
--  11. detalles_signos         ← depende de observaciones y signos
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. SIGNOS CLÍNICOS
--
-- Restricciones de negocio:
--   - Nombre único (UQ declarado en script de constraints)
--   - Al menos 2 signos por patología para que sea inferible (RF-64)
--   - Los tipos mapean a las categorías de variables IoT del catálogo I3P-1
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.signos_clinicos
    (nombre, descripcion, escala_medicion, tipo, requiere_laboratorio)
VALUES
-- Signos físicos medibles por IoT (biométricos — RF-53)
('Temperatura corporal elevada',
 'Temperatura rectal superior al rango fisiológico normal para la especie. '
 'Indicador primario de procesos infecciosos sistémicos.',
 '°C (35.0 – 43.0)', 'FISICO', false),

('Frecuencia respiratoria aumentada',
 'Número de ciclos respiratorios por minuto por encima del rango normal. '
 'Indicador de distress respiratorio, fiebre o estrés térmico.',
 'rpm (10 – 80)', 'FISICO', false),

('Frecuencia cardíaca elevada',
 'Número de latidos por minuto por encima del rango normal para la especie. '
 'Asociado con fiebre, dolor, deshidratación o compromiso cardiovascular.',
 'bpm (40 – 120)', 'FISICO', false),

('Condición corporal baja',
 'Puntuación BCS (Body Condition Score) inferior al mínimo aceptable. '
 'Indica desnutrición, enfermedad crónica o parasitosis severa.',
 'BCS 1.0 – 5.0', 'FISICO', false),

-- Signos comportamentales detectables por actividad IoT
('Inactividad o postración prolongada',
 'Reducción significativa de la actividad motora normal del animal. '
 'Indicador inespecífico pero sensible de malestar sistémico.',
 'Escala: 0=postrado, 5=normal', 'COMPORTAMENTAL', false),

('Reducción del consumo de alimento',
 'Disminución del apetito medible respecto a la línea base del animal. '
 'Asociado con fiebre, dolor abdominal, infecciones y toxemia.',
 'Porcentaje respecto baseline', 'COMPORTAMENTAL', false),

('Aislamiento del grupo',
 'Separación voluntaria del animal del grupo social habitual. '
 'Indicador comportamental de dolor, debilidad o estado previo a parto.',
 'Booleano / observación directa', 'COMPORTAMENTAL', false),

-- Signos metabólicos (requieren laboratorio o análisis)
('Hipocalcemia clínica',
 'Concentración sérica de calcio inferior al nivel mínimo funcional. '
 'Causa paresia del posparto (fiebre de leche) en vacas de alta producción.',
 'mmol/L (< 2.0 = hipocalcemia)', 'METABOLICO', true),

('Cetosis subclínica',
 'Elevación de cuerpos cetónicos en sangre sin signos clínicos evidentes. '
 'Detectable mediante tiras reactivas o sensores de cetona en leche.',
 'mmol/L BHBA (> 1.4 = riesgo)', 'METABOLICO', true),

-- Signos podales (pódales)
('Cojera grado 2 o superior',
 'Dificultad para desplazarse con apoyo irregular en uno o más miembros. '
 'Grado 2 = cojera visible en movimiento; grado 3+ = sin apoyo.',
 'Escala 1-5 (Sprecher)', 'PODAL', false),

-- Signo ambiental: temperatura ambiental extrema (entrada desde M3)
('Exposición a temperatura ambiental extrema',
 'Temperatura ambiental registrada por sensores IoT por encima del umbral '
 'crítico para la especie. Factor precipitante de estrés térmico.',
 '°C (> 30 = estrés leve; > 36 = crítico)', 'FISICO', false);


-- ─────────────────────────────────────────────────────────────
-- 2. VERSIONES DEL MODELO
--
-- Restricciones de negocio (RF-68):
--   - Solo puede haber una versión en producción a la vez
--   - hash_artecfacto (typo en DDL): SHA-256 del artefacto
--   - Solo ONNX o TensorFlow SavedModel (RF-68 restricción 2)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.versiones_modelos
    (nombre_version, algoritmo, descripcion,
     fecha_entrenamiento, fecha_despliegue, fecha_retiro,
     accuracy, auc_roc, f1_score, precision_modelo, recall_modelo,
     umbral_clasificacion, ruta_artefacto, hash_artecfacto,
     esta_produccion, id_usuario)
VALUES
-- Versión 1: modelo base inicial (retirado)
('v1.0-RF-2024S1',
 'RANDOM_FOREST',
 'Modelo Random Forest inicial. Entrenado con datos del primer semestre 2024. '
 'Cubre 3 patologías: estrés térmico, cetosis y mastitis bovina. '
 'Dataset: 1200 registros, 70/30 train-test. '
 'Retirado al desplegar v1.1 con mejor AUC-ROC.',
 '2024-01-15 08:00:00+00', '2024-02-01 00:00:00+00', '2024-07-01 00:00:00+00',
 0.8230, 0.8745, 0.7980, 0.8310, 0.7680,
 70.00,
 's3://pecuaria-models/v1.0-RF-2024S1/model.onnx',
 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
 false, 1),

-- Versión 2: modelo mejorado (actualmente en producción)
('v1.1-RF-2024S2',
 'RANDOM_FOREST',
 'Random Forest v1.1. Entrenado con datos completos de 2024. '
 'Mejoras: +5 features de telemetría IoT (M03), ampliado a 4 patologías. '
 'Dataset: 2800 registros balanceados, split 75/25. '
 'AUC-ROC mejora de 0.87 a 0.91 respecto a v1.0. '
 'Modelo actualmente en producción.',
 '2024-07-10 09:00:00+00', '2024-08-01 00:00:00+00', NULL,
 0.8890, 0.9120, 0.8640, 0.8820, 0.8480,
 75.00,
 's3://pecuaria-models/v1.1-RF-2024S2/model.onnx',
 'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3',
 true, 1),

-- Versión 3: modelo XGBoost experimental (no desplegado)
('v2.0-XGB-2025S1-EXP',
 'XGBOOST',
 'XGBoost experimental para evaluación comparativa. '
 'Entrenado con metodología CRISP-DM ciclo 2025-S1. '
 'Pendiente validación veterinaria (RF-71) antes de despliegue. '
 'No está en producción.',
 '2025-01-20 10:00:00+00', NULL, NULL,
 0.9010, 0.9280, 0.8850, 0.8970, 0.8740,
 72.00,
 's3://pecuaria-models/v2.0-XGB-2025S1-EXP/model.onnx',
 'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4',
 false, 1);

-- ─────────────────────────────────────────────────────────────
-- 3. DATASETS
--
-- Restricciones de negocio (RF-70):
--   - Solo datos con apto_para_ia = true (RF-62)
--   - Dataset hash obligatorio para trazabilidad
--   - registros_positivos + registros_negativos ≈ total_registros
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.datasets
    (id_version_modelo, nombre,
     fecha_inicio_datos, fecha_fin_datos,
     total_resgistros, registros_positivos, registros_negativos,
     enfermedades_incluidas, descripcion,
     porcentaje_train, porcentaje_test,
     tiene_variables_ambientales, semestre_huila)
VALUES
-- Dataset de v1.0
(1,
 'DS-2024S1-Bovinos-Hato-Principal',
 '2023-07-01', '2023-12-31',
 1200, 380, 820,
 '["estres_termico", "cetosis_subclinica", "mastitis_bovina"]',
 'Dataset semestre 1 2024 (datos jul-dic 2023). '
 'Fuente: hato principal Finca El Remanso. '
 'Incluye variables de telemetría IoT (M03) y observaciones veterinarias manuales. '
 'Pre-procesado con RF-62: 100% registros con apto_para_ia=true. '
 'Hash SHA-256: d4e5f6a7b8c9d0e1f2a3.',
 70, 30,
 true, 'S1'),

-- Dataset de v1.1
(2,
 'DS-2024S2-Bovinos-Multiespecie',
 '2024-01-01', '2024-06-30',
 2800, 910, 1890,
 '["estres_termico", "cetosis_subclinica", "mastitis_bovina", "hipocalcemia_posparto"]',
 'Dataset semestre 2 2024. Multiespecie: bovinos y caprinos. '
 'Integra telemetría IoT (M03) con 15 features sensoriales '
 'y 8 variables clínicas manuales. '
 'Balanceo SMOTE aplicado en clase positiva. '
 'Validado con RF-62: 0 registros excluidos por calidad. '
 'Hash SHA-256: e5f6a7b8c9d0e1f2a3b4.',
 75, 25,
 true, 'S2'),

-- Dataset de v2.0 experimental
(3,
 'DS-2025S1-XGB-Experimental',
 '2024-07-01', '2024-12-31',
 3500, 1120, 2380,
 '["estres_termico", "cetosis_subclinica", "mastitis_bovina", "hipocalcemia_posparto", "cojera_bovina"]',
 'Dataset experimental para XGBoost 2025-S1. '
 'Primer dataset con 5 patologías y 20 features. '
 'Incluye datos de contagio del motor RF-67. '
 'Pendiente validación antes de uso en producción.',
 75, 25,
 true, 'S1');


-- ─────────────────────────────────────────────────────────────
-- 4. PATOLOGÍAS-SIGNOS
--
-- Restricciones de negocio (RF-64):
--   - Al menos 2 variables sensóricas por patología para ser inferible
--   - peso_relativo: importancia del signo en el diagnóstico
--   - sensibilidad: probabilidad de que el signo esté presente si hay patología
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.patologias_signos
    (id_signo_clinico, id_patologia, peso_relativo, sensibilidad, fuente_evidencia)
VALUES
-- Patología 1 (modulo9): Estrés térmico bovino
-- Signos: temperatura corporal, FC, FR, inactividad, temperatura ambiental
(1, 1, 0.3500, 0.8900,
 'NRC 1971 - Thermal effects on dairy cows; Collier et al. 2012 - THI thresholds'),
(2, 1, 0.2500, 0.7800,
 'Du Preez et al. 1990 - Respiration rate as heat stress indicator'),
(3, 1, 0.1800, 0.6500,
 'West 2003 - Physiological indicators of heat stress in dairy cattle'),
(5, 1, 0.2000, 0.7200,
 'Collier & Gebremedhin 2015 - Activity reduction in thermal stress'),
(11, 1, 0.1200, 0.9500,
 'Kadzere et al. 2002 - Heat stress in lactating dairy cows - review'),

-- Patología 2 (modulo9): Cetosis subclínica bovina
-- Signos: condición corporal, reducción apetito, cetosis, FC
(4, 2, 0.3000, 0.7500,
 'Duffield 2000 - Subclinical ketosis in lactating dairy cattle'),
(6, 2, 0.2800, 0.8200,
 'Ospina et al. 2010 - Association between SCK and health outcomes'),
(9, 2, 0.4000, 0.9100,
 'McArt et al. 2012 - Hyperketonemia in early lactating dairy cattle'),
(3, 2, 0.1500, 0.5500,
 'Warnick et al. 2001 - Heart rate changes in periparturient cows'),

-- Patología 3 (modulo9): Hipocalcemia posparto (fiebre de leche)
-- Signos: hipocalcemia, temperatura, postración, FC
(8, 3, 0.5500, 0.9500,
 'Goff 2008 - The monitoring, prevention and treatment of milk fever'),
(1, 3, 0.2000, 0.6800,
 'Reinhardt & Reinhardt 1982 - Temperature in parturient bovines'),
(5, 3, 0.3000, 0.8800,
 'Shappell et al. 1987 - Recumbency, ataxia and parturient paresis'),
(3, 3, 0.1800, 0.7200,
 'Horst et al. 1997 - Calcium and vitamin D metabolism in periparturient cows');


-- ─────────────────────────────────────────────────────────────
-- 5. CICLOS DE ENTRENAMIENTO
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.ciclos_entrenamientos
    (id_modelo_version_anterior, id_modelo_version_nueva,
     semestre, estado_ciclo,
     fecha_inicio_planificada, fecha_final_planificada,
     inicio_real, inicio_planificada,
     tipo, drift_score, metrica_comparacion_auc,
     es_aprobado_despliegue, id_usuario_aprobado, notas)
VALUES
-- Ciclo 1: primer entrenamiento semestral (completado, desplegado como v1.0)
(NULL, 1,
 '2024-S1', 'COMPLETADO',
 '2024-01-10', '2024-01-31',
 '2024-01-15 08:00:00+00', '2024-01-10 09:00:00+00',
 'SEMESTRAL', NULL, NULL,
 true, 1,
 'Primer ciclo de entrenamiento CRISP-DM. Datos: DS-2024S1. '
 'No hay versión anterior (modelo inaugural). AUC-ROC baseline: 0.8745. '
 'Aprobado por equipo veterinario para despliegue.'),

-- Ciclo 2: reentrenamiento semestral (completado, desplegado como v1.1)
(1, 2,
 '2024-S2', 'COMPLETADO',
 '2024-07-05', '2024-07-20',
 '2024-07-10 09:00:00+00', '2024-07-05 08:00:00+00',
 'SEMESTRAL', 0.0420, 0.9120,
 true, 1,
 'Reentrenamiento semestral CRISP-DM. Datos: DS-2024S2. '
 'Drift detectado en feature temperatura_corporal (PSI=0.18 > umbral 0.15). '
 'AUC-ROC mejoró de 0.8745 a 0.9120 (+0.0375). '
 'Nuevo modelo aprobado y desplegado en producción.'),

-- Ciclo 3: ciclo experimental en curso
(2, 3,
 '2025-S1', 'EN_PROCESO',
 '2025-01-15', '2025-02-15',
 '2025-01-20 10:00:00+00', '2025-01-15 09:00:00+00',
 'SEMESTRAL', NULL, NULL,
 NULL, NULL,
 'Ciclo experimental con XGBoost. Dataset DS-2025S1-XGB. '
 'Pendiente validación clínica (RF-71) y aprobación de despliegue. '
 'Prueba comparativa contra Random Forest v1.1.');


-- ─────────────────────────────────────────────────────────────
-- 6. OBSERVACIONES CLÍNICAS
--
-- Restricciones de negocio (RF-65):
--   - fuente_datos: 'manual' | 'iot' | 'mixta'
--   - Las observaciones son el punto de entrada al motor de inferencia
--   - Inmutabilidad: no se permite edición post-inserción
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.observaciones_clinicas
    (id_activo_biologico, id_usuario,
     fecha, temperatura_rectal,
     frecuencia_cardiaca, frecuencia_respiratoria,
     condicion_corporal, observacion, fuente_datos)
VALUES
-- Observación 1: BOV-001 Holstein — parámetros normales (referencia)
(1, 1,
 NOW() - INTERVAL '5 days',
 38.4, 68, 26, 3.5,
 'Observación rutinaria semanal. Animal en producción normal. '
 'Sin signos clínicos evidentes. BCS 3.5 adecuado para etapa productiva.',
 'mixta'),

-- Observación 2: BOV-003 Simmental — estrés térmico leve
(3, 1,
 NOW() - INTERVAL '3 days',
 39.8, 88, 42, 3.0,
 'Temperatura corporal elevada (39.8 °C). Frecuencia respiratoria 42 rpm, '
 'por encima del rango normal (26-30). Animal en zona de sombra. '
 'Temperatura ambiental registrada por IoT: 35.2 °C. '
 'Sospecha de estrés térmico leve. Se incrementa suministro de agua.',
 'mixta'),

-- Observación 3: BOV-004 Normando — síntomas de cetosis subclínica
(4, 2,
 NOW() - INTERVAL '2 days',
 38.9, 74, 28, 2.5,
 'Vaca Normando en primer mes postparto. BCS 2.5 (por debajo del ideal). '
 'Reducción aproximada del 30% en consumo de alimento. '
 'Prueba de cetona en leche: positivo (++). '
 'Se recomienda propilen glicol oral y monitoreo estrecho.',
 'manual'),

-- Observación 4: BOV-002 Brahman — parámetros normales, monitoreo rutinario
(2, 1,
 NOW() - INTERVAL '1 day',
 38.1, 62, 22, 3.8,
 'Novilla Brahman en desarrollo. Todos los parámetros dentro de rango normal. '
 'BCS 3.8 adecuado. Sin signos de enfermedad.',
 'iot'),

-- Observación 5: BOV-003 Simmental — seguimiento al estrés térmico
(3, 1,
 NOW() - INTERVAL '12 hours',
 40.2, 95, 48, 2.8,
 'Segundo control post-alerta estrés térmico. Temperatura escaló a 40.2 °C. '
 'Frecuencia respiratoria 48 rpm (zona crítica). BCS bajó a 2.8. '
 'Animal aislado y con terapia de refresco. Solicitud de inferencia urgente.',
 'mixta');


-- ─────────────────────────────────────────────────────────────
-- 7. PREDICCIONES
--
-- Restricciones de negocio (RF-65, RF-66):
--   - Inmutabilidad total post-inserción
--   - supera_umbral = (probabilidad_pct >= umbral_usado)
--   - tiempo_proceso_ms <= 2000 (SLA RF-65)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.predicciones
    (id_observacion, id_patologia, id_version_modelo,
     probabilidad_pct, supera_umbral, umbral_usado,
     clase_predicha, confianza_modelo,
     features_json, fecha_prediccion, tiempo_proceso_ms)
VALUES
-- Predicción 1: Obs.1 BOV-001 — estrés térmico NEGATIVO (normal)
(1, 1, 2,
 22.500, false, 75.00,
 'NEGATIVO', 0.9340,
 '{"temperatura_corporal": 38.4, "frecuencia_respiratoria": 26,
   "frecuencia_cardiaca": 68, "condicion_corporal": 3.5,
   "temperatura_ambiental": 27.8, "actividad_normalizada": 0.92}',
 NOW() - INTERVAL '5 days' + INTERVAL '30 seconds',
 187),

-- Predicción 2: Obs.2 BOV-003 — estrés térmico POSITIVO (alerta)
(2, 1, 2,
 82.300, true, 75.00,
 'POSITIVO', 0.7810,
 '{"temperatura_corporal": 39.8, "frecuencia_respiratoria": 42,
   "frecuencia_cardiaca": 88, "condicion_corporal": 3.0,
   "temperatura_ambiental": 35.2, "actividad_normalizada": 0.61}',
 NOW() - INTERVAL '3 days' + INTERVAL '45 seconds',
 234),

-- Predicción 3: Obs.3 BOV-004 — cetosis subclínica POSITIVO
(3, 2, 2,
 78.600, true, 75.00,
 'POSITIVO', 0.8120,
 '{"condicion_corporal": 2.5, "reduccion_apetito_pct": 30,
   "temperatura_corporal": 38.9, "frecuencia_cardiaca": 74,
   "bhba_estimado": 1.8, "dias_postparto": 28}',
 NOW() - INTERVAL '2 days' + INTERVAL '38 seconds',
 198),

-- Predicción 4: Obs.4 BOV-002 — estrés térmico NEGATIVO (normal)
(4, 1, 2,
 15.800, false, 75.00,
 'NEGATIVO', 0.9560,
 '{"temperatura_corporal": 38.1, "frecuencia_respiratoria": 22,
   "frecuencia_cardiaca": 62, "condicion_corporal": 3.8,
   "temperatura_ambiental": 26.4, "actividad_normalizada": 0.95}',
 NOW() - INTERVAL '1 day' + INTERVAL '22 seconds',
 145),

-- Predicción 5: Obs.5 BOV-003 — estrés térmico POSITIVO (crítico)
(5, 1, 2,
 94.100, true, 75.00,
 'POSITIVO', 0.9230,
 '{"temperatura_corporal": 40.2, "frecuencia_respiratoria": 48,
   "frecuencia_cardiaca": 95, "condicion_corporal": 2.8,
   "temperatura_ambiental": 36.8, "actividad_normalizada": 0.38}',
 NOW() - INTERVAL '12 hours' + INTERVAL '28 seconds',
 212);


-- ─────────────────────────────────────────────────────────────
-- 8. ALERTAS PATOLÓGICAS
--
-- Restricciones de negocio (RF-65, RF-67):
--   - Solo se genera alerta si supera_umbral = true en predicciones
--   - nivel_criticidad se deriva de probabilidad_pct:
--       >= 90 → CRITICA, >= 75 → ALTA, >= 60 → MEDIA, < 60 → BAJA
--   - id_notificacion referencia modulo1.notificaciones
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.alertas_patologicas
    (id_prediccion, id_activo_biologico, id_finca,
     id_patologia, probabilidad_pct, nivel_criticidad,
     estado_alerta, fecha_generacion, fecha_notificacion,
     id_usuario, diagnostico_confirmado, es_verdadero, id_notificacion)
VALUES
-- Alerta 1: BOV-003 estrés térmico — ALTA probabilidad (82.3%)
-- Obs.2 → Predicción 2
(2, 3, 1,
 1, 82.300, 'ALTA',
 'ATENDIDA', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '5 minutes',
 2,
 'Estrés térmico confirmado por médico veterinario. '
 'Temperatura corporal 39.8 °C con ambiente 35.2 °C. '
 'Tratamiento: incremento ventilación, suministro electrolitos, sombra adicional.',
 true, 1),

-- Alerta 2: BOV-004 cetosis subclínica — ALTA probabilidad (78.6%)
-- Obs.3 → Predicción 3
(3, 4, 1,
 2, 78.600, 'ALTA',
 'NOTIFICADA', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '3 minutes',
 2, NULL, NULL, 2),

-- Alerta 3: BOV-003 estrés térmico crítico — CRITICA probabilidad (94.1%)
-- Obs.5 → Predicción 5
(5, 3, 1,
 1, 94.100, 'CRITICA',
 'PENDIENTE', NOW() - INTERVAL '12 hours', NULL,
 NULL, NULL, NULL, 3);


-- ─────────────────────────────────────────────────────────────
-- 9. AUDITORÍAS DE PREDICCIONES
--
-- Restricciones de negocio (RF-72):
--   - Append-only: no se permite UPDATE ni DELETE
--   - Cubre todo el ciclo: INSERT → ALERTA_ACTIVADA → VALIDACION_VET
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.auditorias_predicciones
    (id_prediccion, accion, id_usuario,
     fecha_accion, datos_anteriores, datos_nuevos,
     ip_origen, servicio_origen)
VALUES
-- Auditoría Pred.1: inserción predicción BOV-001 normal
(1, 'INSERT', NULL,
 NOW() - INTERVAL '5 days' + INTERVAL '30 seconds',
 NULL,
 '{"id_prediccion": 1, "probabilidad_pct": 22.5, "clase_predicha": "NEGATIVO",
   "supera_umbral": false, "umbral_usado": 75.0}',
 '10.0.1.15', 'motor-inferencia-rf65-v1.1'),

-- Auditoría Pred.2: inserción predicción BOV-003 estrés positivo
(2, 'INSERT', NULL,
 NOW() - INTERVAL '3 days' + INTERVAL '45 seconds',
 NULL,
 '{"id_prediccion": 2, "probabilidad_pct": 82.3, "clase_predicha": "POSITIVO",
   "supera_umbral": true, "umbral_usado": 75.0}',
 '10.0.1.15', 'motor-inferencia-rf65-v1.1'),

-- Auditoría Pred.2: alerta activada
(2, 'ALERTA_ACTIVADA', NULL,
 NOW() - INTERVAL '3 days' + INTERVAL '50 seconds',
 NULL,
 '{"id_alerta": 1, "nivel_criticidad": "ALTA", "estado_alerta": "PENDIENTE",
   "probabilidad_pct": 82.3}',
 '10.0.1.15', 'motor-alertas-rf67'),

-- Auditoría Pred.2: validación veterinaria (confirmó estrés térmico)
(2, 'VALIDACION_VET', 2,
 NOW() - INTERVAL '3 days' + INTERVAL '4 hours',
 '{"estado_alerta": "NOTIFICADA", "diagnostico_confirmado": null, "es_verdadero": null}',
 '{"estado_alerta": "ATENDIDA",
   "diagnostico_confirmado": "Estres termico confirmado. Temperatura 39.8 °C con ambiente 35.2 °C.",
   "es_verdadero": true}',
 '192.168.1.42', 'interfaz-veterinaria-web'),

-- Auditoría Pred.3: inserción predicción BOV-004 cetosis
(3, 'INSERT', NULL,
 NOW() - INTERVAL '2 days' + INTERVAL '38 seconds',
 NULL,
 '{"id_prediccion": 3, "probabilidad_pct": 78.6, "clase_predicha": "POSITIVO",
   "supera_umbral": true, "umbral_usado": 75.0}',
 '10.0.1.15', 'motor-inferencia-rf65-v1.1'),

-- Auditoría Pred.3: alerta activada
(3, 'ALERTA_ACTIVADA', NULL,
 NOW() - INTERVAL '2 days' + INTERVAL '42 seconds',
 NULL,
 '{"id_alerta": 2, "nivel_criticidad": "ALTA", "estado_alerta": "PENDIENTE"}',
 '10.0.1.15', 'motor-alertas-rf67'),

-- Auditoría Pred.5: inserción predicción BOV-003 crítico
(5, 'INSERT', NULL,
 NOW() - INTERVAL '12 hours' + INTERVAL '28 seconds',
 NULL,
 '{"id_prediccion": 5, "probabilidad_pct": 94.1, "clase_predicha": "POSITIVO",
   "supera_umbral": true, "umbral_usado": 75.0}',
 '10.0.1.15', 'motor-inferencia-rf65-v1.1'),

-- Auditoría Pred.5: alerta crítica activada
(5, 'ALERTA_ACTIVADA', NULL,
 NOW() - INTERVAL '12 hours' + INTERVAL '32 seconds',
 NULL,
 '{"id_alerta": 3, "nivel_criticidad": "CRITICA", "estado_alerta": "PENDIENTE"}',
 '10.0.1.15', 'motor-alertas-rf67');


-- ─────────────────────────────────────────────────────────────
-- 10. MÉTRICAS DE DRIFT
--
-- Restricciones de negocio (RF-70):
--   - supera_umbral_drift = (valor_metrica > umbral_alerta_drift)
--   - PSI > 0.25 → drift severo; PSI 0.10-0.25 → moderado
--   - accion_tomada: NINGUNA / ALERTA_GENERADA / REENTRENAMIENTO_INICIADO
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.metricas_drift
    (id_modelo_version, fecha_calculo, tipo_metrica,
     feature_evaluado, valor_metrica, umbral_alerta_drift,
     supera_umbral_drift, periodo_referencia, periodo_actual,
     accion_tomada)
VALUES
-- Drift v1.0: PSI de temperatura corporal (supera umbral → causa de reentrenamiento)
(1, NOW() - INTERVAL '120 days', 'PSI',
 'temperatura_corporal', 0.187500, 0.150000,
 true, '2023-S2', '2024-S1',
 'REENTRENAMIENTO_INICIADO'),

-- Drift v1.0: Accuracy global (monitoreo general)
(1, NOW() - INTERVAL '120 days', 'ACCURACY_DRIFT',
 NULL, 0.043200, 0.050000,
 false, '2023-S2', '2024-S1',
 'NINGUNA'),

-- Drift v1.1: PSI de temperatura corporal (bajo umbral — modelo estable)
(2, NOW() - INTERVAL '30 days', 'PSI',
 'temperatura_corporal', 0.089300, 0.150000,
 false, '2024-S1', '2024-S2',
 'NINGUNA'),

-- Drift v1.1: PSI de frecuencia respiratoria
(2, NOW() - INTERVAL '30 days', 'PSI',
 'frecuencia_respiratoria', 0.112400, 0.150000,
 false, '2024-S1', '2024-S2',
 'NINGUNA'),

-- Drift v1.1: KL Divergence en condición corporal
(2, NOW() - INTERVAL '30 days', 'KL_DIVERGENCE',
 'condicion_corporal', 0.034100, 0.100000,
 false, '2024-S1', '2024-S2',
 'NINGUNA'),

-- Drift v1.1: Accuracy global (monitoreo periódico — sin degradación)
(2, NOW() - INTERVAL '15 days', 'ACCURACY_DRIFT',
 NULL, 0.021600, 0.050000,
 false, '2024-S2-inicial', '2024-S2-actual',
 'NINGUNA'),

-- Drift v1.1: Alerta generada por distribución de feature temperatura ambiental
(2, NOW() - INTERVAL '7 days', 'DISTRIBUCION_FEATURE',
 'temperatura_ambiental', 0.163800, 0.150000,
 true, '2024-Q3', '2024-Q4',
 'ALERTA_GENERADA');


-- ─────────────────────────────────────────────────────────────
-- 11. DETALLES DE SIGNOS
--
-- UQ uq_det_obs_signo: (id_observaciones, id_signo_clinico)
-- Un signo no puede registrarse dos veces en la misma observación
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo4.detalles_signos
    (id_observaciones, id_signo_clinico,
     es_presente, valor_numerico, intensidad, notas)
VALUES
-- Observación 1 (BOV-001 normal): signos presentes con valores normales
(1, 1,  true,  38.4, 1, 'Temperatura normal para Holstein adulta en producción.'),
(1, 2,  true,  26.0, 1, 'Frecuencia respiratoria dentro de rango normal.'),
(1, 3,  true,  68.0, 1, 'Frecuencia cardíaca normal.'),
(1, 4,  true,  3.5,  2, 'BCS 3.5 — adecuado para etapa de producción.'),
(1, 5,  false, NULL, NULL, 'Sin signos de inactividad. Animal activo y alerta.'),

-- Observación 2 (BOV-003 estrés térmico leve):
(2, 1,  true,  39.8, 3, 'Temperatura elevada. Umbral fisiológico superado (>39.5 °C).'),
(2, 2,  true,  42.0, 3, 'FR aumentada. Zona de estrés leve (>30 rpm en bovinos).'),
(2, 3,  true,  88.0, 3, 'FC elevada respecto a baseline del animal.'),
(2, 5,  true,  NULL, 2, 'Reducción de actividad: buscando sombra y agua.'),
(2, 11, true,  35.2, 4, 'Temperatura ambiental 35.2 °C — zona de estrés térmico.'),

-- Observación 3 (BOV-004 cetosis):
(3, 1,  true,  38.9, 2, 'Temperatura levemente elevada pero dentro de rango.'),
(3, 4,  true,  2.5,  3, 'BCS 2.5 — bajo para posparto temprano (ideal ≥ 3.0).'),
(3, 6,  true,  NULL, 3, 'Reducción aprox 30% ingesta. Rechazo de concentrado.'),
(3, 9,  true,  1.8,  4, 'BHBA estimado 1.8 mmol/L — cetosis subclínica confirmada.'),

-- Observación 4 (BOV-002 normal):
(4, 1,  true,  38.1, 1, 'Temperatura normal.'),
(4, 2,  true,  22.0, 1, 'FR normal para Brahman en ambiente 26 °C.'),
(4, 4,  true,  3.8,  1, 'BCS 3.8 — excelente para novilla en desarrollo.'),
(4, 5,  false, NULL, NULL, 'Animal completamente activo. Sin signos de malestar.'),

-- Observación 5 (BOV-003 estrés térmico crítico):
(5, 1,  true,  40.2, 4, 'Temperatura crítica (>40 °C). Hipertermia confirmada.'),
(5, 2,  true,  48.0, 4, 'FR crítica (>45 rpm). Distress respiratorio evidente.'),
(5, 3,  true,  95.0, 4, 'FC muy elevada. Signos de compromiso cardiovascular.'),
(5, 5,  true,  NULL, 4, 'Postración parcial. Animal renuente a moverse.'),
(5, 11, true,  36.8, 5, 'Temperatura ambiental 36.8 °C — zona de estrés crítico.');
