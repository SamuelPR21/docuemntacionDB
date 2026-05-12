-- Vistas Modulo 4 del motor de inferencia y prediccion.

-- 1) Lista las patologias registradas, la especie relacionada, el tipo o categoria
-- de la patologia y su estado funcional. La relacion con especies se toma desde
-- modulo9.especies_patologias.
CREATE OR REPLACE VIEW modulo4.vw_catalogo_patologias AS
SELECT
    p.id_patologias AS id_patologia,
    p.nombre AS nombre_patologia,
    p.nombre_tecnico,
    e.id_especie,
    COALESCE(e.nombre, 'Sin especie asociada') AS especie,
    COALESCE(vars.variables_sensoricas_asociadas, 'Sin variables asociadas') AS variables_sensoricas_asociadas,
    p.categoria AS tipo_patologia,
    CASE
        WHEN p.es_activo IS TRUE THEN 'ACTIVA'
        ELSE 'INACTIVA'
    END AS estado,
    p.codigo_cie,
    p.descripcion
FROM modulo9.patologias p
LEFT JOIN modulo9.especies_patologias ep
  ON ep.id_patologia = p.id_patologias
LEFT JOIN modulo9.especies e
  ON e.id_especie = ep.id_especie
LEFT JOIN LATERAL (
    SELECT string_agg(DISTINCT va.nombre, ', ' ORDER BY va.nombre) AS variables_sensoricas_asociadas
    FROM modulo9.umbrales_ambientales ua
    JOIN modulo9.variables_ambientales va
      ON va.id_variable_ambiental = ua.id_variable_ambiental
    WHERE ua.id_especie = e.id_especie
      AND ua.es_activo IS TRUE
      AND va.es_activo IS TRUE
) vars ON true;

-- 2) Lista las caracteristicas usadas para una prediccion: signo clinico,
-- patologia, especie, peso/sensibilidad como umbrales de decision, version del
-- modelo y modo de ejecucion.
CREATE OR REPLACE VIEW modulo4.vw_configuracion_motor AS
WITH versiones_por_patologia AS (
    SELECT DISTINCT
        pred.id_patologia,
        pred.id_version_modelo
    FROM modulo4.predicciones pred
)
SELECT
    ps.id_patologia_signo,
    pat.id_patologias AS id_patologia,
    pat.nombre AS patologia,
    COALESCE(e.nombre, 'Sin especie asociada') AS especie,
    ps.peso_relativo AS peso_umbral,
    ps.sensibilidad AS sensibilidad_umbral,
    vm.id_version_modelo,
    vm.nombre_version AS version_modelo,
    vm.algoritmo AS tipo_modelo,
    CASE
        WHEN vm.id_version_modelo IS NULL THEN 'SIN_VERSION_ASOCIADA'
        WHEN vm.esta_produccion IS TRUE THEN 'PRODUCCION'
        WHEN vm.fecha_retiro IS NOT NULL THEN 'RETIRADO'
        WHEN vm.fecha_despliegue IS NOT NULL THEN 'DESPLEGADO_NO_PRODUCCION'
        ELSE 'ENTRENAMIENTO'
    END AS modo_ejecucion
FROM modulo4.patologias_signos ps
JOIN modulo9.patologias pat
  ON pat.id_patologias = ps.id_patologia
LEFT JOIN modulo9.especies_patologias ep
  ON ep.id_patologia = pat.id_patologias
LEFT JOIN modulo9.especies e
  ON e.id_especie = ep.id_especie
LEFT JOIN versiones_por_patologia vp
  ON vp.id_patologia = pat.id_patologias
LEFT JOIN modulo4.versiones_modelos vm
  ON vm.id_version_modelo = vp.id_version_modelo;

