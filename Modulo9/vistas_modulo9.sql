-- Vistas Modulo 9

-- RF15: listado principal con conteo de ciclos y patologias asociadas.
CREATE OR REPLACE VIEW modulo9.vw_rf15_especies_resumen AS
SELECT
    e.id_especie,
    e.nombre,
    e.descripcion,
    e.es_activo,
    e.fecha_creacion,
    e.fecha_actualizacion,
    COUNT(DISTINCT cb.id_ciclo_biologico) AS total_ciclos,
    COUNT(DISTINCT ep.id_especies_patologias) AS total_patologias
FROM modulo9.especies AS e
LEFT JOIN modulo9.ciclos_biologicos AS cb
    ON cb.id_especie = e.id_especie
LEFT JOIN modulo9.especies_patologias AS ep
    ON ep.id_especie = e.id_especie
GROUP BY
    e.id_especie,
    e.nombre,
    e.descripcion,
    e.es_activo,
    e.fecha_creacion,
    e.fecha_actualizacion;


-- RF15: selector de especie activa.
CREATE OR REPLACE VIEW modulo9.vw_rf15_especies_activas_selector AS
SELECT
    e.id_especie,
    e.nombre,
    e.descripcion
FROM modulo9.especies AS e
WHERE e.es_activo IS TRUE;


-- RF15: soporte para validar nombres duplicados.
CREATE OR REPLACE VIEW modulo9.vw_rf15_especies_nombre_normalizado AS
SELECT
    e.id_especie,
    e.nombre,
    lower(e.nombre::text) AS nombre_normalizado
FROM modulo9.especies AS e;


-- RF15: dependencias antes de desactivar especie.
CREATE OR REPLACE VIEW modulo9.vw_rf15_dependencias_especie AS
SELECT
    e.id_especie,
    e.nombre,
    COUNT(DISTINCT ua.id_umbral_ambiental) FILTER (WHERE ua.es_activo IS TRUE) AS umbrales_activos,
    COUNT(DISTINCT cb.id_ciclo_biologico) FILTER (WHERE cb.es_activo IS TRUE) AS ciclos_activos,
    COUNT(DISTINCT ep.id_especies_patologias) AS patologias_asociadas
FROM modulo9.especies AS e
LEFT JOIN modulo9.umbrales_ambientales AS ua
    ON ua.id_especie = e.id_especie
LEFT JOIN modulo9.ciclos_biologicos AS cb
    ON cb.id_especie = e.id_especie
LEFT JOIN modulo9.especies_patologias AS ep
    ON ep.id_especie = e.id_especie
GROUP BY
    e.id_especie,
    e.nombre;


-- RF17: historial de auditoria de gestion de especies.
CREATE OR REPLACE VIEW modulo9.vw_rf17_gestion_especies_historial AS
SELECT
    ge.id_ediciones_especies,
    ge.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario,
    ge.fecha_gestion,
    ge.id_especie,
    e.nombre AS especie,
    ge.id_umbral_ambiental,
    ua.nombre AS umbral_relacionado
FROM modulo9.gestion_especies AS ge
JOIN modulo1.usuarios AS u
    ON u.id_usuario = ge.id_usuario
JOIN modulo9.especies AS e
    ON e.id_especie = ge.id_especie
LEFT JOIN modulo9.umbrales_ambientales AS ua
    ON ua.id_umbral_ambiental = ge.id_umbral_ambiental;


-- RF16: etapas del ciclo biologico por especie.
CREATE OR REPLACE VIEW modulo9.vw_rf16_ciclos_biologicos_especie AS
SELECT
    cb.id_especie,
    cb.id_ciclo_biologico,
    cb.nombre,
    cb.descripcion,
    cb.duracion_dias,
    cb.es_activo AS ciclo_activo,
    e.nombre AS especie,
    e.es_activo AS especie_activa
FROM modulo9.ciclos_biologicos AS cb
JOIN modulo9.especies AS e
    ON e.id_especie = cb.id_especie;


-- RF16: patologias asociadas por especie.
CREATE OR REPLACE VIEW modulo9.vw_rf16_patologias_especie AS
SELECT
    ep.id_especie,
    ep.id_especies_patologias,
    p.id_patologias,
    p.nombre,
    p.descripcion,
    p.es_activo,
    p.nombre_tecnico,
    p.etiologia,
    p.categoria,
    p.codigo_cie
FROM modulo9.especies_patologias AS ep
JOIN modulo9.patologias AS p
    ON p.id_patologias = ep.id_patologia;


-- RF16: conteo de etapas y patologias por especie.
CREATE OR REPLACE VIEW modulo9.vw_rf16_cabecera_especie AS
SELECT
    e.id_especie,
    e.nombre,
    COUNT(DISTINCT cb.id_ciclo_biologico) AS total_etapas,
    COUNT(DISTINCT ep.id_especies_patologias) AS total_patologias
FROM modulo9.especies AS e
LEFT JOIN modulo9.ciclos_biologicos AS cb
    ON cb.id_especie = e.id_especie
LEFT JOIN modulo9.especies_patologias AS ep
    ON ep.id_especie = e.id_especie
GROUP BY
    e.id_especie,
    e.nombre;


