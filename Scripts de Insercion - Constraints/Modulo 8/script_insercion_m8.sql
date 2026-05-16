-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 8
-- ==============================================================
--
-- TABLAS DEL MÓDULO 8:
--   1.  indicadores_kpi
--   2.  dashboards
--   3.  widgets_dashboard
--   4.  configuraciones_semaforo
--   5.  snapshots_kpi
--   6.  preferencias_visualizacion
--   7.  reportes_financieros
--   8.  reportes_regulatorios
--   9.  auditorias_reportes
--  10.  historiales_clinicos
--  11.  retroalimentacion_feedback
--  12.  acciones_critica_log
--  13.  consultas_auditoria_externas
--
-- TYPOS EN EL DDL (usar nombres exactos del DDL):
--   historiales_clinicos.procentaje_probabilidad (falta 's')
--   acciones_critica_log.resultado_operacion (enum sin prefijo modulo8)
--   preferencias_visualizacion.modo_accesebilidad (typo)
--   configuraciones_semaforo: columna NOT NULL lleva nombre
--     'configuraciones_semaforo_es_actvio_not_null' (typo)
--
-- ESTADO DE CONSTRAINTS EN EL BACKUP:
--   CHECKs INLINE ya activos en DDL (NO se re-ejecutan):
--     chk_accion_critica_clave_error_cuando_falla
--     chk_accion_critica_confirmacion_obligatoria
--     chk_accion_critica_tipo_valido
--     chk_auditoria_reporte_estado_final_valido
--     chk_auditoria_reporte_filtros_no_vacios
--     chk_semaforo_amarillo_menor_que_rojo
--     chk_semaforo_rango_amarillo_coherente
--     chk_semaforo_rango_rojo_coherente
--     chk_semaforo_rango_verde_coherente
--     chk_semaforo_rangos_sin_solapamiento
--     chk_semaforo_umbrales_positivos
--     chk_auditoria_ip_origen_real
--     chk_dashboard_nombre_notempty
--     check_fecha_historial_clinicos (duplicado de chk_historial_fechas_orden)
--     chk_historial_fechas_orden
--     chk_historial_nivel_riesgo_valido
--     chk_historial_probabilidad_rango
--     chk_historial_rango_max_24_meses
--     chk_historial_total_eventos_positivo
--     chk_historial_tvco_rango
--     checklk_tvco_porcentaje (typo en nombre — también en DDL)
--     chk_kpi_categoria_valida
--     chk_kpi_codigo_notempty
--     chk_reporte_financiero_ruta_notempty
--     chk_reporte_financiero_sha256_formato
--     chk_reporte_reg_ruta_cuando_generado
--     chk_reporte_reg_tamano_max_50mb
--     chk_reporte_reg_tipo_ente_valido
--     chk_snapshot_fecha_calculo_no_futura
--     chk_widget_dimensiones_positivas
--     chk_widget_posicion_positiva
--     chk_widget_titulo_notempty
--
--   FKs ACTIVAS (SIN NOT VALID):
--     fk_auditorias_reportes_regulatoria
--     fk_configuraciones_semaforo_indicador_kpi_id
--     fk_retroalimentacion_feedback_historial_clinico
--     fk_snapshots_kpi_indicadores_id
--     fk_widgets_dashboard_id
--     fk_consultas_auditoria_externas_auditoria (M8→M7)
--     fk_reportes_financieros_periodos_conatbles_id (M8→M6)
--     fk_reportes_regulatorios_periodo_contable_id (M8→M6)
--
--   UQs ELIMINADAS (re-creadas en constraints):
--     uq_accion_critica_id_operacion
--     uq_feedback_una_retro_por_vet_historial
--     uq_id_operacion
--     uq_indicador_kpi_codigo
--     uq_un_registro_por_usuario
--     uq_una_retro_vet_historial
--
-- ENUMs DEL MÓDULO 8:
--
--   acciones_critica_log_resultado_operacion:
--     'EXITOSO','FALLIDO','EN_CURSO','CANCELADO'

