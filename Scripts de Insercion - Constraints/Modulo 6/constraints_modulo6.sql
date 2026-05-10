-- ================================================================
-- CONSTRAINTS — MÓDULO 6
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo constraints NO existentes en el DDL del backup.
--
-- COMPATIBILIDAD backup6_0_0.sql:
--   Verificado contra backup6_0_0.sql. No se requieren cambios
--   respecto a la versión backup5_0_0.sql. El backup6 añade
--   tablas del módulo 8 y dos FKs de M8 → modulo6.periodos_contables,
--   pero el DDL de las 14 tablas de M6, los 25 ENUMs, los 10 CHECKs
--   inline y las 7 UQs eliminadas son idénticos en ambas versiones.
--
-- YA EXISTENTES en el backup (NO se re-ejecutan):
--
--   PKs (14 tablas):
--     auditorias_financieras_pkey, calculos_valor_razonable_pkey,
--     cotizaciones_pkey, deterorios_activos_pkey,
--     mediciones_posteriores_pkey, parametros_costos_venta_pkey,
--     periodos_contables_pkey, precios_mercado_pkey,
--     reconocimientos_iniciales_pkey,
--     reconocimientos_productos_agricolas_pkey,
--     registros_costos_pkey, revisiones_reconocimiento_pkey,
--     valoraciones_por_costos_pkey,
--     "variaciones_valor_razonable _pkey"
--
--   CHECKs inline en DDL (10 — ya activos):
--     chk_manual_requiere_justificacion   (calculos_valor_razonable)
--     chk_anulacion_requiere_motivo       (cotizaciones)
--     chk_estimada_requiere_justificacion (precios_mercado)
--     chk_precio_vencimiento              (precios_mercado)
--     chk_vigencia_no_retroactiva         (precios_mercado)
--     chk_periodo_fechas                  (periodos_contables)
--     chk_variacion_total_coherente       (mediciones_posteriores)
--     chk_monto_coherente                 (variaciones_valor_razonable)
--     chk_accounting_account_no_vacio     (registros_costos)
--     chk_exportable_type_code            (registros_costos)
--
--   FKs ACTIVAS (sin NOT VALID — no requieren VALIDATE CONSTRAINT):
--     Ver listado completo en encabezado de script_insercion_m6.sql.
--
--   UQs ELIMINADAS EN MIGRACIÓN (7, re-creadas en PARTE 1):
--     unique_valoraciones_por_costos_activo_biologico
--     "uq_param_especie_region ", "uq_periodo_rango "
--     uq_precio_especie_cat_fuente_vigencia
--     uq_reconocimeinto_revertido
--     uq_reconocimientos_iniciales_id_activo_biologico
--     uq_reconocimientos_productos_agricolas_evento_productivo
--
-- NOTA SOBRE ENUMs:
--   Los 25 ENUMs de M6 ya restringen valores por tipo.
--   No se incluyen CHECKs IN() sobre columnas ENUM.
--
-- Se AGREGAN:
--   PARTE 1 — UNIQUE constraints (re-creación de 7 UQs eliminadas)
--   PARTE 2 — CHECK constraints directos
--   PARTE 3 — CHECK constraints diferidos (NOT VALID + VALIDATE)
--   PARTE 4 — Índices de desempeño
-- ================================================================


-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- ----------------------------------------------------------------

-- [P1] Verificar que no haya más de un período ABIERTO:
-- SELECT COUNT(*) FROM modulo6.periodos_contables WHERE estado = 'ABIERTO';
-- Si > 1, corregir antes de crear uix_periodo_unico_abierto.

-- [P2] Verificar reconocimiento vigente único por activo:
-- SELECT id_actvo_biologico, COUNT(*)
--   FROM modulo6.reconocimientos_iniciales
--  WHERE estado != 'REVERTIDO'
--  GROUP BY id_actvo_biologico HAVING COUNT(*) > 1;

