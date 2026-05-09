-- ================================================================
-- CONSTRAINTS — MÓDULO 5
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo constraints NO existentes en el DDL del backup5_0_0.sql.
--
-- YA EXISTENTES en el backup (NO se re-ejecutan):
--
--   PKs (9): auditorias_suministros_pkey, costos_productivos_pkey,
--     historial_suministros_activos_pkey, mediciones_incrementales_pkey,
--     mediciones_inventarios_pkey, registros_consumo_alimentos_pkey,
--     registros_medicamentos_pkey, reporte_gastos_acumulados_pkey,
--     tipos_alimentos_pkey
--
--   FK ACTIVA (sin NOT VALID — ya válida):
--     fk_registro_consumo_alimento_tipo_alimento
--       registros_consumo_alimentos(id_tipo_alimento)
--       → modulo5.tipos_alimentos(id_tipo_elemento)
--
--   FKs ELIMINADAS EN MIGRACIÓN (referencias lógicas — NO se recrean):
--     Todas las FKs hacia modulo1, modulo2, modulo9 fueron
--     eliminadas en el backup. Son referencias lógicas sin
--     constraint formal activo (mismo patrón que M4).
--
--   UQ ELIMINADA (se re-crea en PARTE 1):
--     uq_tipo_alimento_nombre — eliminada en el backup.
--     El nombre del alimento debe ser único para evitar
--     duplicados en el catálogo.
--
--   CHECKs inline en DDL: NINGUNO en el backup5_0_0.sql.
--
-- NOTA SOBRE enum_medicion_incremental_esquema:
--   Este tipo fue declarado como TYPE COMPUESTO (AS), no ENUM.
--   No aplica CHECK ni enum_range sobre columnas de este tipo.
--
-- NOTA SOBRE ENUMs:
--   Las columnas ENUM ya restringen los valores por tipo.
--   No se incluyen CHECKs sobre columnas ENUM:
--     enum_auditoria_suministro_resultado
--     enum_auditoria_suministro_tipo_operacion
--     enum_costo_productivo_tipo_operacion
--     enum_historial_suministros_activos_formatos_exportacion
--     enum_historial_suministros_activos_origen
--     enum_medicion_inventario_estado_proceso
--     enum_medicion_inventario_tipo_costo
--     enum_registro_medicamenti_via_aplicacion
--     enum_tipo_alimento_estado
--
-- Se AGREGAN:
--   PARTE 1 — UNIQUE constraints
--   PARTE 2 — CHECK constraints directos
--   PARTE 3 — CHECK constraints diferidos (NOT VALID + VALIDATE)
--   PARTE 4 — Índices de desempeño
-- ================================================================

-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- ----------------------------------------------------------------

-- [P1] Verificar tipos_alimentos CESADO no referenciados en consumos activos:
-- SELECT rca.id_consumo_alimeto, ta.nombre, ta.estado
--   FROM modulo5.registros_consumo_alimentos rca
--   JOIN modulo5.tipos_alimentos ta ON ta.id_tipo_elemento = rca.id_tipo_alimento
--  WHERE ta.estado = 'CESADO';

-- [P2] Verificar costo_total en costos_productivos coherente:
-- SELECT id_costo_productivo, costo_medicamento, costo_mano_obra,
--        costo_infraestructura, costo_total,
--        (costo_medicamento + costo_mano_obra + costo_infraestructura) AS suma
--   FROM modulo5.costos_productivos
--  WHERE costo_total != (costo_medicamento + costo_mano_obra + costo_infraestructura);

-- [P3] Verificar nombres duplicados en tipos_alimentos antes de crear UQ:
-- SELECT nombre, COUNT(*) FROM modulo5.tipos_alimentos
--  GROUP BY nombre HAVING COUNT(*) > 1;

-- [P4] Verificar costo_total_medicamento en registros_medicamentos:
-- SELECT id_registro_medicamento, cantidad, costo_unitario_medicamento,
--        costo_total_medicamento,
--        ROUND(cantidad * costo_unitario_medicamento, 4) AS calculado
--   FROM modulo5.registros_medicamentos
--  WHERE ABS(costo_total_medicamento - ROUND(cantidad * costo_unitario_medicamento,4)) > 0.01;

