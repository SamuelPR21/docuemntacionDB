-- Vistas para Modulo 2

-- RF33: listado base de activos biologicos.
CREATE OR REPLACE VIEW modulo2.vw_rf33_activos_biologicos_listado AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador,
    lower(ab.indentficador::text) AS identificador_normalizado,
    ab.id_especie,
    e.nombre AS especie,
    ab.id_infraestructura,
    i.nombre AS infraestructura,
    ab.tipo,
    ab.fecha_inicio_ciclo,
    ab.id_estado,
    eab.nombre AS estado,
    ab.descripcion,
    ab.origen_financiero,
    ab.costo_adquisicion,
    ab.atributos_dinamicos,
    ab.id_usuario,
    ab.fecha_creacion
FROM modulo2.activos_biologicos AS ab
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo2.estados_activos_biologicos AS eab
    ON eab.id_estado_activo_biologico = ab.id_estado;


-- RF34 / RF52: historial de movimientos por activo.
CREATE OR REPLACE VIEW modulo2.vw_rf34_movimientos_activo AS
SELECT
    m.id_movimiento,
    m.id_activo_biologico,
    ab.indentficador AS identificador,
    m.tipo AS tipo_movimiento,
    m.id_infraestructura_origen,
    i_origen.nombre AS infraestructura_origen,
    m.id_infraestructura_destino,
    i_destino.nombre AS infraestructura_destino,
    f_origen.id_finca AS id_finca_origen,
    f_origen.nombre AS finca_origen,
    f_destino.id_finca AS id_finca_destino,
    f_destino.nombre AS finca_destino,
    m.fecha_transferencia,
    m.fecha_fin,
    m.fecha_registro,
    m.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable
FROM modulo2.movimientos AS m
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = m.id_activo_biologico
JOIN modulo9.infraestructuras AS i_origen
    ON i_origen.id_infraestructura = m.id_infraestructura_origen
JOIN modulo9.infraestructuras AS i_destino
    ON i_destino.id_infraestructura = m.id_infraestructura_destino
JOIN modulo9.fincas AS f_origen
    ON f_origen.id_finca = i_origen.id_finca
JOIN modulo9.fincas AS f_destino
    ON f_destino.id_finca = i_destino.id_finca
JOIN modulo1.usuarios AS u
    ON u.id_usuario = m.id_usuario;


-- RF35: activos biologicos individuales por estado.
CREATE OR REPLACE VIEW modulo2.vw_rf35_activos_individuales AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador,
    dai.raza,
    dai.sexo,
    dai.fecha_nacimeinto AS fecha_nacimiento,
    dai.peso_inicial,
    ab.id_especie,
    e.nombre AS especie,
    ab.id_infraestructura,
    i.nombre AS infraestructura,
    ab.id_estado,
    eab.nombre AS estado,
    ab.descripcion,
    ab.fecha_creacion
FROM modulo2.activos_biologicos AS ab
JOIN modulo2.detalles_activos_individuales AS dai
    ON dai.id_activo_biologico = ab.id_activo_biologico
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo2.estados_activos_biologicos AS eab
    ON eab.id_estado_activo_biologico = ab.id_estado
WHERE ab.tipo = 'INDIVIDUAL'::modulo2.enum_activo_biologico_tipo;


-- RF35 / RF44 / RF52: historial de estados por activo.
CREATE OR REPLACE VIEW modulo2.vw_rf35_historial_estados_activo AS
SELECT
    h.id_historico_estado_activo,
    h.id_activo_biologico,
    ab.indentficador AS identificador,
    h.id_estado_anterior,
    ea_ant.nombre AS estado_anterior,
    h.id_estado_nuevo,
    ea_nvo.nombre AS estado_nuevo,
    h.fecha_cambio,
    h.motivo_cambio,
    h.modulo_origen,
    h.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable
FROM modulo2.historicos_estados_activos AS h
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = h.id_activo_biologico
JOIN modulo2.estados_activos_biologicos AS ea_ant
    ON ea_ant.id_estado_activo_biologico = h.id_estado_anterior