-- [P3] Verificar coherencia valor_neto en calculos_valor_razonable:
-- SELECT id_calculo_valor_razonable,
--        ABS(valor_neto - (valor_razonable_bruto - costo_transporte
--            - costo_comisiones - costo_impuestos_transaccion
--            - otros_costos_disposicion)) AS diferencia
--   FROM modulo6.calculos_valor_razonable
--  WHERE ABS(valor_neto - (valor_razonable_bruto - costo_transporte
--        - costo_comisiones - costo_impuestos_transaccion
--        - otros_costos_disposicion)) > 1.0;

-- [P4] Verificar coherencia valor_contable_por_costo en valoraciones:
-- SELECT id_valoracion_por_costo,
--        ABS(valor_contable_por_costo
--            - GREATEST(0, costos_adquisicion
--              - depreciacion_acumulada - deterioro_acumulado)) AS diferencia
--   FROM modulo6.valoraciones_por_costos
--  WHERE ABS(valor_contable_por_costo
--            - GREATEST(0, costos_adquisicion
--              - depreciacion_acumulada - deterioro_acumulado)) > 1.0;

-- [P5] Verificar una sola revisión por reconocimiento:
-- SELECT id_reconocimiento_revertido, COUNT(*)
--   FROM modulo6.revisiones_reconocimiento
--  GROUP BY id_reconocimiento_revertido HAVING COUNT(*) > 1;


-- ================================================================
-- PARTE 1 — UNIQUE CONSTRAINTS (RE-CREACIÓN DE UQs ELIMINADAS)
-- ================================================================

-- [RF-87] Un solo período ABIERTO simultáneamente
-- (el enum tiene espacio al final: 'EN_CIERRE ')
-- EJECUTAR BLOQUE 0 [P1] antes si hay múltiples ABIERTOS
CREATE UNIQUE INDEX IF NOT EXISTS uix_periodo_unico_abierto
    ON modulo6.periodos_contables (estado)
    WHERE estado = 'ABIERTO';

-- [RF-87] Rango de fechas único por período (sin solapamiento)
-- ("uq_periodo_rango " fue eliminada — con espacio)
CREATE UNIQUE INDEX IF NOT EXISTS uix_periodo_rango_fechas
    ON modulo6.periodos_contables (fecha_inicio, fecha_fin);

-- [RF-84] Parámetro de costo único por especie y región activa
-- ("uq_param_especie_region " fue eliminada — con espacio)
CREATE UNIQUE INDEX IF NOT EXISTS uix_param_especie_region
    ON modulo6.parametros_costos_venta (id_especie, region)
    WHERE es_activo = true;

-- [RF-89] Precio único por especie, fuente y fecha de vigencia
-- (uq_precio_especie_cat_fuente_vigencia fue eliminada)
-- NOTA: cagetoria es ARRAY; no puede ser parte de UNIQUE directamente.
-- El índice cubre especie, fuente y vigencia como aproximación robusta.
CREATE UNIQUE INDEX IF NOT EXISTS uix_precio_especie_fuente_vigencia
    ON modulo6.precios_mercado (id_especie, fuente, fecha_vigencia)
    WHERE estado IN ('ACTIVO', 'PROGRAMADO');

-- [RF-82] Un solo reconocimiento vigente por activo biológico
-- (uq_reconocimientos_iniciales_id_activo_biologico fue eliminada)
-- EJECUTAR BLOQUE 0 [P2] antes si hay duplicados
CREATE UNIQUE INDEX IF NOT EXISTS uix_reconocimiento_activo_vigente
    ON modulo6.reconocimientos_iniciales (id_actvo_biologico)
    WHERE estado != 'REVERTIDO';

-- [RF-85] Un reconocimiento de producto por evento productivo
-- (uq_reconocimientos_productos_agricolas_evento_productivo fue eliminada)
CREATE UNIQUE INDEX IF NOT EXISTS uix_reconoc_producto_evento
    ON modulo6.reconocimientos_productos_agricolas (id_evento_productivo);