-- 3) Lista cada prediccion asociada a un activo biologico, incluyendo especie,
-- patologia evaluada, nivel de riesgo, confianza, latencia de procesamiento,
-- indicadores/features usados por el modelo y fecha de generacion.
CREATE OR REPLACE VIEW modulo4.vw_m04_monitoreo_inferencia AS
SELECT
    pred.id_prediccion,
    ab.id_activo_biologico,
	f.nombre AS finca,
    ab.identificador AS activo_biologico,
    ab.tipo AS tipo_activo,
    e.id_especie,
    e.nombre AS especie,
    pat.id_patologias AS id_patologia,
    pat.nombre AS patologia,
    vm.id_version_modelo,
    vm.nombre_version AS version_modelo,
    vm.algoritmo AS tipo_modelo,
    pred.probabilidad_pct,
    pred.umbral_usado,
    pred.supera_umbral,
    COALESCE(
        alerta.nivel_criticidad,
        CASE
            WHEN pred.probabilidad_pct >= 90 THEN 'CRITICO'
            WHEN pred.supera_umbral IS TRUE THEN 'ALTO'
            WHEN pred.probabilidad_pct >= (pred.umbral_usado * 0.75) THEN 'MEDIO'
            ELSE 'BAJO'
        END
    ) AS nivel_riesgo,
    pred.confianza_modelo AS confianza,
    pred.tiempo_proceso_ms,
    pred.features_json,
    
    pred.fecha_prediccion,
    oc.id_observacion_clinica,
    oc.fecha AS fecha_observacion_clinica
FROM modulo4.predicciones pred
JOIN modulo4.observaciones_clinicas oc
  ON oc.id_observacion_clinica = pred.id_observacion
JOIN modulo2.activos_biologicos ab
  ON ab.id_activo_biologico = oc.id_activo_biologico
LEFT JOIN modulo9.infraestructuras i
  ON i.id_infraestructura = ab.id_infraestructura
LEFT JOIN modulo9.fincas f
  ON f.id_finca = i.id_finca
JOIN modulo9.especies e
  ON e.id_especie = ab.id_especie
JOIN modulo9.patologias pat
  ON pat.id_patologias = pred.id_patologia
JOIN modulo4.versiones_modelos vm
  ON vm.id_version_modelo = pred.id_version_modelo
LEFT JOIN modulo4.alertas_patologicas alerta
  ON alerta.id_prediccion = pred.id_prediccion;


-- 4) Lista observaciones clinicas por activo biologico con fecha, condiciones
-- medidas y patologias relacionadas por las predicciones generadas desde esa
-- observacion. Se agrupa por observacion para evitar duplicar el registro
-- clinico cuando se evaluan varias patologias.
CREATE OR REPLACE VIEW modulo4.vw_m04_historial_diagnostico AS
SELECT
    oc.id_observacion_clinica,
    ab.id_activo_biologico,
    ab.identificador AS activo_biologico,
    ab.tipo AS tipo_activo,
    e.id_especie,
    e.nombre AS especie,
    oc.fecha,
    jsonb_build_object(
        'temperatura_rectal', oc.temperatura_rectal,
        'frecuencia_cardiaca', oc.frecuencia_cardiaca,
        'frecuencia_respiratoria', oc.frecuencia_respiratoria,
        'condicion_corporal', oc.condicion_corporal,
        'fuente_datos', oc.fuente_datos,
        'observacion', oc.observacion,
        'validada_por_veterinario', COALESCE(bool_or(ap.accion::text = 'VALIDACION_VET'), false)
    ) AS condiciones,
    COALESCE(
        string_agg(DISTINCT pat.nombre, ', ' ORDER BY pat.nombre),
        'Sin prediccion asociada'
    ) AS patologia,
    COUNT(DISTINCT pred.id_prediccion) AS total_predicciones_asociadas,
    u.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable
FROM modulo4.observaciones_clinicas oc
JOIN modulo2.activos_biologicos ab
  ON ab.id_activo_biologico = oc.id_activo_biologico
JOIN modulo9.especies e
  ON e.id_especie = ab.id_especie
LEFT JOIN modulo4.predicciones pred
  ON pred.id_observacion = oc.id_observacion_clinica
LEFT JOIN modulo9.patologias pat
  ON pat.id_patologias = pred.id_patologia
LEFT JOIN modulo4.auditorias_predicciones ap
  ON ap.id_prediccion = pred.id_prediccion
LEFT JOIN modulo1.usuarios u
  ON u.id_usuario = oc.id_usuario
GROUP BY
    oc.id_observacion_clinica,
    ab.id_activo_biologico,
    ab.identificador,
    ab.tipo,
    e.id_especie,
    e.nombre,
    oc.fecha,
    oc.temperatura_rectal,
    oc.frecuencia_cardiaca,
    oc.frecuencia_respiratoria,
    oc.condicion_corporal,
    oc.fuente_datos,
    oc.observacion,
    u.id_usuario,
    u.nombre,
    u.apellidos;

