-- =============================================================================
-- VISTAS VIRTUALES — Módulo 5 (Suministros)
-- Derivadas de los mockups RF-74 a RF-81 y el esquema de la BD
-- Esquema destino: modulo5
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- RF-74 · Eficiencia Alimenticia
-- Pantalla: KPIs de conversión alimenticia, tabla de activos con ICA,
--           historial de cálculos por período
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_eficiencia_alimenticia AS
SELECT
    -- Identificación del activo
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    i.nombre                                                  AS infraestructura,

    -- Resultado ICA más reciente
    ica.id_resultado_ica,
    ica.periodo_evaluacion,
    ica.fecha_inicio_periodo,
    ica.fecha_fin_periodo,
    ica.alimento_consumido_total_kg,
    ica.ganancia_peso_kg,
    ica.ca_calculado                                          AS indice_conversion_alimenticia,
    ica.clasificacion_ca                                      AS clasificacion_ica,
    ica.data_quality_score,
    ica.causa_no_calculo,
    ica.tipo_calculo,
    ica.fecha_calculo                                         AS fecha_ultimo_calculo,

    -- Calidad de datos semaforo (para columna "Calidad de datos" del mockup)
    CASE
        WHEN ica.data_quality_score IS NULL          THEN 'SIN_DATOS'
        WHEN ica.data_quality_score >= 80            THEN 'BUENA'
        WHEN ica.data_quality_score >= 50            THEN 'REGULAR'
        ELSE                                              'CRITICA'
    END                                                       AS calidad_datos_semaforo,

    -- Clasificación para KPIs del panel superior
    CASE
        WHEN ica.clasificacion_ca IS NULL            THEN 'SIN_DATOS'
        WHEN ica.clasificacion_ca::text IN
             ('CRITICA','MUY_BAJA')                  THEN 'CRITICA'
        WHEN ica.clasificacion_ca::text = 'BAJA'     THEN 'BAJA'
        ELSE                                              'NORMAL'
    END                                                       AS nivel_eficiencia,

    -- Trazabilidad
    u.nombre || ' ' || u.apellidos                            AS registrado_por,
    ica.creado_en                                             AS fecha_registro

FROM modulo2.activos_biologicos ab
JOIN modulo9.especies          e   ON e.id_especie        = ab.id_especie
JOIN modulo9.infraestructuras  i   ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo9.fincas            f   ON f.id_finca           = i.id_finca
LEFT JOIN modulo5.resultado_ica ica
    ON ica.id_activo_biologico = ab.id_activo_biologico
    -- Solo el ICA más reciente por activo
    AND ica.fecha_calculo = (
        SELECT MAX(ica2.fecha_calculo)
        FROM modulo5.resultado_ica ica2
        WHERE ica2.id_activo_biologico = ab.id_activo_biologico
    )
LEFT JOIN modulo1.usuarios     u   ON u.id_usuario         = ica.id_usuario
WHERE ab.id_estado IN (
    SELECT id_estado_activo_biologico
    FROM modulo2.estados_activos_biologicos
    WHERE nombre NOT IN ('BAJA','VENDIDO')
);

COMMENT ON VIEW modulo5.vw_m05_eficiencia_alimenticia
    IS 'RF-74. Eficiencia alimenticia por activo biológico activo. '
       'Expone el ICA más reciente, su clasificación y la calidad del dato '
       'para alimentar los KPIs (total, crítica, baja, sin datos) '
       'y la tabla principal del mockup.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-74 (historial) · Historial de cálculos de ICA por activo y período
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_historial_ica AS
SELECT
    ica.id_resultado_ica,
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    ica.periodo_evaluacion,
    ica.fecha_inicio_periodo,
    ica.fecha_fin_periodo,
    ica.ca_calculado                                          AS indice_conversion_alimenticia,
    ica.clasificacion_ca                                      AS clasificacion_ica,
    ica.alimento_consumido_total_kg,
    ica.ganancia_peso_kg,
    ica.tipo_calculo                                          AS origen_calculo,
    ica.fecha_calculo,
    ica.data_quality_score
FROM modulo5.resultado_ica     ica
JOIN modulo2.activos_biologicos ab  ON ab.id_activo_biologico = ica.id_activo_biologico
JOIN modulo9.especies           e   ON e.id_especie           = ab.id_especie
ORDER BY ica.id_activo_biologico, ica.fecha_calculo DESC;