--   dashboards_estado_sincronizacion:
--     'SINCRONIZADO','SINCRONIZANDO','OFFLINE','CONFLICTO'
--
--   historiales_clinicos_predictivos_modo_visualizacion:
--     'LINEAL','AGRUPADO'
--
--   indicadores_kpi_modulo_origen:
--     'MODULO1'..'MODULO8'
--
--   reportes_regulatorios_estado:
--     'GENERADO','EN_PROCESO','FALLIDO','CANCELADO','EXPIRADO'
--
--   reportes_regulatorios_formato:
--     'PDF','EXCEL'
--
--   reportes_regulatorios_tipo:
--     'REPORTE_INVENTARIO_BIOLOGICO','REPORTE_COSTOS_SUMINISTROS',
--     'REPORTE_PRODUCTIVIDAD','REPORTE_BAJAS_Y_SALIDAS',
--     'REPORTE_VALORACION_NIC41','REPORTE_ESTADO_EXPORTACIONES',
--     'REPORTE_VARIACION_PERIODOS','REPORTE_HISTORICO_SANITARIO',
--     'REPORTE_FICHA_ANIMAL','REPORTE_VACUNACION_MEDICAMENTOS',
--     'REPORTE_RIESGO_SANITARIO','REPORTE_TELEMETRIA',
--     'REPORTE_ESTADO_DISPOSITIVOS','REPORTE_CALIBRACION_SENSORES',
--     'REPORTE_ALERTAS_SENSORES','REPORTE_EJECUTIVO_CONSOLIDADO',
--     'REPORTE_RENTABILIDAD_FINCA','REPORTE_COMPARATIVO_PERIODOS'

--   retroalimentacion_feedback_estado:
--     'CORRECTO','PARCIAL','INCORRECTO','SIN_EVENTO'
--
--   snapshots_kpi_estado_semaforo:
--     'VERDE','AMARILLO','ROJO'
-- ==============================================================

-- ==============================================================
-- PRECONDICIÓN 0 — VERIFICAR DEPENDENCIAS EXTERNAS
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo1.usuarios
        WHERE id_usuario IN (1, 2) HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo1.usuarios '
            'debe tener ids 1 y 2. Ejecute primero M1.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo6.periodos_contables
        WHERE id_periodo_contable IN (3, 4) HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo6.periodos_contables '
            'debe tener ids 3 y 4. Ejecute primero M6.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.infraestructuras
        WHERE id_infraestructura = 1
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo9.infraestructuras '
            'debe tener al menos 1 registro. Ejecute primero M9.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK internas):
--   1.  indicadores_kpi               ← sin FK interna M8
--   2.  dashboards                    ← sin FK interna M8
--   3.  widgets_dashboard             ← depende de 2
--   4.  configuraciones_semaforo      ← depende de 1
--   5.  snapshots_kpi                 ← depende de 1
--   6.  preferencias_visualizacion    ← sin FK interna M8
--   7.  reportes_financieros          ← depende de M6 (FK activa)
--   8.  reportes_regulatorios         ← depende de M6 (FK activa)
--   9.  auditorias_reportes           ← depende de 8
--  10.  historiales_clinicos          ← sin FK interna M8
--  11.  retroalimentacion_feedback    ← depende de 10
--  12.  acciones_critica_log          ← sin FK interna M8
--  13.  consultas_auditoria_externas  ← depende de M7 (FK activa)
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. INDICADORES KPI
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.indicadores_kpi
    (id_indicador_kpi, codigo, descripcion, categoria,
     unidad_medida, modulo_origen, formula,
     es_critico, fecha_creacion)
VALUES
-- KPIs financieros (M6)
(1, 'KPI-FIN-VR-TOTAL',
 'Valor razonable total de activos biológicos del período',
 'FINANCIERO', 'COP', 'MODULO6',
 'SUM(calculos_valor_razonable.valor_neto) '
 'WHERE id_periodo_contable = :periodo AND estado = ''CALCULADO''',
 true, NOW() - INTERVAL '200 days'),

