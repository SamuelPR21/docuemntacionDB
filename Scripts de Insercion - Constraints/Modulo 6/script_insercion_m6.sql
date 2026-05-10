-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 6
-- ==============================================================
--
-- TABLAS DEL MÓDULO 6 (verificadas contra backup5_0_0.sql y backup6_0_0.sql):
--   1.  periodos_contables
--   2.  parametros_costos_venta
--   3.  precios_mercado
--   4.  calculos_valor_razonable
--   5.  reconocimientos_iniciales
--   6.  revisiones_reconocimiento
--   7.  mediciones_posteriores
--   8.  reconocimientos_productos_agricolas
--   9.  variaciones_valor_razonable
--  10.  valoraciones_por_costos
--  11.  deterorios_activos
--  12.  registros_costos
--  13.  cotizaciones
--  14.  auditorias_financieras
--
-- TYPOS EN EL DDL (usar nombres exactos del DDL):
--   reconocimientos_iniciales.id_actvo_biologico    (falta 'i')
--   reconocimientos_iniciales."fecha_reconocimiento " (espacio al final)
--   parametros_costos_venta."id_parametro_costo_venta " (espacio al final)
--   auditorias_financieras."id_periodo_contable "   (espacio al final)
--   precios_mercado.cagetoria                        (debería ser 'categoria')
--   precios_mercado.id_precio_coregido               (typo: 'coregido')
--   deterorios_activos (nombre de tabla con typo)
--   deterorios_activos.id_valoracio_costo            (typo: 'valoracio')
--   mediciones_posteriores."id_ medicion_posterior"  (espacio en medio)
--   cotizaciones."valor_cotizacion_propuesto "       (espacio al final)
--   reconocimientos_productos_agricolas.id_reconocimiento_prodcutos_agricola (typo)
--
-- ESTADO DE CONSTRAINTS EN EL BACKUP:
--   CHECKs INLINE ya activos (NO se re-ejecutan):
--     chk_manual_requiere_justificacion, chk_anulacion_requiere_motivo,
--     chk_estimada_requiere_justificacion, chk_precio_vencimiento,
--     chk_vigencia_no_retroactiva, chk_periodo_fechas,
--     chk_variacion_total_coherente, chk_monto_coherente,
--     chk_accounting_account_no_vacio, chk_exportable_type_code
--
--   FKs ACTIVAS (SIN NOT VALID — directas, ya verificadas):
--     Internas M6: fk_calculos_valor_razonable_parametro_costo_venta,
--       fk_calculos_valor_razonable_periodo_contable,
--       fk_calculos_valor_razonable_precio_mercado_id,
--       fk_cotizaciones_periodo_contable_id,
--       fk_deterorios_activos_valoracio_costo_id,
--       fk_mediciones_posteriores_calculo_actual_id,
--       fk_mediciones_posteriores_calculo_anterioir_id,
--       fk_mediciones_posteriores_periodo_contable_id,
--       fk_precios_mercado_precio_corregido_id,
--       fk_recon_prod_agricolas_calculo_vr_id,
--       fk_reconocimientos_iniciales_periodo_contable_id,
--       fk_reconocimientos_iniciales_precio_mercado_id,
--       fk_reconocimientos_productos_agricolas_periodo_contable_id,
--       fk_registros_costos_periodo_contable_id,
--       fk_revisiones_reconocimiento_id,
--       fk_variacion_valor_razonable_variacion_corregido_id,
--       fk_auditorias_financieras_periodo_contable_id
--     Hacia M1: fk_calculos_valor_razonable_usuario_id,
--       fk_cotizaciones_usuario_id, fk_deterorios_activos_valoracio_usuario_id,
--       fk_parametros_costos_usuario_id, fk_periodos_conable_usuario_id,
--       fk_precios_mercado_usuario_id, fk_reconocimientos_iniciales_usuario_id,
--       fk_reconocimientos_productos_agricolas_usuario_id,
--       fk_registros_costos_usuario_id
--     Hacia M2: fk_calculos_valor_razonable_activo_biologico_id,
--       fk_mediciones_posteriores_activo_biologico_id,
--       fk_mediciones_posteriores_evento_id,
--       fk_reconocimientos_iniciales_activo_biologico_id,
--       fk_reconocimientos_productos_agricolas_activos_biologicos,
--       fk_reconocimientos_productos_agricolas_id,
--       fk_registros_costos_activo_biologico_id,
--       fk_deterorios_activos_valoracio_evento_sanitario_id
--     Hacia M9: fk_precios_mercado_especie_id,
--       fk_parametros_costos_venta_especie_id
--
--   UQs ELIMINADAS EN MIGRACIÓN (re-creadas en constraints):
--     unique_valoraciones_por_costos_activo_biologico
--     "uq_param_especie_region ", "uq_periodo_rango "
--     uq_precio_especie_cat_fuente_vigencia
--     uq_reconocimeinto_revertido
--     uq_reconocimientos_iniciales_id_activo_biologico
--     uq_reconocimientos_productos_agricolas_evento_productivo
--
-- ENUMs DEL MÓDULO 6:
--   [E1]  enum_auditoria_financiera_metodo_valoracion:
--         'VALOR_RAZONABLE','VALORACION_POR_COSTO'
--
--   [E2]  enum_auditorias_financieras_severidad:
--         'INFO','WARNING','ERROR'
--
--   [E3]  enum_auditorias_financieras_tipo_evento_auditoria:
--         'RECONOCIMIENTO_INICIAL','RECONOCIMIENTO_REVERTIDO',
--         'MEDICION_POSTERIOR','VARIACION_REGISTRADA','COSTO_REGISTRADO',
--         'ACTIVO_MARCADO_SIN_MERCADO','COTIZACION_REGISTRADA', ...
--
--   [E4]  enum_calculos_valor_razonable_estado:
--         'CALCULADO','REVISION_REQUERIDA'
--
--   [E5]  enum_calculos_valor_razonable_metodo_costo:
--         'PARAMETRIZADO','MANUAL','MIXTO'
--
--   [E6]  enum_cotizaciones_estado_cotizacion:
--         'COTIZADO','VENCIDA','ANULADA','CONVERTIDA_EN_VENTA'
--
--   [E7]  enum_mediciones_posteriores_estado:
--         'COMPLETADO','MEDICION_PENDIENTE','ERROR'
--
--   [E8]  enum_mediciones_posteriores_origen_medicion:
--         'EVENTO','CIERRE_PERIODO'
--
--   [E9]  enum_periodo_contables_estado:
--         'ABIERTO','EN_CIERRE ','CERRADO'
--         NOTA: 'EN_CIERRE ' tiene espacio al final en el DDL
--
--   [E10] enum_periodos_contables_tipo_cierre:
--         'MENSUAL','TRIMESTRAL','ANUAL'
--
--   [E11] enum_precio_mercado_categoria (ARRAY):
--         'PESO_KG','POR_CABEZA'
--
--   [E12] enum_precio_mercado_estado:
--         'ACTIVO','PROGRAMADO','VENCIDO','SUPERADO'
--
--   [E13] enum_precio_mercado_fuente:
--         'MERCADO_ACTIVO','UPRA','ESTIMADA'
--
--   [E14] enum_precios_mercado_origen_precio:
--         'MANUAL','API_M07'
--   [E15] enum_reconocimientos_iniciales_clasificacion:
--         'PRODUCCION','CONSUMO'
--
--   [E16] enum_reconocimientos_iniciales_estado_reconocimiento:
--         'PENDIENTE_CONFIRMACION','CONFIRMADO','REVERTIDO'
--
--   [E17] enum_reconocimientos_iniciales_indicador_valoracion:
--         'VALOR_RAZONABLE','VALORACION_POR_COSTO'
--
--   [E18] enum_reconocimientos_productos_agricolas_tipo_producto:
--         'PRODUCTO_DE_CONSUMO','PRODUCTO_PERIODICO'
--
--   [E19] enum_registros_costos_estado_costo:
--         'REGISTRADO','PENDIENTE_CLASIFICACION'
--
--   [E20] enum_registros_costos_naturaleza_costo:
--         'MANTENIMIENTO','INVERSION','VENTA'
--
--   [E21] enum_registros_costos_politica_capitalizacion:
--         'CAPITALIZAR','GASTO'
--
--   [E22] enum_registros_costos_subtipo_costo:
--         'ALIMENTO','MEDICAMENTO','MANO_OBRA','VETERINARIO',
--         'TRANSPORTE','COMISION','IMPUESTO_TRANSACCION',
--         'SACRIFICIO','INVERSION_DIRECTA','OTRO'
--
--   [E23] enum_valoraciones_por_costos_escenario:
--         'INICIAL_RF82','AUTONOMO_CONTADOR'
--
--   [E24] enum_variaciones_valor_razonable_estado_trazabilidad:
--         'VERIFICACION_PENDIENTE','VERIFICADO','PENDIENTE_TRAZABILIDAD'
--
--   [E25] enum_variaciones_valor_razonable_tipo:
--         'GANANCIA_TRANSFORMACION_BIOLOGICA',
--         'PERDIDA_TRANSFORMACION_BIOLOGICA',
--         'GANANCIA_PRECIO_MERCADO','PERDIDA_PRECIO_MERCADO'
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
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo1.usuarios debe '
            'contener usuarios con id=1 e id=2. Ejecute primero M1.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico IN (1, 2, 3) HAVING COUNT(*) = 3
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo2.activos_biologicos '
            'debe contener al menos 3 registros. Ejecute primero M2.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.especies
        WHERE id_especie IN (1, 2, 3) HAVING COUNT(*) = 3
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo9.especies debe '
            'contener al menos 3 registros. Ejecute primero M9.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK internas):