JOIN modulo2.estados_activos_biologicos AS ea_nvo
    ON ea_nvo.id_estado_activo_biologico = h.id_estado_nuevo
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = h.id_usuario;


-- RF37: fases productivas con secuencia para un activo.
CREATE OR REPLACE VIEW modulo2.vw_rf37_fases_productivas_secuencia AS
SELECT
    row_number() OVER (
        PARTITION BY gf.id_activo_biologico, gf.id_gestion_fases
        ORDER BY cpb.id_ciclos_productivo_biologico
    ) AS paso,
    gf.id_gestion_fases,
    gf.id_activo_biologico,
    ab.indentficador AS identificador_activo,
    e.id_especie,
    e.nombre AS especie,
    cp.id_ciclo_productivo,
    cp.nombre AS ciclo_productivo,
    cpb.id_ciclos_productivo_biologico AS orden_secuencia,
    cb.id_ciclo_biologico,
    cb.nombre AS fase,
    cb.descripcion,
    cb.duracion_dias,
    CASE
        WHEN gf.es_activa THEN 'Ciclo activo'
        ELSE 'Ciclo cerrado'
    END AS estado_ciclo,
    gf.fecha_inicio,
    gf.fecha_finalizacion,
    gf.es_activa
FROM modulo2.gestiones_fases AS gf
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = gf.id_activo_biologico
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
JOIN modulo9.ciclos_productivos_biologicos AS cpb
    ON cpb.id_ciclo_productivo = cp.id_ciclo_productivo
JOIN modulo9.ciclos_biologicos AS cb
    ON cb.id_ciclo_biologico = cpb.id_ciclo_biologico
   AND cb.id_especie = ab.id_especie;


-- RF37 / RF52: historial de fases con usuario responsable.
CREATE OR REPLACE VIEW modulo2.vw_rf37_historial_fases AS
SELECT
    row_number() OVER (
        PARTITION BY gf.id_activo_biologico, gf.id_gestion_fases
        ORDER BY cpb.id_ciclos_productivo_biologico
    ) AS paso,
    gf.id_gestion_fases,
    gf.id_activo_biologico,
    ab.indentficador AS identificador_activo,
    cb.id_ciclo_biologico,
    cb.nombre AS fase,
    gf.id_ciclo_productiva,
    cp.nombre AS ciclo_productivo,
    gf.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_involucrado,
    gf.fecha_inicio,
    gf.fecha_finalizacion,
    gf.es_activa
FROM modulo2.gestiones_fases AS gf
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = gf.id_activo_biologico
JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
JOIN modulo9.ciclos_productivos_biologicos AS cpb
    ON cpb.id_ciclo_productivo = cp.id_ciclo_productivo
JOIN modulo9.ciclos_biologicos AS cb
    ON cb.id_ciclo_biologico = cpb.id_ciclo_biologico
   AND cb.id_especie = ab.id_especie
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = gf.id_usuario;


-- RF37: estado actual de gestion de fase.
CREATE OR REPLACE VIEW modulo2.vw_rf37_estado_fase_actual AS
SELECT
    gf.id_gestion_fases,
    gf.id_activo_biologico,
    ab.indentficador AS identificador,
    gf.id_ciclo_productiva,
    cp.nombre AS ciclo_actual,
    gf.fecha_inicio,
    gf.fecha_finalizacion,
    gf.es_activa,
    gf.id_usuario
FROM modulo2.gestiones_fases AS gf
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = gf.id_activo_biologico
JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva;


-- RF38: eventos por activo biologico.
CREATE OR REPLACE VIEW modulo2.vw_rf38_eventos_activo AS
SELECT
    ea.id_eventos,
    ea.id_activo_biologico,
    ea.fecha,
    ea.descripcion,
    ea.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS registrado_por