-- RF16: soporte para validar unicidad de etapas por especie.
CREATE OR REPLACE VIEW modulo9.vw_rf16_ciclos_nombre_normalizado AS
SELECT
    cb.id_ciclo_biologico,
    cb.id_especie,
    cb.nombre,
    lower(cb.nombre::text) AS nombre_normalizado
FROM modulo9.ciclos_biologicos AS cb;


-- RF16: soporte para validar unicidad global de patologias.
CREATE OR REPLACE VIEW modulo9.vw_rf16_patologias_nombre_normalizado AS
SELECT
    p.id_patologias,
    p.nombre,
    lower(p.nombre::text) AS nombre_normalizado
FROM modulo9.patologias AS p;


-- RF16: dependencias antes de desactivar etapa.
CREATE OR REPLACE VIEW modulo9.vw_rf16_dependencias_ciclos AS
SELECT
    cb.id_ciclo_biologico,
    cb.nombre,
    COUNT(cpb.id_ciclos_productivo_biologico) AS referencias_productivas
FROM modulo9.ciclos_biologicos AS cb
LEFT JOIN modulo9.ciclos_productivos_biologicos AS cpb
    ON cpb.id_ciclo_biologico = cb.id_ciclo_biologico
GROUP BY
    cb.id_ciclo_biologico,
    cb.nombre;


-- RF16: dependencias antes de desactivar patologia.
-- El dump no tiene modulo9.eventos_sanitarios ni id_patologia en modulo2.eventos_sanitarios.
CREATE OR REPLACE VIEW modulo9.vw_rf16_dependencias_patologias AS
SELECT
    p.id_patologias,
    p.nombre,
    COUNT(DISTINCT ep.id_especies_patologias) AS especies_asociadas,
    COUNT(DISTINCT ps.id_patologia_signo) AS signos_asociados,
    COUNT(DISTINCT pr.id_prediccion) AS predicciones_asociadas,
    COUNT(DISTINCT ap.id_alerta_patologica) AS alertas_asociadas
FROM modulo9.patologias AS p
LEFT JOIN modulo9.especies_patologias AS ep
    ON ep.id_patologia = p.id_patologias
LEFT JOIN modulo4.patologias_signos AS ps
    ON ps.id_patologia = p.id_patologias
LEFT JOIN modulo4.predicciones AS pr
    ON pr.id_patologia = p.id_patologias
LEFT JOIN modulo4.alertas_patologicas AS ap
    ON ap.id_patologia = p.id_patologias
GROUP BY
    p.id_patologias,
    p.nombre;


-- RF17: variables ambientales con indicador de configuracion por especie.
CREATE OR REPLACE VIEW modulo9.vw_rf17_variables_configuracion_especie AS
SELECT
    e.id_especie,
    e.nombre AS especie,
    va.id_variable_ambiental,
    va.nombre,
    va.unidad,
    va.valor_fisico_min,
    va.valor_fisico_max,
    va.es_activo,
    (COUNT(ua.id_umbral_ambiental) > 0) AS ya_configurada,
    MIN(ua.id_umbral_ambiental) AS id_umbral_ambiental,
    MIN(ua.nombre) AS nombre_umbral,
    COUNT(ua.id_umbral_ambiental) AS total_umbrales_activos
FROM modulo9.especies AS e
CROSS JOIN modulo9.variables_ambientales AS va
LEFT JOIN modulo9.umbrales_ambientales AS ua
    ON ua.id_variable_ambiental = va.id_variable_ambiental
   AND ua.id_especie = e.id_especie
   AND ua.es_activo IS TRUE
WHERE va.es_activo IS TRUE
GROUP BY
    e.id_especie,
    e.nombre,
    va.id_variable_ambiental,
    va.nombre,
    va.unidad,
    va.valor_fisico_min,
    va.valor_fisico_max,
    va.es_activo;


-- RF17: detalle de umbral con niveles de alerta.
CREATE OR REPLACE VIEW modulo9.vw_rf17_umbrales_detalle_niveles AS
SELECT
    ua.id_umbral_ambiental,
    ua.id_especie,
    e.nombre AS especie,
    ua.nombre,
    ua.unidad_medida,
    ua.descripcion,
    ua.es_activo,
    va.id_variable_ambiental,
    va.nombre AS variable,
    va.unidad,
    va.valor_fisico_min,
    va.valor_fisico_max,
    COALESCE(
        json_agg(
            json_build_object(
                'id', na.id_nivel_alerta_ambiental,
                'nivel', na.nivel,
                'limite_inferior', na.limite_inferior,
                'limite_superior', na.limite_superior
            )
            ORDER BY na.limite_inferior ASC
        ) FILTER (WHERE na.id_nivel_alerta_ambiental IS NOT NULL),
        '[]'::json
    ) AS niveles_alerta
FROM modulo9.umbrales_ambientales AS ua
JOIN modulo9.especies AS e
    ON e.id_especie = ua.id_especie
JOIN modulo9.variables_ambientales AS va
    ON va.id_variable_ambiental = ua.id_variable_ambiental
LEFT JOIN modulo9.niveles_alerta_ambientales AS na
    ON na.id_umbral_ambiental = ua.id_umbral_ambiental
GROUP BY
    ua.id_umbral_ambiental,
    ua.id_especie,
    e.nombre,
    ua.nombre,
    ua.unidad_medida,
    ua.descripcion,
    ua.es_activo,
    va.id_variable_ambiental,
    va.nombre,
    va.unidad,
    va.valor_fisico_min,
    va.valor_fisico_max;