COMMENT ON VIEW modulo5.vw_m05_historial_ica
    IS 'RF-74 (panel historial). Serie temporal de cálculos de ICA por activo. '
       'Columnas del mockup: Fecha del cálculo, Período evaluado, '
       'Índice de conversión, Clasificación, Alimento total (kg), '
       'Ganancia de peso (kg), Origen.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-75 · Registro de Alimentación
-- Pantalla: tabla de registros de consumo de alimentos con detalle de activo
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_registro_alimentacion AS
SELECT
    rca.id_consumo_alimeto,
    rca.id_registro_rf75,

    -- Activo y ubicación
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    ab.tipo                                                   AS tipo_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    i.nombre                                                  AS infraestructura,

    -- Ciclo productivo activo del animal
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,

    -- Cantidad de individuos (poblacional)
    dabp.cantidad_actual                                      AS individuos_en_lote,

    -- Datos del suministro
    ta.id_tipo_elemento                                       AS id_tipo_alimento,
    ta.nombre                                                 AS tipo_alimento,
    rca.tipo_unidad                                           AS unidad_medida,
    rca.cantidad_suministrada,
    rca.costo_unitario                                       AS costo_unitario,
    rca.costo_total,
    rca.consumo_por_individuo_kg,
    rca.observacion,

    -- Fechas
    COALESCE(rca.fecha_consumo, rca.fecha_registro)           AS fecha_hora_suministro,
    rca.fecha_inicio_periodo,
    rca.fecha_fin_periodo,
    rca.fecha_registro,

    -- Estado y trazabilidad
    rca.estado_registro,
    rca.justificacion_anulacion,
    rca.fecha_hora_anulacion,
    u.nombre || ' ' || u.apellidos                            AS registrado_por,
    u.id_usuario

FROM modulo5.registros_consumo_alimentos rca
JOIN modulo2.activos_biologicos           ab   ON ab.id_activo_biologico = rca.id_activo_biologico
JOIN modulo9.especies                     e    ON e.id_especie           = ab.id_especie
JOIN modulo9.infraestructuras             i    ON i.id_infraestructura   = ab.id_infraestructura
JOIN modulo9.fincas                       f    ON f.id_finca             = i.id_finca
JOIN modulo5.tipos_alimentos              ta   ON ta.id_tipo_elemento    = rca.id_tipo_alimento
LEFT JOIN modulo1.usuarios                u    ON u.id_usuario           = rca.id_usuario
-- Ciclo productivo activo del activo
LEFT JOIN modulo2.gestiones_fases         gf
    ON gf.id_activo_biologico = ab.id_activo_biologico AND gf.es_activa = true
LEFT JOIN modulo9.ciclos_productivos      cp   ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
-- Datos poblacionales (para lotes)
LEFT JOIN modulo2.detalles_activos_biologicos_poblacionales dabp
    ON dabp.id_activo_biologico = ab.id_activo_biologico;

COMMENT ON VIEW modulo5.vw_m05_registro_alimentacion
    IS 'RF-75. Lista de registros de consumo de alimentos. '
       'Columnas del mockup: Activo, Especie/Finca, Tipo de alimento, '
       'Fecha y hora, Cantidad (kg), Costo total, Estado, Registrado por. '
       'Incluye datos de contexto del activo para el panel de previsualización '
       'del formulario de registro.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-76 · Aplicación de Medicamentos