FROM modulo2.eventos_activos AS ea
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF39 / RF46 / RF52: historial general de eventos biologicos con clasificacion.
CREATE OR REPLACE VIEW modulo2.vw_rf39_historial_eventos_activo AS
SELECT
    ea.id_eventos,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    ea.fecha,
    ea.descripcion,
    ea.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable,
    CASE
        WHEN ec.id_evento IS NOT NULL THEN 'CRECIMIENTO'
        WHEN es.id_evento IS NOT NULL THEN 'SANITARIO'
        WHEN ep.id_evento IS NOT NULL THEN 'PRODUCTIVO'
        WHEN eb.id_evento IS NOT NULL THEN 'BAJA'
        WHEN er.id_evento_reproductivo IS NOT NULL THEN 'REPRODUCTIVO'
        ELSE 'GENERAL'
    END AS tipo_evento
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
LEFT JOIN modulo2.eventos_crecimeinto AS ec
    ON ec.id_evento = ea.id_eventos
LEFT JOIN modulo2.eventos_sanitarios AS es
    ON es.id_evento = ea.id_eventos
LEFT JOIN modulo2.eventos_productivos AS ep
    ON ep.id_evento = ea.id_eventos
LEFT JOIN modulo2.eventos_bajas AS eb
    ON eb.id_evento = ea.id_eventos
LEFT JOIN modulo2.eventos_reproductivos AS er
    ON er.id_evento_reproductivo = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF46 / RF52: eventos sanitarios.
CREATE OR REPLACE VIEW modulo2.vw_rf46_eventos_sanitarios AS
SELECT
    'SANITARIO'::text AS categoria,
    ea.id_eventos,
    ea.fecha,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    ea.descripcion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario,
    'modulo2'::text AS modulo_origen,
    es.diagnostico,
    es.medicamento,
    es.dosis,
    es.unidad_dosis,
    es.frecuencia
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_sanitarios AS es
    ON es.id_evento = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF46 / RF52: eventos de crecimiento.
CREATE OR REPLACE VIEW modulo2.vw_rf46_eventos_crecimiento AS
SELECT
    'CRECIMIENTO'::text AS categoria,
    ea.id_eventos,
    ea.fecha,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    ea.descripcion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario,
    'modulo2'::text AS modulo_origen,
    ec.tipo_medicion,
    ec.valor_medicion,
    ec.unidad_medida,
    ec.tipo_agregacion,
    ec.frecuencia
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_crecimeinto AS ec
    ON ec.id_evento = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF46 / RF52: eventos reproductivos.
CREATE OR REPLACE VIEW modulo2.vw_rf46_eventos_reproductivos AS
SELECT
    'REPRODUCTIVO'::text AS categoria,
    ea.id_eventos,
    ea.fecha,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    ea.descripcion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario,
    'modulo2'::text AS modulo_origen,
    er.categoria AS categoria_reproductiva,
    er.id_padre,
    er.resultado,
    er.numero_cria,
    er.id_madre
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_reproductivos AS er
    ON er.id_evento_reproductivo = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF46 / RF52: eventos productivos.
CREATE OR REPLACE VIEW modulo2.vw_rf46_eventos_productivos AS
SELECT
    'PRODUCTIVO'::text AS categoria,
    ea.id_eventos,
    ea.fecha,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    ea.descripcion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario,
    'modulo2'::text AS modulo_origen,
    ep.cantidad,
    ep.condiciones,
    ep.id_metrica_produccion,
    mp.nombre AS metrica_produccion,
    ep.id_ciclo_productivo,
    cp.nombre AS ciclo_productivo
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_productivos AS ep
    ON ep.id_evento = ea.id_eventos
LEFT JOIN modulo9.metricas_produccion AS mp
    ON mp.id_metrica_produccion = ep.id_metrica_produccion
LEFT JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = ep.id_ciclo_productivo
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF46 / RF52: eventos de baja.
CREATE OR REPLACE VIEW modulo2.vw_rf46_eventos_bajas AS
SELECT
    'BAJA'::text AS categoria,
    ea.id_eventos,
    ea.fecha,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    ea.descripcion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario,
    'modulo2'::text AS modulo_origen,
    eb.tipo,
    eb.cantidad_afectada,
    eb.detalles,
    ab.id_estado
FROM modulo2.eventos_activos AS ea
JOIN modulo2.eventos_bajas AS eb
    ON eb.id_evento = ea.id_eventos
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario;


