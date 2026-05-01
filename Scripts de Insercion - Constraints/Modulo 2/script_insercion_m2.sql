-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 2
-- ==============================================================
--
-- TIPOS DE COLUMNA timetz EN EL DDL (verificados contra backup):
--   [T1] detalles_activos_individuales.fecha_creacion       → timetz
--   [T2] auditoria_activos_biologicos_individuales.fecha_cambio → timetz
--   [T3] gestiones_fases.fecha_inicio                       → timetz
--   [T4] movimientos.fecha_fin                              → timetz
--   NOTA: historicos_estados_activos.fecha_cambio es TIMESTAMPTZ (no timetz)
--         asociaciones_activos_sensores.fecha_fin es TIMESTAMPTZ NOT NULL
--
-- ENUMS DEL MÓDULO 2 (verificar antes de ejecutar):
--   [E1] enum_activo_biologico_origen_financiero:
--        SELECT enum_range(NULL::modulo2.enum_activo_biologico_origen_financiero);
--        Valores: 'compra','nacimiento','donacion','transferencia_interna'
--   [E2] enum_activo_biologico_tipo:
--        SELECT enum_range(NULL::modulo2.enum_activo_biologico_tipo);
--        Valores: 'INDIVIDUAL','POBLACIONAL'
--   [E3] enum_movimiento_tipo:
--        SELECT enum_range(NULL::modulo2.enum_movimiento_tipo);
--        Valores: 'entrada','salida'
--   [E4] enum_evento_reproductivo_categoria:
--        SELECT enum_range(NULL::modulo2.enum_evento_reproductivo_categoria);
--        Valores: 'servicio','inseminacion','diagnostico','parto','aborto','nacimiento'
--   [E5] enum_evento_bajas_tipo:
--        SELECT enum_range(NULL::modulo2.enum_evento_bajas_tipo);
--        Valores: 'muerte','venta','sacrificio','perdida','descarte_sanitario'
--   [E6] enum_indicador_zootecnico_tipo:
--        SELECT enum_range(NULL::modulo2.enum_indicador_zootecnico_tipo);
--        Valores: 'ganancia_peso','produccion_promedio','tasa_morbilidad',
--                 'tasa_mortalidad','conversion_alimenticia'
--   [E7] enum_asociaciones_activos_sensores_tipo:
--        SELECT enum_range(NULL::modulo2.enum_asociaciones_activos_sensores_tipo);
--        Valores: 'directa','ambiental','poblacional'
--
-- ==============================================================


-- ==============================================================
-- PRECONDICIÓN 0 — VERIFICAR DEPENDENCIA DE MÓDULO 1
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo1.usuarios WHERE id_usuario IN (1, 2)
        HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo1.usuarios debe contener '
            'usuarios con id=1 e id=2. Ejecute primero el script '
            'de inserción del Módulo 1.';
    END IF;
END $$;


-- ==============================================================
-- PRECONDICIÓN 1 — VERIFICAR DEPENDENCIAS DE MÓDULO 9
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo9.infraestructuras
        WHERE id_infraestructura IN (1, 2, 3, 4)
        HAVING COUNT(*) = 4
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.infraestructuras debe '
            'contener registros con ids 1-4. Ejecute primero el '
            'script de inserción del Módulo 9.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo9.especies
        WHERE id_especie IN (1, 2, 3)
        HAVING COUNT(*) = 3
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo9.especies debe contener '
            'registros con ids 1-3. Ejecute primero el script de '
            'inserción del Módulo 9.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK):
