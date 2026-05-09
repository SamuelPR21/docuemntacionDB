-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 5
-- ==============================================================
--
-- TABLAS DEL MÓDULO 5 (verificadas contra backup5_0_0.sql):
--   1. tipos_alimentos
--   2. registros_consumo_alimentos
--   3. registros_medicamentos
--   4. costos_productivos
--   5. mediciones_incrementales
--   6. mediciones_inventarios
--   7. reporte_gastos_acumulados
--   8. historial_suministros_activos
--   9. auditorias_suministros
--
-- ESTADO DE CONSTRAINTS EN EL BACKUP:
--   FKs ACTIVAS (SIN NOT VALID, solo queda 1):
--     fk_registro_consumo_alimento_tipo_alimento
--       registros_consumo_alimentos(id_tipo_alimento)
--       → modulo5.tipos_alimentos(id_tipo_elemento)
--
--   FKs ELIMINADAS EN MIGRACIÓN (referencias lógicas sin FK formal):
--     fk_auditoria_suministro_sesion, fk_auditoria_suministro_usuario
--     fk_costo_productivo_activo_biologico, fk_costo_productivo_ciclo_productivo
--     fk_historial_suministros_activo_biologico
--     fk_historial_suministros_activos_ciclo_productivo
--     fk_historial_suministros_activos_usuario
--     fk_medicion_incremental_activo_biologico
--     fk_medicion_incremental_ciclo_productivo
--     fk_medicion_incremental_usuario
--     fk_medicion_inventario_activo_biologico
--     fk_medicion_inventario_ciclo_productivo
--     fk_medicion_inventario_usuario
--     fk_registro_consumo_alimento_activo_biologico
--     fk_registro_consumo_alimento_usuario
--     fk_registro_gasto_acumulado_activo_biologico
--     fk_registro_gasto_acumulado_infraestructura
--     fk_registro_gasto_acumulado_usuario
--     fk_registro_medicamento_activo_biologico
--     fk_registro_medicamento_usuario
--     fk_registro_medicamento_usuario_vet
--
--   UQs ELIMINADAS:
--     uq_tipo_alimento_nombre (se re-crea en constraints)
--
--   NOTA sobre enum_medicion_incremental_esquema:
--     Es un TYPE COMPUESTO VACÍO declarado como:
--       CREATE TYPE modulo5.enum_medicion_incremental_esquema AS ();
--     Al no tener campos, el literal correcto de inserción es '()'.
--     No aplica enum_range() ni CHECK sobre esta columna.
--
-- ENUMs DEL MÓDULO 5 (verificar antes de ejecutar):
--   [E1] enum_auditoria_suministro_resultado:
--        SELECT enum_range(NULL::modulo5.enum_auditoria_suministro_resultado);
--        Valores: 'EXITOSO','FALLIDO','RECHAZADO'
--
--   [E2] enum_auditoria_suministro_tipo_operacion:
--        SELECT enum_range(NULL::modulo5.enum_auditoria_suministro_tipo_operacion);
--        Valores: 'INSERT','UPDATE','DELETE','SELECT'
--
--   [E3] enum_costo_productivo_tipo_operacion:
--        SELECT enum_range(NULL::modulo5.enum_costo_productivo_tipo_operacion);
--        Valores: 'REGISTRO','AJUSTE','REVERSO'
--
--   [E4] enum_historial_suministros_activos_formatos_exportacion:
--        SELECT enum_range(NULL::modulo5.enum_historial_suministros_activos_formatos_exportacion);
--        Valores: 'XLS','PDF','PANTALLA'
--
--   [E5] enum_historial_suministros_activos_origen:
--        SELECT enum_range(NULL::modulo5.enum_historial_suministros_activos_origen);
--        Valores: 'ALIMENTO','MEDICAMENTO','AMBOS'
--
--   [E6] enum_medicion_inventario_estado_proceso:
--        SELECT enum_range(NULL::modulo5.enum_medicion_inventario_estado_proceso);
--        Valores: 'PENDIENTE','INCREMENTAL','COMPLETADO'
--
--   [E7] enum_medicion_inventario_tipo_costo:
--        SELECT enum_range(NULL::modulo5.enum_medicion_inventario_tipo_costo);
--        Valores: 'ALIMENTO','MEDICAMENTO','SERVICIO','VETERINARIO'
--
--   [E8] enum_registro_medicamenti_via_aplicacion:
--        SELECT enum_range(NULL::modulo5.enum_registro_medicamenti_via_aplicacion);
--        Valores: 'ORAL','IM','IV','SC'
--
--   [E9] enum_tipo_alimento_estado:
--        SELECT enum_range(NULL::modulo5.enum_tipo_alimento_estado);
--        Valores: 'ACTIVO','CESADO'
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
        SELECT 1 FROM modulo2.activos_biologicos
        WHERE id_activo_biologico IN (1, 2, 3, 4)
        HAVING COUNT(*) = 4
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo2.activos_biologicos debe '
            'contener al menos los activos BOV-001 a BOV-004 (ids 1-4). '
            'Ejecute primero M2.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.ciclos_productivos
        WHERE id_ciclo_productivo IN (1, 2)
        HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.ciclos_productivos debe '
            'contener al menos 2 registros. Ejecute primero M9.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK):