-- RF46 / RF47 / RF52: historial unificado del activo.
CREATE OR REPLACE VIEW modulo2.vw_rf46_historial_completo_activo AS
SELECT
    h.fecha_cambio AS fecha_evento,
    h.id_activo_biologico,
    ab.indentficador AS identificador,
    'ESTADO'::text AS categoria,
    ea_ant.nombre::text AS detalle_1,
    ea_nvo.nombre::text AS detalle_2,
    h.motivo_cambio::text AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.historicos_estados_activos AS h
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = h.id_activo_biologico
JOIN modulo2.estados_activos_biologicos AS ea_ant
    ON ea_ant.id_estado_activo_biologico = h.id_estado_anterior
JOIN modulo2.estados_activos_biologicos AS ea_nvo
    ON ea_nvo.id_estado_activo_biologico = h.id_estado_nuevo
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = h.id_usuario
UNION ALL
SELECT
    COALESCE(
        gf.fecha_finalizacion,
        (CURRENT_DATE + gf.fecha_inicio::time)::timestamp with time zone
    ) AS fecha_evento,
    gf.id_activo_biologico,
    ab.indentficador AS identificador,
    'FASE_PRODUCTIVA'::text AS categoria,
    cp.nombre::text AS detalle_1,
    CASE WHEN gf.es_activa THEN 'Activa' ELSE 'Finalizada' END AS detalle_2,
    (
        'duracion_dias=' || cp.duracion_dias ||
        ', es_activa=' || gf.es_activa ||
        ', fecha_finalizacion=' || COALESCE(gf.fecha_finalizacion::text, 'NULL')
    ) AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.gestiones_fases AS gf
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = gf.id_activo_biologico
JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = gf.id_usuario
UNION ALL
SELECT
    ea.fecha AS fecha_evento,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    'SANITARIO'::text AS categoria,
    es.diagnostico::text AS detalle_1,
    es.medicamento::text AS detalle_2,
    ea.descripcion::text AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_sanitarios AS es
    ON es.id_evento = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario
UNION ALL
SELECT
    ea.fecha AS fecha_evento,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    'CRECIMIENTO'::text AS categoria,
    ec.tipo_medicion::text AS detalle_1,
    (ec.valor_medicion || ' ' || ec.unidad_medida)::text AS detalle_2,
    ea.descripcion::text AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_crecimeinto AS ec
    ON ec.id_evento = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario
UNION ALL
SELECT
    ea.fecha AS fecha_evento,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    'PRODUCTIVO'::text AS categoria,
    COALESCE(mp.nombre, ep.id_metrica_produccion::text) AS detalle_1,
    (ep.cantidad || COALESCE(' ' || mp.unidad_medida, ''))::text AS detalle_2,
    ea.descripcion::text AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_productivos AS ep
    ON ep.id_evento = ea.id_eventos
LEFT JOIN modulo9.metricas_produccion AS mp
    ON mp.id_metrica_produccion = ep.id_metrica_produccion
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario
UNION ALL
SELECT
    ea.fecha AS fecha_evento,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    'REPRODUCTIVO'::text AS categoria,
    er.categoria::text AS detalle_1,
    er.resultado::text AS detalle_2,
    ea.descripcion::text AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_reproductivos AS er
    ON er.id_evento_reproductivo = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario
UNION ALL
SELECT
    ea.fecha AS fecha_evento,
    ea.id_activo_biologico,
    ab.indentficador AS identificador,
    'BAJA'::text AS categoria,
    eb.tipo::text AS detalle_1,
    eb.cantidad_afectada::text AS detalle_2,
    COALESCE(eb.detalles, ea.descripcion)::text AS observacion,
    COALESCE(concat_ws(' ', u.nombre, u.apellidos), 'Sin usuario') AS usuario_responsable
FROM modulo2.eventos_activos AS ea
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = ea.id_activo_biologico
JOIN modulo2.eventos_bajas AS eb
    ON eb.id_evento = ea.id_eventos
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = ea.id_usuario
UNION ALL
SELECT
    (lower(iz.rango_fecha)::timestamp)::timestamp with time zone AS fecha_evento,
    iz.id_activo_biologico,
    ab.indentficador AS identificador,
    'INDICADOR'::text AS categoria,
    iz.tipo::text AS detalle_1,
    upper(iz.rango_fecha)::text AS detalle_2,
    iz.paramtros_calculo::text AS observacion,
    NULL::text AS usuario_responsable