--   1.  estados_activos_biologicos
--   2.  activos_biologicos
--   3.  detalles_activos_individuales         ← timetz [T1]
--   4.  detalles_activos_biologicos_poblacionales
--   5.  movimientos                            ← timetz [T4]
--   6.  gestiones_fases                        ← timetz [T3]
--   7.  eventos_activos
--   8.  eventos_crecimeinto                   ← frecuencia varchar(55)
--   9.  eventos_sanitarios
--   10. eventos_reproductivos                 ← PK propia + FK a eventos_activos
--   11. eventos_productivos
--   12. eventos_bajas
--   13. historicos_estados_activos            ← fecha_cambio timestamptz
--   14. auditoria_activos_biologicos          ← timetz [T2]
--   15. asociaciones_activos_sensores         ← fecha_fin timestamptz NOT NULL
--   16. indicadores_zootecnicos
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. ESTADOS DE ACTIVOS BIOLÓGICOS
--
-- Transiciones válidas:
--   ACTIVO(1)      → INACTIVO(2)|EN_TRATAMIENTO(3)|AISLADO(4)|CERRADO(5)|BAJA(6)
--   INACTIVO(2)    → ACTIVO(1)|EN_TRATAMIENTO(3)|CERRADO(5)|BAJA(6)
--   EN_TRATAMIENTO(3) → ACTIVO(1)|INACTIVO(2)|AISLADO(4)|CERRADO(5)|BAJA(6)
--   AISLADO(4)     → ACTIVO(1)|INACTIVO(2)|EN_TRATAMIENTO(3)|CERRADO(5)|BAJA(6)
--   CERRADO(5)     → BAJA(6) únicamente
--   BAJA(6)        → ninguna (irreversible)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.estados_activos_biologicos (nombre) VALUES
    ('ACTIVO'),          -- id 1: estado inicial automático (RF-33)
    ('INACTIVO'),        -- id 2: temporalmente fuera de operación
    ('EN_TRATAMIENTO'),  -- id 3: bajo intervención sanitaria
    ('AISLADO'),         -- id 4: separado por condición sanitaria/manejo
    ('CERRADO'),         -- id 5: ciclo finalizado, originado por RF-38
    ('BAJA');            -- id 6: retirado definitivamente, originado por RF-45

-- ─────────────────────────────────────────────────────────────
-- 2. ACTIVOS BIOLÓGICOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.activos_biologicos
    (id_especie, indentficador, id_infraestructura, tipo,
     fecha_inicio_ciclo, id_estado, descripcion, origen_financiero,
     costo_adquisicion, atributos_dinamicos, id_usuario, fecha_creacion)
VALUES
-- ── Individuales (bovinos) ────────────────────────────────────
(1, 'BOV-001', 1, 'INDIVIDUAL', 2024,
 1, 'Vaca Holstein adulta, alto rendimiento lechero',
 'compra', 3500000.0000,
 '{"color": "blanco-negro", "condicion_corporal": 3.5}', 1, NOW()),

(1, 'BOV-002', 1, 'INDIVIDUAL', 2024,
 1, 'Novilla Brahman en desarrollo',
 'nacimiento', 0.0000,
 '{"color": "gris", "condicion_corporal": 3.0}', 1, NOW()),

-- BOV-003: ACTIVO — el tratamiento antiparasitario fue un evento pasado
(1, 'BOV-003', 2, 'INDIVIDUAL', 2024,
 1, 'Toro reproductor Simmental',
 'compra', 8000000.0000,
 '{"color": "rojizo", "condicion_corporal": 4.0}', 1, NOW()),

-- BOV-004: ACTIVO — la gestación es evento reproductivo (RF-42), no estado
(1, 'BOV-004', 1, 'INDIVIDUAL', 2024,
 1, 'Vaca Normando gestante',
 'compra', 4200000.0000,
 '{"color": "pardo-blanco", "condicion_corporal": 3.8}', 2, NOW()),

-- BOV-005: AISLADO — cuarentena post-compra representada con AISLADO (RF-44)
(1, 'BOV-005', 2, 'INDIVIDUAL', 2024,
 4, 'Novillo en aislamiento sanitario post-compra',
 'compra', 2800000.0000,
 '{"color": "negro", "condicion_corporal": 2.5}', 2, NOW()),

-- ── Poblacionales (aves) ──────────────────────────────────────
(2, 'LOTE-AV-001', 3, 'POBLACIONAL', 2024,
 1, 'Lote de pollos de engorde linea Ross',
 'compra', 1500000.0000,
 '{"linea_genetica": "Ross 308", "galpon": "G1"}', 1, NOW()),