-- RF17: soporte para validar duplicado activo especie + variable.
CREATE OR REPLACE VIEW modulo9.vw_rf17_umbral_activo_por_especie_variable AS
SELECT
    ua.id_especie,
    ua.id_variable_ambiental,
    COUNT(*) AS total_configuraciones_activas,
    array_agg(ua.id_umbral_ambiental ORDER BY ua.id_umbral_ambiental) AS umbrales_activos
FROM modulo9.umbrales_ambientales AS ua
WHERE ua.es_activo IS TRUE
GROUP BY
    ua.id_especie,
    ua.id_variable_ambiental;


-- RF18: configuracion global activa.
CREATE OR REPLACE VIEW modulo9.vw_rf18_configuracion_global_activa AS
SELECT
    cg.id_configuracion_global,
    cg.frecuencia_muestreo,
    cg.heartbeat,
    cg.fecha_actualizacion,
    cg.es_activo,
    cg.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS modificado_por,
    u.correo_electronico
FROM modulo9.configuraciones_globales AS cg
JOIN modulo1.usuarios AS u
    ON u.id_usuario = cg.id_usuario
WHERE cg.es_activo IS TRUE;


-- RF18: historial de configuraciones globales.
CREATE OR REPLACE VIEW modulo9.vw_rf18_configuraciones_globales_historial AS
SELECT
    cg.id_configuracion_global,
    cg.frecuencia_muestreo,
    cg.heartbeat,
    cg.fecha_actualizacion,
    cg.es_activo,
    cg.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS modificado_por
FROM modulo9.configuraciones_globales AS cg
JOIN modulo1.usuarios AS u
    ON u.id_usuario = cg.id_usuario;


-- RF19: fincas de un productor con conteo de infraestructuras.
CREATE OR REPLACE VIEW modulo9.vw_rf19_fincas_productor_resumen AS
SELECT
    f.id_usuario,
    f.id_finca,
    f.nombre,
    f.ubicacion,
    f.tamano_h,
    f.es_activo,
    f.fecha_creacion,
    f.fecha_actualizacion,
    concat_ws(' ', u.nombre, u.apellidos) AS productor,
    u.correo_electronico,
    COUNT(i.id_infraestructura) FILTER (WHERE i.es_activo IS TRUE) AS areas_activas,
    COUNT(i.id_infraestructura) AS total_areas
FROM modulo9.fincas AS f
JOIN modulo1.usuarios AS u
    ON u.id_usuario = f.id_usuario
LEFT JOIN modulo9.infraestructuras AS i
    ON i.id_finca = f.id_finca
GROUP BY
    f.id_usuario,
    f.id_finca,
    f.nombre,
    f.ubicacion,
    f.tamano_h,
    f.es_activo,
    f.fecha_creacion,
    f.fecha_actualizacion,
    u.nombre,
    u.apellidos,
    u.correo_electronico;


-- RF19: productores disponibles para asignar a una finca.
CREATE OR REPLACE VIEW modulo9.vw_rf19_productores_selector AS
SELECT
    u.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS nombre_completo,
    u.correo_electronico
FROM modulo1.usuarios AS u
JOIN modulo1.roles AS r
    ON r.id_rol = u.id_rol
WHERE lower(r.nombre_rol::text) = 'productor';


-- RF19: resumen global de fincas.
CREATE OR REPLACE VIEW modulo9.vw_rf19_fincas_resumen_global AS
SELECT
    COUNT(*) AS total_fincas,
    COUNT(*) FILTER (WHERE f.es_activo IS TRUE) AS fincas_activas,
    COUNT(*) FILTER (WHERE f.es_activo IS FALSE) AS fincas_inactivas
FROM modulo9.fincas AS f;


-- RF19: soporte para validar nombres duplicados de fincas.
CREATE OR REPLACE VIEW modulo9.vw_rf19_fincas_nombre_normalizado AS
SELECT
    f.id_finca,
    f.id_usuario,
    f.nombre,
    lower(f.nombre::text) AS nombre_normalizado
FROM modulo9.fincas AS f;


-- RF19: dependencias antes de desactivar finca.
CREATE OR REPLACE VIEW modulo9.vw_rf19_dependencias_fincas AS
SELECT
    f.id_finca,
    f.nombre,
    COUNT(DISTINCT i.id_infraestructura) FILTER (WHERE i.es_activo IS TRUE) AS infra_activas,
    COUNT(DISTINCT d.id_dispositivo_iot) FILTER (WHERE d.es_activo IS TRUE) AS dispositivos_activos
FROM modulo9.fincas AS f
LEFT JOIN modulo9.infraestructuras AS i
    ON i.id_finca = f.id_finca
LEFT JOIN modulo9.dispositivos_iot AS d
    ON d.id_infraestructura = i.id_infraestructura
GROUP BY
    f.id_finca,
    f.nombre;


-- RF20: fincas activas para selector.
CREATE OR REPLACE VIEW modulo9.vw_rf20_fincas_activas_selector AS
SELECT
    f.id_finca,
    f.nombre,
    f.ubicacion ->> 'municipio' AS municipio,
    f.ubicacion ->> 'departamento' AS departamento,
    f.es_activo,
    concat_ws(' ', u.nombre, u.apellidos) AS productor,
    COUNT(i.id_infraestructura) FILTER (WHERE i.es_activo IS TRUE) AS areas_activas,
    COUNT(i.id_infraestructura) AS total_areas