FROM modulo2.indicadores_zootecnicos AS iz
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = iz.id_activo_biologico;


-- RF47 / RF51 / RF52: indicadores zootecnicos por activo.
CREATE OR REPLACE VIEW modulo2.vw_rf47_indicadores_zootecnicos_activo AS
SELECT
    iz.id_indicador_zootecnico,
    iz.id_activo_biologico,
    ab.indentficador AS identificador_activo,
    e.id_especie,
    e.nombre AS especie,
    iz.tipo AS tipo_indicador,
    lower(iz.rango_fecha) AS fecha_inicio,
    upper(iz.rango_fecha) AS fecha_fin,
    iz.rango_fecha,
    iz.paramtros_calculo
FROM modulo2.indicadores_zootecnicos AS iz
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = iz.id_activo_biologico
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie;


-- RF47 / RF52: ficha integral del activo.
CREATE OR REPLACE VIEW modulo2.vw_rf47_ficha_integral_activo AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS codigo,
    ab.tipo,
    e.nombre AS especie,
    ab.fecha_creacion::date AS fecha_registro,
    (CURRENT_DATE - ab.fecha_creacion::date) AS dias_en_sistema,
    est.nombre AS estado_actual,
    i.nombre AS infraestructura_asociada,
    fase_activa.nombre AS fase_productiva_activa,
    di.raza,
    di.sexo,
    di.fecha_nacimeinto::date AS fecha_nacimiento,
    COALESCE(ult_peso.valor_medicion, di.peso_inicial, dp.peso_promedio) AS peso_actual,
    COALESCE(ult_peso.unidad_medida, 'kg') AS unidad_peso,
    ult_peso.fecha::date AS fecha_ultimo_peso,
    dp.cantidad_actual,
    dp.biomasa_total
FROM modulo2.activos_biologicos AS ab
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo2.estados_activos_biologicos AS est
    ON est.id_estado_activo_biologico = ab.id_estado
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
LEFT JOIN modulo2.detalles_activos_individuales AS di
    ON di.id_activo_biologico = ab.id_activo_biologico
LEFT JOIN modulo2.detalles_activos_biologicos_poblacionales AS dp
    ON dp.id_activo_biologico = ab.id_activo_biologico
LEFT JOIN LATERAL (
    SELECT
        cp2.nombre
    FROM modulo2.gestiones_fases AS gf
    JOIN modulo9.ciclos_productivos AS cp2
        ON cp2.id_ciclo_productivo = gf.id_ciclo_productiva
    WHERE gf.id_activo_biologico = ab.id_activo_biologico
      AND gf.es_activa IS TRUE
    ORDER BY gf.id_gestion_fases DESC
    LIMIT 1
) AS fase_activa
    ON TRUE
LEFT JOIN LATERAL (
    SELECT
        ea.fecha,
        ec.valor_medicion,
        ec.unidad_medida
    FROM modulo2.eventos_activos AS ea
    JOIN modulo2.eventos_crecimeinto AS ec
        ON ec.id_evento = ea.id_eventos
    WHERE ea.id_activo_biologico = ab.id_activo_biologico
      AND lower(ec.tipo_medicion::text) LIKE '%peso%'
    ORDER BY
        ea.fecha DESC,
        ea.id_eventos DESC
    LIMIT 1
) AS ult_peso
    ON TRUE;


-- RF48: estado actual de infraestructura del activo.
CREATE OR REPLACE VIEW modulo2.vw_rf48_infraestructura_actual_activo AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador,
    ab.id_infraestructura,
    i.nombre AS infraestructura_actual
FROM modulo2.activos_biologicos AS ab
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura;