(2, 'LOTE-AV-002', 3, 'POBLACIONAL', 2024,
 1, 'Lote de gallinas ponedoras',
 'compra', 2200000.0000,
 '{"linea_genetica": "Lohmann Brown", "galpon": "G2"}', 2, NOW()),

-- ── Poblacionales (peces) ─────────────────────────────────────
(3, 'LOTE-PEC-001', 4, 'POBLACIONAL', 2024,
 1, 'Lote de tilapia roja en estanque 1',
 'compra', 980000.0000,
 '{"estanque": "E1", "tipo_agua": "dulce"}', 1, NOW()),

-- LOTE-PEC-002: CERRADO — ciclo finalizado por cosecha total (RF-38)
(3, 'LOTE-PEC-002', 4, 'POBLACIONAL', 2024,
 5, 'Lote de cachama — ciclo productivo cerrado por cosecha',
 'compra', 750000.0000,
 '{"estanque": "E2", "tipo_agua": "dulce"}', 2, NOW()),

-- BOV-006: BAJA — retirado definitivamente del sistema (RF-45)
(1, 'BOV-006', 1, 'INDIVIDUAL', 2023,
 6, 'Vaca Holstein — dada de baja por venta al mercado',
 'nacimiento', 0.0000,
 '{"color": "rojo", "condicion_corporal": 3.2}', 1, NOW());

-- ─────────────────────────────────────────────────────────────
-- 3. DETALLES DE ACTIVOS INDIVIDUALES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.detalles_activos_individuales
    (id_activo_biologico, raza, sexo, fecha_nacimeinto,
     peso_inicial, fecha_creacion, fecha_actualizacion, id_usuario)
VALUES
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 'Holstein',  'Hembra', '2019-03-15 00:00:00+00', 42.500, CURRENT_TIME, NOW(), 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 'Brahman',   'Hembra', '2022-07-20 00:00:00+00', 38.000, CURRENT_TIME, NOW(), 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 'Simmental', 'Macho',  '2018-11-05 00:00:00+00', 55.000, CURRENT_TIME, NOW(), 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-004'),
 'Normando',  'Hembra', '2020-04-10 00:00:00+00', 40.000, CURRENT_TIME, NOW(), 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-005'),
 'Brahman',   'Macho',  '2021-09-01 00:00:00+00', 45.000, CURRENT_TIME, NOW(), 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-006'),
 'Holstein',  'Hembra', '2018-06-12 00:00:00+00', 41.000, CURRENT_TIME, NOW(), 1);

-- ─────────────────────────────────────────────────────────────
-- 4. DETALLES DE ACTIVOS POBLACIONALES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.detalles_activos_biologicos_poblacionales
    (id_activo_biologico, cantidad_inicial, cantidad_actual,
     peso_promedio, biomasa_total, densidad)
VALUES
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-001'),
 5000, 4870, 1.850, 9009.500, 12.500),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-002'),
 3000, 2980, 1.950, 5811.000, 8.200),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-001'),
 8000, 7650, 0.480, 3672.000, 25.000),
-- LOTE-PEC-002: cosechado — cantidad=0, biomasa=0, densidad=0
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-002'),
 6000, 0, 0.000, 0.000, 0.000);

-- ─────────────────────────────────────────────────────────────
-- 5. MOVIMIENTOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.movimientos
    (id_usuario, fecha_transferencia, fecha_fin, tipo,
     id_activo_biologico, id_infraestructura_origen,
     id_infraestructura_destino, fecha_registro)
VALUES
(1, '2024-01-10 08:00:00+00', '08:30:00+00', 'entrada',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 1, 2, '2024-01-10 09:00:00+00'),
(1, '2024-02-05 07:00:00+00', '07:45:00+00', 'salida',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 1, 3, '2024-02-05 08:00:00+00'),
(2, '2024-03-01 09:00:00+00', '09:30:00+00', 'entrada',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 2, 1, '2024-03-01 10:00:00+00'),
(1, '2024-04-15 06:00:00+00', '06:20:00+00', 'entrada',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-005'),
 4, 2, '2024-04-15 07:00:00+00'),