--   1.  periodos_contables            ← tabla raíz del módulo
--   2.  parametros_costos_venta       ← depende de M9.especies
--   3.  precios_mercado               ← depende de M9.especies
--   4.  calculos_valor_razonable      ← depende de 1, 2, 3
--   5.  reconocimientos_iniciales     ← depende de 1, 3
--   6.  revisiones_reconocimiento     ← depende de 5
--   7.  mediciones_posteriores        ← depende de 4
--   8.  reconocimientos_productos_agricolas ← depende de 4
--   9.  variaciones_valor_razonable   ← depende de 1
--  10.  valoraciones_por_costos       ← depende de M2
--  11.  deterorios_activos            ← depende de 10
--  12.  registros_costos              ← depende de 1
--  13.  cotizaciones                  ← depende de 1
--  14.  auditorias_financieras        ← append-only, depende de 1
-- ==============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. PERÍODOS CONTABLES
--
-- RF-87: solo puede haber un período ABIERTO simultáneamente.
-- Un período CERRADO es inmutable. Solo el Contador puede cerrar.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.periodos_contables
    (tipo_cierre, fecha_inicio, fecha_fin, estado,
     fecha_cierre, id_usuario, fecha_creacion)
VALUES
-- Q1-2024: período cerrado (histórico)
('TRIMESTRAL', '2024-01-01', '2024-03-31', 'CERRADO',
 '2024-04-05 17:00:00+00', 1, NOW() - INTERVAL '400 days'),