-- Pantalla: tabla de registros de medicamentos con período de retiro
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_aplicacion_medicamentos AS
SELECT
    rm.id_registro_medicamento,
    rm.id_registro_rf76,

    -- Activo y ubicación
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    ab.tipo                                                   AS tipo_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    i.nombre                                                  AS infraestructura,

    -- Ciclo y lote
    cp.nombre                                                 AS ciclo_productivo,
    dabp.cantidad_actual                                      AS individuos_en_lote,

    -- Datos del medicamento
    rm.nombre_medicamento,
    rm.descripcion_clinica,
    rm.unidad_dosis,
    rm.cantidad                                               AS cantidad_dosis,
    rm.dosis_por_individuo,
    rm.via_aplicacion,
    rm.lote_medicameto                                        AS lote_medicamento,
    rm.fehca_vencimietno_lote                                 AS fecha_vencimiento_lote,
    rm.motivo_aplicacion,

    -- Costos
    rm.costo_unitario_medicamento,
    rm.costo_total_medicamento,

    -- Período de retiro
    rm.periodo_retiro_dias,
    rm.fecha_fin_retiro                                       AS retiro_hasta,
    CASE
        WHEN rm.fecha_fin_retiro IS NULL         THEN 'SIN_RETIRO'
        WHEN rm.fecha_fin_retiro > CURRENT_DATE  THEN 'EN_RETIRO'
        ELSE                                          'RETIRO_CUMPLIDO'
    END                                                       AS estado_retiro,

    -- Fechas
    rm.fecha_aplicacion,
    rm.hora_aplicacion,
    rm.fecha_registro,

    -- Estado y evento sanitario vinculado
    rm.estado_registro,
    rm.justificacion_anulacion,
    rm.fecha_hora_anulacion,
    rm.id_evento_sanitario,

    -- Usuarios
    u_reg.nombre || ' ' || u_reg.apellidos                   AS registrado_por,
    u_vet.nombre || ' ' || u_vet.apellidos                   AS veterinario

FROM modulo5.registros_medicamentos                rm
JOIN modulo2.activos_biologicos                    ab
    ON ab.id_activo_biologico = rm.id_activo_biologico
JOIN modulo9.especies                              e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras                      i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo9.fincas                                f
    ON f.id_finca = i.id_finca
LEFT JOIN modulo1.usuarios                         u_reg
    ON u_reg.id_usuario = rm.id_usuario
LEFT JOIN modulo1.usuarios                         u_vet
    ON u_vet.id_usuario = rm.id_usuario_veterinario
LEFT JOIN modulo2.gestiones_fases                  gf
    ON gf.id_activo_biologico = ab.id_activo_biologico AND gf.es_activa = true
LEFT JOIN modulo9.ciclos_productivos               cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
LEFT JOIN modulo2.detalles_activos_biologicos_poblacionales dabp
    ON dabp.id_activo_biologico = ab.id_activo_biologico;

COMMENT ON VIEW modulo5.vw_m05_aplicacion_medicamentos
    IS 'RF-76. Lista de registros de aplicación de medicamentos. '
       'Columnas del mockup: Activo, Especie/Finca, Medicamento, '
       'Fecha y hora, Dosis, Vía, Retiro hasta, Costo total, Estado, Veterinario. '
       'Calcula estado_retiro para el semáforo de período de retiro.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-77 · Reporte de Gastos
-- Pantalla: KPIs (gasto total, alimentación, medicación, por individuo),
--           tabla de desglose y tabla de detalle de transacciones
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_reporte_gastos AS
SELECT
    rga.id_reporte_gasto_acumulado,

    -- Activo y ubicación
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    i.nombre                                                  AS infraestructura,

    -- Ciclo productivo
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,

    -- Período del reporte
    rga.fecha_incio_reporte                                   AS fecha_inicio,
    rga.fecha_fin_report                                      AS fecha_fin,
    rga.categoria,

    -- Costos desagregados (KPIs del mockup)
    rga.total_costo_alimento,
    rga.total_costo_medicamento,
    rga.total_costo_directo,
    rga.total_costo_alimento + rga.total_costo_medicamento    AS total_suministros,

    -- Gasto por individuo (para KPI "Gasto por individuo")
    CASE
        WHEN COALESCE(dabp.cantidad_actual, dai.peso_inicial, 1) > 0
        THEN ROUND(
            rga.total_costo_directo /
            COALESCE(dabp.cantidad_actual::numeric, 1), 4
        )
        ELSE NULL
    END                                                       AS costo_por_individuo,

    -- Cantidad de individuos referencia
    COALESCE(dabp.cantidad_actual, 1)                         AS individuos_referencia,

    -- Trazabilidad
    rga.fecha_generacion,
    u.nombre || ' ' || u.apellidos                            AS generado_por

FROM modulo5.reporte_gastos_acumulados               rga
JOIN modulo2.activos_biologicos                      ab
    ON ab.id_activo_biologico = rga.id_activo_biologico
JOIN modulo9.especies                                e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras                        i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo9.fincas                                  f
    ON f.id_finca = i.id_finca
LEFT JOIN modulo1.usuarios                           u
    ON u.id_usuario = rga.id_usuario