FROM modulo9.fincas AS f
JOIN modulo1.usuarios AS u
    ON u.id_usuario = f.id_usuario
LEFT JOIN modulo9.infraestructuras AS i
    ON i.id_finca = f.id_finca
WHERE f.es_activo IS TRUE
GROUP BY
    f.id_finca,
    f.nombre,
    f.ubicacion,
    f.es_activo,
    u.nombre,
    u.apellidos;


-- RF20: areas productivas de una finca con conteo de dispositivos.
CREATE OR REPLACE VIEW modulo9.vw_rf20_areas_finca_resumen AS
SELECT
    i.id_finca,
    i.id_infraestructura,
    i.nombre,
    i.descripcion,
    i.tipo,
    i.superficie,
    i.es_activo,
    COUNT(d.id_dispositivo_iot) FILTER (WHERE d.es_activo IS TRUE) AS dispositivos_activos,
    COUNT(d.id_dispositivo_iot) AS total_dispositivos
FROM modulo9.infraestructuras AS i
LEFT JOIN modulo9.dispositivos_iot AS d
    ON d.id_infraestructura = i.id_infraestructura
GROUP BY
    i.id_finca,
    i.id_infraestructura,
    i.nombre,
    i.descripcion,
    i.tipo,
    i.superficie,
    i.es_activo;


-- RF20: areas productivas con conteo de dispositivos y contexto de finca.
CREATE OR REPLACE VIEW modulo9.vw_rf20_areas_productivas_dispositivos AS
SELECT
    i.id_infraestructura,
    i.id_finca,
    i.nombre AS area,
    i.tipo,
    i.es_activo,
    f.nombre AS finca,
    f.ubicacion ->> 'municipio' AS municipio,
    COUNT(d.id_dispositivo_iot) AS total_dispositivos
FROM modulo9.infraestructuras AS i
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
LEFT JOIN modulo9.dispositivos_iot AS d
    ON d.id_infraestructura = i.id_infraestructura
GROUP BY
    i.id_infraestructura,
    i.id_finca,
    i.nombre,
    i.tipo,
    i.es_activo,
    f.nombre,
    f.ubicacion;


-- RF20: soporte para validar nombre unico dentro de una finca.
CREATE OR REPLACE VIEW modulo9.vw_rf20_infraestructuras_nombre_normalizado AS
SELECT
    i.id_infraestructura,
    i.id_finca,
    i.nombre,
    lower(i.nombre::text) AS nombre_normalizado
FROM modulo9.infraestructuras AS i;


-- RF20: dependencias antes de desactivar area.
CREATE OR REPLACE VIEW modulo9.vw_rf20_dependencias_infraestructuras AS
SELECT
    i.id_infraestructura,
    i.nombre,
    COUNT(d.id_dispositivo_iot) FILTER (WHERE d.es_activo IS TRUE) AS dispositivos_activos
FROM modulo9.infraestructuras AS i
LEFT JOIN modulo9.dispositivos_iot AS d
    ON d.id_infraestructura = i.id_infraestructura
GROUP BY
    i.id_infraestructura,
    i.nombre;


-- RF21: dispositivos IoT de un area con conteo de sensores.
CREATE OR REPLACE VIEW modulo9.vw_rf21_dispositivos_area_sensores AS
SELECT
    d.id_infraestructura,
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    d.fecha_creacion,
    COUNT(s.id_sensores) AS total_sensores,
    COUNT(s.id_sensores) FILTER (WHERE s.es_activo IS TRUE) AS sensores_activos
FROM modulo9.dispositivos_iot AS d
LEFT JOIN modulo9.sensores AS s
    ON s.id_dispositivo_iot = d.id_dispositivo_iot
GROUP BY
    d.id_infraestructura,
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    d.fecha_creacion;


-- RF21: dispositivos con conteo de sensores libres y asociados.
CREATE OR REPLACE VIEW modulo9.vw_rf21_dispositivos_sensores_asociacion AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    i.id_infraestructura,
    i.nombre AS area,
    f.id_finca,
    f.nombre AS finca,
    COUNT(s.id_sensores) AS total_sensores,
    COUNT(s.id_sensores) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM modulo9.sensores_areas_asociadas AS saa
            WHERE saa.id_sensor = s.id_sensores
              AND saa.tiene_estado IS TRUE
        )
    ) AS sensores_libres,
    COUNT(s.id_sensores) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM modulo9.sensores_areas_asociadas AS saa
            WHERE saa.id_sensor = s.id_sensores
              AND saa.tiene_estado IS TRUE
        )
    ) AS sensores_asociados
FROM modulo9.dispositivos_iot AS d
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
LEFT JOIN modulo9.sensores AS s
    ON s.id_dispositivo_iot = d.id_dispositivo_iot
WHERE d.es_activo IS TRUE
GROUP BY
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    i.id_infraestructura,
    i.nombre,
    f.id_finca,
    f.nombre;


-- RF21: soporte para validar serial unico de dispositivo.
CREATE OR REPLACE VIEW modulo9.vw_rf21_dispositivos_seriales AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    lower(d.serial::text) AS serial_normalizado
FROM modulo9.dispositivos_iot AS d;


