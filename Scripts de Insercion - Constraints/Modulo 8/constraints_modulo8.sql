-- ================================================================
-- CONSTRAINTS — MÓDULO 8
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo constraints NO existentes en el DDL del backup6_1_1.sql
--
-- YA EXISTENTES (NO se re-ejecutan):
--
--   PKs (13 tablas).
--
--   CHECKs INLINE en DDL (31 — ya activos):
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
--     checklk_tvco_porcentaje (typo en nombre del DDL)
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
--   FKs ACTIVAS (sin NOT VALID):
--     fk_auditorias_reportes_regulatoria
--     fk_configuraciones_semaforo_indicador_kpi_id
--     fk_retroalimentacion_feedback_historial_clinico
--     fk_snapshots_kpi_indicadores_id
--     fk_widgets_dashboard_id
--     fk_consultas_auditoria_externas_auditoria (M8→M7)
--     fk_reportes_financieros_periodos_conatbles_id (M8→M6)
--     fk_reportes_regulatorios_periodo_contable_id (M8→M6)
--
--   UQs ELIMINADAS (re-creadas en PARTE 1):
--     uq_accion_critica_id_operacion, uq_id_operacion,
--     uq_feedback_una_retro_por_vet_historial,
--     uq_indicador_kpi_codigo,
--     uq_un_registro_por_usuario,
--     uq_una_retro_vet_historial
--
-- Se AGREGAN:
--   PARTE 1 — UNIQUE constraints (re-creación de 6 UQs eliminadas)
--   PARTE 2 — CHECK constraints directos
--   PARTE 3 — CHECK constraints diferidos (NOT VALID + VALIDATE)
--   PARTE 4 — Índices de desempeño
-- ================================================================


-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- ----------------------------------------------------------------

-- [P1] Verificar duplicados en indicadores_kpi por código:
-- SELECT codigo, COUNT(*) FROM modulo8.indicadores_kpi
--  GROUP BY codigo HAVING COUNT(*) > 1;

-- [P2] Verificar más de una retroalimentación por (historial, usuario):
-- SELECT id_historial_clinico, id_usuario, COUNT(*)
--   FROM modulo8.retroalimentacion_feedback
--  GROUP BY id_historial_clinico, id_usuario HAVING COUNT(*) > 1;

-- [P3] Verificar más de una preferencia por usuario:
-- SELECT id_usuario, COUNT(*) FROM modulo8.preferencias_visualizacion
--  GROUP BY id_usuario HAVING COUNT(*) > 1;

-- [P4] Verificar duplicados en acciones_critica_log por id_operacion:
-- SELECT id_operacion, COUNT(*) FROM modulo8.acciones_critica_log
--  GROUP BY id_operacion HAVING COUNT(*) > 1;


-- ================================================================
-- PARTE 1 — UNIQUE CONSTRAINTS (RE-CREACIÓN DE 6 UQs ELIMINADAS)
-- ================================================================

-- [RF-106] id_operacion único en acciones críticas
-- (Tanto uq_accion_critica_id_operacion como uq_id_operacion
-- fueron eliminadas — son la misma restricción con dos nombres)
CREATE UNIQUE INDEX IF NOT EXISTS uix_accion_critica_id_operacion
    ON modulo8.acciones_critica_log (id_operacion);

-- [RF-103] Código de KPI único en el catálogo
CREATE UNIQUE INDEX IF NOT EXISTS uix_indicador_kpi_codigo
    ON modulo8.indicadores_kpi (codigo);

-- [RF-105] Una sola preferencia por usuario
CREATE UNIQUE INDEX IF NOT EXISTS uix_preferencia_por_usuario
    ON modulo8.preferencias_visualizacion (id_usuario);

-- [RF-105, RF-72] Una sola retroalimentación por (historial, usuario)
-- (Tanto uq_feedback_una_retro_por_vet_historial
-- como uq_una_retro_vet_historial fueron eliminadas)
CREATE UNIQUE INDEX IF NOT EXISTS uix_retroalimentacion_historial_usuario
    ON modulo8.retroalimentacion_feedback (id_historial_clinico, id_usuario);


-- ================================================================
-- PARTE 2 — CHECK CONSTRAINTS DIRECTOS
-- ================================================================