LEFT JOIN modulo9.infraestructuras                   i2
    ON i2.id_infraestructura = rga.id_infraestructura -- infraestructura del reporte (puede diferir)
LEFT JOIN modulo2.gestiones_fases                    gf
    ON gf.id_activo_biologico = ab.id_activo_biologico AND gf.es_activa = true
LEFT JOIN modulo9.ciclos_productivos                 cp
    ON cp.id_ciclo_productivo = gf.id_ciclo_productiva
LEFT JOIN modulo2.detalles_activos_biologicos_poblacionales dabp
    ON dabp.id_activo_biologico = ab.id_activo_biologico
LEFT JOIN modulo2.detalles_activos_individuales      dai
    ON dai.id_activo_biologico = ab.id_activo_biologico;

COMMENT ON VIEW modulo5.vw_m05_reporte_gastos
    IS 'RF-77. Reporte de gastos acumulados por activo y período. '
       'Alimenta los KPIs: Gasto total acumulado, Alimentación, Medicación, '
       'Gasto por individuo. Incluye desglose por categoría.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-77 (detalle) · Transacciones individuales del reporte de gastos
-- Combina registros de alimentos y medicamentos en una sola vista unificada
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_reporte_gastos_detalle AS

-- Registros de alimentos
SELECT
    'ALIMENTO' AS categoria,
    rca.id_consumo_alimeto::text AS id_origen,
    ab.id_activo_biologico,
    ab.identificador AS identificador_activo,
    COALESCE(
        rca.fecha_consumo,
        rca.fecha_registro
    )::timestamp AS fecha,
    ta.nombre AS descripcion,
    rca.costo_total AS monto_cop,
    rca.estado_registro::text AS estado,
    e.nombre AS especie,
    f.nombre AS finca

FROM modulo5.registros_consumo_alimentos rca
JOIN modulo2.activos_biologicos ab
    ON ab.id_activo_biologico = rca.id_activo_biologico
JOIN modulo9.especies e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo9.fincas f
    ON f.id_finca = i.id_finca
JOIN modulo5.tipos_alimentos ta
    ON ta.id_tipo_elemento = rca.id_tipo_alimento

UNION ALL

-- Registros de medicamentos
SELECT
    'MEDICAMENTO' AS categoria,
    rm.id_registro_medicamento::text AS id_origen,
    ab.id_activo_biologico,
    ab.identificador AS identificador_activo,

    -- Construir timestamp con fecha + hora
    (rm.fecha_registro + rm.hora_aplicacion)::timestamp AS fecha,

    rm.nombre_medicamento AS descripcion,
    rm.costo_total_medicamento AS monto_cop,
    rm.estado_registro::text AS estado,
    e.nombre AS especie,
    f.nombre AS finca

FROM modulo5.registros_medicamentos rm
JOIN modulo2.activos_biologicos ab
    ON ab.id_activo_biologico = rm.id_activo_biologico
JOIN modulo9.especies e
    ON e.id_especie = ab.id_especie
JOIN modulo9.infraestructuras i
    ON i.id_infraestructura = ab.id_infraestructura
JOIN modulo9.fincas f
    ON f.id_finca = i.id_finca;

COMMENT ON VIEW modulo5.vw_m05_reporte_gastos_detalle
IS 'RF-77 (tabla de detalle). Unión de alimentos y medicamentos en una sola serie de transacciones. Columnas del mockup: Fecha, Categoría, Descripción, Monto (COP), Estado.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-78 · Costos de Producción
-- Pantalla: acumulado por ciclo + historial de registros del ciclo
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW modulo5.vw_m05_costos_produccion AS
SELECT
    rs.id_registro_suministro,

    -- Activo y ciclo
    ab.id_activo_biologico,
    ab.identificador AS identificador_activo,
    e.nombre AS especie,
    f.nombre AS finca,
    cp.id_ciclo_productivo,
    cp.nombre AS ciclo_productivo,

    -- Acumulado del ciclo
    ac.acumulado_total_ciclo,
    ac.acumulado_por_categoria,
    ac.version_acumulado,
    ac.fecha_ultima_actualizacion AS acumulado_actualizado_en,
    ac.estado AS estado_acumulado,

    -- Registro individual
    rs.naturaleza_costo,
    rs.unidad_medida,
    rs.cantidad,
    rs.precio_unitario_resuelto AS precio_unitario,
    rs.costo_registro AS costo,
    rs.origen_precio,
    rs.fecha_aplicacion,
    rs.fecha_registro,
    rs.tipo_operacion,
    rs.observacion,
    rs.motivo_correccion,
    rs.id_registro_original,

    -- Trazabilidad
    NULL::text AS registrado_por