-- RF22: sensores de un dispositivo con estado de asociacion actual.
CREATE OR REPLACE VIEW modulo9.vw_rf22_sensores_dispositivo_asociacion AS
SELECT
    s.id_dispositivo_iot,
    s.id_sensores,
    s.nombre,
    s.es_activo,
    saa.id_sensores_area_asociada,
    saa.tiene_estado AS asociado_activo,
    saa.punto_instalacion,
    i.id_infraestructura,
    i.nombre AS area_asociada,
    f.id_finca,
    f.nombre AS finca_asociada,
    saa.fecha_asociacion
FROM modulo9.sensores AS s
LEFT JOIN LATERAL (
    SELECT
        saa_actual.id_sensores_area_asociada,
        saa_actual.tiene_estado,
        saa_actual.punto_instalacion,
        saa_actual.id_infraestructura,
        saa_actual.fecha_asociacion
    FROM modulo9.sensores_areas_asociadas AS saa_actual
    WHERE saa_actual.id_sensor = s.id_sensores
      AND saa_actual.tiene_estado IS TRUE
    ORDER BY
        saa_actual.fecha_asociacion DESC,
        saa_actual.id_sensores_area_asociada DESC
    LIMIT 1
) AS saa
    ON TRUE
LEFT JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = saa.id_infraestructura
LEFT JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca;


-- RF22: areas destino disponibles para asociar.
CREATE OR REPLACE VIEW modulo9.vw_rf22_areas_destino_disponibles AS
SELECT
    i.id_infraestructura,
    i.nombre,
    i.tipo,
    f.id_finca,
    f.nombre AS finca
FROM modulo9.infraestructuras AS i
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
WHERE i.es_activo IS TRUE
  AND f.es_activo IS TRUE;


-- RF23: dispositivos con ultima configuracion remota y area asociada.
CREATE OR REPLACE VIEW modulo9.vw_rf23_dispositivos_configuracion_area AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    cr.id_configuracion_remota,
    cr.frecuencia_captura,
    cr.intervalo_transmision,
    cr.estado AS estado_configuracion,
    cr.fecha_creacion AS fecha_configuracion,
    cr.fecha_aplicacion,
    i.id_infraestructura,
    i.nombre AS area,
    f.id_finca,
    f.nombre AS finca
FROM modulo9.dispositivos_iot AS d
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        cr_actual.id_configuracion_remota,
        cr_actual.frecuencia_captura,
        cr_actual.intervalo_transmision,
        cr_actual.estado,
        cr_actual.fecha_creacion,
        cr_actual.fecha_aplicacion
    FROM modulo9.configuraciones_remotas AS cr_actual
    WHERE cr_actual.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY
        cr_actual.fecha_creacion DESC NULLS LAST,
        cr_actual.id_configuracion_remota DESC
    LIMIT 1
) AS cr
    ON TRUE;


-- RF23: ultima configuracion pendiente por dispositivo.
CREATE OR REPLACE VIEW modulo9.vw_rf23_configuraciones_pendientes AS
SELECT
    cr.id_dispositivo_iot,
    cr.id_configuracion_remota,
    cr.frecuencia_captura,
    cr.intervalo_transmision,
    cr.estado,
    cr.fecha_creacion
FROM (
    SELECT
        cr_base.*,
        row_number() OVER (
            PARTITION BY cr_base.id_dispositivo_iot
            ORDER BY cr_base.fecha_creacion DESC NULLS LAST,
                     cr_base.id_configuracion_remota DESC
        ) AS orden_pendiente
    FROM modulo9.configuraciones_remotas AS cr_base
    WHERE cr_base.estado = 'PENDIENTE'
) AS cr
WHERE cr.orden_pendiente = 1;


-- RF24: dispositivos activos con conteo de sensores y calibraciones.
CREATE OR REPLACE VIEW modulo9.vw_rf24_dispositivos_activos_calibraciones AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    i.id_infraestructura,
    i.nombre AS area,
    f.id_finca,
    f.nombre AS finca,
    COUNT(DISTINCT s.id_sensores) AS total_sensores,
    COUNT(DISTINCT c.id_calibracion) AS total_calibraciones,
    MAX(c.fecha_calibracion) AS ultima_calibracion
FROM modulo9.dispositivos_iot AS d
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
LEFT JOIN modulo9.sensores AS s
    ON s.id_dispositivo_iot = d.id_dispositivo_iot
LEFT JOIN modulo9.calibraciones AS c
    ON c.id_dispositivo_iot = d.id_dispositivo_iot
WHERE d.es_activo IS TRUE
GROUP BY
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    d.es_activo,
    i.id_infraestructura,
    i.nombre,
    f.id_finca,
    f.nombre;


-- RF24: sensores de un dispositivo para calibracion.
CREATE OR REPLACE VIEW modulo9.vw_rf24_sensores_dispositivo_calibracion AS
SELECT
    s.id_dispositivo_iot,
    s.id_sensores,
    s.nombre,
    s.es_activo,
    ultima.fecha_calibracion AS ultima_calibracion,
    ultima.valor_referencia AS ultimo_valor_referencia
FROM modulo9.sensores AS s
LEFT JOIN LATERAL (
    SELECT
        c.fecha_calibracion,
        c.valor_referencia
    FROM modulo9.calibraciones AS c
    WHERE c.id_sensor = s.id_sensores
    ORDER BY
        c.fecha_calibracion DESC,
        c.id_calibracion DESC
    LIMIT 1
) AS ultima
    ON TRUE