-- Q2-2024: período cerrado
('TRIMESTRAL', '2024-04-01', '2024-06-30', 'CERRADO',
 '2024-07-08 16:30:00+00', 1, NOW() - INTERVAL '300 days'),

-- Q3-2024: período cerrado (base para medición posterior)
('TRIMESTRAL', '2024-07-01', '2024-09-30', 'CERRADO',
 '2024-10-10 15:00:00+00', 1, NOW() - INTERVAL '200 days'),

-- Q4-2024: período ABIERTO — único período activo
('TRIMESTRAL', '2024-10-01', '2024-12-31', 'ABIERTO',
 NULL, 1, NOW() - INTERVAL '100 days');


-- ─────────────────────────────────────────────────────────────
-- 2. PARÁMETROS DE COSTOS DE VENTA
--
-- Porcentajes en [0,1]: son proporciones, no porcentajes enteros.
-- UQ eliminada: uq_param_especie_region (se re-crea en constraints).
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.parametros_costos_venta
    (id_especie, region,
     pct_transporte, pct_comisiones, pct_impuestos,
     es_activo, id_usuario, fecha_creacion)
VALUES
-- Bovinos — Huila/Tolima
(1, 'Huila - Tolima',
 0.0200, 0.0300, 0.0100,
 true, 1, NOW() - INTERVAL '180 days'),

-- Bovinos — Antioquia/Eje Cafetero (mercado diferenciado)
(1, 'Antioquia - Eje Cafetero',
 0.0250, 0.0350, 0.0100,
 true, 1, NOW() - INTERVAL '180 days'),

-- Aves — Huila/Tolima
(2, 'Huila - Tolima',
 0.0150, 0.0200, 0.0050,
 true, 1, NOW() - INTERVAL '180 days'),

-- Peces/Acuicultura — Huila/Tolima
(3, 'Huila - Tolima',
 0.0350, 0.0250, 0.0100,
 true, 1, NOW() - INTERVAL '180 days');

-- ─────────────────────────────────────────────────────────────
-- 3. PRECIOS DE MERCADO
--
-- CHECKs ya en DDL: chk_estimada_requiere_justificacion,
--   chk_precio_vencimiento, chk_vigencia_no_retroactiva
-- RF-89: append-only — no edición nunca.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.precios_mercado
    (id_especie, cagetoria, precio_unitario, unidad_medida,
     fecha_vigencia, fecha_vencimiento,
     fuente, estado, evidencia, justificacion,
     origen_registro, id_precio_coregido,
     id_usuario, fecha_registro)
VALUES
-- Bovinos adultos POR_CABEZA — MERCADO_ACTIVO (subasta Neiva)
(1, ARRAY['POR_CABEZA']::modulo6.enum_precio_mercado_categoria[],
 4500000.00, 'cabeza',
 '2024-10-01', '2024-12-31',
 'MERCADO_ACTIVO', 'ACTIVO',
 'Subasta ganadera Neiva oct-2024. Precio promedio ponderado '
 '10 subastas semana 40-2024. Fuente: SUBASTA_HLA_20241001_001.',
 NULL, 'MANUAL', NULL, 1, NOW() - INTERVAL '90 days'),

-- Bovinos PESO_KG — UPRA
(1, ARRAY['PESO_KG']::modulo6.enum_precio_mercado_categoria[],
 9800.00, 'kg_en_pie',
 '2024-10-01', '2024-12-31',
 'UPRA', 'ACTIVO',
 'Precio UPRA octubre 2024. Boletín semanal UPRA No.42-2024. '
 'Categoría: bovinos machos en pie departamento Huila.',
 NULL, 'MANUAL', NULL, 1, NOW() - INTERVAL '90 days'),

-- Pollos engorde PESO_KG — MERCADO_ACTIVO
(2, ARRAY['PESO_KG']::modulo6.enum_precio_mercado_categoria[],
 5200.00, 'kg',
 '2024-10-01', '2024-12-31',
 'MERCADO_ACTIVO', 'ACTIVO',
 'Central mayorista Neiva semana 40-2024. Precio pollo en pie. '
 'Fuente: ASOHUILA_PM_20241001.',
 NULL, 'MANUAL', NULL, 1, NOW() - INTERVAL '90 days'),

-- Tilapia roja PESO_KG — MERCADO_ACTIVO
(3, ARRAY['PESO_KG']::modulo6.enum_precio_mercado_categoria[],
 8500.00, 'kg',
 '2024-10-01', '2024-12-31',
 'MERCADO_ACTIVO', 'ACTIVO',
 'Precio tilapia roja CORABASTOS semana 40-2024. '
 'Categoría: tilapia roja fresca entera > 250 g. '
 'Fuente: SIPR_CORABASTOS_20241001.',
 NULL, 'MANUAL', NULL, 1, NOW() - INTERVAL '90 days'),