(2, '2024-05-20 10:00:00+00', '10:45:00+00', 'salida',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-001'),
 3, 1, '2024-05-20 11:00:00+00'),
(1, '2024-06-01 08:30:00+00', '09:00:00+00', 'entrada',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-001'),
 4, 3, '2024-06-01 09:30:00+00');

-- ─────────────────────────────────────────────────────────────
-- 6. GESTIONES DE FASES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.gestiones_fases
    (id_activo_biologico, id_ciclo_productiva, fecha_inicio,
     fecha_finalizacion, es_activa, id_usuario)
VALUES
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 9, '08:00:00+00', '2024-12-31 00:00:00+00', true,  1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 9, '08:00:00+00', NULL, true,  1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 10, '07:00:00+00', '2024-06-30 00:00:00+00', false, 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-001'),
 9, '06:00:00+00', '2024-09-30 00:00:00+00', false, 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-002'),
 10, '06:00:00+00', NULL, true,  2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-001'),
 9, '07:30:00+00', NULL, true,  1);

-- ─────────────────────────────────────────────────────────────
-- 7. EVENTOS ACTIVOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.eventos_activos
    (id_activo_biologico, fecha, descripcion, id_usuario)
VALUES
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 '2024-02-01 08:00:00+00', 'Pesaje mensual — vaca Holstein BOV-001', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 '2024-02-01 08:30:00+00', 'Pesaje mensual — novilla Brahman BOV-002', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-001'),
 '2024-03-15 07:00:00+00', 'Pesaje lote pollos semana 3', 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 '2024-01-20 09:00:00+00', 'Desparasitacion rutinaria — toro Simmental BOV-003', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-005'),
 '2024-04-16 10:00:00+00', 'Tratamiento preventivo — novillo aislado BOV-005', 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-002'),
 '2024-03-10 08:00:00+00', 'Vacunacion Newcastle — lote ponedoras LOTE-AV-002', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-004'),
 '2024-03-05 07:30:00+00', 'Servicio de monta natural — vaca Normando BOV-004', 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 '2023-09-10 08:00:00+00', 'Parto — vaca Holstein BOV-001, 1 cria', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 '2024-03-01 06:00:00+00', 'Registro produccion de leche diaria', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-002'),
 '2024-03-01 06:30:00+00', 'Registro produccion de huevo diaria', 2),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-002'),
 '2024-07-01 08:00:00+00', 'Cosecha total — lote cachama LOTE-PEC-002', 1),
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-006'),
 '2024-08-15 09:00:00+00', 'Baja por venta — vaca Holstein BOV-006', 2);

-- ─────────────────────────────────────────────────────────────
-- 8. EVENTOS DE CRECIMIENTO
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.eventos_crecimeinto
    (id_evento, tipo_medicion, valor_medicion,
     unidad_medida, tipo_agregacion, frecuencia)
VALUES
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-001' AND ea.descripcion LIKE '%Pesaje mensual%BOV-001%'),
 'peso_vivo', 520.50, 'kg', 'individual', 'mensual'),
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-002' AND ea.descripcion LIKE '%Pesaje mensual%BOV-002%'),
 'peso_vivo', 285.00, 'kg', 'individual', 'mensual'),
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'LOTE-AV-001' AND ea.descripcion LIKE '%Pesaje lote%'),
 'peso_vivo', 1.85, 'kg', 'promedio', 'semanal');

-- ─────────────────────────────────────────────────────────────
-- 9. EVENTOS SANITARIOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.eventos_sanitarios
    (id_evento, diagnostico, medicamento, dosis, unidad_dosis, frecuencia)
VALUES
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-003' AND ea.descripcion LIKE '%Desparasitacion%'),
 'Parasitosis gastrointestinal preventiva', 'Ivermectina 1%', 5.00, 'ml', 2),
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-005' AND ea.descripcion LIKE '%Tratamiento%'),
 'Control preventivo post-aislamiento sanitario', 'Oxitetraciclina', 10.00, 'ml', 3),
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'LOTE-AV-002' AND ea.descripcion LIKE '%Vacunacion%'),
 'Prevencion Newcastle y Bronquitis Infecciosa', 'Vacuna ND-IB', 0.50, 'ml', 1);