--   1. tipos_alimentos                  ← sin dependencias internas
--   2. registros_consumo_alimentos      ← depende de tipos_alimentos
--   3. registros_medicamentos           ← sin dependencias internas M5
--   4. costos_productivos               ← referencias lógicas M2/M9
--   5. mediciones_incrementales         ← referencias lógicas M2/M9
--   6. mediciones_inventarios           ← referencias lógicas M2/M9
--   7. reporte_gastos_acumulados        ← referencias lógicas M2/M9
--   8. historial_suministros_activos    ← referencias lógicas M2/M9
--   9. auditorias_suministros           ← append-only, sin FK interna
-- ==============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. TIPOS DE ALIMENTOS
--
-- Restricciones de negocio (RF-74):
--   - costo_unitario > 0 (precio validado antes de registro)
--   - Solo alimentos ACTIVO pueden ser referenciados en consumos
--   - CESADO: se conserva en catálogo pero no acepta nuevos consumos
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.tipos_alimentos
    (nombre, descripcion, costo_unitario, unidad_medida,
     estado, justificacion_estado,
     fecha_creacion, fecha_actualizacion)
VALUES
-- Alimentos concentrados para bovinos
('Concentrado Inicio Bovinos',
 'Concentrado de alta proteína (22%) para terneros hasta 3 meses. '
 'Base maíz-soya. Estimula desarrollo ruminal temprano.',
 2850.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

('Concentrado Producción Lechera',
 'Concentrado formulado para vacas en producción. Proteína 18%, '
 'energía 2.8 Mcal/kg MS. Suplementa pasto kikuyo.',
 2650.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

('Concentrado Engorde Bovinos',
 'Concentrado de alta energía (3.1 Mcal/kg) para novillos en '
 'fase de ceba. Proteína 14%, enriquecido con minerales.',
 2400.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

('Heno de Ryegrass',
 'Heno de ryegrass perenne con 10% de proteína y 55% de NDT. '
 'Suplemento forrajero en época seca.',
 650.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

('Ensilaje de Maíz',
 'Ensilaje fermentado de maíz entero a 32-35% MS. '
 'Excelente fuente de energía para ganado lechero.',
 420.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

-- Alimentos para aves
('Concentrado Iniciación Pollos',
 'Alimento balanceado para pollos de engorde (0-21 días). '
 'Proteína 23%, aminoácidos esenciales balanceados.',
 3100.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

('Concentrado Finalización Pollos',
 'Alimento para pollos de engorde (22-42 días). '
 'Proteína 20%, optimizado para conversión alimenticia.',
 2950.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

-- Alimentos para peces (acuicultura)
('Alimento Peces Alevines 2mm',
 'Pellet flotante 2mm para alevines de tilapia y cachama. '
 'Proteína 45%, lípidos 12%. Digestibilidad >92%.',
 8500.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

('Alimento Peces Engorde 6mm',
 'Pellet extruido 6mm para tilapia en fase de engorde. '
 'Proteína 32%, lípidos 8%. Tasa de alimentación: 3% BW/día.',
 6200.0000, 'kg', 'ACTIVO', NULL,
 NOW(), NOW()),

-- Suplementos minerales (cesados — sustituidos por nueva formulación)
('Sal Mineralizada Básica (descontinuado)',
 'Mezcla mineral básica con macro y microminerales. '
 'Descontinuada. Sustituida por Sal Mineralizada Premium.',
 1850.0000, 'kg', 'CESADO',
 'Formulación descontinuada por el proveedor. '
 'Sustituir por Sal Mineralizada Premium (id=11). '
 'Registros históricos conservados en auditoría.',
 NOW() - INTERVAL '90 days', NOW() - INTERVAL '90 days');

-- ─────────────────────────────────────────────────────────────
-- 2. REGISTROS DE CONSUMO DE ALIMENTOS
--
-- Restricciones RF-74:
--   - cantidad > 0
--   - fecha_consumo no futura
--   - Solo activos en estado ACTIVO pueden registrar consumos
--   - Solo tipos_alimentos con estado ACTIVO
--   - Registro VALIDADO es inmutable (gestionado en aplicación)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.registros_consumo_alimentos
    (id_activo_biologico, id_tipo_alimento, tipo_alimento,
     tipo_unidad, cantidad_suministrada, costo_total,
     observacion, fecha_inicio_periodo, fecha_fin_periodo,
     fecha_registro, id_usuario)
VALUES
-- BOV-001 (Holstein lechera) — Concentrado producción + ensilaje
(1, 2, 'Concentrado Producción Lechera',
 'kg', 4.500, 11925.0000,
 'Ración diaria ordeño mañana',
 NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days',
 NOW() - INTERVAL '7 days', 1),

(1, 5, 'Ensilaje de Maíz',
 'kg', 15.000, 6300.0000,
 'Suplemento energético diario',
 NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days',
 NOW() - INTERVAL '7 days', 1),

-- BOV-001 — consumo siguiente período
(1, 2, 'Concentrado Producción Lechera',
 'kg', 4.500, 11925.0000,
 'Ración diaria ordeño mañana',
 NOW() - INTERVAL '6 days', NOW() - INTERVAL '5 days',
 NOW() - INTERVAL '6 days', 1),

-- BOV-002 (Brahman novilla) — concentrado engorde
(2, 3, 'Concentrado Engorde Bovinos',
 'kg', 3.000, 7200.0000,
 'Alimentación suplementaria novilla desarrollo',
 NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days',
 NOW() - INTERVAL '7 days', 1),

(2, 4, 'Heno de Ryegrass',
 'kg', 5.000, 3250.0000,
 'Heno suplementario época seca',
 NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days',
 NOW() - INTERVAL '7 days', 1),

-- BOV-003 (Simmental toro) — concentrado producción
(3, 3, 'Concentrado Engorde Bovinos',
 'kg', 5.000, 12000.0000,
 'Ración reproductores activos',
 NOW() - INTERVAL '5 days', NOW() - INTERVAL '4 days',
 NOW() - INTERVAL '5 days', 1),

-- BOV-004 (Normando gestante) — concentrado preparto
(4, 2, 'Concentrado Producción Lechera',
 'kg', 3.500, 9275.0000,
 'Alimentación gestante tercer trimestre',
 NOW() - INTERVAL '4 days', NOW() - INTERVAL '3 days',
 NOW() - INTERVAL '4 days', 2),

-- LOTE-AV-001 (Pollos engorde) — concentrado finalización
(5, 7, 'Concentrado Finalización Pollos',
 'kg', 320.000, 944000.0000,
 'Alimentación lote semana 4',
 NOW() - INTERVAL '3 days', NOW() - INTERVAL '2 days',
 NOW() - INTERVAL '3 days', 1),

-- LOTE-PEC-001 (Tilapia estanque-01) — pellet engorde
(7, 9, 'Alimento Peces Engorde 6mm',
 'kg', 38.250, 237150.0000,
 'Alimentación diaria 3% biomasa',
 NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day',
 NOW() - INTERVAL '2 days', 1);


-- ─────────────────────────────────────────────────────────────
-- 3. REGISTROS DE MEDICAMENTOS
--
-- Restricciones RF-75:
--   - fecha_aplicacion no futura, no anterior a fecha_inicio activo
--   - via_administracion: obligatoria → valores ORAL/IM/IV/SC
--   - costo_total = cantidad × costo_unitario
--   - fehca_vencimietno_lote >= fecha_aplicacion (no aplicar vencido)
--   - Solo usuarios con rol Veterinario pueden registrar (app)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.registros_medicamentos
    (id_activo_biologico, nombre_medicamento, descripcion_clinica,
     unidad_dosis, cantidad, fecha_aplicacion,
     costo_unitario_medicamento, costo_total_medicamento,
     via_aplicacion, lote_medicameto, fehca_vencimietno_lote,
     fecha_registro, id_usuario, id_usuario_veterinario)
VALUES
-- BOV-003 — Ivermectina antiparasitaria (del evento sanitario M4)
(3,
 'Ivermectina 1%',
 'Tratamiento antiparasitario preventivo. Desparasitación rutinaria '
 'semiestral en toro reproductor Simmental BOV-003. '
 'Indicación: control de parásitos gastrointestinales y ectoparásitos. '
 'Dosis: 1 ml/50 kg PV. Peso animal: 520 kg (aprox).',
 'ml', 10.400,
 CURRENT_DATE - INTERVAL '20 days',
 1850.0000, 19240.0000,
 'SC', 'IVE-2024-LOT-8821', '2025-12-31',
 NOW() - INTERVAL '20 days', 1, 2),

-- BOV-003 — Vitaminas ADE post-tratamiento
(3,
 'Complejo Vitamínico ADE Injectable',
 'Suplementación vitamínica post-desparasitación. '
 'Administración de vitaminas A (5.000.000 UI), D3 (1.000.000 UI) '
 'y E (1.500 mg) para fortalecer sistema inmune. '
 'Indicación complementaria al tratamiento antiparasitario.',
 'ml', 5.000,
 CURRENT_DATE - INTERVAL '20 days',
 3200.0000, 16000.0000,
 'IM', 'ADE-2024-LOT-3341', '2025-06-30',
 NOW() - INTERVAL '20 days', 1, 2),

-- BOV-005 — Tratamiento aislamiento (oxitetraciclina del evento sanitario)
(5,
 'Oxitetraciclina 20%',
 'Tratamiento preventivo antibiótico en bovino en aislamiento sanitario. '
 'Post-compra: profilaxis para evitar introducción de enfermedades '
 'bacterianas al hato principal. Dosis: 10 ml/100 kg PV. '
 'Animal en aislamiento por protocolo de cuarentena.',
 'ml', 15.000,
 CURRENT_DATE - INTERVAL '16 days',
 4500.0000, 67500.0000,
 'IM', 'OXI-2024-LOT-5512', '2025-09-30',
 NOW() - INTERVAL '16 days', 1, 2),

-- BOV-004 — Calcio parenteral gestante (hipocalcemia preventiva)
(4,
 'Calcio Borogluconato 25%',
 'Suplementación de calcio intravenosa preventiva en vaca gestante. '
 'Normando en tercer trimestre de gestación. Prevención de hipocalcemia '
 'posparto (fiebre de leche). Protocolo: 500 ml IV lento, 1 aplicación. '
 'Monitoreo post-aplicación 30 minutos.',
 'ml', 500.000,
 CURRENT_DATE - INTERVAL '4 days',
 320.0000, 160000.0000,
 'IV', 'CAL-2024-LOT-7790', '2025-03-31',
 NOW() - INTERVAL '4 days', 2, 2),

-- LOTE-AV-002 — Vacuna Newcastle (del evento sanitario M4)
(6,
 'Vacuna ND-IB (Newcastle-Bronquitis Infecciosa)',
 'Vacunación preventiva lote ponedoras contra Newcastle y Bronquitis '
 'Infecciosa. Aplicación ocular/nasal según protocolo del fabricante. '
 'Cepa La Sota (ND) + Massachusetts (IB). Revacunación cada 60 días. '
 'Lote: 3000 aves ponedoras LOTE-AV-002.',
 'dosis', 3000.000,
 CURRENT_DATE - INTERVAL '60 days',
 180.0000, 540000.0000,
 'ORAL', 'VAC-2024-LOT-ND-1122', '2025-01-31',
 NOW() - INTERVAL '60 days', 1, 2),

-- LOTE-PEC-001 — Sal y tratamiento preventivo tilapia
(7,
 'Sal Marina para Tratamiento Acuícola',
 'Tratamiento preventivo con sal marina para control de ectoparásitos '
 'en tilapia. Concentración: 3 g/L. Duración: baño de 30 minutos. '
 'Indicación: mantenimiento preventivo mensual por protocolo acuícola. '
 'Estanque E1: 3672 m³ de agua.',
 'kg', 11016.000,
 CURRENT_DATE - INTERVAL '10 days',
 850.0000, 9363600.0000,
 'ORAL', 'SAL-2024-LOT-M-9981', '2025-12-31',
 NOW() - INTERVAL '10 days', 1, 2);


-- ─────────────────────────────────────────────────────────────
-- 4. COSTOS PRODUCTIVOS
--
-- Restricciones RF-77:
--   - costo_total = costo_medicamento + costo_mano_obra + costo_infraestructura
--   - Solo costos de ciclos ACTIVOS (no se imputan a ciclos cerrados)
--   - Precios confirmados (no estimados) o precio manual con justificación
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.costos_productivos
    (id_activo_biologico, id_ciclo_productivo,
     fecha_inicio_calculo, fecha_final_calculo,
     costo_medicamento, costo_mano_obra, costo_infraestructura,
     costo_total, justificacion_precio, tipo_operacion, id_usuario,
     fecha_calculo)
VALUES
-- BOV-001 ciclo productivo (Ciclo 1 = lechería Holstein)
(1, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE,
 35240.0000, 120000.0000, 45000.0000,
 200240.0000,
 'Costos directos Q4-2024: medicamentos (ivermectina+ADE)', 'REGISTRO', 1,
 NOW()),

-- BOV-002 (Brahman novilla)
(2, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE,
 0.0000, 80000.0000, 30000.0000,
 110000.0000,
 'Sin medicamentos en el período. Mano de obra y uso de instalaciones.',
 'REGISTRO', 1,
 NOW()),

-- BOV-003 (Simmental toro)
(3, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE,
 35240.0000, 90000.0000, 35000.0000,
 160240.0000,
 'Desparasitación + vitaminas. Costo mano de obra incluye manejo.',
 'REGISTRO', 1,
 NOW()),

-- BOV-004 (Normando gestante)
(4, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE,
 160000.0000, 95000.0000, 30000.0000,
 285000.0000,
 'Calcio IV preventivo gestante. Mayor mano de obra por supervisión.',
 'REGISTRO', 1,
 NOW()),

-- LOTE-AV-001 (Pollos engorde — ciclo 2)
(5, 2,
 CURRENT_DATE - INTERVAL '42 days', CURRENT_DATE - INTERVAL '1 day',
 0.0000, 350000.0000, 180000.0000,
 530000.0000,
 'Lote finalizado. Sin medicamentos en el período (ciclo sano). '
 'Costo infraestructura incluye galpón G1 y equipos.',
 'REGISTRO', 1,
 NOW() - INTERVAL '1 day'),

-- LOTE-PEC-001 (Tilapia estanque-01 — ciclo 1)
(7, 1,
 CURRENT_DATE - INTERVAL '60 days', CURRENT_DATE,
 9363600.0000, 480000.0000, 250000.0000,
 10093600.0000,
 'Tratamiento con sal marina (preventivo mensual acuícola). '
 'Costo elevado por volumen del estanque E1 (3672 m³).',
 'REGISTRO', 1,
 NOW());

-- ─────────────────────────────────────────────────────────────
-- 5. MEDICIONES INCREMENTALES
--
-- Restricciones RF-74:
--   - ganancia_peso > 0 (sino CA no calculable)
--   - conversion_alimenticia = consumo_alimento_acumulado / ganancia_peso
--   - Datos de peso desde eventos tipo PESAJE de RF-40 exclusivamente
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.mediciones_incrementales
    (id_activo_biologico, id_ciclo_productivo, fecha_medicion,
     peso_actual, peso_inicial_ciclo, ganancia_peso,
     consumo_alimento_acumulado, conversion_alimenticia,
     costo_acumalado, costo_acumulado_inversion,
     esquema_proceso, id_usuario, fecha_creacion)
VALUES
-- BOV-001 (Holstein): CA mensual
-- Peso inicial ciclo: 480 kg (inicio oct 2024)
-- Peso actual: 520.5 kg → ganancia: 40.5 kg en 30 días
-- Consumo alimento acumulado: 30 días × (4.5 kg conc + 15 kg ensilaje) = 583.5 kg
-- CA = 583.5 / 40.5 = 14.4074 kg alimento / kg ganancia
(1, 1,
 CURRENT_DATE - INTERVAL '1 day',
 520.500, 480.000, 40.500,
 583.5000, 14.4074,
 124650.0000, 200240.0000,
 '()', 1, NOW()),

-- BOV-002 (Brahman novilla): CA mensual
-- Peso inicial ciclo: 260 kg
-- Peso actual: 285 kg → ganancia: 25 kg
-- Consumo: 30 × (3 kg conc + 5 kg heno) = 240 kg
-- CA = 240 / 25 = 9.6000
(2, 1,
 CURRENT_DATE - INTERVAL '1 day',
 285.000, 260.000, 25.000,
 240.0000, 9.6000,
 32100.0000, 110000.0000,
 '()', 1, NOW()),

-- BOV-003 (Simmental): CA mensual
-- Peso inicial: 480 kg → Peso actual: 520.5 kg, ganancia: 40.5 kg
-- Consumo: 30 × 5 kg = 150 kg
-- CA = 150 / 40.5 = 3.7037
(3, 1,
 CURRENT_DATE - INTERVAL '1 day',
 520.500, 480.000, 40.500,
 150.0000, 3.7037,
 21600.0000, 160240.0000,
 '()', 1, NOW()),

-- LOTE-AV-001: CA semanal (pollos de engorde)
-- Peso promedio inicial: 0.045 kg (1er día de vida)
-- Peso promedio actual: 1.850 kg → ganancia: 1.805 kg
-- Consumo acumulado lote: 4870 aves × 3.2 kg = 15584 kg (42 días)
-- CA = 15584 / (4870 × 1.805) = 15584 / 8790.35 = 1.7729
(5, 2,
 CURRENT_DATE - INTERVAL '2 days',
 1.850, 0.045, 1.805,
 15584.0000, 1.7729,
 46500000.0000, 530000.0000,
 '()', 1, NOW()),

-- LOTE-PEC-001: CA mensual (Tilapia)
-- Peso inicial ciclo: 0.10 kg → Peso actual: 0.480 kg, ganancia: 0.380 kg
-- Consumo acumulado: 7650 peces × 0.38 × 30 días × 0.03 (3% BW/día) = 2622.6 kg
-- CA = 2622.6 / (7650 × 0.38) = 2622.6 / 2907 = 0.9021
(7, 1,
 CURRENT_DATE - INTERVAL '2 days',
 0.480, 0.100, 0.380,
 2622.6000, 0.9021,
 16260120.0000, 10093600.0000,
 '()', 1, NOW());


-- ─────────────────────────────────────────────────────────────
-- 6. MEDICIONES DE INVENTARIOS
--
-- Restricciones RF-77:
--   - costo_acumulado >= costo_directo
--   - estado COMPLETADO es inmutable una vez alcanzado
--   - RF-78: solo ciclos ACTIVOS o CERRADOS pueden tener mediciones
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.mediciones_inventarios
    (id_ciclo_productivo, id_activo_biologico, fecha_medicion,
     tipo_costo, costo_directo, costo_acumulado,
     estado_proceso, id_usuario, fecha_creacion)
VALUES
-- BOV-001: costos alimentación del mes (ALIMENTO)
(1, 1, CURRENT_DATE - INTERVAL '1 day',
 'ALIMENTO', 47025.0000, 564300.0000,
 'INCREMENTAL', 1, NOW()),

-- BOV-001: costos medicamentos del mes
(1, 1, CURRENT_DATE - INTERVAL '1 day',
 'MEDICAMENTO', 35240.0000, 211440.0000,
 'INCREMENTAL', 1, NOW()),

-- BOV-003: costos alimentación
(1, 3, CURRENT_DATE - INTERVAL '1 day',
 'ALIMENTO', 12000.0000, 144000.0000,
 'INCREMENTAL', 1, NOW()),

-- BOV-003: costos medicamentos (antiparasitario + vitaminas)
(1, 3, CURRENT_DATE - INTERVAL '1 day',
 'MEDICAMENTO', 35240.0000, 211440.0000,
 'INCREMENTAL', 1, NOW()),

-- BOV-004: costos medicamentos (calcio preventivo gestante)
(1, 4, CURRENT_DATE - INTERVAL '1 day',
 'MEDICAMENTO', 160000.0000, 480000.0000,
 'INCREMENTAL', 2, NOW()),

-- BOV-004: costos veterinario (servicio profesional gestante)
(1, 4, CURRENT_DATE - INTERVAL '1 day',
 'VETERINARIO', 95000.0000, 285000.0000,
 'INCREMENTAL', 2, NOW()),

-- LOTE-AV-001: costos alimentación pollos (COMPLETADO — ciclo finalizado)
(2, 5, CURRENT_DATE - INTERVAL '1 day',
 'ALIMENTO', 944000.0000, 39648000.0000,
 'COMPLETADO', 1, NOW() - INTERVAL '1 day'),

-- LOTE-PEC-001: costos medicamentos acuicultura
(1, 7, CURRENT_DATE - INTERVAL '1 day',
 'MEDICAMENTO', 9363600.0000, 18727200.0000,
 'INCREMENTAL', 1, NOW()),

-- LOTE-PEC-001: costos alimentación tilapia
(1, 7, CURRENT_DATE - INTERVAL '1 day',
 'ALIMENTO', 237150.0000, 14229000.0000,
 'INCREMENTAL', 1, NOW());


-- ─────────────────────────────────────────────────────────────
-- 7. REPORTE DE GASTOS ACUMULADOS
--
-- Restricciones RF-76:
--   - Solo registros con estado VALIDADO (gestionado en aplicación)
--   - fecha_fin_reporte <= fecha_actual (no futura)
--   - fecha_inicio >= fecha_inicio_ciclo del activo
--   - total_costo_directo = total_costo_alimento + total_costo_medicamento
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.reporte_gastos_acumulados
    (id_activo_biologico, id_infraestructura,
     fecha_incio_reporte, fecha_fin_report, categoria,
     total_costo_alimento, total_costo_medicamento,
     total_costo_directo, id_usuario, fecha_generacion)
VALUES
-- Reporte mensual BOV-001 (lechería)
(1, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 'BOVINO_LECHERO',
 47025.0000, 35240.0000, 82265.0000, 1, NOW()),

-- Reporte mensual BOV-002 (novilla desarrollo)
(2, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 'BOVINO_CARNE',
 32100.0000, 0.0000, 32100.0000, 1, NOW()),

-- Reporte mensual BOV-003 (toro reproductor)
(3, 2,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 'BOVINO_REPRODUCTOR',
 12000.0000, 35240.0000, 47240.0000, 1, NOW()),

-- Reporte mensual BOV-004 (gestante)
(4, 1,
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 'BOVINO_GESTANTE',
 9275.0000, 160000.0000, 169275.0000, 2, NOW()),

-- Reporte ciclo completo LOTE-AV-001 (pollos — ciclo 42 días)
(5, 3,
 CURRENT_DATE - INTERVAL '42 days', CURRENT_DATE - INTERVAL '1 day',
 'AVICOLA_ENGORDE',
 39648000.0000, 0.0000, 39648000.0000, 1, NOW() - INTERVAL '1 day'),

-- Reporte mensual LOTE-PEC-001 (tilapia)
(7, 4,
 CURRENT_DATE - INTERVAL '60 days', CURRENT_DATE - INTERVAL '1 day',
 'ACUICOLA_PECES',
 14229000.0000, 9363600.0000, 23592600.0000, 1, NOW());


-- ─────────────────────────────────────────────────────────────
-- 8. HISTORIAL DE SUMINISTROS POR ACTIVO
--
-- RF-80:
--   - Solo lectura; correcciones generan nuevo historial
--   - Acceso por rol: Gestor solo sus UPs, Contador solo lectura
--   - Exportación > 10.000 registros → asíncrona (HTTP 202)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.historial_suministros_activos
    (id_activo_biologico, id_ciclo_productivos, id_usuario,
     origen, fecha_inicio, fecha_fin,
     costo_total_alimento, costo_total_medicamento, costo_total_suministros,
     num_registros_medicamento, num_registros_alimento,
     formato_exportacion, fecha_consulta)
VALUES
-- Historial completo BOV-001 (AMBOS tipos)
(1, 1, 1,
 'AMBOS',
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 47025.0000, 35240.0000, 82265.0000,
 2, 3,
 'PANTALLA', NOW()),

-- Historial solo MEDICAMENTO BOV-003 (para informe veterinario)
(3, 1, 2,
 'MEDICAMENTO',
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 0.0000, 35240.0000, 35240.0000,
 2, 0,
 'PDF', NOW()),

-- Historial completo BOV-004 (AMBOS — para informe gestante)
(4, 1, 2,
 'AMBOS',
 CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day',
 9275.0000, 160000.0000, 169275.0000,
 1, 1,
 'PANTALLA', NOW()),

-- Historial ALIMENTO LOTE-AV-001 (solo alimentación — ciclo finalizado)
(5, 2, 1,
 'ALIMENTO',
 CURRENT_DATE - INTERVAL '42 days', CURRENT_DATE - INTERVAL '1 day',
 39648000.0000, 0.0000, 39648000.0000,
 0, 1,
 'XLS', NOW() - INTERVAL '1 day'),

-- Historial AMBOS LOTE-PEC-001 (acuicultura — exportación)
(7, 1, 1,
 'AMBOS',
 CURRENT_DATE - INTERVAL '60 days', CURRENT_DATE - INTERVAL '1 day',
 14229000.0000, 9363600.0000, 23592600.0000,
 1, 1,
 'XLS', NOW());


-- ─────────────────────────────────────────────────────────────
-- 9. AUDITORÍAS DE SUMINISTROS
--
-- Restricciones RF-79:
--   - Append-only: no UPDATE ni DELETE
--   - Solo componentes internos M05 pueden emitir eventos (no manual)
--   - hash_integridad SHA-256 (gestionado por M12, no en esta tabla)
--   - Retención: 5 años para eventos NIC41; 1 año para TECNICO
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo5.auditorias_suministros
    (entidad_afectada, tipo_operacion, datos_anteriores, datos_nuevos,
     id_usuario, ip_origen, id_sesion, resultado, fecha_evento)
VALUES
-- Auditoría inserción tipo_alimento 'Concentrado Producción Lechera'
('tipos_alimentos', 'INSERT',
 NULL,
 '{"id_tipo_elemento": 2, "nombre": "Concentrado Produccion Lechera", '
 '"costo_unitario": 2650.0, "unidad_medida": "kg", "estado": "ACTIVO"}',
 1, '10.0.1.20', 1, 'EXITOSO',
 NOW() - INTERVAL '30 days'),

-- Auditoría inserción registro_consumo BOV-001 primer período
('registros_consumo_alimentos', 'INSERT',
 NULL,
 '{"id_consumo": 1, "id_activo_biologico": 1, "id_tipo_alimento": 2, '
 '"cantidad_suministrada": 4.5, "costo_total": 11925.0, '
 '"fecha_inicio": "hace 7 dias"}',
 1, '10.0.1.20', 1, 'EXITOSO',
 NOW() - INTERVAL '7 days'),

-- Auditoría inserción registro_medicamento BOV-003 (ivermectina)
('registros_medicamentos', 'INSERT',
 NULL,
 '{"id_registro": 1, "id_activo_biologico": 3, '
 '"nombre_medicamento": "Ivermectina 1%", "cantidad": 10.4, '
 '"costo_total": 19240.0, "via_aplicacion": "SC"}',
 1, '10.0.1.20', 1, 'EXITOSO',
 NOW() - INTERVAL '20 days'),

-- Auditoría consulta historial BOV-001 (SELECT para reporte)
('historial_suministros_activos', 'SELECT',
 NULL,
 '{"id_activo_biologico": 1, "origen": "AMBOS", '
 '"periodo": "ultimo_mes", "formato": "PANTALLA"}',
 1, '192.168.1.50', 2, 'EXITOSO',
 NOW() - INTERVAL '1 hour'),

-- Auditoría inserción costo_productivo BOV-001
('costos_productivos', 'INSERT',
 NULL,
 '{"id_activo_biologico": 1, "id_ciclo_productivo": 1, '
 '"costo_total": 200240.0, "tipo_operacion": "REGISTRO"}',
 1, '10.0.1.20', 1, 'EXITOSO',
 NOW() - INTERVAL '29 days'),

-- Auditoría intento fallido (usuario sin permisos intenta eliminar)
('registros_consumo_alimentos', 'DELETE',
 '{"id_consumo": 2, "motivo_intento": "Corrección de cantidad"}',
 NULL,
 2, '192.168.1.55', 3, 'RECHAZADO',
 NOW() - INTERVAL '6 days'),

-- Auditoría generación reporte gastos acumulados LOTE-AV-001
('reporte_gastos_acumulados', 'SELECT',
 NULL,
 '{"id_activo_biologico": 5, "categoria": "AVICOLA_ENGORDE", '
 '"total_costo_directo": 39648000.0, "formato": "XLS"}',
 1, '10.0.1.25', 2, 'EXITOSO',
 NOW() - INTERVAL '1 day'),

-- Auditoría inserción medición incremental BOV-001 (CA calculado)
('mediciones_incrementales', 'INSERT',
 NULL,
 '{"id_activo_biologico": 1, "id_ciclo": 1, '
 '"conversion_alimenticia": 14.4074, "ganancia_peso": 40.5, '
 '"consumo_alimento_acumulado": 583.5}',
 1, '10.0.1.20', 1, 'EXITOSO',
 NOW() - INTERVAL '1 day');