-- RF49: asociaciones de sensores con activos.
CREATE OR REPLACE VIEW modulo2.vw_rf49_asociaciones_sensores_activos AS
SELECT
    aas.id_asociacion_activo_sensor,
    aas.id_sensor,
    s.nombre AS sensor,
    d.serial AS dispositivo_serial,
    i.nombre AS infraestructura_sensor,
    aas.id_usuario,
    aas.fecha_inicio,
    aas.fecha_fin,
    aas.motivo,
    aas.id_activo_biologico,
    ab.indentficador AS identificador,
    aas.tipo
FROM modulo2.asociaciones_activos_sensores AS aas
JOIN modulo9.sensores AS s
    ON s.id_sensores = aas.id_sensor
JOIN modulo9.dispositivos_iot AS d
    ON d.id_dispositivo_iot = s.id_dispositivo_iot
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = d.id_infraestructura
LEFT JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = aas.id_activo_biologico;


-- RF51: auditoria de activos biologicos registrados.
CREATE OR REPLACE VIEW modulo2.vw_rf51_auditoria_activos_registrados AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador,
    ab.tipo,
    e.nombre AS especie,
    i.nombre AS infraestructura,
    ab.fecha_inicio_ciclo,
    eab.nombre AS estado,
    ab.descripcion,
    ab.origen_financiero,
    ab.costo_adquisicion,
    ab.fecha_creacion,
    ab.id_usuario
FROM modulo2.activos_biologicos AS ab
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo2.estados_activos_biologicos AS eab
    ON eab.id_estado_activo_biologico = ab.id_estado;


-- RF52: auditoria de activos individuales.
CREATE OR REPLACE VIEW modulo2.vw_rf52_auditoria_activos_individuales AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador,
    dai.raza,
    dai.sexo,
    dai.fecha_nacimeinto AS fecha_nacimiento,
    dai.peso_inicial,
    e.nombre AS especie,
    i.nombre AS infraestructura,
    eab.nombre AS estado,
    ab.fecha_creacion,
    ab.descripcion,
    ab.id_usuario
FROM modulo2.activos_biologicos AS ab
JOIN modulo2.detalles_activos_individuales AS dai
    ON dai.id_activo_biologico = ab.id_activo_biologico
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo2.estados_activos_biologicos AS eab
    ON eab.id_estado_activo_biologico = ab.id_estado
WHERE ab.tipo = 'INDIVIDUAL'::modulo2.enum_activo_biologico_tipo;


-- RF52: auditoria de activos poblacionales / lotes.
CREATE OR REPLACE VIEW modulo2.vw_rf52_auditoria_activos_poblacionales AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador_lote,
    e.nombre AS especie,
    i.nombre AS infraestructura,
    eab.nombre AS estado,
    dp.cantidad_inicial,
    dp.cantidad_actual,
    dp.peso_promedio,
    dp.biomasa_total,
    dp.densidad,
    ab.descripcion,
    ab.fecha_creacion,
    ab.id_usuario
FROM modulo2.activos_biologicos AS ab
JOIN modulo2.detalles_activos_biologicos_poblacionales AS dp
    ON dp.id_activo_biologico = ab.id_activo_biologico
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo2.estados_activos_biologicos AS eab
    ON eab.id_estado_activo_biologico = ab.id_estado
WHERE ab.tipo = 'POBLACIONAL'::modulo2.enum_activo_biologico_tipo;


-- RF52: auditoria de cambios de fases.
CREATE OR REPLACE VIEW modulo2.vw_rf52_auditoria_fases_ciclo_productivo AS
SELECT
    gf.id_gestion_fases,
    gf.id_activo_biologico,
    ab.indentficador AS identificador_activo,
    e.nombre AS especie,
    cp.id_ciclo_productivo,
    cp.nombre AS ciclo_productivo,
    gf.fecha_inicio,
    gf.fecha_finalizacion,
    gf.es_activa,
    gf.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable
FROM modulo2.gestiones_fases AS gf
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = gf.id_activo_biologico
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = gf.id_usuario;