(2, 'KPI-FIN-VARIACION-VR',
 'Variación neta de valor razonable en el período (ganancia/pérdida)',
 'FINANCIERO', 'COP', 'MODULO6',
 'SUM(variaciones_valor_razonable.monto_variacion) '
 'WHERE id_periodo_contable = :periodo',
 true, NOW() - INTERVAL '200 days'),

(3, 'KPI-FIN-COSTOS-MANTENIMIENTO',
 'Total de costos de mantenimiento registrados en el período',
 'FINANCIERO', 'COP', 'MODULO6',
 'SUM(registros_costos.monto_costo) '
 'WHERE naturaleza_costo = ''MANTENIMIENTO'' AND id_periodo_contable = :periodo',
 false, NOW() - INTERVAL '200 days'),

-- KPIs productivos (M5)
(4, 'KPI-PRD-CA-PROMEDIO',
 'Conversión alimenticia promedio de activos en ciclo activo',
 'PRODUCTIVO', 'kg/kg', 'MODULO5',
 'AVG(mediciones_incrementales.conversion_alimenticia) '
 'WHERE id_ciclo_productivo IN :ciclos_activos',
 true, NOW() - INTERVAL '200 days'),

(5, 'KPI-PRD-GANANCIA-PESO',
 'Ganancia de peso promedio por activo biológico en el período',
 'PRODUCTIVO', 'kg', 'MODULO5',
 'AVG(mediciones_incrementales.ganancia_peso) '
 'WHERE fecha_medicion BETWEEN :inicio AND :fin',
 false, NOW() - INTERVAL '200 days'),

-- KPIs sanitarios (M4)
(6, 'KPI-SAN-RIESGO-PATOLOGICO',
 'Porcentaje de activos con predicción de riesgo ALTO en el período',
 'SANITARIO', '%', 'MODULO4',
 'COUNT(*) FILTER (WHERE probabilidad_pct >= 75) * 100.0 / COUNT(*) '
 'FROM predicciones WHERE fecha_prediccion BETWEEN :inicio AND :fin',
 true, NOW() - INTERVAL '200 days'),

-- KPIs IoT (M3)
(7, 'KPI-IOT-DISPOSITIVOS-ACTIVOS',
 'Porcentaje de dispositivos IoT conectados sobre el total registrado',
 'IOT', '%', 'MODULO3',
 'COUNT(*) FILTER (WHERE estado = ''CONECTADO'') * 100.0 / COUNT(*) '
 'FROM estados_conectividad '
 'WHERE fecha_registro = (SELECT MAX(fecha_registro) FROM estados_conectividad)',
 false, NOW() - INTERVAL '200 days'),

-- KPI ambiental (M3)
(8, 'KPI-AMB-ALERTAS-CRITICAS',
 'Número de alertas de telemetría en nivel CRITICAL sin reconocer',
 'AMBIENTAL', 'unidades', 'MODULO3',
 'COUNT(*) FROM alertas_telemetria '
 'WHERE nivel = ''CRITICAL'' AND reconocida_por IS NULL',
 true, NOW() - INTERVAL '200 days');


-- ─────────────────────────────────────────────────────────────
-- 2. DASHBOARDS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.dashboards
    (id_dashboard, nombre, tipo, id_usuario,
     es_predeterminado, fecha_creacion, estado_sincronizacion)
VALUES
-- Dashboard principal del Productor
(1, 'Dashboard Operativo Principal',
 'OPERATIVO', 1,
 true, NOW() - INTERVAL '180 days',
 'SINCRONIZADO'),

-- Dashboard financiero del Contador
(2, 'Dashboard Financiero NIC 41',
 'FINANCIERO', 2,
 true, NOW() - INTERVAL '180 days',
 'SINCRONIZADO'),

-- Dashboard sanitario del Veterinario
(3, 'Dashboard Sanitario y Predictivo',
 'SANITARIO', 2,
 false, NOW() - INTERVAL '90 days',
 'SINCRONIZADO'),