FROM modulo5.registro_suministro rs
JOIN modulo2.activos_biologicos ab
    ON ab.id_activo_biologico = rs.id_activo_biologico

JOIN modulo9.especies e
    ON e.id_especie = ab.id_especie

JOIN modulo9.infraestructuras i
    ON i.id_infraestructura = ab.id_infraestructura

JOIN modulo9.fincas f
    ON f.id_finca = i.id_finca

JOIN modulo9.ciclos_productivos cp
    ON cp.id_ciclo_productivo = rs.id_ciclo_productivo

LEFT JOIN modulo5.acumulado_ciclo ac
    ON ac.id_ciclo_productivo = rs.id_ciclo_productivo;

COMMENT ON VIEW modulo5.vw_m05_costos_produccion
IS 'RF-78. Costos de producción por ciclo productivo. Combina el acumulado del ciclo con el detalle de cada registro de suministro.';

-- ─────────────────────────────────────────────────────────────────────────────
-- RF-79 · Provisión de Costos NIC 41
-- Pantalla: tabla de reportes de provisión + tabla de entregas incrementales
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_provision_nic41 AS
SELECT
    pn.id_provision,

    -- Activo y ciclo
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,

    -- Datos de la provisión (columnas tabla principal del mockup)
    pn.modalidad,
    pn.monto_provision,
    pn.desglose_categoria,
    pn.version_reporte,
    pn.estado,
    pn.hash_integridad,
    pn.es_reporte_potencialmente_incompleto,
    pn.motivo_correccion,

    -- Fechas
    pn.fecha_generacion,
    pn.fecha_entrega_m06,

    -- Integridad calculada
    CASE
        WHEN pn.hash_integridad IS NULL              THEN 'SIN_HASH'
        WHEN pn.es_reporte_potencialmente_incompleto THEN 'INCOMPLETO'
        ELSE                                              'VERIFICADO'
    END                                                       AS estado_integridad

FROM modulo5.provision_nic41        pn
JOIN modulo2.activos_biologicos     ab  ON ab.id_activo_biologico = pn.id_activo_biologico
JOIN modulo9.especies               e   ON e.id_especie           = ab.id_especie
JOIN modulo9.infraestructuras       i   ON i.id_infraestructura   = ab.id_infraestructura
JOIN modulo9.fincas                 f   ON f.id_finca             = i.id_finca
LEFT JOIN modulo9.ciclos_productivos cp ON cp.id_ciclo_productivo = pn.id_ciclo_productivo;

COMMENT ON VIEW modulo5.vw_m05_provision_nic41
    IS 'RF-79 (tabla de reportes). Provisiones de costos NIC 41 generadas. '
       'Columnas del mockup: Fecha de generación, Activo biológico, '
       'Ciclo productivo, Monto total, Versión, Estado, Integridad.';


CREATE OR REPLACE VIEW modulo5.vw_m05_provision_incrementales AS
SELECT
    aus.id_auditoria_suministro,

    -- Activo y ciclo
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,

    -- Datos del evento incremental (tabla "Outbox" del mockup)
    aus.tipo_operacion                                        AS tipo_evento,
    aus.costo_afectado                                        AS costo_registro,
    aus.resultado                                             AS estado_entrega,
    aus.numero_reintentos                                     AS reintentos,
    aus.fecha_intentos                                        AS timestamp_ultimo_intento,
    aus.hash_integridad,
    aus.registro_incompleto,
    aus.detalle_causa,
    aus.clasificacion_registro,
    aus.fecha_evento                                          AS fecha_hora,

    -- Acumulado del ciclo al momento del evento
    ac.acumulado_total_ciclo                                  AS acumulado_ciclo

FROM modulo5.auditorias_suministros          aus
JOIN modulo2.activos_biologicos              ab  ON ab.id_activo_biologico = aus.id_activo_biologico
JOIN modulo9.especies                        e   ON e.id_especie           = ab.id_especie
LEFT JOIN modulo9.ciclos_productivos         cp  ON cp.id_ciclo_productivo = aus.id_ciclo_productivo
LEFT JOIN modulo5.acumulado_ciclo            ac  ON ac.id_ciclo_productivo = aus.id_ciclo_productivo
WHERE aus.id_activo_biologico IS NOT NULL;