-- 5) Lista las versiones de modelos con su tipo, estado calculado, metricas
-- principales, fecha de entrenamiento y usuario responsable. La sensibilidad
-- se toma desde recall_modelo, que es la metrica equivalente en la tabla.
CREATE OR REPLACE VIEW modulo4.vw_m04_05_gestion_modelos_ia AS
SELECT
    vm.id_version_modelo,
    vm.nombre_version AS version_modelo,
    vm.algoritmo AS tipo_modelo,
    CASE
        WHEN vm.esta_produccion IS TRUE THEN 'PRODUCCION'
        WHEN vm.fecha_retiro IS NOT NULL THEN 'RETIRADO'
        WHEN vm.fecha_despliegue IS NOT NULL THEN 'DESPLEGADO_NO_PRODUCCION'
        ELSE 'ENTRENAMIENTO'
    END AS estado_modelo,
    vm.f1_score,
    vm.recall_modelo AS sensibilidad,
    vm.precision_modelo,
    vm.accuracy,
    vm.auc_roc,
    vm.fecha_entrenamiento,
    vm.fecha_despliegue,
    vm.fecha_retiro,
    u.id_usuario AS id_usuario_responsable,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable
FROM modulo4.versiones_modelos vm
LEFT JOIN modulo1.usuarios u
  ON u.id_usuario = vm.id_usuario;

-- 6) Lista las caracteristicas de cada version del modelo: algoritmo,
-- metricas, umbral, artefacto, datasets usados y metricas de drift asociadas.
-- Los datasets y drift se agregan como JSON para mantener una fila por version.
CREATE OR REPLACE VIEW modulo4.vw_m04_06_caracteristicas_version_modelo AS
SELECT
    vm.id_version_modelo,
    vm.nombre_version AS version_modelo,
    vm.algoritmo AS tipo_modelo,
    vm.descripcion,
    vm.umbral_clasificacion AS umbral_modelo,
    vm.accuracy,
    vm.auc_roc,
    vm.f1_score,
    vm.precision_modelo,
    vm.recall_modelo AS sensibilidad,
    vm.ruta_artefacto,
    vm.hash_artecfacto,
    vm.esta_produccion,
    COALESCE(ds.total_datasets, 0) AS total_datasets,
    COALESCE(ds.datasets, '[]'::jsonb) AS datasets,
    COALESCE(md.total_metricas_drift, 0) AS total_metricas_drift,
    COALESCE(md.tiene_drift_alertado, false) AS tiene_drift_alertado,
    COALESCE(md.metricas_drift, '[]'::jsonb) AS metricas_drift
FROM modulo4.versiones_modelos vm
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS total_datasets,
        jsonb_agg(
            jsonb_build_object(
                'id_dataset', d.id_dataset,
                'nombre', d.nombre,
                'fecha_inicio_datos', d.fecha_inicio_datos,
                'fecha_fin_datos', d.fecha_fin_datos,
                'total_registros', d.total_resgistros,
                'registros_positivos', d.registros_positivos,
                'registros_negativos', d.registros_negativos,
                'porcentaje_train', d.porcentaje_train,
                'porcentaje_test', d.porcentaje_test,
                'tiene_variables_ambientales', d.tiene_variables_ambientales,
                'semestre_huila', d.semestre_huila,
                'enfermedades_incluidas', d.enfermedades_incluidas
            )
            ORDER BY d.fecha_inicio_datos, d.id_dataset
        ) AS datasets
    FROM modulo4.datasets d
    WHERE d.id_version_modelo = vm.id_version_modelo
) ds ON true
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS total_metricas_drift,
        bool_or(m.supera_umbral_drift) AS tiene_drift_alertado,
        jsonb_agg(
            jsonb_build_object(
                'id_metrica_drift', m.id_metrica_drift,
                'fecha_calculo', m.fecha_calculo,
                'tipo_metrica', m.tipo_metrica,
                'feature_evaluado', m.feature_evaluado,
                'valor_metrica', m.valor_metrica,
                'umbral_alerta_drift', m.umbral_alerta_drift,
                'supera_umbral_drift', m.supera_umbral_drift,
                'periodo_referencia', m.periodo_referencia,
                'periodo_actual', m.periodo_actual,
                'accion_tomada', m.accion_tomada
            )
            ORDER BY m.fecha_calculo DESC, m.id_metrica_drift DESC
        ) AS metricas_drift
    FROM modulo4.metricas_drift m
    WHERE m.id_modelo_version = vm.id_version_modelo
) md ON true;