-- Dashboard offline (no sincronizado aún)
(4, 'Dashboard Exportaciones AAEF',
 'INTEGRACION', 1,
 false, NOW() - INTERVAL '30 days',
 'OFFLINE');


-- ─────────────────────────────────────────────────────────────
-- 3. WIDGETS DASHBOARD
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.widgets_dashboard
    (id_widget_dashboard, id_dashboard, titulo, tipo_widget,
     fuente_datos, posicion_x, posicion_y, ancho, alto,
     configuracion, fecha_creacion)
VALUES
-- Dashboard 1: widgets operativos
(1, 1, 'Valor Razonable Total del Período',
 'METRICA_NUMERO', 'KPI-FIN-VR-TOTAL',
 0, 0, 6, 2,
 '{"formato": "moneda_cop", "prefijo": "$", "decimales": 0, "color": "#1F4E79"}',
 NOW() - INTERVAL '180 days'),

(2, 1, 'Variación de VR vs Período Anterior',
 'METRICA_VARIACION', 'KPI-FIN-VARIACION-VR',
 6, 0, 6, 2,
 '{"formato": "moneda_cop", "mostrar_flecha": true, "umbral_alerta": 0}',
 NOW() - INTERVAL '180 days'),

(3, 1, 'Conversión Alimenticia Promedio',
 'METRICA_NUMERO', 'KPI-PRD-CA-PROMEDIO',
 0, 2, 4, 2,
 '{"formato": "decimal_2", "sufijo": "kg/kg", "umbral_critico": 15.0}',
 NOW() - INTERVAL '180 days'),

(4, 1, 'Estado de Dispositivos IoT',
 'SEMAFORO_CIRCULAR', 'KPI-IOT-DISPOSITIVOS-ACTIVOS',
 4, 2, 4, 2,
 '{"umbral_verde_min": 80, "umbral_amarillo_min": 50, "mostrar_porcentaje": true}',
 NOW() - INTERVAL '180 days'),

(5, 1, 'Alertas Críticas Activas',
 'LISTA_ALERTAS', 'KPI-AMB-ALERTAS-CRITICAS',
 8, 2, 4, 4,
 '{"max_items": 5, "ordenar_por": "fecha_desc", "color_critico": "#FF0000"}',
 NOW() - INTERVAL '180 days'),

-- Dashboard 2: widgets financieros
(6, 2, 'Costos de Mantenimiento del Período',
 'GRAFICO_BARRAS', 'KPI-FIN-COSTOS-MANTENIMIENTO',
 0, 0, 12, 4,
 '{"agrupar_por": "subtipo_costo", "formato": "moneda_cop"}',
 NOW() - INTERVAL '180 days'),

(7, 2, 'Riesgo Sanitario por Activo',
 'GRAFICO_TORTA', 'KPI-SAN-RIESGO-PATOLOGICO',
 0, 4, 6, 4,
 '{"colores": {"ALTO": "#FF4444", "MEDIO": "#FFA500", "BAJO": "#44BB44"}}',
 NOW() - INTERVAL '180 days'),

-- Dashboard 3: widget sanitario
(8, 3, 'Activos con Riesgo Patológico Alto',
 'TABLA_DETALLE', 'KPI-SAN-RIESGO-PATOLOGICO',
 0, 0, 12, 6,
 '{"columnas": ["id_activo", "nombre", "probabilidad_pct", "fecha_prediccion"],
   "ordenar_por": "probabilidad_pct DESC", "max_filas": 10}',
 NOW() - INTERVAL '90 days');


-- ─────────────────────────────────────────────────────────────
-- 4. CONFIGURACIONES SEMÁFORO
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.configuraciones_semaforo
    (id_configuracion_semaforo, id_indicador_kpi,
     id_activo_biologico,
     umbral_verde_min, umbral_verde_max,
     umbral_amarillo_min, umbral_amarillo_max,
     umbral_rojo_min, umbral_rojo_max,
     fecha_vigencia, es_activo, id_infraestructura)