-- ─────────────────────────────────────────────────────────────
-- 10. EVENTOS REPRODUCTIVOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.eventos_reproductivos
    (id_evento_reproductivo, categoria, id_padre,
     resultado, numero_cria, id_madre)
VALUES
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-004' AND ea.descripcion LIKE '%monta natural%'),
 'servicio',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 'positivo', 0,
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-004')),

((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-001' AND ea.descripcion LIKE '%Parto%'),
 'parto',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 'exitoso', 1,
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'));

-- ─────────────────────────────────────────────────────────────
-- 11. EVENTOS PRODUCTIVOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.eventos_productivos
    (id_evento, cantidad, condiciones,
     id_metrica_produccion, id_ciclo_productivo)
VALUES
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-001' AND ea.descripcion LIKE '%leche%'),
 24.500, 'Ordeno mecanico, temperatura 18°C, buenas condiciones sanitarias', 9, 8),

((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'LOTE-AV-002' AND ea.descripcion LIKE '%huevo%'),
 280.000, 'Recoleccion manual, nido limpio, temperatura 22°C', 10, 9);

-- ─────────────────────────────────────────────────────────────
-- 12. EVENTOS DE BAJAS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.eventos_bajas
    (id_evento, cantidad_afectada, detalles, tipo)
VALUES
((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'LOTE-PEC-002'),
 6000,
 'Cosecha programada al finalizar ciclo productivo. '
 'Lote LOTE-PEC-002 con 6000 individuos cosechados y comercializados.',
 'venta'),

((SELECT ea.id_eventos FROM modulo2.eventos_activos ea
  JOIN modulo2.activos_biologicos ab ON ab.id_activo_biologico = ea.id_activo_biologico
  WHERE ab.indentficador = 'BOV-006'),
 1,
 'Baja definitiva: venta de vaca Holstein BOV-006 al mercado. '
 'Fin de vida productiva, ciclo 2023 cerrado.',
 'venta');

-- ─────────────────────────────────────────────────────────────
-- 13. HISTÓRICO DE ESTADOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.historicos_estados_activos
    (id_activo_biologico, id_estado_nuevo, id_estado_anterior,
     fecha_cambio, motivo_cambio, modulo_origen, id_usuario)
VALUES
-- BOV-003: ACTIVO(1) → EN_TRATAMIENTO(3)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 3, 1, '2024-01-20 09:00:00+00',
 'Inicio tratamiento antiparasitario con Ivermectina 1%',
 'modulo2', 1),

-- BOV-003: EN_TRATAMIENTO(3) → ACTIVO(1)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 1, 3, '2024-01-25 09:00:00+00',
 'Alta medica post-tratamiento antiparasitario',
 'modulo2', 1),

-- BOV-005: ACTIVO(1) → AISLADO(4)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-005'),
 4, 1, '2024-04-15 06:00:00+00',
 'Aislamiento sanitario obligatorio post-compra para evaluacion',
 'modulo2', 2),

-- LOTE-PEC-002: ACTIVO(1) → CERRADO(5) — cosecha = cierre de ciclo (RF-38)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-002'),
 5, 1, '2024-07-01 08:00:00+00',
 'Cierre de ciclo productivo por cosecha total del lote',
 'modulo2', 1),

-- BOV-006: ACTIVO(1) → CERRADO(5) — fin de vida productiva (RF-38)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-006'),
 5, 1, '2024-08-10 09:00:00+00',
 'Cierre de ciclo productivo previo a la baja por venta',
 'modulo2', 2),

-- BOV-006: CERRADO(5) → BAJA(6) — unica transicion valida desde CERRADO (RF-44, RF-45)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-006'),
 6, 5, '2024-08-15 09:00:00+00',
 'Baja definitiva por venta al mercado. Estado final irreversible.',
 'modulo2', 2);


-- ─────────────────────────────────────────────────────────────
-- 14. AUDITORÍA DE ACTIVOS INDIVIDUALES  (RF-35, RF-46)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.auditoria_activos_biologicos_individuales
    (id_activo_biologico, id_usuario, campo_modificado,
     valor_anterior, valor_nuevo, fecha_cambio, modulo_origen)