COMMENT ON VIEW modulo5.vw_m05_provision_incrementales
    IS 'RF-79 (tabla Outbox incremental). Eventos de auditoría de suministros '
       'pendientes de entrega al módulo financiero. '
       'Columnas del mockup: Fecha y hora, Activo, Ciclo, Categoría, '
       'Costo del registro, Acumulado del ciclo, Estado entrega, Reintentos.';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-80 · Trazabilidad de Costos
-- Pantalla: log de auditoría con tipo de evento, resultado, clasificación,
--           activo, ciclo, monto y detalle
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_trazabilidad_costos AS
SELECT
    aus.id_auditoria_suministro,

    -- Activo y ciclo
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,

    -- Evento de auditoría (columnas tabla del mockup)
    aus.fecha_evento                                          AS fecha_operacion,
    aus.tipo_operacion                                        AS tipo_evento,
    aus.resultado,
    aus.clasificacion_registro                                AS clasificacion,
    aus.retencion_aplicable                                   AS retencion,
    aus.costo_afectado                                        AS monto_afectado,

    -- Integridad
    aus.hash_integridad,
    aus.registro_incompleto,
    aus.detalle_causa,

    -- Reintentos
    aus.numero_reintentos,
    aus.fecha_intentos,

    -- Antes / después (para panel de detalle)
    aus.datos_anteriores,
    aus.datos_nuevos,

    -- Usuario y sesión
    u.nombre || ' ' || u.apellidos                           AS usuario,
    aus.ip_origen,
    aus.id_sesion

FROM modulo5.auditorias_suministros         aus
LEFT JOIN modulo2.activos_biologicos        ab  ON ab.id_activo_biologico = aus.id_activo_biologico
LEFT JOIN modulo9.especies                  e   ON e.id_especie           = ab.id_especie
LEFT JOIN modulo9.infraestructuras          i   ON i.id_infraestructura   = ab.id_infraestructura
LEFT JOIN modulo9.fincas                    f   ON f.id_finca             = i.id_finca
LEFT JOIN modulo9.ciclos_productivos        cp  ON cp.id_ciclo_productivo = aus.id_ciclo_productivo
LEFT JOIN modulo1.usuarios                  u   ON u.id_usuario           = aus.id_usuario;

COMMENT ON VIEW modulo5.vw_m05_trazabilidad_costos
    IS 'RF-80. Log completo de auditoría de suministros. '
       'Columnas del mockup: Fecha de operación, Tipo de evento, Resultado, '
       'Clasificación, Activo biológico, Ciclo, Monto afectado. '
       'Incluye datos para el panel de detalle (datos_anteriores/datos_nuevos, '
       'reintentos, hash de integridad).';


-- ─────────────────────────────────────────────────────────────────────────────
-- RF-81 · Historial de Suministros
-- Pantalla: tabla consolidada alimentos + medicamentos, filtros por activo,
--           ciclo, tipo de suministro, origen del precio, rango de fechas,
--           rango de costos; panel de resumen (total registros, monto, especie)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW modulo5.vw_m05_historial_suministros AS
SELECT
    hsa.id_historial_suministro_activo,

    -- Activo y ciclo
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,

    -- Filtros del mockup
    hsa.origen                                                AS tipo_suministro_origen,
    hsa.fecha_inicio,
    hsa.fecha_fin,

    -- Totales del resumen (panel summary del mockup)
    hsa.num_registros_alimento,
    hsa.num_registros_medicamento,
    hsa.num_registros_alimento
        + hsa.num_registros_medicamento                      AS total_registros,
    hsa.costo_total_alimento,
    hsa.costo_total_medicamento,
    hsa.costo_total_suministros,

    -- Opciones de exportación
    hsa.formato_exportacion,
    hsa.fecha_consulta