VALUES
-- Semáforo KPI conversión alimenticia bovinos (KPI id=4)
-- VERDE: CA entre 3 y 12, AMARILLO: 12-16, ROJO: > 16
(1, 4, NULL,
 3.00, 12.00,
 12.01, 16.00,
 16.01, 30.00,
 '2024-07-01', true, 1),

-- Semáforo KPI riesgo patológico (KPI id=6)
-- VERDE: riesgo < 20%, AMARILLO: 20-50%, ROJO: > 50%
(2, 6, NULL,
 0.00, 20.00,
 20.01, 50.00,
 50.01, 100.00,
 '2024-07-01', true, 1),

-- Semáforo KPI dispositivos IoT activos (KPI id=7)
-- VERDE: > 80%, AMARILLO: 50-80%, ROJO: < 50%
(3, 7, NULL,
 80.00, 100.00,
 50.00, 79.99,
 0.00, 49.99,
 '2024-07-01', true, 1),

-- Semáforo KPI alertas críticas activas (KPI id=8)
-- VERDE: 0 alertas, AMARILLO: 1-3, ROJO: > 3
(4, 8, NULL,
 0.00, 0.00,
 1.00, 3.00,
 3.01, 999.00,
 '2024-07-01', true, 1);


-- ─────────────────────────────────────────────────────────────
-- 5. SNAPSHOTS KPI
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.snapshots_kpi
    (id_snapshot_kpi, id_indicador_kpi, id_activo_biologico,
     id_infraestructura, estado_semaforo, fecha_calculo, metadatos)
VALUES
-- Snapshot VR Total Q3-2024 (KPI id=1)
(1, 1, 1, 1, 'VERDE',
 NOW() - INTERVAL '100 days',
 '{"valor": 4286400.00, "periodo": "Q3-2024",
   "unidad": "COP", "activos_incluidos": 3}'),

-- Snapshot CA BOV-001 (KPI id=4) — dentro del rango verde
(2, 4, 1, 1, 'VERDE',
 NOW() - INTERVAL '1 day',
 '{"valor": 14.41, "activo": "BOV-001", "ciclo": 1,
   "unidad": "kg/kg", "umbral_verde_max": 12.0,
   "nota": "Vaca lechera: CA alta por producción de leche"}'),

-- Snapshot CA LOTE-PEC-001 (KPI id=4) — excelente
(3, 4, 7, 1, 'VERDE',
 NOW() - INTERVAL '1 day',
 '{"valor": 0.90, "activo": "LOTE-PEC-001", "ciclo": 1,
   "unidad": "kg/kg"}'),

-- Snapshot riesgo BOV-003 (KPI id=6) — AMARILLO
(4, 6, 3, 1, 'AMARILLO',
 NOW() - INTERVAL '12 hours',
 '{"valor": 82.30, "activo": "BOV-003",
   "patologia": "estres_termico", "probabilidad_pct": 82.3}'),

-- Snapshot alertas críticas (KPI id=8) — ROJO
(5, 8, 7, 1, 'ROJO',
 NOW() - INTERVAL '1 hour',
 '{"valor": 1, "alertas_activas": 1,
   "detalle": "OD critico Alevinera-01: 2.8 mg/L"}');


-- ─────────────────────────────────────────────────────────────
-- 6. PREFERENCIAS DE VISUALIZACIÓN
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.preferencias_visualizacion
    (id_preferencia_visualizacion, id_usuario, idioma,
     tamano_fuente, modo_accesebilidad, mostrar_tooltips,
     fecha_actualizacion)
VALUES
-- Preferencias usuario 1 (Productor/Admin)
(1, 1, 'es-CO', 'NORMAL', false, true, NOW() - INTERVAL '90 days'),

-- Preferencias usuario 2 (Veterinario/Contador)
(2, 2, 'es-CO', 'GRANDE', false, true, NOW() - INTERVAL '60 days');


-- ─────────────────────────────────────────────────────────────
-- 7. REPORTES FINANCIEROS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.reportes_financieros
    (id_reporte_financiero, id_usuario, id_periodo_contable,
     tipo_reporte, formato, ruta_archivo,
     sha256_archivo, fecha_generacion)