-- [P5] Verificar conversión alimenticia coherente (CA = consumo/ganancia):
-- SELECT id_medicion_incremental, consumo_alimento_acumulado,
--        ganancia_peso, conversion_alimenticia,
--        ROUND(consumo_alimento_acumulado / NULLIF(ganancia_peso,0), 4) AS calculado
--   FROM modulo5.mediciones_incrementales
--  WHERE ABS(conversion_alimenticia - ROUND(consumo_alimento_acumulado
--            / NULLIF(ganancia_peso,0), 4)) > 0.001;


-- ================================================================
-- PARTE 1 — UNIQUE CONSTRAINTS
-- ================================================================

-- [RF-74] Nombre de alimento único en el catálogo
-- (uq_tipo_alimento_nombre fue eliminada en la migración; se re-crea)
ALTER TABLE modulo5.tipos_alimentos
    ADD CONSTRAINT uq_tipo_alimento_nombre
        UNIQUE (nombre);

-- ================================================================
-- PARTE 2 — CHECK CONSTRAINTS DIRECTOS
-- ================================================================

-- ──────────────────────────────────────────────────────────────
-- TABLA: tipos_alimentos
-- ──────────────────────────────────────────────────────────────

-- [RF-74] Costo unitario del alimento debe ser positivo
-- No tiene sentido un alimento con precio cero o negativo en el catálogo
ALTER TABLE modulo5.tipos_alimentos
    ADD CONSTRAINT chk_tipo_alimento_costo_positivo
        CHECK (costo_unitario > 0);

-- [RF-74] Unidad de medida no puede ser cadena vacía
ALTER TABLE modulo5.tipos_alimentos
    ADD CONSTRAINT chk_tipo_alimento_unidad_no_vacia
        CHECK (char_length(trim(unidad_medida)) > 0);