WHERE s.es_activo IS TRUE;


-- RF24: historial completo de calibraciones de un sensor.
CREATE OR REPLACE VIEW modulo9.vw_rf24_historial_calibraciones_sensor AS
SELECT
    c.id_sensor,
    c.id_calibracion,
    c.fecha_calibracion,
    c.valor_referencia,
    c.observaciones,
    c.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS tecnico
FROM modulo9.calibraciones AS c
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = c.id_usuario;


-- RF25: contexto completo del usuario autenticado.
-- En el dump no existe una relacion directa finca-especie; se reportan
-- las especies activas que tienen umbrales activos configurados.
CREATE OR REPLACE VIEW modulo9.vw_rf25_contexto_usuario AS
SELECT
    u.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS nombre_completo,
    r.id_rol,
    r.nombre_rol,
    f.id_finca,
    f.nombre AS finca_activa,
    f.ubicacion ->> 'departamento' AS departamento,
    f.es_activo AS finca_activa_estado,
    especies.especies_configuradas AS especies_en_finca
FROM modulo1.usuarios AS u
JOIN modulo1.roles AS r
    ON r.id_rol = u.id_rol
LEFT JOIN modulo9.fincas AS f
    ON f.id_usuario = u.id_usuario
   AND f.es_activo IS TRUE
LEFT JOIN LATERAL (
    SELECT
        COALESCE(
            array_agg(DISTINCT e.nombre::text ORDER BY e.nombre::text),
            ARRAY[]::text[]
        ) AS especies_configuradas
    FROM modulo9.umbrales_ambientales AS ua
    JOIN modulo9.especies AS e
        ON e.id_especie = ua.id_especie
    WHERE ua.es_activo IS TRUE
      AND e.es_activo IS TRUE
) AS especies
    ON TRUE;


-- RF25: permisos del rol del usuario.
CREATE OR REPLACE VIEW modulo9.vw_rf25_permisos_roles AS
SELECT
    r.id_rol,
    r.nombre_rol,
    rec.nombre_recurso AS modulo,
    a.descripcion AS accion,
    a.codigo AS codigo_accion,
    p.id_permiso,
    p.nombre AS permiso,
    p.es_activo
FROM modulo1.roles AS r
JOIN modulo1.permisos AS p
    ON p.id_rol = r.id_rol
JOIN modulo1.recursos AS rec
    ON rec.id_recurso = p.id_recurso
JOIN modulo1.acciones AS a
    ON a.id_accion = p.id_accion;


-- RF26: configuracion visual activa, version mas reciente por finca.
CREATE OR REPLACE VIEW modulo9.vw_rf26_identidad_visual_activa AS
SELECT DISTINCT ON (iv.id_finca)
    iv.id_finca,
    iv.id_identidad_visual,
    iv.logo_path,
    iv.primary_color,
    iv.secondary_color,
    iv.org_display_name,
    iv.version,
    iv.fecha_creacion,
    f.nombre AS finca,
    iv.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS modificado_por
FROM modulo9.identidad_visuales AS iv
JOIN modulo9.fincas AS f
    ON f.id_finca = iv.id_finca
JOIN modulo1.usuarios AS u
    ON u.id_usuario = iv.id_usuario
ORDER BY
    iv.id_finca,
    iv.version DESC NULLS LAST,
    iv.fecha_creacion DESC NULLS LAST,
    iv.id_identidad_visual DESC;


-- RF26: historial de cambios de identidad visual.
CREATE OR REPLACE VIEW modulo9.vw_rf26_auditorias_visuales_historial AS
SELECT
    av.id_auditoria_visual,
    av.fecha_creacion,
    av.valor_anterior,
    av.valor_nuevo,
    av.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario
FROM modulo9.auditorias_visuales AS av
JOIN modulo1.usuarios AS u
    ON u.id_usuario = av.id_usuario;


-- RF27: preferencia de tema del usuario y tema global.
CREATE OR REPLACE VIEW modulo9.vw_rf27_tema_usuario_global AS
SELECT
    u.id_usuario,
    tv_user.id_tema_visual AS id_preferencia_usuario,
    tv_user.theme_mode AS tema_usuario,
    tv_user.fecha_actualizacion AS actualizado_en,
    tv_global.theme_mode AS tema_global,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario
FROM modulo1.usuarios AS u
LEFT JOIN LATERAL (
    SELECT
        tv.id_tema_visual,
        tv.theme_mode,
        tv.fecha_actualizacion
    FROM modulo9.temas_visuales AS tv
    WHERE tv.id_usuario = u.id_usuario
      AND tv.es_global IS FALSE
    ORDER BY
        tv.fecha_actualizacion DESC,
        tv.id_tema_visual DESC
    LIMIT 1
) AS tv_user
    ON TRUE
LEFT JOIN LATERAL (
    SELECT
        tv.theme_mode
    FROM modulo9.temas_visuales AS tv
    WHERE tv.es_global IS TRUE
    ORDER BY
        tv.fecha_actualizacion DESC,
        tv.id_tema_visual DESC
    LIMIT 1
) AS tv_global
    ON TRUE;