VALUES
-- Reporte valoración NIC41 Q3-2024 (período CERRADO)
(1, 2, 3,
 'REPORTE_VALORACION_NIC41', 'PDF',
 's3://pecuaria-reportes/2024/Q3/valoracion-nic41-q3-2024.pdf',
 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
 NOW() - INTERVAL '100 days'),

-- Reporte variación de períodos Q3-2024
(2, 2, 3,
 'REPORTE_VARIACION_PERIODOS', 'EXCEL',
 's3://pecuaria-reportes/2024/Q3/variacion-periodos-q3-2024.xlsx',
 'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3',
 NOW() - INTERVAL '98 days'),

-- Reporte estado exportaciones Q3-2024
(3, 2, 3,
 'REPORTE_ESTADO_EXPORTACIONES', 'PDF',
 's3://pecuaria-reportes/2024/Q3/estado-exportaciones-q3-2024.pdf',
 'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4',
 NOW() - INTERVAL '95 days'),

-- Reporte rentabilidad finca Q2-2024
(4, 2, 2,
 'REPORTE_RENTABILIDAD_FINCA', 'PDF',
 's3://pecuaria-reportes/2024/Q2/rentabilidad-finca-q2-2024.pdf',
 'd4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5',
 NOW() - INTERVAL '200 days');


-- ─────────────────────────────────────────────────────────────
-- 8. REPORTES REGULATORIOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.reportes_regulatorios
    (id_reporte_regulatorio, id_usuario, formato,
     ruta_archivo, fecha_generacion, estado,
     id_finca, tipo_reporte, id_periodo_contable,
     id_activo_biologico, tamano_archivo_kb, tipo)
VALUES
-- Reporte inventario biológico Q3-2024 para ICA — GENERADO
(1, 1, 'PDF',
 's3://pecuaria-reportes/regulatorios/2024/Q3/inventario-biologico-ica-q3.pdf',
 NOW() - INTERVAL '100 days', 'GENERADO',
 1, 'REPORTE_INVENTARIO_BIOLOGICO', 3,
 1, 856, 'ICA'),

-- Reporte historial sanitario BOV-001 — GENERADO
(2, 2, 'PDF',
 's3://pecuaria-reportes/regulatorios/2024/Q3/historico-sanitario-bov001.pdf',
 NOW() - INTERVAL '95 days', 'GENERADO',
 1, 'REPORTE_HISTORICO_SANITARIO', 3,
 1, 312, 'ICA'),

-- Reporte vacunación y medicamentos LOTE-AV-002 — GENERADO
(3, 2, 'EXCEL',
 's3://pecuaria-reportes/regulatorios/2024/Q3/vacunacion-av002.xlsx',
 NOW() - INTERVAL '90 days', 'GENERADO',
 1, 'REPORTE_VACUNACION_MEDICAMENTOS', 3,
 6, 124, 'INTERNO'),

-- Reporte riesgo sanitario Q4-2024 — EN_PROCESO (sin ruta aún)
(4, 2, 'PDF',
 NULL,
 NOW() - INTERVAL '2 hours', 'EN_PROCESO',
 1, 'REPORTE_RIESGO_SANITARIO', 4,
 3, NULL, 'ICA'),

-- Reporte valoración NIC41 UPRA Q3-2024 — GENERADO
(5, 2, 'PDF',
 's3://pecuaria-reportes/regulatorios/2024/Q3/valoracion-nic41-upra.pdf',
 NOW() - INTERVAL '88 days', 'GENERADO',
 1, 'REPORTE_VALORACION_NIC41', 3,
 1, 2048, 'UPRA');

-- ─────────────────────────────────────────────────────────────
-- 9. AUDITORÍAS DE REPORTES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.auditorias_reportes
    (id_auditoria_reporte, id_reporte_regulatoria,
     filtros_aplicados, id_usuario,
     timestamp_snapshot, estado_final)