-- Bovinos PESO_KG Q3-2024 — ESTIMADA (período cerrado, histórico)
-- Justificación obligatoria por fuente = 'ESTIMADA'
(1, ARRAY['PESO_KG']::modulo6.enum_precio_mercado_categoria[],
 9500.00, 'kg_en_pie',
 '2024-07-01', '2024-09-30',
 'ESTIMADA', 'VENCIDO',
 'Precio estimado julio 2024 base en tendencia UPRA Q2-2024. '
 'Aprobado por Contador. Memo CONT-2024-012.',
 'Precio UPRA no disponible al momento del cálculo. '
 'Estimación con promedio móvil 3 meses Q2-2024. '
 'Desviación máxima aceptable: 5% respecto a valor real.',
 'MANUAL', NULL, 1, NOW() - INTERVAL '180 days');


-- ─────────────────────────────────────────────────────────────
-- 4. CÁLCULOS DE VALOR RAZONABLE
--
-- valor_neto = bruto − transporte − comisiones
--              − impuestos_transaccion − otros_costos
-- CHECK chk_manual_requiere_justificacion ya en DDL.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.calculos_valor_razonable
    (id_activo_biologico, id_precio_mercado, id_parametro_costo_venta,
     valor_razonable_bruto,
     costo_transporte, costo_comisiones, costo_impuestos_transaccion,
     otros_costos_disposicion, valor_neto,
     metodo_costo, justificacion, estado,
     id_usuario, fecha_calculo, id_periodo_contable)
VALUES
-- BOV-001 (Holstein) Q4-2024 — PARAMETRIZADO
-- 520.5 kg × $9.800/kg = $5.100.900 bruto | costos 6% | neto $4.794.846
(1, 2, 1,
 5100900.0000, 102018.0000, 153027.0000, 51009.0000, 0.0000,
 4794846.0000,
 'PARAMETRIZADO', NULL, 'CALCULADO',
 1, NOW() - INTERVAL '60 days', 4),

-- BOV-002 (Brahman novilla) Q4-2024 — PARAMETRIZADO
-- 285 kg × $9.800/kg = $2.793.000 bruto | costos 6% | neto $2.625.420
(2, 2, 1,
 2793000.0000, 55860.0000, 83790.0000, 27930.0000, 0.0000,
 2625420.0000,
 'PARAMETRIZADO', NULL, 'CALCULADO',
 1, NOW() - INTERVAL '60 days', 4),

-- BOV-001 Q3-2024 — base para medición posterior
-- 480 kg × $9.500/kg (estimado) = $4.560.000 bruto | neto $4.286.400
(1, 5, 1,
 4560000.0000, 91200.0000, 136800.0000, 45600.0000, 0.0000,
 4286400.0000,
 'PARAMETRIZADO', NULL, 'CALCULADO',
 1, NOW() - INTERVAL '150 days', 3),

-- LOTE-AV-001 (Pollos engorde) Q4-2024 — PARAMETRIZADO
-- 4870 aves × 1.85 kg × $5.200/kg = $46.849.400 | costos 4% | neto $44.975.424
(5, 3, 3,
 46849400.0000, 702741.0000, 936988.0000, 234247.0000, 0.0000,
 44975424.0000,
 'PARAMETRIZADO', NULL, 'CALCULADO',
 1, NOW() - INTERVAL '30 days', 4),

-- LOTE-PEC-001 (Tilapia) Q4-2024 — MANUAL (transporte ajustado)
-- 7650 × 0.48 kg × $8.500 = $31.212.000 | costos 7% (ajustados) | neto $29.027.160
(7, 4, 4,
 31212000.0000, 1092420.0000, 780300.0000, 312120.0000, 0.0000,
 29027160.0000,
 'MANUAL',
 'Costo transporte ajustado manualmente. Distancia estanque-mercado '
 '85 km, superior al promedio regional. Costo real: $1.092.420 (3.5%) '
 'vs parámetro base (2.5%). Aprobado Contador: Memo CONT-2024-019.',
 'CALCULADO',
 1, NOW() - INTERVAL '30 days', 4);


-- ─────────────────────────────────────────────────────────────
-- 5. RECONOCIMIENTOS INICIALES
--
-- RF-82: UQ sobre id_actvo_biologico WHERE estado != 'REVERTIDO'
-- Solo el Contador puede confirmar. CONFIRMADO = inmutable.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.reconocimientos_iniciales
    (id_actvo_biologico, "fecha_reconocimiento ",
     clasificacion, indicador_valoracion,
     id_precio_mercado, valor_razonable_neto_inicial,
     costos_venta_estimados, estado,
     cuenta_debito, cuenta_credito,
     id_usuario, id_periodo_contable, fecha_creacion)
VALUES
-- BOV-001: CONFIRMADO — PRODUCCION (vaca lechera)
(1, NOW() - INTERVAL '180 days',
 'PRODUCCION', 'VALOR_RAZONABLE',
 2, 4286400.0000, 273600.0000, 'CONFIRMADO',
 '111005', '321005', 1, 2, NOW() - INTERVAL '180 days'),

-- BOV-002: CONFIRMADO — PRODUCCION (novilla desarrollo)
(2, NOW() - INTERVAL '150 days',
 'PRODUCCION', 'VALOR_RAZONABLE',
 2, 2546400.0000, 163200.0000, 'CONFIRMADO',
 '111005', '321005', 1, 2, NOW() - INTERVAL '150 days'),

-- BOV-003: CONFIRMADO — PRODUCCION (toro reproductor)
(3, NOW() - INTERVAL '160 days',
 'PRODUCCION', 'VALOR_RAZONABLE',
 2, 4559400.0000, 291600.0000, 'CONFIRMADO',
 '111005', '321005', 1, 2, NOW() - INTERVAL '160 days'),