-- RF27: listado completo de preferencias de tema por usuario.
CREATE OR REPLACE VIEW modulo9.vw_rf27_preferencias_tema_usuarios AS
SELECT
    u.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario,
    r.nombre_rol,
    tv.id_tema_visual,
    tv.theme_mode,
    tv.es_global,
    tv.fecha_actualizacion
FROM modulo9.temas_visuales AS tv
JOIN modulo1.usuarios AS u
    ON u.id_usuario = tv.id_usuario
JOIN modulo1.roles AS r
    ON r.id_rol = u.id_rol;


-- RF28: layout mas reciente del dashboard por usuario.
CREATE OR REPLACE VIEW modulo9.vw_rf28_dashboard_layout_usuario AS
SELECT DISTINCT ON (dl.id_usuario)
    dl.id_usuario,
    dl.id_dashboard_layout,
    dl.config,
    dl.active_widget,
    dl.fecha_actualizacion,
    jsonb_array_length(COALESCE(dl.config -> 'grid', '[]'::jsonb)) AS total_widgets_configurados
FROM modulo9.dashboard_layouts AS dl
ORDER BY
    dl.id_usuario,
    dl.fecha_actualizacion DESC NULLS LAST,
    dl.id_dashboard_layout DESC;


-- RF28: widget estado actual de dispositivos IoT.
CREATE OR REPLACE VIEW modulo9.vw_rf28_widget_estado_dispositivos AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    d.es_activo,
    i.id_infraestructura,
    i.nombre AS area,
    f.id_finca,
    f.nombre AS finca,
    ultima_cal.ultima_calibracion,
    cr.frecuencia_captura,
    cr.intervalo_transmision,
    cr.estado AS estado_configuracion
FROM modulo9.dispositivos_iot AS d
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
LEFT JOIN LATERAL (
    SELECT
        MAX(c.fecha_calibracion) AS ultima_calibracion
    FROM modulo9.calibraciones AS c
    WHERE c.id_dispositivo_iot = d.id_dispositivo_iot
) AS ultima_cal
    ON TRUE
LEFT JOIN LATERAL (
    SELECT
        cr_actual.frecuencia_captura,
        cr_actual.intervalo_transmision,
        cr_actual.estado
    FROM modulo9.configuraciones_remotas AS cr_actual
    WHERE cr_actual.id_dispositivo_iot = d.id_dispositivo_iot
    ORDER BY
        cr_actual.fecha_creacion DESC NULLS LAST,
        cr_actual.id_configuracion_remota DESC
    LIMIT 1
) AS cr
    ON TRUE;


-- RF28: widget dispositivos con configuracion pendiente de creacion.
CREATE OR REPLACE VIEW modulo9.vw_rf28_widget_dispositivos_sin_configuracion AS
SELECT
    d.id_dispositivo_iot,
    d.serial,
    d.descripcion,
    i.id_infraestructura,
    i.nombre AS area,
    f.id_finca,
    f.nombre AS finca
FROM modulo9.dispositivos_iot AS d
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = d.id_infraestructura
JOIN modulo9.fincas AS f
    ON f.id_finca = i.id_finca
WHERE d.es_activo IS TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM modulo9.configuraciones_remotas AS cr
      WHERE cr.id_dispositivo_iot = d.id_dispositivo_iot
  );


-- RF28: widget estado general de fincas.
CREATE OR REPLACE VIEW modulo9.vw_rf28_widget_estado_fincas AS
SELECT
    f.id_finca,
    f.nombre,
    f.es_activo,
    f.ubicacion ->> 'departamento' AS departamento,
    COUNT(DISTINCT i.id_infraestructura) FILTER (WHERE i.es_activo IS TRUE) AS areas_activas,
    COUNT(DISTINCT d.id_dispositivo_iot) FILTER (WHERE d.es_activo IS TRUE) AS dispositivos_activos
FROM modulo9.fincas AS f
LEFT JOIN modulo9.infraestructuras AS i
    ON i.id_finca = f.id_finca
LEFT JOIN modulo9.dispositivos_iot AS d
    ON d.id_infraestructura = i.id_infraestructura
GROUP BY
    f.id_finca,
    f.nombre,
    f.es_activo,
    f.ubicacion;


-- RF29: preferencia de idioma del usuario y global del sistema.
CREATE OR REPLACE VIEW modulo9.vw_rf29_idioma_usuario_global AS
SELECT
    u.id_usuario,
    pi_user.id_preferencia_idioma,
    pi_user.locale_code AS idioma_usuario,
    pi_user.es_por_defecto,
    pi_user.fecha_actualizacion,
    pi_global.locale_code AS idioma_global,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario
FROM modulo1.usuarios AS u
LEFT JOIN LATERAL (
    SELECT
        pi.id_preferencia_idioma,
        pi.locale_code,
        pi.es_por_defecto,
        pi.fecha_actualizacion
    FROM modulo9.preferencias_idiomas AS pi
    WHERE pi.id_usuario = u.id_usuario
      AND pi.es_por_defecto IS FALSE
    ORDER BY
        pi.fecha_actualizacion DESC NULLS LAST,
        pi.id_preferencia_idioma DESC
    LIMIT 1
) AS pi_user
    ON TRUE
LEFT JOIN LATERAL (
    SELECT
        pi.locale_code
    FROM modulo9.preferencias_idiomas AS pi
    WHERE pi.es_por_defecto IS TRUE
    ORDER BY
        pi.fecha_actualizacion DESC NULLS LAST,
        pi.id_preferencia_idioma DESC
    LIMIT 1
) AS pi_global
    ON TRUE;