VALUES
-- Auditoría reporte 1 (inventario ICA)
(1, 1,
 '{"periodo": "Q3-2024", "id_finca": 1, "tipo_ente": "ICA",
   "formato": "PDF", "incluir_activos_bajas": false,
   "id_activo_biologico": null, "rango_fechas": "2024-07-01/2024-09-30"}',
 1, NOW() - INTERVAL '100 days', 'GENERADO'),

-- Auditoría reporte 2 (historial sanitario)
(2, 2,
 '{"periodo": "Q3-2024", "id_activo": 1, "tipo_ente": "ICA",
   "formato": "PDF", "incluir_retroalimentacion": true,
   "rango_fechas": "2024-07-01/2024-09-30"}',
 2, NOW() - INTERVAL '95 days', 'GENERADO'),

-- Auditoría reporte 3 (vacunación)
(3, 3,
 '{"periodo": "Q3-2024", "id_activo": 6, "tipo_ente": "INTERNO",
   "formato": "EXCEL", "incluir_vencimientos": true}',
 2, NOW() - INTERVAL '90 days', 'GENERADO'),

-- Auditoría reporte 4 (riesgo sanitario — en proceso)
(4, 4,
 '{"periodo": "Q4-2024", "id_activo": 3, "tipo_ente": "ICA",
   "formato": "PDF", "umbral_riesgo": "ALTO"}',
 2, NOW() - INTERVAL '2 hours', NULL);

-- ─────────────────────────────────────────────────────────────
-- 10. HISTORIALES CLÍNICOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.historiales_clinicos
    (id_historial_clinicos, id_activo_biologico,
     procentaje_probabilidad, nivel_riesgo, observaciones,
     fecha_registro, modo_visualizacion,
     total_eventos_sanitarios, fecha_inicio, fecha_fin,
     tvco_porcentaje)
VALUES
-- BOV-001: historial predictivo últimos 6 meses — riesgo BAJO
(1, 1,
 22.50, 'BAJO',
 'Vaca Holstein en producción normal. Sin eventos sanitarios relevantes. '
 'Predicción de estrés térmico en 22.5% para el período. '
 'Parámetros fisiológicos dentro de rangos normales.',
 NOW() - INTERVAL '1 day',
 'LINEAL', 0,
 '2024-07-01', '2024-12-31', 94.30),

-- BOV-003: historial predictivo — riesgo ALTO (estrés térmico)
(2, 3,
 94.10, 'ALTO',
 'Toro Simmental con escalación de estrés térmico. '
 'Dos observaciones clínicas consecutivas con temperatura > 39.5°C. '
 'Predicción crítica: 94.1% de probabilidad de estrés térmico severo. '
 'Se recomienda intervención veterinaria inmediata.',
 NOW() - INTERVAL '12 hours',
 'LINEAL', 1,
 '2024-10-01', '2024-12-31', 78.50),

-- BOV-004: historial predictivo — riesgo MEDIO (cetosis)
(3, 4,
 78.60, 'MEDIO',
 'Vaca Normando gestante. Cetosis subclínica detectada en primer mes posparto. '
 'BCS 2.5, reducción de apetito del 30%. BHBA estimado 1.8 mmol/L. '
 'Tratamiento con propilen glicol iniciado.',
 NOW() - INTERVAL '2 days',
 'LINEAL', 1,
 '2024-10-01', '2024-12-31', 85.20),

-- BOV-002: historial predictivo — riesgo BAJO
(4, 2,
 15.80, 'BAJO',
 'Novilla Brahman en desarrollo. Sin eventos sanitarios. '
 'Todos los parámetros dentro de rango normal.',
 NOW() - INTERVAL '1 day',
 'LINEAL', 0,
 '2024-10-01', '2024-12-31', 96.50);

-- ─────────────────────────────────────────────────────────────
-- 11. RETROALIMENTACIÓN FEEDBACK
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.retroalimentacion_feedback
    (id_retroalimentacion_feedback, id_historial_clinico,
     id_usuario, estado, tiene_conflicto, fecha_registro)