-- RF52: auditoria de cierres de ciclo productivo.
CREATE OR REPLACE VIEW modulo2.vw_rf52_auditoria_cierres_ciclo_productivo AS
SELECT
    gf.id_gestion_fases,
    gf.id_activo_biologico,
    ab.indentficador AS identificador,
    cp.nombre AS ciclo_productivo,
    gf.fecha_finalizacion,
    h.id_historico_estado_activo,
    ea_ant.nombre AS estado_anterior,
    ea_nvo.nombre AS estado_nuevo,
    h.motivo_cambio,
    h.modulo_origen,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable
FROM modulo2.gestiones_fases AS gf
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = gf.id_activo_biologico
JOIN modulo9.ciclos_productivos AS cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
LEFT JOIN modulo2.historicos_estados_activos AS h
    ON h.id_activo_biologico = gf.id_activo_biologico
   AND (
       h.modulo_origen = 'RF-38'
       OR (
           gf.fecha_finalizacion IS NOT NULL
           AND h.fecha_cambio BETWEEN gf.fecha_finalizacion - INTERVAL '5 minutes'
                                  AND gf.fecha_finalizacion + INTERVAL '5 minutes'
       )
   )
LEFT JOIN modulo2.estados_activos_biologicos AS ea_ant
    ON ea_ant.id_estado_activo_biologico = h.id_estado_anterior
LEFT JOIN modulo2.estados_activos_biologicos AS ea_nvo
    ON ea_nvo.id_estado_activo_biologico = h.id_estado_nuevo
LEFT JOIN modulo1.usuarios AS u
    ON u.id_usuario = COALESCE(h.id_usuario, gf.id_usuario)
WHERE gf.fecha_finalizacion IS NOT NULL;


-- RF52: auditoria de transferencias internas.
CREATE OR REPLACE VIEW modulo2.vw_rf52_auditoria_transferencias_internas AS
SELECT
    m.id_movimiento,
    m.id_activo_biologico,
    ab.indentficador AS identificador,
    m.id_usuario,
    concat_ws(' ', u.nombre, u.apellidos) AS usuario_responsable,
    m.fecha_transferencia,
    m.tipo,
    m.id_infraestructura_origen,
    io.nombre AS infraestructura_origen,
    m.id_infraestructura_destino,
    ides.nombre AS infraestructura_destino,
    m.fecha_registro
FROM modulo2.movimientos AS m
JOIN modulo2.activos_biologicos AS ab
    ON ab.id_activo_biologico = m.id_activo_biologico
JOIN modulo1.usuarios AS u
    ON u.id_usuario = m.id_usuario
JOIN modulo9.infraestructuras AS io
    ON io.id_infraestructura = m.id_infraestructura_origen
JOIN modulo9.infraestructuras AS ides
    ON ides.id_infraestructura = m.id_infraestructura_destino;


-- RF52: auditoria de acceso de modulos analiticos a datos.
CREATE OR REPLACE VIEW modulo2.vw_rf52_auditoria_acceso_modulos_analiticos AS
SELECT
    ab.id_activo_biologico,
    ab.indentficador AS identificador,
    ab.tipo,
    e.nombre AS especie,
    est.nombre AS estado_actual,
    i.nombre AS infraestructura_actual,
    ab.fecha_creacion,
    COUNT(DISTINCT ea.id_eventos) AS total_eventos,
    COUNT(DISTINCT iz.id_indicador_zootecnico) AS total_indicadores,
    MAX(ea.fecha) AS fecha_ultimo_evento
FROM modulo2.activos_biologicos AS ab
JOIN modulo9.especies AS e
    ON e.id_especie = ab.id_especie
JOIN modulo2.estados_activos_biologicos AS est
    ON est.id_estado_activo_biologico = ab.id_estado
JOIN modulo9.infraestructuras AS i
    ON i.id_infraestructura = ab.id_infraestructura
LEFT JOIN modulo2.eventos_activos AS ea
    ON ea.id_activo_biologico = ab.id_activo_biologico
LEFT JOIN modulo2.indicadores_zootecnicos AS iz
    ON iz.id_activo_biologico = ab.id_activo_biologico
GROUP BY
    ab.id_activo_biologico,
    ab.indentficador,
    ab.tipo,
    e.nombre,
    est.nombre,
    i.nombre,
    ab.fecha_creacion;