-- LOTE-AV-001: CONFIRMADO — CONSUMO (pollos para venta/sacrificio)
(5, NOW() - INTERVAL '45 days',
 'CONSUMO', 'VALOR_RAZONABLE',
 3, 44975424.0000, 1873974.0000, 'CONFIRMADO',
 '111005', '321005', 1, 4, NOW() - INTERVAL '45 days'),

-- LOTE-PEC-001: PENDIENTE_CONFIRMACION — pendiente revisión Contador
(7, NOW() - INTERVAL '30 days',
 'PRODUCCION', 'VALOR_RAZONABLE',
 4, 29027160.0000, 2184870.0000, 'PENDIENTE_CONFIRMACION',
 '111005', '321005', 1, 4, NOW() - INTERVAL '30 days'),

-- BOV-004 (Normando gestante): REVERTIDO
-- Reconocido inicialmente con precio POR_CABEZA ($4.500.000/cabeza) en
-- lugar de PESO_KG, lo que sobrevaluó el activo gestante.
-- El Contador detectó el error en revisión del Q2-2024 y ejecutó la
-- reversión formal. Este registro persiste como trazabilidad histórica
-- y habilita el registro en revisiones_reconocimiento (sección 6).
(4, NOW() - INTERVAL '200 days',
 'PRODUCCION', 'VALOR_RAZONABLE',
 1, 4500000.0000, 270000.0000, 'REVERTIDO',
 '111005', '321005', 1, 2, NOW() - INTERVAL '200 days');

-- ─────────────────────────────────────────────────────────────
-- 6. REVISIONES DE RECONOCIMIENTO
--
-- RF-82: operación excepcional auditada. El reconocimiento
-- original pasa a estado REVERTIDO pero nunca se elimina.
-- La UQ uix_revision_por_reconocimiento garantiza una sola
-- reversión por reconocimiento (re-creada en constraints).
-- monto_revision: monto del asiento de reversión (positivo).
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.revisiones_reconocimiento
    (id_reconocimiento_revertido, motivo_revision,
     monto_revision, cuenta_debito, cuenta_credito,
     id_usuario, fecha_revision)
VALUES
-- Reversión reconocimiento BOV-004 (id=6 en reconocimientos_iniciales)
-- Error: precio POR_CABEZA ($4.500.000) usado en vez de PESO_KG ($9.800/kg).
-- Valor correcto por PESO_KG: 435 kg × $9.800 × 0.94 = $4.004.460 neto.
-- Sobrevaluación: $4.500.000 − $4.004.460 = $495.540.
-- El asiento de reversión cancela el reconocimiento erróneo por su
-- valor original completo; se emitirá nuevo reconocimiento en Q3-2024.
(6,
 'Reconocimiento inicial erróneo en BOV-004 (Normando gestante). '
 'Se utilizó precio de referencia POR_CABEZA ($4.500.000) en lugar '
 'de PESO_KG ($9.800/kg). Error detectado en revisión Q2-2024. '
 'Precio correcto por PESO_KG sobre 435 kg: valor neto $4.004.460. '
 'Sobrevaluación estimada: $495.540. '
 'Autorización Contador: Memo CONT-2024-008 del 05/07/2024. '
 'Se emitirá nuevo reconocimiento en período Q3-2024.',
 4500000.0000,
 '321005', '111005',
 1, NOW() - INTERVAL '170 days');

-- ─────────────────────────────────────────────────────────────
-- 7. MEDICIONES POSTERIORES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.mediciones_posteriores
    ("id_ medicion_posterior",
     id_activo_biologico, id_evento,
     id_calculo_actual, id_calculo_anterior,
     origen_medicion,
     valor_razonable_anterior, valor_razonable_actual,
     ganancia_perdida_transformacion, ganancia_perdida_precio_mercado,
     variacion_total, tiene_valor_estimado,
     estado, id_periodo_contable, fecha_medicion)
VALUES
-- BOV-001: medición Q4-2024 vs Q3-2024
-- VR anterior Q3: $4.286.400 → VR actual Q4: $4.794.846
-- Transformación biológica: +$480.000 (crecimiento 40.5 kg)
-- Variación precio: +$28.446 ($9.500 → $9.800/kg)
-- Variación total: +$508.446
(1, 1, NULL, 1, 3,
 'CIERRE_PERIODO',
 4286400.0000, 4794846.0000,
 480000.0000, 28446.0000,
 508446.0000, false,
 'COMPLETADO', 4, NOW() - INTERVAL '45 days');


-- ─────────────────────────────────────────────────────────────
-- 8. RECONOCIMIENTOS DE PRODUCTOS AGRÍCOLAS
--
-- valor_producto = (precio_mercado_producto − costo_venta_producto) × cantidad
-- PRODUCTO_PERIODICO: no reduce VR del activo biológico.
-- UQ sobre id_evento_productivo (un reconocimiento por evento).
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.reconocimientos_productos_agricolas
    (id_reconocimiento_prodcutos_agricola,
     id_evento_productivo, id_activo_biologico,
     producto_agricola, cantidad_cosechada, unidad_medida,
     precio_mercado_producto, costo_venta_producto, valor_producto,
     proporcion_cosechada, valor_reduccion_activo,
     id_calculo_valor_razonable,
     cuenta_debito, cuenta_credito,
     id_periodo_contable, id_parametro_m09,
     justificacion, fecha_cosecha,
     fecha_registro, id_usuario, tipo)