VALUES
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 1, 'id_infraestructura',
 '{"id_infraestructura": 1}', '{"id_infraestructura": 2}',
 '08:00:00+00', 'modulo2'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 1, 'id_estado',
 '{"id_estado": 1, "nombre": "ACTIVO"}', '{"id_estado": 4, "nombre": "AISLADO"}',
 '06:00:00+00', 'modulo2'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 1, 'descripcion',
 '{"descripcion": "Toro en evaluacion"}',
 '{"descripcion": "Toro reproductor Simmental"}',
 '09:00:00+00', 'modulo2'),

-- BOV-004: auditoría de descripcion (no estado inexistente)
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-004'),
 2, 'descripcion',
 '{"descripcion": "Vaca Normando"}',
 '{"descripcion": "Vaca Normando gestante"}',
 '07:30:00+00', 'modulo2'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-005'),
 2, 'costo_adquisicion',
 '{"costo_adquisicion": 2500000}',
 '{"costo_adquisicion": 2800000}',
 '10:00:00+00', 'modulo2');

-- ─────────────────────────────────────────────────────────────
-- 15. ASOCIACIONES ACTIVOS-SENSORES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.asociaciones_activos_sensores
    (id_sensor, id_usuario, fecha_inicio, fecha_fin,
     motivo, id_activo_biologico, tipo)
VALUES
(1, 1, '2024-01-01 00:00:00+00', '2024-12-31 23:59:59+00',
 'Monitoreo temperatura corporal — vaca Holstein BOV-001',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 'directa'),

(2, 1, '2024-01-01 00:00:00+00', '2024-06-30 23:59:59+00',
 'Sensor actividad — deteccion de celo BOV-002',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 'directa'),

(3, 2, '2024-03-01 00:00:00+00', '2024-09-30 23:59:59+00',
 'Monitoreo oxigeno disuelto — estanque tilapia LOTE-PEC-001',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-001'),
 'poblacional'),

(4, 2, '2024-04-15 00:00:00+00', '2024-08-15 23:59:59+00',
 'Sensor temperatura ambiental — galpon ponedoras LOTE-AV-002',
 (SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-002'),
 'ambiental');

-- ─────────────────────────────────────────────────────────────
-- 16. INDICADORES ZOOTÉCNICOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo2.indicadores_zootecnicos
    (id_activo_biologico, rango_fecha, tipo, paramtros_calculo)
VALUES
((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-001'),
 '[2024-01-01, 2024-03-31]', 'produccion_promedio',
 '{"unidad": "litros/dia", "promedio": 22.5, "total_dias": 90}'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-002'),
 '[2024-01-01, 2024-03-31]', 'ganancia_peso',
 '{"peso_inicial_kg": 260.0, "peso_final_kg": 285.0, "dias": 90, "gpd_kg": 0.278}'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-001'),
 '[2024-01-15, 2024-03-15]', 'ganancia_peso',
 '{"peso_inicial_kg": 0.045, "peso_final_kg": 1.85, "dias": 59, "gpd_kg": 0.031}'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-001'),
 '[2024-01-15, 2024-03-15]', 'tasa_mortalidad',
 '{"cantidad_inicial": 5000, "muertes": 130, "porcentaje": 2.6}'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-AV-002'),
 '[2024-01-01, 2024-03-31]', 'produccion_promedio',
 '{"unidad": "huevos/ave/dia", "promedio": 0.94, "total_aves": 2980}'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'LOTE-PEC-001'),
 '[2024-03-01, 2024-06-30]', 'ganancia_peso',
 '{"peso_inicial_kg": 0.10, "peso_final_kg": 0.48, "dias": 121, "gpd_kg": 0.003}'),

((SELECT id_activo_biologico FROM modulo2.activos_biologicos WHERE indentficador = 'BOV-003'),
 '[2024-01-01, 2024-06-30]', 'tasa_morbilidad',
 '{"eventos_sanitarios": 1, "total_dias": 181, "porcentaje": 0.55}');