-- RF29: listado de preferencias por usuario.
CREATE OR REPLACE VIEW modulo9.vw_rf29_preferencias_idioma_usuarios AS
SELECT
    u.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario,
    r.nombre_rol,
    pi.id_preferencia_idioma,
    pi.locale_code,
    pi.es_por_defecto,
    pi.fecha_actualizacion
FROM modulo9.preferencias_idiomas AS pi
JOIN modulo1.usuarios AS u
    ON u.id_usuario = pi.id_usuario
JOIN modulo1.roles AS r
    ON r.id_rol = u.id_rol;


-- RF31: listado de plantillas con especie y version.
CREATE OR REPLACE VIEW modulo9.vw_rf31_plantillas_listado AS
SELECT
    p.id_plantilla,
    p.template_name,
    p.version,
    p.fecha_creacion,
    p.id_especie,
    e.nombre AS especie,
    p.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS creado_por,
    jsonb_array_length(COALESCE(p.params_snapshot -> 'umbrales', '[]'::jsonb)) AS total_umbrales,
    jsonb_array_length(COALESCE(p.params_snapshot -> 'ciclos_biologicos', '[]'::jsonb)) AS total_ciclos,
    jsonb_array_length(COALESCE(p.params_snapshot -> 'metricas', '[]'::jsonb)) AS total_metricas
FROM modulo9.plantillas AS p
JOIN modulo9.especies AS e
    ON e.id_especie = p.id_especie
JOIN modulo1.usuarios AS u
    ON u.id_usuario = p.id_usuario;


-- RF31: resumen de plantillas.
CREATE OR REPLACE VIEW modulo9.vw_rf31_plantillas_resumen AS
SELECT
    COUNT(*) AS total_plantillas,
    COUNT(DISTINCT p.id_especie) AS especies_cubiertas,
    COUNT(DISTINCT p.template_name) AS nombres_unicos
FROM modulo9.plantillas AS p;


-- RF31/RF32: detalle completo de plantilla.
CREATE OR REPLACE VIEW modulo9.vw_rf32_plantillas_detalle AS
SELECT
    p.id_plantilla,
    p.template_name,
    p.version,
    p.fecha_creacion,
    p.params_snapshot,
    e.id_especie,
    e.nombre AS especie,
    e.es_activo AS especie_activa,
    p.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS creado_por
FROM modulo9.plantillas AS p
JOIN modulo9.especies AS e
    ON e.id_especie = p.id_especie
JOIN modulo1.usuarios AS u
    ON u.id_usuario = p.id_usuario;


-- RF31/RF32: parametros disponibles para armar snapshot base.
CREATE OR REPLACE VIEW modulo9.vw_rf31_params_disponibles_especie AS
SELECT
    e.id_especie,
    e.nombre AS especie,
    json_build_object(
        'umbrales',
        (
            SELECT COALESCE(
                json_agg(
                    json_build_object(
                        'id', ua.id_umbral_ambiental,
                        'nombre', ua.nombre
                    )
                    ORDER BY ua.nombre
                ),
                '[]'::json
            )
            FROM modulo9.umbrales_ambientales AS ua
            WHERE ua.id_especie = e.id_especie
              AND ua.es_activo IS TRUE
        ),
        'ciclos',
        (
            SELECT COALESCE(
                json_agg(
                    json_build_object(
                        'id', cb.id_ciclo_biologico,
                        'nombre', cb.nombre
                    )
                    ORDER BY cb.nombre
                ),
                '[]'::json
            )
            FROM modulo9.ciclos_biologicos AS cb
            WHERE cb.id_especie = e.id_especie
              AND cb.es_activo IS TRUE
        ),
        'patologias',
        (
            SELECT COALESCE(
                json_agg(
                    json_build_object(
                        'id', p.id_patologias,
                        'nombre', p.nombre
                    )
                    ORDER BY p.nombre
                ),
                '[]'::json
            )
            FROM modulo9.especies_patologias AS ep
            JOIN modulo9.patologias AS p
                ON p.id_patologias = ep.id_patologia
            WHERE ep.id_especie = e.id_especie
              AND p.es_activo IS TRUE
        )
    ) AS params_disponibles
FROM modulo9.especies AS e;


-- RF31: soporte para validar nombre unico de plantilla.
CREATE OR REPLACE VIEW modulo9.vw_rf31_plantillas_nombre_normalizado AS
SELECT
    p.id_plantilla,
    p.template_name,
    lower(p.template_name::text) AS template_name_normalizado
FROM modulo9.plantillas AS p;


-- RF33: historial de aplicaciones de plantillas.
CREATE OR REPLACE VIEW modulo9.vw_rf33_aplicaciones_plantillas_historial AS
SELECT
    ap.id_plantilla,
    ap.id_aplicacion_plantilla,
    ap.target_config,
    ap.before_snapshot,
    ap.after_snapshot,
    ap.fecha_aplicacion,
    ap.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS aplicado_por,
    p.template_name,
    p.version
FROM modulo9.aplicaciones_plantillas AS ap
JOIN modulo1.usuarios AS u
    ON u.id_usuario = ap.id_usuario
JOIN modulo9.plantillas AS p
    ON p.id_plantilla = ap.id_plantilla;