VALUES
-- Retroalimentación sobre BOV-003 (historial id=2, riesgo ALTO)
-- Veterinario confirma: estrés térmico CORRECTO
(1, 2, 2, 'CORRECTO', false, NOW() - INTERVAL '6 hours'),

-- Retroalimentación sobre BOV-004 (historial id=3, cetosis)
-- Veterinario confirma: predicción PARCIALMENTE correcta
(2, 3, 2, 'PARCIAL', false, NOW() - INTERVAL '1 day'),

-- Retroalimentación sobre BOV-001 (historial id=1)
-- Veterinario indica: sin evento real en el período
(3, 1, 2, 'SIN_EVENTO', false, NOW() - INTERVAL '1 day');

-- ─────────────────────────────────────────────────────────────
-- 12. ACCIONES CRÍTICAS LOG
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.acciones_critica_log
    (id_accion_critica_log, id_usuario, id_operacion,
     tipo_accion, resultado_operacion,
     requiere_confirmacion, confirmacion,
     fecha_ejecucion, clave_error_funcional)
VALUES
-- Cierre período Q3-2024 (exitoso, requería confirmación)
(1, 2,
 'f1a2b3c4-d5e6-7890-abcd-ef1234567890',
 'CIERRE_PERIODO', 'EXITOSO',
 true, true,
 NOW() - INTERVAL '100 days', NULL),

-- Exportación SIGCON Q3-2024 (exitosa)
(2, 2,
 'a2b3c4d5-e6f7-8901-bcde-f12345678901',
 'EXPORTACION_SIGCON', 'EXITOSO',
 false, NULL,
 NOW() - INTERVAL '100 days', NULL),

-- Reversión reconocimiento BOV-004 (exitosa, requería confirmación)
(3, 2,
 'b3c4d5e6-f7a8-9012-cdef-123456789012',
 'REVERSION_RECONOCIMIENTO', 'EXITOSO',
 true, true,
 NOW() - INTERVAL '170 days', NULL),

-- Generación reporte Q4-2024 (fallida — error de período ABIERTO)
-- Si resultado='FALLIDO' → clave_error_funcional obligatoria
(4, 2,
 'c4d5e6f7-a8b9-0123-def0-234567890123',
 'GENERACION_REPORTE', 'FALLIDO',
 false, NULL,
 NOW() - INTERVAL '60 days',
 'PERIODO_NO_CERRADO'),

-- Revocación credenciales cliente suspendido (exitosa)
(5, 1,
 'd5e6f7a8-b9c0-1234-ef01-345678901234',
 'REVOCACION_CREDENCIALES', 'EXITOSO',
 true, true,
 NOW() - INTERVAL '200 days', NULL);


-- ─────────────────────────────────────────────────────────────
-- 13. CONSULTAS DE AUDITORÍA EXTERNAS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo8.consultas_auditoria_externas
    (id_consulta_auditoria_externa, id_usuario,
     id_auditoria_peticion, fecha_consulta,
     ip_origen, observaciones)
VALUES
-- Consulta externa sobre la auditoría de la solicitud exitosa (id=1)
(1, 2,
 1,
 NOW() - INTERVAL '80 days',
 '190.144.32.10',
 'Revisión trimestral de auditoría de exportaciones AAEF. '
 'Verificación de integridad del paquete Q3-2024 enviado a Agrofusión.'),

-- Consulta externa sobre la auditoría de solicitud fallida (id=2)
(2, 2,
 2,
 NOW() - INTERVAL '55 days',
 '190.144.32.10',
 'Seguimiento del error INVALID_PERIOD en intento de exportación Q4-2024. '
 'Confirmación de que el período aún estaba ABIERTO al momento de la solicitud.'),

-- Consulta de auditoría de acceso no autorizado (id=3)
(3, 1,
 3,
 NOW() - INTERVAL '45 days',
 '192.168.1.100',
 'Investigación del intento de acceso no autorizado por Banco Agrario. '
 'Cliente en estado SUSPENDIDO intentó exportar datos del sistema.');