-- [RF-82] Una sola reversión por reconocimiento inicial
-- (uq_reconocimeinto_revertido fue eliminada — con typo en nombre)
CREATE UNIQUE INDEX IF NOT EXISTS uix_revision_por_reconocimiento
    ON modulo6.revisiones_reconocimiento (id_reconocimiento_revertido);

-- [RF-88] Una sola valoración por costo activa por activo biológico
-- (unique_valoraciones_por_costos_activo_biologico fue eliminada)
-- EJECUTAR BLOQUE 0 si hay múltiples activas por activo
CREATE UNIQUE INDEX IF NOT EXISTS uix_valoracion_costo_activa
    ON modulo6.valoraciones_por_costos (id_activo_biologico)
    WHERE es_activa = true;


-- ================================================================
-- PARTE 2 — CHECK CONSTRAINTS DIRECTOS
-- ================================================================

-- ──────────────────────────────────────────────────────────────
-- TABLA: periodos_contables
-- ──────────────────────────────────────────────────────────────

-- [RF-87] Período no ABIERTO → fecha_cierre obligatoria
ALTER TABLE modulo6.periodos_contables
    ADD CONSTRAINT chk_periodo_cierre_coherente
        CHECK (estado = 'ABIERTO' OR fecha_cierre IS NOT NULL);