-- [RF-74] Nombre no puede ser cadena vacía
ALTER TABLE modulo5.tipos_alimentos
    ADD CONSTRAINT chk_tipo_alimento_nombre_no_vacio
        CHECK (char_length(trim(nombre)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: registros_consumo_alimentos
-- ──────────────────────────────────────────────────────────────

-- [RF-74] Cantidad suministrada positiva (> 0)
-- Restricción explícita RF-74: "cantidad_alimento_kg > 0.
-- No se permiten valores negativos ni cero."
ALTER TABLE modulo5.registros_consumo_alimentos
    ADD CONSTRAINT chk_consumo_cantidad_positiva
        CHECK (cantidad_suministrada > 0);

-- [RF-74] Costo total no negativo cuando está definido
ALTER TABLE modulo5.registros_consumo_alimentos
    ADD CONSTRAINT chk_consumo_costo_no_negativo
        CHECK (costo_total IS NULL OR costo_total >= 0);

-- [RF-74] Coherencia temporal del período de consumo
ALTER TABLE modulo5.registros_consumo_alimentos
    ADD CONSTRAINT chk_consumo_periodo_coherente
        CHECK (
            fecha_inicio_periodo IS NULL
            OR fecha_fin_periodo IS NULL
            OR fecha_inicio_periodo <= fecha_fin_periodo
        );

-- [RF-74] Unidad no vacía
ALTER TABLE modulo5.registros_consumo_alimentos
    ADD CONSTRAINT chk_consumo_unidad_no_vacia
        CHECK (char_length(trim(tipo_unidad)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: registros_medicamentos
-- ──────────────────────────────────────────────────────────────

-- [RF-75] Cantidad de medicamento positiva (> 0)
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_cantidad_positiva
        CHECK (cantidad > 0);

-- [RF-75] Costo unitario positivo (precio confirmado obligatorio)
-- Restricción RF-77: "el cálculo solo utiliza precios confirmados"
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_costo_unitario_positivo
        CHECK (costo_unitario_medicamento > 0);

-- [RF-75] Costo total positivo
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_costo_total_positivo
        CHECK (costo_total_medicamento > 0);

-- [RF-75] Coherencia matemática: costo_total = cantidad × costo_unitario
-- Tolerancia de 1 unidad monetaria para errores de redondeo
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_costo_total_coherente
        CHECK (
            ABS(costo_total_medicamento
                - ROUND(cantidad * costo_unitario_medicamento, 4)) <= 1.0
        );

-- [RF-75] Lote no vencido al momento de la aplicación
-- fehca_vencimietno_lote (typo en DDL) debe ser >= fecha_aplicacion
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_lote_no_vencido
        CHECK (
            fehca_vencimietno_lote IS NULL
            OR fehca_vencimietno_lote >= fecha_aplicacion
        );

-- [RF-75] Unidad de dosis no vacía
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_unidad_dosis_no_vacia
        CHECK (char_length(trim(unidad_dosis)) > 0);

-- [RF-75] Nombre del medicamento no vacío
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_nombre_no_vacio
        CHECK (char_length(trim(nombre_medicamento)) > 0);

-- [RF-75] descripcion_clinica con contenido mínimo (RF-75 restringe
-- que el campo sea obligatorio y tenga mínimo contenido relevante)
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_descripcion_minima
        CHECK (char_length(trim(descripcion_clinica)) >= 20);

-- ──────────────────────────────────────────────────────────────
-- TABLA: costos_productivos
-- ──────────────────────────────────────────────────────────────

-- [RF-77] Costos individuales no negativos
ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_medicamento_no_negativo
        CHECK (costo_medicamento >= 0);

ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_mano_obra_no_negativo
        CHECK (costo_mano_obra >= 0);

ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_infraestructura_no_negativo
        CHECK (costo_infraestructura >= 0);

-- [RF-77] Costo total positivo (debe haber al menos algún costo)
ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_total_positivo
        CHECK (costo_total > 0);

-- [RF-77] Coherencia matemática del costo total
-- costo_total = costo_medicamento + costo_mano_obra + costo_infraestructura
ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_total_coherente
        CHECK (
            ABS(costo_total
                - (costo_medicamento + costo_mano_obra + costo_infraestructura))
            <= 1.0
        );

-- [RF-77] Coherencia de fechas del cálculo
ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_fechas_coherentes
        CHECK (fecha_final_calculo >= fecha_inicio_calculo);

-- ──────────────────────────────────────────────────────────────
-- TABLA: mediciones_incrementales
-- ──────────────────────────────────────────────────────────────

-- [RF-74 CA] Peso actual positivo
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_peso_actual_positivo
        CHECK (peso_actual > 0);

-- [RF-74 CA] Peso inicial del ciclo positivo
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_peso_inicial_positivo
        CHECK (peso_inicial_ciclo > 0);

-- [RF-74 CA] Ganancia de peso positiva (requisito para que CA sea calculable)
-- Restricción explícita RF-74: "ganancia_peso > 0"
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_ganancia_positiva
        CHECK (ganancia_peso > 0);

-- [RF-74 CA] Coherencia ganancia = actual - inicial
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_ganancia_coherente
        CHECK (
            ABS(ganancia_peso - (peso_actual - peso_inicial_ciclo)) <= 0.001
        );

-- [RF-74 CA] Consumo de alimento acumulado positivo
-- Restricción explícita RF-74: "alimento_consumido_total > 0 kg"
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_consumo_positivo
        CHECK (consumo_alimento_acumulado > 0);

-- [RF-74 CA] Conversión alimenticia positiva
-- CA = consumo / ganancia, ambos positivos → CA siempre positivo
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_ca_positiva
        CHECK (conversion_alimenticia > 0);

-- [RF-74 CA] Costo acumulado de inversión no negativo
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_costo_acumulado_no_negativo
        CHECK (costo_acumulado_inversion >= 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: mediciones_inventarios
-- ──────────────────────────────────────────────────────────────

-- [RF-77] Costo directo positivo (> 0, hay un costo real registrado)
ALTER TABLE modulo5.mediciones_inventarios
    ADD CONSTRAINT chk_inv_costo_directo_positivo
        CHECK (costo_directo > 0);

-- [RF-77] Costo acumulado >= costo directo
-- El acumulado siempre incluye al menos el costo directo del período
ALTER TABLE modulo5.mediciones_inventarios
    ADD CONSTRAINT chk_inv_costo_acumulado_coherente
        CHECK (costo_acumulado >= costo_directo);

-- ──────────────────────────────────────────────────────────────
-- TABLA: reporte_gastos_acumulados
-- ──────────────────────────────────────────────────────────────

-- [RF-76] Costos individuales no negativos (DEFAULT 0)
ALTER TABLE modulo5.reporte_gastos_acumulados
    ADD CONSTRAINT chk_reporte_costo_alimento_no_negativo
        CHECK (total_costo_alimento >= 0);

ALTER TABLE modulo5.reporte_gastos_acumulados
    ADD CONSTRAINT chk_reporte_costo_medicamento_no_negativo
        CHECK (total_costo_medicamento >= 0);

-- [RF-76] Costo directo total igual a suma de alimento + medicamento
ALTER TABLE modulo5.reporte_gastos_acumulados
    ADD CONSTRAINT chk_reporte_costo_directo_coherente
        CHECK (
            ABS(total_costo_directo
                - (total_costo_alimento + total_costo_medicamento))
            <= 1.0
        );

-- [RF-76] Coherencia de fechas del reporte
-- fecha_incio_reporte / fecha_fin_report (typos en DDL)
ALTER TABLE modulo5.reporte_gastos_acumulados
    ADD CONSTRAINT chk_reporte_fechas_coherentes
        CHECK (fecha_fin_report >= fecha_incio_reporte);

-- ──────────────────────────────────────────────────────────────
-- TABLA: historial_suministros_activos
-- ──────────────────────────────────────────────────────────────

-- [RF-80] Costos totales no negativos
ALTER TABLE modulo5.historial_suministros_activos
    ADD CONSTRAINT chk_historial_costos_no_negativos
        CHECK (
            costo_total_alimento >= 0
            AND costo_total_medicamento >= 0
            AND costo_total_suministros >= 0
        );

-- [RF-80] Coherencia: costo_total_suministros = alimento + medicamento
ALTER TABLE modulo5.historial_suministros_activos
    ADD CONSTRAINT chk_historial_costo_suministros_coherente
        CHECK (
            ABS(costo_total_suministros
                - (costo_total_alimento + costo_total_medicamento))
            <= 1.0
        );

-- [RF-80] Contadores de registros no negativos
ALTER TABLE modulo5.historial_suministros_activos
    ADD CONSTRAINT chk_historial_contadores_no_negativos
        CHECK (
            num_registros_medicamento >= 0
            AND num_registros_alimento >= 0
        );

-- [RF-80] Coherencia rango de fechas del historial
ALTER TABLE modulo5.historial_suministros_activos
    ADD CONSTRAINT chk_historial_fechas_coherentes
        CHECK (
            fecha_inicio IS NULL
            OR fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        );

-- [RF-80] Si origen = ALIMENTO, costo_medicamento debe ser 0
ALTER TABLE modulo5.historial_suministros_activos
    ADD CONSTRAINT chk_historial_origen_alimento_coherente
        CHECK (
            origen != 'ALIMENTO'
            OR costo_total_medicamento = 0
        );

-- [RF-80] Si origen = MEDICAMENTO, costo_alimento debe ser 0
ALTER TABLE modulo5.historial_suministros_activos
    ADD CONSTRAINT chk_historial_origen_medicamento_coherente
        CHECK (
            origen != 'MEDICAMENTO'
            OR costo_total_alimento = 0
        );


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS DIFERIDOS (NOT VALID + VALIDATE)
-- ================================================================

-- [RF-74] fecha_registro de consumo no futura
ALTER TABLE modulo5.registros_consumo_alimentos
    ADD CONSTRAINT chk_consumo_fecha_no_futura
        CHECK (fecha_registro IS NULL OR fecha_registro <= NOW())
        NOT VALID;
ALTER TABLE modulo5.registros_consumo_alimentos
    VALIDATE CONSTRAINT chk_consumo_fecha_no_futura;

-- [RF-74] fecha_fin_periodo de consumo no futura
ALTER TABLE modulo5.registros_consumo_alimentos
    ADD CONSTRAINT chk_consumo_periodo_no_futuro
        CHECK (fecha_fin_periodo IS NULL OR fecha_fin_periodo <= NOW())
        NOT VALID;
ALTER TABLE modulo5.registros_consumo_alimentos
    VALIDATE CONSTRAINT chk_consumo_periodo_no_futuro;

-- [RF-75] fecha_aplicacion de medicamento no futura
-- Restricción explícita RF-75: "fecha_aplicacion no puede ser
-- posterior a la fecha actual"
ALTER TABLE modulo5.registros_medicamentos
    ADD CONSTRAINT chk_medicamento_fecha_no_futura
        CHECK (fecha_aplicacion <= CURRENT_DATE)
        NOT VALID;
ALTER TABLE modulo5.registros_medicamentos
    VALIDATE CONSTRAINT chk_medicamento_fecha_no_futura;

-- [RF-77] fecha_final_calculo de costos no futura
ALTER TABLE modulo5.costos_productivos
    ADD CONSTRAINT chk_costo_fecha_final_no_futura
        CHECK (fecha_final_calculo <= CURRENT_DATE)
        NOT VALID;
ALTER TABLE modulo5.costos_productivos
    VALIDATE CONSTRAINT chk_costo_fecha_final_no_futura;

-- [RF-74 CA] fecha_medicion incremental no futura
ALTER TABLE modulo5.mediciones_incrementales
    ADD CONSTRAINT chk_mi_fecha_no_futura
        CHECK (fecha_medicion <= CURRENT_DATE)
        NOT VALID;
ALTER TABLE modulo5.mediciones_incrementales
    VALIDATE CONSTRAINT chk_mi_fecha_no_futura;

-- [RF-77] fecha_medicion de inventario no futura
ALTER TABLE modulo5.mediciones_inventarios
    ADD CONSTRAINT chk_inv_fecha_no_futura
        CHECK (fecha_medicion <= CURRENT_DATE)
        NOT VALID;
ALTER TABLE modulo5.mediciones_inventarios
    VALIDATE CONSTRAINT chk_inv_fecha_no_futura;

-- [RF-76] fecha_fin_report de reporte no futura
-- Restricción explícita RF-76: "fecha_fin_reporte <= fecha_actual"
ALTER TABLE modulo5.reporte_gastos_acumulados
    ADD CONSTRAINT chk_reporte_fecha_no_futura
        CHECK (fecha_fin_report <= CURRENT_DATE)
        NOT VALID;
ALTER TABLE modulo5.reporte_gastos_acumulados
    VALIDATE CONSTRAINT chk_reporte_fecha_no_futura;

-- [RF-79] fecha_evento de auditoría no futura
ALTER TABLE modulo5.auditorias_suministros
    ADD CONSTRAINT chk_auditoria_fecha_no_futura
        CHECK (fecha_evento <= NOW())
        NOT VALID;
ALTER TABLE modulo5.auditorias_suministros
    VALIDATE CONSTRAINT chk_auditoria_fecha_no_futura;


-- ================================================================
-- PARTE 4 — ÍNDICES DE DESEMPEÑO
-- ================================================================

-- [RF-74] Consulta de consumos por activo y período (CA mensual)
CREATE INDEX IF NOT EXISTS idx_consumo_activo_periodo
    ON modulo5.registros_consumo_alimentos
    (id_activo_biologico, fecha_inicio_periodo DESC, fecha_fin_periodo DESC);

-- [RF-75] Consulta de medicamentos por activo y fecha
CREATE INDEX IF NOT EXISTS idx_medicamento_activo_fecha
    ON modulo5.registros_medicamentos
    (id_activo_biologico, fecha_aplicacion DESC);

-- [RF-76] Consulta de reportes por activo y rango de fechas
CREATE INDEX IF NOT EXISTS idx_reporte_activo_fechas
    ON modulo5.reporte_gastos_acumulados
    (id_activo_biologico, fecha_incio_reporte, fecha_fin_report);

-- [RF-77] Consulta de costos acumulados por ciclo productivo
CREATE INDEX IF NOT EXISTS idx_costo_ciclo_activo
    ON modulo5.costos_productivos
    (id_ciclo_productivo, id_activo_biologico, fecha_calculo DESC);

-- [RF-74 CA] Consulta de mediciones incrementales por activo y ciclo
CREATE INDEX IF NOT EXISTS idx_medicion_incremental_activo_ciclo
    ON modulo5.mediciones_incrementales
    (id_activo_biologico, id_ciclo_productivo, fecha_medicion DESC);

-- [RF-77] Mediciones de inventario por activo, ciclo y tipo de costo
CREATE INDEX IF NOT EXISTS idx_medicion_inventario_activo_tipo
    ON modulo5.mediciones_inventarios
    (id_activo_biologico, id_ciclo_productivo, tipo_costo);

-- [RF-80] Historial de suministros por activo y fecha de consulta
CREATE INDEX IF NOT EXISTS idx_historial_activo_fecha
    ON modulo5.historial_suministros_activos
    (id_activo_biologico, fecha_consulta DESC);

-- [RF-79] Auditorías por entidad afectada y fecha (trazabilidad)
CREATE INDEX IF NOT EXISTS idx_auditoria_entidad_fecha
    ON modulo5.auditorias_suministros
    (entidad_afectada, fecha_evento DESC);

-- [RF-79] Auditorías por usuario (seguimiento de actividad)
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario_fecha
    ON modulo5.auditorias_suministros
    (id_usuario, fecha_evento DESC);

-- [RF-74] Tipos de alimento activos (filtro frecuente)
CREATE INDEX IF NOT EXISTS idx_tipo_alimento_estado
    ON modulo5.tipos_alimentos (estado)
    WHERE estado = 'ACTIVO';


-- ================================================================
-- REFERENCIA: ESTADO FINAL DE CONSTRAINTS EN EL BACKUP
-- ================================================================
--
-- PKs existentes (9 tablas) — no se re-ejecutan.
--
-- FK ACTIVA (sin NOT VALID):
--   fk_registro_consumo_alimento_tipo_alimento
--     registros_consumo_alimentos(id_tipo_alimento)
--     → modulo5.tipos_alimentos(id_tipo_elemento)
--   Esta es la ÚNICA FK activa del módulo 5.
--   No requiere VALIDATE (ya es válida).
--
-- FKs ELIMINADAS EN MIGRACIÓN (referencias lógicas):
--   fk_auditoria_suministro_sesion       → modulo1.sesiones
--   fk_auditoria_suministro_usuario      → modulo1.usuarios
--   fk_costo_productivo_activo_biologico → modulo2.activos_biologicos
--   fk_costo_productivo_ciclo_productivo → modulo9.ciclos_productivos
--   fk_historial_suministros_activo_biologico
--   fk_historial_suministros_activos_ciclo_productivo
--   fk_historial_suministros_activos_usuario
--   fk_medicion_incremental_activo_biologico
--   fk_medicion_incremental_ciclo_productivo
--   fk_medicion_incremental_usuario
--   fk_medicion_inventario_activo_biologico
--   fk_medicion_inventario_ciclo_productivo
--   fk_medicion_inventario_usuario
--   fk_registro_consumo_alimento_activo_biologico
--   fk_registro_consumo_alimento_usuario
--   fk_registro_gasto_acumulado_activo_biologico
--   fk_registro_gasto_acumulado_infraestructura
--   fk_registro_gasto_acumulado_usuario
--   fk_registro_medicamento_activo_biologico
--   fk_registro_medicamento_usuario
--   fk_registro_medicamento_usuario_vet
--
-- UQ ELIMINADA (re-creada en PARTE 1):
--   uq_tipo_alimento_nombre
--
-- ================================================================