VALUES
-- Leche BOV-001: producción periódica Q4-2024
-- 24.5 L × ($1.800 - $900)/L = $22.050
-- PRODUCTO_PERIODICO: no reduce VR activo
(1, 9, 1,
 'Leche bovina fresca entera', 24.5000, 'litros',
 1800.0000, 900.0000, 22050.0000,
 NULL, NULL, 1,
 '130505', '431005',
 4, NULL,
 'Reconocimiento diario leche BOV-001 (Holstein). '
 'Precio referencia: mercado Neiva oct-2024. '
 'PRODUCTO_PERIODICO: no reduce VR del activo biológico.',
 CURRENT_DATE - INTERVAL '60 days',
 NOW() - INTERVAL '60 days', 1, 'PRODUCTO_PERIODICO'),

-- Huevos LOTE-AV-002: producción periódica Q4-2024
-- 280 huevos × ($420 - $84)/huevo = $94.080
(2, 10, 6,
 'Huevos gallina ponedora AA', 280.0000, 'unidades',
 420.0000, 84.0000, 94080.0000,
 NULL, NULL, 3,
 '130505', '431005',
 4, NULL,
 'Reconocimiento diario huevos LOTE-AV-002 (Lohmann ponedoras). '
 'Precio mayorista Neiva oct-2024. '
 'PRODUCTO_PERIODICO: no reduce VR del activo biológico.',
 CURRENT_DATE - INTERVAL '60 days',
 NOW() - INTERVAL '60 days', 1, 'PRODUCTO_PERIODICO');

-- ─────────────────────────────────────────────────────────────
-- 9. VARIACIONES DE VALOR RAZONABLE
--
-- CHECK chk_monto_coherente: ABS(monto_variacion
--   - (variacion_transformacion + variacion_precio_mercado)) < 0.01 (ya en DDL)
-- Registros inmutables — correcciones = nueva entrada con id_variacion_corregida.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.variaciones_valor_razonable
    (id_variacion_valor_razonable,
     id_activo_biologico, tipo,
     monto_variacion, variacion_transformacion, variacion_precio_mercado,
     valor_razonable_anterior, valor_razonable_nuevo,
     id_evento, id_medicion_posterior,
     id_periodo_contable, estado_trazabilidad,
     tiene_estimacion, id_usuario, fecha_registro,
     id_variacion_corregida)
VALUES
-- BOV-001: ganancia por transformación biológica Q4-2024
-- +$480.000 por crecimiento físico (40.5 kg × $9.800/kg ≈ $396.900 transformación)
(1, 1, 'GANANCIA_TRANSFORMACION_BIOLOGICA',
 480000.00, 480000.00, 0.00,
 4286400.00, 4766400.00,
 1, 1, 4, 'VERIFICACION_PENDIENTE',
 false, 1, NOW() - INTERVAL '45 days', NULL),

-- BOV-001: ganancia por variación de precio de mercado Q4-2024
-- +$28.446 ($9.500 → $9.800/kg sobre 520.5 kg)
(2, 1, 'GANANCIA_PRECIO_MERCADO',
 28446.00, 0.00, 28446.00,
 4766400.00, 4794846.00,
 1, 1, 4, 'VERIFICACION_PENDIENTE',
 false, 1, NOW() - INTERVAL '45 days', NULL),

-- BOV-002: ganancia por transformación biológica Q4-2024
-- +$245.000 (crecimiento 25 kg × $9.800/kg)
(3, 2, 'GANANCIA_TRANSFORMACION_BIOLOGICA',
 245000.00, 245000.00, 0.00,
 2546400.00, 2791400.00,
 2, NULL, 4, 'VERIFICACION_PENDIENTE',
 false, 1, NOW() - INTERVAL '45 days', NULL);


-- ─────────────────────────────────────────────────────────────
-- 10. VALORACIONES POR COSTOS
--
-- Método alternativo NIC 41 Párr. 30 para activos sin mercado activo.
-- valor_contable = costo_adquisicion − deprec_acumulada − deterioro_acumulado
-- Si la suma supera el costo, valor_contable = 0 (no negativo).
-- UQ: una sola valoración activa por activo (es_activa = true).
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.valoraciones_por_costos
    (id_activo_biologico, escenario_activacion,
     costos_adquisicion, tasa_depreciacion,
     fecha_adquisicion, depreciacion_acumulada,
     deterioro_acumulado, valor_contable_por_costo,
     razon_sin_mercado, id_usuario,
     fecha_marcacion, es_activa)
VALUES
-- BOV-005 (novillo Brahman en cuarentena) — sin precio de mercado activo
-- Costo adquisición: $2.800.000 | Tasa deprec: 10%/año → 6 meses: $140.000
-- Deterioro: $0 inicial (evaluación en progreso) → valor contable: $2.660.000
(5, 'AUTONOMO_CONTADOR',
 2800000.0000, 0.1000,
 '2024-04-15', 140000.0000,
 0.0000, 2660000.0000,
 'Activo en estado AISLADO por cuarentena sanitaria post-compra. '
 'No existe precio de mercado activo para novillo Brahman en cuarentena '
 'en la región Huila. RF-89 no tiene precio vigente para esta categoría. '
 'Contador autoriza valoración alternativa Párr. 30 NIC 41. '
 'Memo CONT-2024-015 del 15/10/2024.',
 1, NOW() - INTERVAL '80 days', true);