-- 7) Lista modelos con id, tipo, version, estado, fecha de inicio y los
-- dispositivos donde se infiere que el modelo opera. 
CREATE OR REPLACE VIEW modulo4.vw_m04_distribucion_modelos AS
SELECT
    vm.id_version_modelo,
    vm.algoritmo AS tipo_modelo,
    vm.nombre_version AS version_modelo,
    CASE
        WHEN vm.esta_produccion IS TRUE THEN 'PRODUCCION'
        WHEN vm.fecha_retiro IS NOT NULL THEN 'RETIRADO'
        WHEN vm.fecha_despliegue IS NOT NULL THEN 'DESPLEGADO_NO_PRODUCCION'
        ELSE 'ENTRENAMIENTO'
    END AS estado_modelo,
    COALESCE(vm.fecha_despliegue, vm.fecha_entrenamiento) AS inicio,
    COALESCE(dispositivos.cantidad_dispositivos, 0) AS cantidad_dispositivos,
    COALESCE(dispositivos.dispositivos_modelo, 'Sin dispositivo asociado') AS dispositivos_modelo
    ,COALESCE(dispositivos.infraestructura, 'Sin infraestructura asociada') AS infraestructura
    ,COALESCE(dispositivos.finca, 'Sin finca asociada') AS finca
FROM modulo4.versiones_modelos vm
LEFT JOIN LATERAL (
    SELECT
        COUNT(DISTINCT d.id_dispositivo_iot) AS cantidad_dispositivos,
        string_agg(
            DISTINCT concat(d.serial, ' - ', d.descripcion),
            ', '
            ORDER BY concat(d.serial, ' - ', d.descripcion)
        ) FILTER (WHERE d.id_dispositivo_iot IS NOT NULL) AS dispositivos_modelo,
        string_agg(
            DISTINCT i.nombre,
            ', '
            ORDER BY i.nombre
        ) AS infraestructura,
        string_agg(
            DISTINCT f.nombre,
            ', '
            ORDER BY f.nombre
        ) AS finca
    FROM modulo4.predicciones pred
    JOIN modulo4.observaciones_clinicas oc
      ON oc.id_observacion_clinica = pred.id_observacion
    JOIN modulo2.activos_biologicos ab
      ON ab.id_activo_biologico = oc.id_activo_biologico
    JOIN modulo9.infraestructuras i
      ON i.id_infraestructura = ab.id_infraestructura
    JOIN modulo9.fincas f
      ON f.id_finca = i.id_finca
    LEFT JOIN modulo9.dispositivos_iot d
      ON d.id_dispositivo_iot = ab.id_dispositivo_iot
    WHERE pred.id_version_modelo = vm.id_version_modelo
) dispositivos ON true;