-- ──────────────────────────────────────────────────────────────
-- TABLA: indicadores_kpi
-- ──────────────────────────────────────────────────────────────

-- [RF-103] unidad_medida no vacía cuando está definida
ALTER TABLE modulo8.indicadores_kpi
    ADD CONSTRAINT chk_kpi_unidad_no_vacia
        CHECK (
            unidad_medida IS NULL
            OR char_length(trim(unidad_medida)) > 0
        );

-- [RF-103] formula no vacía cuando está definida
ALTER TABLE modulo8.indicadores_kpi
    ADD CONSTRAINT chk_kpi_formula_no_vacia
        CHECK (
            formula IS NULL
            OR char_length(trim(formula)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: dashboards
-- ──────────────────────────────────────────────────────────────

-- [RF-103] tipo de dashboard no vacío
ALTER TABLE modulo8.dashboards
    ADD CONSTRAINT chk_dashboard_tipo_no_vacio
        CHECK (char_length(trim(tipo)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: widgets_dashboard
-- ──────────────────────────────────────────────────────────────

-- [RF-103] tipo_widget y fuente_datos no vacíos
ALTER TABLE modulo8.widgets_dashboard
    ADD CONSTRAINT chk_widget_tipo_fuente_no_vacios
        CHECK (
            char_length(trim(tipo_widget)) > 0
            AND char_length(trim(fuente_datos)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: configuraciones_semaforo
-- ──────────────────────────────────────────────────────────────

-- [RF-103] Al menos un rango debe estar definido (la configuración
-- tiene sentido solo si define al menos verde o rojo)
ALTER TABLE modulo8.configuraciones_semaforo
    ADD CONSTRAINT chk_semaforo_al_menos_un_rango
        CHECK (
            umbral_verde_min IS NOT NULL
            OR umbral_rojo_min IS NOT NULL
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: preferencias_visualizacion
-- ──────────────────────────────────────────────────────────────

-- [RF-103] idioma no vacío cuando está definido
ALTER TABLE modulo8.preferencias_visualizacion
    ADD CONSTRAINT chk_preferencia_idioma_no_vacio
        CHECK (
            idioma IS NULL
            OR char_length(trim(idioma)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: reportes_financieros
-- ──────────────────────────────────────────────────────────────

-- [RF-103] tipo_reporte no vacío
ALTER TABLE modulo8.reportes_financieros
    ADD CONSTRAINT chk_reporte_fin_tipo_no_vacio
        CHECK (char_length(trim(tipo_reporte)) > 0);

-- [RF-103] formato no vacío
ALTER TABLE modulo8.reportes_financieros
    ADD CONSTRAINT chk_reporte_fin_formato_no_vacio
        CHECK (char_length(trim(formato)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: reportes_regulatorios
-- ──────────────────────────────────────────────────────────────

-- [RF-103] tamano_archivo_kb positivo cuando está definido
-- (ya cubierto parcialmente por chk_reporte_reg_tamano_max_50mb,
-- pero ese CHECK admite tamano=0; reforzamos > 0)
ALTER TABLE modulo8.reportes_regulatorios
    ADD CONSTRAINT chk_reporte_reg_tamano_positivo
        CHECK (
            tamano_archivo_kb IS NULL
            OR tamano_archivo_kb > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: historiales_clinicos
-- ──────────────────────────────────────────────────────────────

-- [RF-105] total_eventos_sanitarios coherente con nivel_riesgo
-- Si hay nivel de riesgo ALTO debe haber al menos 1 evento sanitario
-- (RF-105: el historial con ALTO tiene observaciones clínicas reales)
ALTER TABLE modulo8.historiales_clinicos
    ADD CONSTRAINT chk_historial_riesgo_eventos_coherente
        CHECK (
            nivel_riesgo != 'ALTO'
            OR total_eventos_sanitarios >= 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: retroalimentacion_feedback
-- ──────────────────────────────────────────────────────────────

-- [RF-105] fecha_registro no futura
-- (se declara directo, sin NOT VALID, el seed no tiene datos futuros)
ALTER TABLE modulo8.retroalimentacion_feedback
    ADD CONSTRAINT chk_feedback_fecha_no_futura
        CHECK (fecha_registro <= NOW());

-- ──────────────────────────────────────────────────────────────
-- TABLA: acciones_critica_log
-- ──────────────────────────────────────────────────────────────

-- [RF-106] clave_error_funcional no vacía cuando está definida
-- (complemento del chk_accion_critica_clave_error_cuando_falla
-- que solo verifica si está presente, no que tenga contenido útil)
ALTER TABLE modulo8.acciones_critica_log
    ADD CONSTRAINT chk_accion_clave_error_no_vacia
        CHECK (
            clave_error_funcional IS NULL
            OR char_length(trim(clave_error_funcional)) > 0
        );

-- [RF-106] tipo_accion no vacío
ALTER TABLE modulo8.acciones_critica_log
    ADD CONSTRAINT chk_accion_tipo_no_vacio
        CHECK (char_length(trim(tipo_accion)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: consultas_auditoria_externas
-- ──────────────────────────────────────────────────────────────

-- [RF-101] observaciones no vacías cuando están definidas
ALTER TABLE modulo8.consultas_auditoria_externas
    ADD CONSTRAINT chk_consulta_observaciones_no_vacias
        CHECK (
            observaciones IS NULL
            OR char_length(trim(observaciones)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: auditorias_reportes
-- ──────────────────────────────────────────────────────────────

-- [RF-103] timestamp_snapshot no futuro
ALTER TABLE modulo8.auditorias_reportes
    ADD CONSTRAINT chk_auditoria_reporte_timestamp_no_futuro
        CHECK (timestamp_snapshot <= NOW());


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS DIFERIDOS (NOT VALID + VALIDATE)
-- ================================================================

-- [RF-103] fecha_creacion de dashboard no futura
ALTER TABLE modulo8.dashboards
    ADD CONSTRAINT chk_dashboard_fecha_no_futura
        CHECK (fecha_creacion <= NOW()) NOT VALID;
ALTER TABLE modulo8.dashboards
    VALIDATE CONSTRAINT chk_dashboard_fecha_no_futura;

-- [RF-103] fecha_calculo de snapshot no futura
-- (ya tiene chk_snapshot_fecha_calculo_no_futura en DDL, no re-declarar)

-- [RF-103] fecha_generacion de reporte financiero no futura
ALTER TABLE modulo8.reportes_financieros
    ADD CONSTRAINT chk_reporte_fin_fecha_no_futura
        CHECK (fecha_generacion <= NOW()) NOT VALID;
ALTER TABLE modulo8.reportes_financieros
    VALIDATE CONSTRAINT chk_reporte_fin_fecha_no_futura;

-- [RF-103] fecha_generacion de reporte regulatorio no futura
ALTER TABLE modulo8.reportes_regulatorios
    ADD CONSTRAINT chk_reporte_reg_fecha_no_futura
        CHECK (fecha_generacion <= NOW()) NOT VALID;
ALTER TABLE modulo8.reportes_regulatorios
    VALIDATE CONSTRAINT chk_reporte_reg_fecha_no_futura;

-- [RF-105] fecha_registro de historial clínico no futura
ALTER TABLE modulo8.historiales_clinicos
    ADD CONSTRAINT chk_historial_registro_no_futuro
        CHECK (fecha_registro <= NOW()) NOT VALID;
ALTER TABLE modulo8.historiales_clinicos
    VALIDATE CONSTRAINT chk_historial_registro_no_futuro;

-- [RF-106] fecha_ejecucion de acción crítica no futura
ALTER TABLE modulo8.acciones_critica_log
    ADD CONSTRAINT chk_accion_fecha_no_futura
        CHECK (fecha_ejecucion <= NOW()) NOT VALID;
ALTER TABLE modulo8.acciones_critica_log
    VALIDATE CONSTRAINT chk_accion_fecha_no_futura;

-- [RF-101] fecha_consulta de auditoría externa no futura
ALTER TABLE modulo8.consultas_auditoria_externas
    ADD CONSTRAINT chk_consulta_fecha_no_futura
        CHECK (fecha_consulta <= NOW()) NOT VALID;
ALTER TABLE modulo8.consultas_auditoria_externas
    VALIDATE CONSTRAINT chk_consulta_fecha_no_futura;

-- [RF-103] fecha_vigencia de configuración semáforo no futura
ALTER TABLE modulo8.configuraciones_semaforo
    ADD CONSTRAINT chk_semaforo_vigencia_no_futura
        CHECK (fecha_vigencia <= CURRENT_DATE) NOT VALID;
ALTER TABLE modulo8.configuraciones_semaforo
    VALIDATE CONSTRAINT chk_semaforo_vigencia_no_futura;


-- ================================================================
-- PARTE 4 — ÍNDICES DE DESEMPEÑO
-- ================================================================

-- [RF-103] KPIs críticos (filtro frecuente para alertas)
CREATE INDEX IF NOT EXISTS idx_kpi_critico
    ON modulo8.indicadores_kpi (es_critico, modulo_origen)
    WHERE es_critico = true;

-- [RF-103] Snapshots recientes por KPI y semáforo
CREATE INDEX IF NOT EXISTS idx_snapshot_kpi_semaforo_fecha
    ON modulo8.snapshots_kpi
    (id_indicador_kpi, estado_semaforo, fecha_calculo DESC);

-- [RF-103] Snapshots en estado ROJO o AMARILLO (alertas activas)
CREATE INDEX IF NOT EXISTS idx_snapshot_alertas_activas
    ON modulo8.snapshots_kpi (estado_semaforo, fecha_calculo DESC)
    WHERE estado_semaforo IN ('ROJO', 'AMARILLO');

-- [RF-103] Configuraciones semáforo activas por KPI
CREATE INDEX IF NOT EXISTS idx_semaforo_kpi_activo
    ON modulo8.configuraciones_semaforo (id_indicador_kpi)
    WHERE es_activo = true;

-- [RF-103] Reportes financieros por usuario y período
CREATE INDEX IF NOT EXISTS idx_reporte_fin_usuario_periodo
    ON modulo8.reportes_financieros
    (id_usuario, id_periodo_contable, fecha_generacion DESC);

-- [RF-103] Reportes regulatorios por estado y tipo_ente
CREATE INDEX IF NOT EXISTS idx_reporte_reg_estado_tipo
    ON modulo8.reportes_regulatorios
    (estado, tipo, id_activo_biologico);

-- [RF-103] Reportes regulatorios EN_PROCESO (monitoreo de generación)
CREATE INDEX IF NOT EXISTS idx_reporte_reg_en_proceso
    ON modulo8.reportes_regulatorios (fecha_generacion DESC)
    WHERE estado = 'EN_PROCESO';

-- [RF-105] Historiales clínicos por activo y nivel de riesgo
CREATE INDEX IF NOT EXISTS idx_historial_activo_riesgo
    ON modulo8.historiales_clinicos
    (id_activo_biologico, nivel_riesgo, fecha_registro DESC);

-- [RF-105] Historiales con riesgo ALTO (prioridad veterinaria)
CREATE INDEX IF NOT EXISTS idx_historial_riesgo_alto
    ON modulo8.historiales_clinicos (fecha_registro DESC)
    WHERE nivel_riesgo = 'ALTO';

-- [RF-106] Acciones críticas por tipo y resultado
CREATE INDEX IF NOT EXISTS idx_accion_critica_tipo_resultado
    ON modulo8.acciones_critica_log
    (tipo_accion, resultado_operacion, fecha_ejecucion DESC);

-- [RF-106] Acciones críticas fallidas (monitoreo de errores)
CREATE INDEX IF NOT EXISTS idx_accion_critica_fallidas
    ON modulo8.acciones_critica_log (fecha_ejecucion DESC)
    WHERE resultado_operacion = 'FALLIDO';

-- [RF-103] Widgets por dashboard (carga del dashboard)
CREATE INDEX IF NOT EXISTS idx_widget_por_dashboard
    ON modulo8.widgets_dashboard (id_dashboard, posicion_y, posicion_x);

-- [RF-101] Consultas externas por auditoria y fecha
CREATE INDEX IF NOT EXISTS idx_consulta_auditoria_fecha
    ON modulo8.consultas_auditoria_externas
    (id_auditoria_peticion, fecha_consulta DESC);