-- ─────────────────────────────────────────────────────────────
-- 11. DETERIOROS DE ACTIVOS
--
-- Cuantificación monetaria de eventos sanitarios sobre activos
-- valorados por costo (Párr. 30 NIC 41).
-- Solo el Contador puede cuantificar el deterioro.
-- DDL: id_valoracio_costo (typo: 'valoracio')
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.deterorios_activos
    (id_valoracio_costo, id_evento_sanitario,
     impacto_economico_cop, justificacion,
     id_usuario, fecha_registro)
VALUES
-- BOV-005: deterioro por cuarentena sanitaria (evento id=3)
-- 2% del costo adquisición ($2.800.000) = $56.000
(1, 3,
 56000.0000,
 'Deterioro evaluado por condición sanitaria de aislamiento. '
 'Novillo BOV-005 en cuarentena post-compra por 30 días. '
 'Impacto: reducción temporal de valor por riesgo sanitario. '
 'Cuantificación: 2% del costo adquisición ($2.800.000). '
 'Metodología: Sección 34 NIIF PYME. '
 'Aprobado: Memo CONT-2024-016 del 30/10/2024.',
 1, NOW() - INTERVAL '50 days');

-- ─────────────────────────────────────────────────────────────
-- 12. REGISTROS DE COSTOS
--
-- RF-90 restricción absoluta: MANTENIMIENTO nunca capitalizable.
-- accounting_account: cuentas PUC del plan contable colombiano.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.registros_costos
    (naturaleza_costo, subtipo_costo, id_activo_biologico,
     monto_costo, accounting_account, line_type,
     type_code, exportable_aaef,
     politica_capitalizacion, estado,
     justificacion, id_periodo_contable, id_usuario,
     fecha_registro)
VALUES
-- BOV-001: alimento mensual — MANTENIMIENTO (nunca capitalizable)
('MANTENIMIENTO', 'ALIMENTO', 1,
 47025.0000, ARRAY['519025']::varchar[],
 'Gastos de alimentacion ganado bovino - Concentrado lechero',
 NULL, false, NULL, 'REGISTRADO',
 NULL, 4, 1, NOW() - INTERVAL '30 days'),

-- BOV-001: medicamento mensual — MANTENIMIENTO
('MANTENIMIENTO', 'MEDICAMENTO', 1,
 35240.0000, ARRAY['519030']::varchar[],
 'Gastos veterinarios y medicamentos - Ivermectina + ADE',
 NULL, false, NULL, 'REGISTRADO',
 NULL, 4, 1, NOW() - INTERVAL '30 days'),

-- BOV-003: mano de obra — MANTENIMIENTO
('MANTENIMIENTO', 'MANO_OBRA', 3,
 90000.0000, ARRAY['519010']::varchar[],
 'Mano de obra directa manejo reproductores',
 NULL, false, NULL, 'REGISTRADO',
 NULL, 4, 1, NOW() - INTERVAL '30 days'),

-- BOV-005: veterinario cuarentena — MANTENIMIENTO
('MANTENIMIENTO', 'VETERINARIO', 5,
 95000.0000, ARRAY['519030']::varchar[],
 'Gastos veterinarios cuarentena post-compra BOV-005',
 NULL, false, NULL, 'REGISTRADO',
 'Costo de supervisión veterinaria durante aislamiento. '
 'No capitalizable: es mantenimiento de condición sanitaria.',
 4, 2, NOW() - INTERVAL '50 days'),

-- LOTE-AV-001: alimento pollos — MANTENIMIENTO exportable a M07
-- type_code = '{2}' requerido por chk_exportable_type_code
('MANTENIMIENTO', 'ALIMENTO', 5,
 944000.0000, ARRAY['519025', '280205']::varchar[],
 'Gastos alimentacion aves engorde - Concentrado finalizacion',
 ARRAY['2']::char[], true, NULL, 'REGISTRADO',
 NULL, 4, 1, NOW() - INTERVAL '20 days'),

-- LOTE-PEC-001: medicamento acuicultura — MANTENIMIENTO exportable
('MANTENIMIENTO', 'MEDICAMENTO', 7,
 9363600.0000, ARRAY['519030', '280205']::varchar[],
 'Tratamiento preventivo sal marina acuicola - Estanque E1',
 ARRAY['2']::char[], true, NULL, 'REGISTRADO',
 'Tratamiento preventivo mensual protocolo acuícola. '
 'Volumen: 11.016 kg sal marina para estanque 3.672 m³.',
 4, 1, NOW() - INTERVAL '20 days');

-- ─────────────────────────────────────────────────────────────
-- 13. COTIZACIONES
--
-- RF-COT: no modifica VR ni estado del activo.
-- Las cuentas de orden no afectan el balance (venta no perfeccionada).
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.cotizaciones
    (fecha_emision, id_periodo_contable,
     activos_cotizados,
     valor_razonable_referencia, "valor_cotizacion_propuesto ",
     condiciones, estado, fecha_vencimiento,
     accounting_account, line_type,
     type_code, motivo_anulacion,
     id_usuario, fecha_registro)
VALUES
-- BOV-001 — cotización vigente (COTIZADO)
(CURRENT_DATE - INTERVAL '20 days', 4,
 ARRAY[1]::integer[],
 4794846.0000, 4600000.0000,
 'Cotización venta directa. Precio incluye carta de salud, '
 'brucelosis y tuberculosis negativos. Vigencia: 30 días. '
 'Pago: 50% anticipo, 50% entrega.',
 'COTIZADO', CURRENT_DATE + INTERVAL '10 days',
 ARRAY['811005', '911005']::varchar[],
 'COTIZACION_VENTA_ACTIVO_BIOLOGICO',
 '4', NULL, 1, NOW() - INTERVAL '20 days'),