-- 8) Lista eventos de auditoria relacionados con predicciones y modelos:
-- severidad, origen, resultado, modelo, version y rango diario de fechas.
CREATE OR REPLACE VIEW modulo4.vw_m04_08_eventos_auditoria_modelos AS
WITH eventos_predicciones AS (
    SELECT
        ('AUDITORIA_PREDICCION-' || ap.id_auditoria_prediccion)::text AS id_evento,
        ap.fecha_accion::timestamp AS fecha_evento,
        ap.accion::text AS tipo_evento,
        CASE
            WHEN ap.accion::text = 'ALERTA_ACTIVADA' THEN 'CRITICAL'
            WHEN ap.accion::text = 'UPDATE' THEN 'WARNING'
            ELSE 'INFO'
        END AS severidad,
        COALESCE(ap.servicio_origen, 'modulo4.auditorias_predicciones') AS origen,
        'EXITOSO'::text AS resultado,
        'modulo4.auditorias_predicciones'::text AS tabla_auditoria,
        ap.id_auditoria_prediccion AS id_registro_auditoria,
        ap.id_prediccion,
        pred.id_version_modelo,
        vm.algoritmo::text AS modelo,
        vm.nombre_version AS version_modelo,
        pat.nombre AS patologia,
        ap.id_usuario,
        concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable,
        ap.datos_anteriores,
        ap.datos_nuevos
    FROM modulo4.auditorias_predicciones ap
    JOIN modulo4.predicciones pred
      ON pred.id_prediccion = ap.id_prediccion
    JOIN modulo4.versiones_modelos vm
      ON vm.id_version_modelo = pred.id_version_modelo
    JOIN modulo9.patologias pat
      ON pat.id_patologias = pred.id_patologia
    LEFT JOIN modulo1.usuarios u
      ON u.id_usuario = ap.id_usuario
),
logs_base AS (
    SELECT
        ld.*,
        COALESCE(ld.datos_nuevos ->> 'id_prediccion', ld.datos_anteriores ->> 'id_prediccion') AS id_prediccion_txt,
        COALESCE(ld.datos_nuevos ->> 'id_version_modelo', ld.datos_anteriores ->> 'id_version_modelo') AS id_version_modelo_txt,
        COALESCE(ld.datos_nuevos ->> 'id_usuario', ld.datos_anteriores ->> 'id_usuario') AS id_usuario_txt
    FROM auditoria.logs_dml ld
    WHERE ld.esquema_afectado = 'modulo4'
      AND ld.tabla_afectada IN (
          'predicciones',
          'versiones_modelos',
          'auditorias_predicciones',
          'alertas_patologicas',
          'metricas_drift',
          'datasets'
      )
),
eventos_dml AS (
    SELECT
        ('LOG_DML-' || lb.id_log)::text AS id_evento,
        lb.fecha_evento::timestamp AS fecha_evento,
        lb.tipo_operacion AS tipo_evento,
        CASE
            WHEN lb.tipo_operacion = 'DELETE' THEN 'CRITICAL'
            WHEN lb.tipo_operacion = 'UPDATE' THEN 'WARNING'
            ELSE 'INFO'
        END AS severidad,
        COALESCE(lb.aplicacion, lb.ip_cliente, lb.usuario_bd, 'auditoria.logs_dml') AS origen,
        'EXITOSO'::text AS resultado,
        'auditoria.logs_dml'::text AS tabla_auditoria,
        lb.id_log AS id_registro_auditoria,
        pred.id_prediccion,
        vm.id_version_modelo,
        vm.algoritmo::text AS modelo,
        vm.nombre_version AS version_modelo,
        pat.nombre AS patologia,
        CASE
            WHEN lb.id_usuario_txt ~ '^[0-9]+$' THEN lb.id_usuario_txt::integer
            ELSE NULL
        END AS id_usuario,
        concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable,
        lb.datos_anteriores,
        lb.datos_nuevos
    FROM logs_base lb
    LEFT JOIN modulo4.predicciones pred
      ON pred.id_prediccion = CASE
          WHEN lb.id_prediccion_txt ~ '^[0-9]+$' THEN lb.id_prediccion_txt::integer
          ELSE NULL
      END
    LEFT JOIN modulo4.versiones_modelos vm
      ON vm.id_version_modelo = COALESCE(
          pred.id_version_modelo,
          CASE
              WHEN lb.id_version_modelo_txt ~ '^[0-9]+$' THEN lb.id_version_modelo_txt::integer
              ELSE NULL
          END
      )
    LEFT JOIN modulo9.patologias pat
      ON pat.id_patologias = pred.id_patologia
    LEFT JOIN modulo1.usuarios u
      ON u.id_usuario = CASE
          WHEN lb.id_usuario_txt ~ '^[0-9]+$' THEN lb.id_usuario_txt::integer
          ELSE NULL
      END
),
eventos_base AS (
    SELECT * FROM eventos_predicciones
    UNION ALL
    SELECT * FROM eventos_dml
)
SELECT
    id_evento,
    fecha_evento,
    date_trunc('day', fecha_evento) AS fecha_inicio_rango,
    date_trunc('day', fecha_evento) + INTERVAL '1 day' - INTERVAL '1 microsecond' AS fecha_fin_rango,
    tipo_evento,
    severidad,
    origen,
    resultado,
    tabla_auditoria,
    id_registro_auditoria,
    id_prediccion,
    id_version_modelo,
    modelo,
    version_modelo,
    patologia,
    id_usuario,
    usuario_responsable,
    datos_anteriores,
    datos_nuevos
FROM eventos_base;