-- [RF-87] fecha_cierre posterior al inicio del período
ALTER TABLE modulo6.periodos_contables
    ADD CONSTRAINT chk_periodo_cierre_posterior_inicio
        CHECK (
            fecha_cierre IS NULL
            OR fecha_cierre >= fecha_inicio::timestamp with time zone
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: parametros_costos_venta
-- ──────────────────────────────────────────────────────────────

-- [RF-84] Porcentajes como proporciones en [0, 1]
ALTER TABLE modulo6.parametros_costos_venta
    ADD CONSTRAINT chk_param_pct_transporte_rango
        CHECK (pct_transporte >= 0 AND pct_transporte <= 1);

ALTER TABLE modulo6.parametros_costos_venta
    ADD CONSTRAINT chk_param_pct_comisiones_rango
        CHECK (pct_comisiones >= 0 AND pct_comisiones <= 1);

ALTER TABLE modulo6.parametros_costos_venta
    ADD CONSTRAINT chk_param_pct_impuestos_rango
        CHECK (pct_impuestos >= 0 AND pct_impuestos <= 1);

-- [RF-84] Región no vacía
ALTER TABLE modulo6.parametros_costos_venta
    ADD CONSTRAINT chk_param_region_no_vacia
        CHECK (char_length(trim(region)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: precios_mercado
-- ──────────────────────────────────────────────────────────────

-- [RF-89] Precio unitario positivo
ALTER TABLE modulo6.precios_mercado
    ADD CONSTRAINT chk_precio_unitario_positivo
        CHECK (precio_unitario > 0);

-- [RF-89] Evidencia no vacía (obligatoria RF-89)
ALTER TABLE modulo6.precios_mercado
    ADD CONSTRAINT chk_precio_evidencia_no_vacia
        CHECK (char_length(trim(evidencia)) > 0);

-- [RF-89] Unidad de medida no vacía
ALTER TABLE modulo6.precios_mercado
    ADD CONSTRAINT chk_precio_unidad_no_vacia
        CHECK (char_length(trim(unidad_medida)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: calculos_valor_razonable
-- ──────────────────────────────────────────────────────────────

-- [RF-84] Valor razonable bruto positivo
ALTER TABLE modulo6.calculos_valor_razonable
    ADD CONSTRAINT chk_calculo_bruto_positivo
        CHECK (valor_razonable_bruto > 0);

-- [RF-84] Costos de disposición no negativos
ALTER TABLE modulo6.calculos_valor_razonable
    ADD CONSTRAINT chk_calculo_costos_no_negativos
        CHECK (
            costo_transporte >= 0
            AND costo_comisiones >= 0
            AND costo_impuestos_transaccion >= 0
            AND otros_costos_disposicion >= 0
        );

-- [RF-84] Coherencia valor_neto = bruto - suma_costos (±1 COP redondeo)
-- valor_neto puede ser <= 0 (RF-84 lo permite explícitamente)
ALTER TABLE modulo6.calculos_valor_razonable
    ADD CONSTRAINT chk_calculo_valor_neto_coherente
        CHECK (
            ABS(valor_neto
                - (valor_razonable_bruto
                   - costo_transporte - costo_comisiones
                   - costo_impuestos_transaccion
                   - otros_costos_disposicion)) <= 1.0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: reconocimientos_iniciales
-- ──────────────────────────────────────────────────────────────

-- [RF-82] Valor razonable neto inicial positivo
ALTER TABLE modulo6.reconocimientos_iniciales
    ADD CONSTRAINT chk_reconoc_valor_positivo
        CHECK (valor_razonable_neto_inicial > 0);

-- [RF-82] Costos de venta estimados no negativos
ALTER TABLE modulo6.reconocimientos_iniciales
    ADD CONSTRAINT chk_reconoc_costos_venta_no_negativos
        CHECK (costos_venta_estimados >= 0);

-- [RF-82] Cuentas PUC no vacías
ALTER TABLE modulo6.reconocimientos_iniciales
    ADD CONSTRAINT chk_reconoc_cuentas_no_vacias
        CHECK (
            char_length(trim(cuenta_debito)) > 0
            AND char_length(trim(cuenta_credito)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: revisiones_reconocimiento
-- ──────────────────────────────────────────────────────────────

-- [RF-82] Monto de reversión positivo
ALTER TABLE modulo6.revisiones_reconocimiento
    ADD CONSTRAINT chk_revision_monto_positivo
        CHECK (monto_revision > 0);

-- [RF-82] Motivo mínimo de 20 caracteres (justificación real)
ALTER TABLE modulo6.revisiones_reconocimiento
    ADD CONSTRAINT chk_revision_motivo_minimo
        CHECK (char_length(trim(motivo_revision)) >= 20);

-- [RF-82] Cuentas de reverso no vacías
ALTER TABLE modulo6.revisiones_reconocimiento
    ADD CONSTRAINT chk_revision_cuentas_no_vacias
        CHECK (
            char_length(trim(cuenta_debito)) > 0
            AND char_length(trim(cuenta_credito)) > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: mediciones_posteriores
-- ──────────────────────────────────────────────────────────────

-- [RF-83] Valores razonables positivos
ALTER TABLE modulo6.mediciones_posteriores
    ADD CONSTRAINT chk_medicion_valores_positivos
        CHECK (
            valor_razonable_anterior > 0
            AND valor_razonable_actual > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: reconocimientos_productos_agricolas
-- ──────────────────────────────────────────────────────────────

-- [RF-85] Cantidad cosechada positiva
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_cantidad_positiva
        CHECK (cantidad_cosechada > 0);

-- [RF-85] Precio de mercado del producto positivo
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_precio_positivo
        CHECK (precio_mercado_producto > 0);

-- [RF-85] Coherencia valor_producto = (precio - costo) × cantidad (±1 COP)
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_valor_coherente
        CHECK (
            ABS(valor_producto
                - ((precio_mercado_producto - costo_venta_producto)
                   * cantidad_cosechada)) <= 1.0
        );

-- [RF-85] Unidad de medida y nombre del producto no vacíos
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_unidad_no_vacia
        CHECK (char_length(trim(unidad_medida)) > 0);

ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_nombre_no_vacio
        CHECK (char_length(trim(producto_agricola)) > 0);

-- [RF-85] proporcion_cosechada en (0, 1] cuando está definida
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_proporcion_rango
        CHECK (
            proporcion_cosechada IS NULL
            OR (proporcion_cosechada > 0 AND proporcion_cosechada <= 1)
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: variaciones_valor_razonable
-- ──────────────────────────────────────────────────────────────

-- [RF-86] Valores razonables positivos
ALTER TABLE modulo6.variaciones_valor_razonable
    ADD CONSTRAINT chk_variacion_vr_positivos
        CHECK (
            valor_razonable_anterior > 0
            AND valor_razonable_nuevo > 0
        );

-- ──────────────────────────────────────────────────────────────
-- TABLA: valoraciones_por_costos
-- ──────────────────────────────────────────────────────────────

-- [RF-88] Costo de adquisición positivo
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_adquisicion_positivo
        CHECK (costos_adquisicion > 0);

-- [RF-88] Tasa de depreciación en (0, 1]
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_tasa_depreciacion_rango
        CHECK (tasa_depreciacion > 0 AND tasa_depreciacion <= 1);

-- [RF-88] Depreciación y deterioro acumulados no negativos
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_acumulados_no_negativos
        CHECK (
            depreciacion_acumulada >= 0
            AND deterioro_acumulado >= 0
        );

-- [RF-88] valor_contable >= 0 (si deprec + deterioro > costo → se establece en 0)
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_valor_contable_no_negativo
        CHECK (valor_contable_por_costo >= 0);

-- [RF-88] Coherencia: valor_contable = max(0, costo - deprec - deterioro) ±1 COP
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_formula_coherente
        CHECK (
            ABS(valor_contable_por_costo
                - GREATEST(0,
                    costos_adquisicion
                    - depreciacion_acumulada
                    - deterioro_acumulado)) <= 1.0
        );

-- [RF-88] Razón sin mercado mínimo 30 caracteres (justificación real)
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_razon_no_vacia
        CHECK (char_length(trim(razon_sin_mercado)) >= 30);

-- ──────────────────────────────────────────────────────────────
-- TABLA: deterorios_activos
-- ──────────────────────────────────────────────────────────────

-- [RF-88] Impacto económico positivo
ALTER TABLE modulo6.deterorios_activos
    ADD CONSTRAINT chk_deterioro_impacto_positivo
        CHECK (impacto_economico_cop > 0);

-- [RF-88] Justificación mínimo 30 caracteres
ALTER TABLE modulo6.deterorios_activos
    ADD CONSTRAINT chk_deterioro_justificacion_minima
        CHECK (char_length(trim(justificacion)) >= 30);

-- ──────────────────────────────────────────────────────────────
-- TABLA: registros_costos
-- ──────────────────────────────────────────────────────────────

-- [RF-90] Monto de costo positivo
ALTER TABLE modulo6.registros_costos
    ADD CONSTRAINT chk_costo_monto_positivo
        CHECK (monto_costo > 0);

-- [RF-90] MANTENIMIENTO nunca capitalizable — restricción absoluta e irrevocable
ALTER TABLE modulo6.registros_costos
    ADD CONSTRAINT chk_costo_mantenimiento_no_capitalizable
        CHECK (
            naturaleza_costo != 'MANTENIMIENTO'
            OR politica_capitalizacion IS NULL
        );

-- [RF-90] line_type no vacío
ALTER TABLE modulo6.registros_costos
    ADD CONSTRAINT chk_costo_line_type_no_vacio
        CHECK (char_length(trim(line_type)) > 0);

-- ──────────────────────────────────────────────────────────────
-- TABLA: cotizaciones
-- ──────────────────────────────────────────────────────────────

-- [RF-COT] valor_razonable_referencia positivo
ALTER TABLE modulo6.cotizaciones
    ADD CONSTRAINT chk_cotizacion_vr_referencia_positivo
        CHECK (valor_razonable_referencia > 0);

-- [RF-COT] accounting_account entre 1 y 2 elementos
ALTER TABLE modulo6.cotizaciones
    ADD CONSTRAINT chk_cotizacion_account_rango
        CHECK (
            accounting_account IS NOT NULL
            AND array_length(accounting_account, 1) >= 1
            AND array_length(accounting_account, 1) <= 2
        );


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS DIFERIDOS (NOT VALID + VALIDATE)
-- ================================================================

-- [RF-87] fecha_inicio de período no futura
ALTER TABLE modulo6.periodos_contables
    ADD CONSTRAINT chk_periodo_inicio_no_futuro
        CHECK (fecha_inicio <= CURRENT_DATE) NOT VALID;
ALTER TABLE modulo6.periodos_contables
    VALIDATE CONSTRAINT chk_periodo_inicio_no_futuro;

-- [RF-84] fecha_calculo no futura
ALTER TABLE modulo6.calculos_valor_razonable
    ADD CONSTRAINT chk_calculo_fecha_no_futura
        CHECK (fecha_calculo <= NOW()) NOT VALID;
ALTER TABLE modulo6.calculos_valor_razonable
    VALIDATE CONSTRAINT chk_calculo_fecha_no_futura;

-- [RF-82] fecha_reconocimiento no futura (columna con espacio al final)
ALTER TABLE modulo6.reconocimientos_iniciales
    ADD CONSTRAINT chk_reconoc_fecha_no_futura
        CHECK ("fecha_reconocimiento " IS NULL
               OR "fecha_reconocimiento " <= NOW()) NOT VALID;
ALTER TABLE modulo6.reconocimientos_iniciales
    VALIDATE CONSTRAINT chk_reconoc_fecha_no_futura;

-- [RF-83] fecha_medicion posterior no futura
ALTER TABLE modulo6.mediciones_posteriores
    ADD CONSTRAINT chk_medicion_fecha_no_futura
        CHECK (fecha_medicion <= NOW()) NOT VALID;
ALTER TABLE modulo6.mediciones_posteriores
    VALIDATE CONSTRAINT chk_medicion_fecha_no_futura;

-- [RF-85] fecha_cosecha no futura
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    ADD CONSTRAINT chk_prod_agricola_cosecha_no_futura
        CHECK (fecha_cosecha <= CURRENT_DATE) NOT VALID;
ALTER TABLE modulo6.reconocimientos_productos_agricolas
    VALIDATE CONSTRAINT chk_prod_agricola_cosecha_no_futura;

-- [RF-86] fecha_registro de variación no futura
ALTER TABLE modulo6.variaciones_valor_razonable
    ADD CONSTRAINT chk_variacion_fecha_no_futura
        CHECK (fecha_registro <= NOW()) NOT VALID;
ALTER TABLE modulo6.variaciones_valor_razonable
    VALIDATE CONSTRAINT chk_variacion_fecha_no_futura;

-- [RF-88] fecha_adquisicion en valoración por costo no futura
ALTER TABLE modulo6.valoraciones_por_costos
    ADD CONSTRAINT chk_valcosto_adquisicion_no_futura
        CHECK (fecha_adquisicion <= CURRENT_DATE) NOT VALID;
ALTER TABLE modulo6.valoraciones_por_costos
    VALIDATE CONSTRAINT chk_valcosto_adquisicion_no_futura;

-- [RF-88] fecha_registro deterioro no futura
ALTER TABLE modulo6.deterorios_activos
    ADD CONSTRAINT chk_deterioro_fecha_no_futura
        CHECK (fecha_registro <= NOW()) NOT VALID;
ALTER TABLE modulo6.deterorios_activos
    VALIDATE CONSTRAINT chk_deterioro_fecha_no_futura;

-- [RF-90] fecha_registro de costo no futura
ALTER TABLE modulo6.registros_costos
    ADD CONSTRAINT chk_costo_fecha_no_futura
        CHECK (fecha_registro <= NOW()) NOT VALID;
ALTER TABLE modulo6.registros_costos
    VALIDATE CONSTRAINT chk_costo_fecha_no_futura;

-- [RF-COT] fecha_emision de cotización no futura
ALTER TABLE modulo6.cotizaciones
    ADD CONSTRAINT chk_cotizacion_emision_no_futura
        CHECK (fecha_emision <= CURRENT_DATE) NOT VALID;
ALTER TABLE modulo6.cotizaciones
    VALIDATE CONSTRAINT chk_cotizacion_emision_no_futura;

-- [RF-94] fecha_registro de auditoría financiera no futura
ALTER TABLE modulo6.auditorias_financieras
    ADD CONSTRAINT chk_auditoria_financiera_fecha_no_futura
        CHECK (fecha_registro <= NOW()) NOT VALID;
ALTER TABLE modulo6.auditorias_financieras
    VALIDATE CONSTRAINT chk_auditoria_financiera_fecha_no_futura;


-- ================================================================
-- PARTE 4 — ÍNDICES DE DESEMPEÑO
-- ================================================================

-- [RF-87] Estado del período (filtro más frecuente del módulo)
CREATE INDEX IF NOT EXISTS idx_periodo_estado
    ON modulo6.periodos_contables (estado, fecha_inicio DESC);

-- [RF-84] Cálculos por activo y período
CREATE INDEX IF NOT EXISTS idx_calculo_activo_periodo
    ON modulo6.calculos_valor_razonable
    (id_activo_biologico, id_periodo_contable, fecha_calculo DESC);

-- [RF-89] Precios por especie, fuente y estado (valoración periódica)
CREATE INDEX IF NOT EXISTS idx_precio_especie_fuente_estado
    ON modulo6.precios_mercado
    (id_especie, fuente, estado, fecha_vigencia DESC);

-- [RF-82] Reconocimientos por activo y estado
CREATE INDEX IF NOT EXISTS idx_reconoc_activo_estado
    ON modulo6.reconocimientos_iniciales (id_actvo_biologico, estado);

-- [RF-83] Mediciones posteriores por activo y período
CREATE INDEX IF NOT EXISTS idx_medicion_activo_periodo
    ON modulo6.mediciones_posteriores
    (id_activo_biologico, id_periodo_contable, fecha_medicion DESC);

-- [RF-86] Variaciones por activo, tipo y período (estado de resultados)
CREATE INDEX IF NOT EXISTS idx_variacion_activo_tipo_periodo
    ON modulo6.variaciones_valor_razonable
    (id_activo_biologico, tipo, id_periodo_contable);

-- [RF-COT / RF-86] Variaciones pendientes de trazabilidad
CREATE INDEX IF NOT EXISTS idx_variacion_trazabilidad_pendiente
    ON modulo6.variaciones_valor_razonable (estado_trazabilidad)
    WHERE estado_trazabilidad = 'VERIFICACION_PENDIENTE';

-- [RF-90] Costos por activo, naturaleza y período (consolidación NIC 41)
CREATE INDEX IF NOT EXISTS idx_costo_activo_naturaleza_periodo
    ON modulo6.registros_costos
    (id_activo_biologico, naturaleza_costo, id_periodo_contable);

-- [RF-90] Costos exportables a M07
CREATE INDEX IF NOT EXISTS idx_costo_exportable
    ON modulo6.registros_costos (exportable_aaef, id_periodo_contable)
    WHERE exportable_aaef = true;

-- [RF-94] Auditorías por activo y fecha (trazabilidad financiera)
CREATE INDEX IF NOT EXISTS idx_auditoria_financiera_activo_fecha
    ON modulo6.auditorias_financieras
    (id_activo_biologico, fecha_registro DESC);

-- [RF-94] Auditorías WARNING/ERROR (monitoreo de alertas contables)
CREATE INDEX IF NOT EXISTS idx_auditoria_financiera_severidad
    ON modulo6.auditorias_financieras (severidad, fecha_registro DESC)
    WHERE severidad IN ('WARNING', 'ERROR');

-- [RF-88] Valoraciones por costo activas
CREATE INDEX IF NOT EXISTS idx_valoracion_costo_activa
    ON modulo6.valoraciones_por_costos (id_activo_biologico)
    WHERE es_activa = true;

-- [RF-COT] Cotizaciones por estado y período
CREATE INDEX IF NOT EXISTS idx_cotizacion_estado_periodo
    ON modulo6.cotizaciones
    (estado, id_periodo_contable, fecha_emision DESC);