-- BOV-002 + BOV-003 — cotización lote (VENCIDA)
(CURRENT_DATE - INTERVAL '60 days', 4,
 ARRAY[2, 3]::integer[],
 7171266.0000, 7000000.0000,
 'Cotización lote novilla + toro. Descuento 2.4% sobre VR total.',
 'VENCIDA', CURRENT_DATE - INTERVAL '30 days',
 ARRAY['811005', '911005']::varchar[],
 'COTIZACION_VENTA_ACTIVO_BIOLOGICO',
 '4', NULL, 1, NOW() - INTERVAL '60 days');


-- ─────────────────────────────────────────────────────────────
-- 14. AUDITORÍAS FINANCIERAS
--
-- RF-94: append-only, generados por el sistema, no por usuarios.
-- Retención mínima: 10 años.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo6.auditorias_financieras
    (tipo, id_activo_biologico, modulo_origen,
     "id_periodo_contable ", monto_afectado,
     metodo_valoracion_anterior, metodo_valoracion_nuevo,
     datos_nuevos, datos_anteriores, severidad,
     id_usuario, ip_origen, fecha_registro)
VALUES
-- Reconocimiento inicial BOV-001 (INFO)
('INFO', 1, 'modulo6', 2, 4286400.0000,
 NULL, 'VALOR_RAZONABLE',
 '{"evento": "RECONOCIMIENTO_INICIAL", "id_reconocimiento": 1, '
 '"valor_razonable_neto": 4286400.0, "clasificacion": "PRODUCCION", '
 '"estado": "CONFIRMADO", "cuenta_debito": "111005"}',
 NULL, 'INFO', 1, '10.0.1.30', NOW() - INTERVAL '180 days'),

-- Reconocimiento inicial BOV-002 (INFO)
('INFO', 2, 'modulo6', 2, 2546400.0000,
 NULL, 'VALOR_RAZONABLE',
 '{"evento": "RECONOCIMIENTO_INICIAL", "id_reconocimiento": 2, '
 '"valor_razonable_neto": 2546400.0, "clasificacion": "PRODUCCION", '
 '"estado": "CONFIRMADO"}',
 NULL, 'INFO', 1, '10.0.1.30', NOW() - INTERVAL '150 days'),

-- Medición posterior BOV-001 — variación +$508.446 (INFO)
('INFO', 1, 'modulo6', 4, 508446.0000,
 'VALOR_RAZONABLE', 'VALOR_RAZONABLE',
 '{"evento": "MEDICION_POSTERIOR", "id_medicion": 1, '
 '"variacion_total": 508446.0, "transformacion": 480000.0, '
 '"precio_mercado": 28446.0}',
 '{"valor_razonable_anterior": 4286400.0}',
 'INFO', 1, '10.0.1.30', NOW() - INTERVAL '45 days'),

-- Activo marcado sin mercado — BOV-005 (WARNING)
('WARNING', 5, 'modulo6', 4, 2800000.0000,
 'VALOR_RAZONABLE', 'VALORACION_POR_COSTO',
 '{"evento": "ACTIVO_MARCADO_SIN_MERCADO", "id_valoracion": 1, '
 '"razon": "Cuarentena sanitaria, sin precio mercado vigente", '
 '"metodo_nuevo": "VALORACION_POR_COSTO"}',
 '{"metodo_anterior": "VALOR_RAZONABLE"}',
 'WARNING', 1, '10.0.1.30', NOW() - INTERVAL '80 days'),

-- Deterioro registrado BOV-005 (INFO)
('INFO', 5, 'modulo6', 4, 56000.0000,
 'VALORACION_POR_COSTO', 'VALORACION_POR_COSTO',
 '{"evento": "COSTO_REGISTRADO", "tipo": "deterioro", '
 '"impacto_economico": 56000.0, "id_evento_sanitario": 3, '
 '"valor_contable_resultante": 2660000.0}',
 '{"deterioro_acumulado_anterior": 0.0}',
 'INFO', 1, '10.0.1.30', NOW() - INTERVAL '50 days'),

-- Cotización registrada BOV-001 (INFO)
('INFO', 1, 'modulo6', 4, 4600000.0000,
 NULL, NULL,
 '{"evento": "COTIZACION_REGISTRADA", "id_cotizacion": 1, '
 '"valor_cotizacion": 4600000.0, "valor_referencia": 4794846.0, '
 '"estado": "COTIZADO", "descuento_pct": 4.1}',
 NULL, 'INFO', 1, '10.0.1.30', NOW() - INTERVAL '20 days'),

-- Reconocimiento revertido BOV-004 (WARNING — cambio contable relevante)
('WARNING', 4, 'modulo6', 2, 4500000.0000,
 'VALOR_RAZONABLE', 'VALOR_RAZONABLE',
 '{"evento": "RECONOCIMIENTO_REVERTIDO", "id_revision": 1, '
 '"id_reconocimiento_revertido": 6, '
 '"motivo": "Precio POR_CABEZA incorrecto, debio usarse PESO_KG", '
 '"monto_reversion": 4500000.0, "sobrevaluacion_estimada": 495540.0}',
 '{"valor_razonable_neto_original": 4500000.0, '
 '"precio_mercado_usado": 1, "cuenta_debito": "111005"}',
 'WARNING', 1, '10.0.1.30', NOW() - INTERVAL '170 days');