FROM modulo5.historial_suministros_activos     hsa
JOIN modulo2.activos_biologicos                ab   ON ab.id_activo_biologico = hsa.id_activo_biologico
JOIN modulo9.especies                          e    ON e.id_especie           = ab.id_especie
JOIN modulo9.infraestructuras                  i    ON i.id_infraestructura   = ab.id_infraestructura
JOIN modulo9.fincas                            f    ON f.id_finca             = i.id_finca
LEFT JOIN modulo9.ciclos_productivos           cp   ON cp.id_ciclo_productivo = hsa.id_ciclo_productivos
LEFT JOIN modulo1.usuarios                     u    ON u.id_usuario           = hsa.id_usuario;

COMMENT ON VIEW modulo5.vw_m05_historial_suministros
    IS 'RF-81 (panel de resumen). Historial consolidado de suministros por activo. '
       'Alimenta los totales del panel summary: total registros, monto total, especie. '
       'Se complementa con vw_m05_historial_suministros_detalle para la tabla paginada.';


CREATE OR REPLACE VIEW modulo5.vw_m05_historial_suministros_detalle AS
-- Registros de alimentos
SELECT
    rs.id_registro_suministro,
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,
    'ALIMENTO'                                                AS tipo_suministro,
    ta.nombre                                                 AS detalle,
    rs.fecha_aplicacion,
    rs.cantidad,
    rs.unidad_medida,
    rs.precio_unitario_resuelto                               AS precio_unitario,
    rs.costo_registro                                         AS costo_total,
    rs.origen_precio,
    rs.tipo_operacion,
    rs.observacion,
    rs.fecha_registro,
    -- UUID de idempotencia para trazabilidad del mockup
    rs.id_registro_rf75                                       AS id_rf_origen

FROM modulo5.registro_suministro              rs
JOIN modulo2.activos_biologicos               ab   ON ab.id_activo_biologico = rs.id_activo_biologico
JOIN modulo9.especies                         e    ON e.id_especie           = ab.id_especie
JOIN modulo9.infraestructuras                 i    ON i.id_infraestructura   = ab.id_infraestructura
JOIN modulo9.fincas                           f    ON f.id_finca             = i.id_finca
JOIN modulo9.ciclos_productivos               cp   ON cp.id_ciclo_productivo = rs.id_ciclo_productivo
LEFT JOIN modulo5.tipos_alimentos             ta   ON ta.id_tipo_elemento::text = rs.id_idempotencia::text  -- relación semántica; ajustar FK cuando esté definida
WHERE rs.naturaleza_costo = 'INVERSION'

UNION ALL

-- Registros de medicamentos
SELECT
    rs.id_registro_suministro,
    ab.id_activo_biologico,
    ab.identificador                                          AS identificador_activo,
    e.nombre                                                  AS especie,
    f.nombre                                                  AS finca,
    cp.id_ciclo_productivo,
    cp.nombre                                                 AS ciclo_productivo,
    'MEDICAMENTO'                                             AS tipo_suministro,
    rm.nombre_medicamento                                     AS detalle,
    rs.fecha_aplicacion,
    rs.cantidad,
    rs.unidad_medida,
    rs.precio_unitario_resuelto                               AS precio_unitario,
    rs.costo_registro                                         AS costo_total,
    rs.origen_precio,
    rs.tipo_operacion,
    rs.observacion,
    rs.fecha_registro,
    rs.id_registro_rf76                                       AS id_rf_origen

FROM modulo5.registro_suministro              rs
JOIN modulo2.activos_biologicos               ab   ON ab.id_activo_biologico = rs.id_activo_biologico
JOIN modulo9.especies                         e    ON e.id_especie           = ab.id_especie
JOIN modulo9.infraestructuras                 i    ON i.id_infraestructura   = ab.id_infraestructura
JOIN modulo9.fincas                           f    ON f.id_finca             = i.id_finca
JOIN modulo9.ciclos_productivos               cp   ON cp.id_ciclo_productivo = rs.id_ciclo_productivo
LEFT JOIN modulo5.registros_medicamentos      rm
    ON rm.id_registro_rf76 = rs.id_registro_rf76
WHERE rs.naturaleza_costo = 'INVERSION';

COMMENT ON VIEW modulo5.vw_m05_historial_suministros_detalle
    IS 'RF-81 (tabla paginada). Detalle de todos los registros de suministro '
       '(alimentos y medicamentos) unificados. Columnas del mockup: Fecha, '
       'Ciclo, Tipo, Detalle, Origen del precio. '
       'Soporta los filtros: activo, ciclo, tipo de suministro, origen de precio, '
       'rango de fechas, costo mín/máx.';