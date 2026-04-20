-- ------------------------------------------------------------
-- 1. ESTADOS DE ACTIVOS BIOLÓGICOS
-- ------------------------------------------------------------
INSERT INTO modulo2.estados_activos_biologicos (nombre) VALUES
    ('Activo'),
    ('Inactivo'),
    ('En tratamiento'),
    ('En cuarentena'),
    ('Vendido'),
    ('Muerto'),
    ('En gestación');
 
 
-- ------------------------------------------------------------
-- 2. ACTIVOS BIOLÓGICOS
-- ------------------------------------------------------------
-- Individuales (bovinos, equinos, etc.)
INSERT INTO modulo2.activos_biologicos
    (id_especie, indentficador, id_infraestructura, tipo, fecha_inicio_ciclo,
     id_estado, descripcion, origen_financiero, costo_adquisicion,
     atributos_dinamicos, id_usuario, fecha_creacion)
VALUES
    -- Individuales
    (1, 'BOV-001', 1, 'INDIVIDUAL', 2024,
     1, 'Vaca Holstein adulta, alto rendimiento lechero',
     'compra', 3500000.0000,
     '{"color": "blanco-negro", "condicion_corporal": 3.5}', 1, NOW()),
 
    (1, 'BOV-002', 1, 'INDIVIDUAL', 2024,
     1, 'Novilla Brahman en desarrollo',
     'nacimiento', 0.0000,
     '{"color": "gris", "condicion_corporal": 3.0}', 1, NOW()),
 
    (1, 'BOV-003', 2, 'INDIVIDUAL', 2024,
     3, 'Toro reproductor Simmental',
     'compra', 8000000.0000,
     '{"color": "rojizo", "condicion_corporal": 4.0}', 1, NOW()),
 
    (1, 'BOV-004', 1, 'INDIVIDUAL', 2024,
     7, 'Vaca Normando gestante',
     'compra', 4200000.0000,
     '{"color": "pardo-blanco", "condicion_corporal": 3.8}', 2, NOW()),
 
    (1, 'BOV-005', 2, 'INDIVIDUAL', 2024,
     4, 'Novillo en cuarentena post-compra',
     'compra', 2800000.0000,
     '{"color": "negro", "condicion_corporal": 2.5}', 2, NOW()),
 
    -- Poblacionales (lotes de aves, peces, etc.)
    (2, 'LOTE-AV-001', 3, 'POBLACIONAL', 2024,
     1, 'Lote de pollos de engorde línea Ross',
     'compra', 1500000.0000,
     '{"linea_genetica": "Ross 308", "galpón": "G1"}', 1, NOW()),
 
    (2, 'LOTE-AV-002', 3, 'POBLACIONAL', 2024,
     1, 'Lote de gallinas ponedoras',
     'compra', 2200000.0000,
     '{"linea_genetica": "Lohmann Brown", "galpón": "G2"}', 2, NOW()),
 
    (3, 'LOTE-PEC-001', 4, 'POBLACIONAL', 2024,
     1, 'Lote de tilapia roja en estanque 1',
     'compra', 980000.0000,
     '{"estanque": "E1", "tipo_agua": "dulce"}', 1, NOW()),
 
    (3, 'LOTE-PEC-002', 4, 'POBLACIONAL', 2024,
     2, 'Lote de cachama finalizado',
     'compra', 750000.0000,
     '{"estanque": "E2", "tipo_agua": "dulce"}', 2, NOW()),
 
    (1, 'BOV-006', 1, 'INDIVIDUAL', 2023,
     5, 'Vaca vendida - ciclo cerrado',
     'nacimiento', 0.0000,
     '{"color": "rojo", "condicion_corporal": 3.2}', 1, NOW());
 
 
-- ------------------------------------------------------------
-- 3. DETALLES DE ACTIVOS INDIVIDUALES
-- (solo para activos tipo INDIVIDUAL: ids 1-5 y 10)
-- ------------------------------------------------------------
INSERT INTO modulo2.detalles_activos_individuales
    (id_activo_biologico, raza, sexo, fecha_nacimeinto, peso_inicial,
     fecha_creacion, fecha_actualizacion, id_usuario)
VALUES
    (11, 'Holstein',   'Hembra', '2019-03-15 00:00:00+00', 42.500, NOW(), NOW(), 1),
    (12, 'Brahman',    'Hembra', '2022-07-20 00:00:00+00', 38.000, NOW(), NOW(), 1),
    (13, 'Simmental',  'Macho',  '2018-11-05 00:00:00+00', 55.000, NOW(), NOW(), 1),
    (14, 'Normando',   'Hembra', '2020-04-10 00:00:00+00', 40.000, NOW(), NOW(), 2),
    (15, 'Brahman',    'Macho',  '2021-09-01 00:00:00+00', 45.000, NOW(), NOW(), 2),
    (20,'Holstein',   'Hembra', '2018-06-12 00:00:00+00', 41.000, NOW(), NOW(), 1);
 
 
-- ------------------------------------------------------------
-- 4. DETALLES DE ACTIVOS POBLACIONALES
-- (solo para activos tipo POBLACIONAL: ids 6-9)
-- ------------------------------------------------------------
INSERT INTO modulo2.detalles_activos_biologicos_poblacionales
    (id_activo_biologico, cantidad_inicial, cantidad_actual,
     peso_promedio, biomasa_total, densidad)
VALUES
    (16, 5000, 4870, 1.850, 9009.500, 12.500),   -- pollos engorde
    (17, 3000, 2980, 1.950, 5811.000,  8.200),   -- gallinas ponedoras
    (18, 8000, 7650, 0.480, 3672.000, 25.000),   -- tilapia
    (19, 6000,    0, 0.620, 3720.000, 18.000);   -- cachama (lote finalizado)
 
 
-- ------------------------------------------------------------
-- 5. MOVIMIENTOS
-- ------------------------------------------------------------
INSERT INTO modulo2.movimientos
    (id_usuario, fecha_transferencia, fecha_fin, tipo,
     id_activo_biologico, id_infraestructura_origen,
     id_infraestructura_destino, fecha_registro)
VALUES
    (1, '2024-01-10 08:00:00+00', '08:30:00+00', 'entrada', 11, 1, 2, '2024-01-10 09:00:00+00'),
    (1, '2024-02-05 07:00:00+00', '07:45:00+00', 'salida',  12, 1, 3, '2024-02-05 08:00:00+00'),
    (2, '2024-03-01 09:00:00+00', '09:30:00+00', 'entrada', 13, 2, 1, '2024-03-01 10:00:00+00'),
    (1, '2024-04-15 06:00:00+00', '06:20:00+00', 'entrada', 15, 4, 2, '2024-04-15 07:00:00+00'),
    (2, '2024-05-20 10:00:00+00', '10:45:00+00', 'salida',  16, 3, 1, '2024-05-20 11:00:00+00'),
    (1, '2024-06-01 08:30:00+00', '09:00:00+00', 'entrada', 18, 4, 3, '2024-06-01 09:30:00+00');
 
 
-- ------------------------------------------------------------
-- 6. GESTIONES DE FASES
-- ------------------------------------------------------------
INSERT INTO modulo2.gestiones_fases
    (id_activo_biologico, id_ciclo_productiva, fecha_inicio,
     fecha_finalizacion, es_activa, id_usuario)
VALUES
    (11, 9, '08:00:00+00', '2024-12-31 00:00:00+00', true,  1),
    (12, 9, '08:00:00+00', NULL,                      true,  1),
    (13, 10, '07:00:00+00', '2024-06-30 00:00:00+00', false, 1),
    (16, 9, '06:00:00+00', '2024-09-30 00:00:00+00', false, 2),
    (17, 10, '06:00:00+00', NULL,                      true,  2),
    (18, 9, '07:30:00+00', NULL,                      true,  1);
 
 
-- ------------------------------------------------------------
-- 7. EVENTOS ACTIVOS (tabla padre de todos los subtipos)
-- ------------------------------------------------------------
INSERT INTO modulo2.eventos_activos
    (id_activo_biologico, fecha, descripcion, id_usuario)
VALUES
    -- Crecimiento
    (11,  '2024-02-01 08:00:00+00', 'Pesaje mensual - vaca Holstein',           1),  -- id 1
    (12,  '2024-02-01 08:30:00+00', 'Pesaje mensual - novilla Brahman',          1),  -- id 2
    (16,  '2024-03-15 07:00:00+00', 'Pesaje lote pollos semana 3',               2),  -- id 3
    -- Sanitarios
    (13,  '2024-01-20 09:00:00+00', 'Desparasitación rutinaria toro Simmental',  1),  -- id 4
    (15,  '2024-04-16 10:00:00+00', 'Tratamiento preventivo novillo cuarentena', 2),  -- id 5
    (17,  '2024-03-10 08:00:00+00', 'Vacunación Newcastle lote ponedoras',       1),  -- id 6
    -- Reproductivos
    (14,  '2024-03-05 07:30:00+00', 'Servicio de monta natural vaca Normando',   2),  -- id 7
    (11,  '2023-09-10 08:00:00+00', 'Parto vaca Holstein - 1 cría',              1),  -- id 8
    -- Productivos
    (11,  '2024-03-01 06:00:00+00', 'Registro producción leche diaria',          1),  -- id 9
    (17,  '2024-03-01 06:30:00+00', 'Registro producción huevo diaria',          2),  -- id 10
    -- Bajas
    (19,  '2024-07-01 08:00:00+00', 'Cosecha total lote cachama',                1),  -- id 11
    (20, '2024-08-15 09:00:00+00', 'Venta vaca Holstein ciclo anterior',        2);  -- id 12
 
 
-- ------------------------------------------------------------
-- 8. EVENTOS DE CRECIMIENTO
-- ------------------------------------------------------------
INSERT INTO modulo2.eventos_crecimeinto
    (id_evento, tipo_medicion, valor_medicion, unidad_medida,
     tipo_agregacion, frecuencia)
VALUES
    (13, 'peso_vivo',   520.50, 'kg',  'individual', 'mensual'),
    (14, 'peso_vivo',   285.00, 'kg',  'individual', 'mensual'),
    (15, 'peso_vivo',     1.85, 'kg',  'promedio',   'semanal');
 
 
-- ------------------------------------------------------------
-- 9. EVENTOS SANITARIOS
-- ------------------------------------------------------------
INSERT INTO modulo2.eventos_sanitarios
    (id_evento, diagnostico, medicamento, dosis, unidad_dosis, frecuencia)
VALUES
    (16, 'Parasitosis gastrointestinal preventiva', 'Ivermectina 1%',    5.00, 'ml', 2),
    (17, 'Control preventivo post-cuarentena',      'Oxitetraciclina',  10.00, 'ml', 3),
    (18, 'Prevención Newcastle y Bronquitis',       'Vacuna ND-IB',      0.50, 'ml', 1);
 
 
-- ------------------------------------------------------------
-- 10. EVENTOS REPRODUCTIVOS
-- ------------------------------------------------------------
INSERT INTO modulo2.eventos_reproductivos
    (id_evento_reproductivo, categoria, id_padre, resultado,
     numero_cria, id_madre)
VALUES
    (19, 'servicio', 13, 'positivo',  0, 14),  -- monta Normando con toro Simmental
    (20, 'parto',    13, 'exitoso',   1, 11);  -- parto Holstein
 
 
-- ------------------------------------------------------------
-- 11. EVENTOS PRODUCTIVOS
-- ------------------------------------------------------------
INSERT INTO modulo2.eventos_productivos
    (id_evento, cantidad, condiciones, id_metrica_produccion, id_ciclo_productivo)
VALUES
    (21,  24.500, 'Ordeño mecánico, temperatura 18°C, buenas condiciones',  9, 8),
    (22, 280.000,'Recolección manual, nido limpio, temperatura 22°C',       10, 9);
 
 
-- ------------------------------------------------------------
-- 12. EVENTOS DE BAJAS
-- ------------------------------------------------------------
INSERT INTO modulo2.eventos_bajas
    (id_evento, cantidad_afectada, detalles, tipo)
VALUES
    (23, 6000, 'Cosecha programada fin de ciclo productivo cachama', 'venta'),
    (24,    1, 'Venta de vaca Holstein al final de su vida productiva', 'venta');
 
 
-- ------------------------------------------------------------
-- 13. HISTÓRICO DE ESTADOS DE ACTIVOS
-- ------------------------------------------------------------
INSERT INTO modulo2.historicos_estados_activos
    (id_activo_biologico, id_estado_nuevo, id_estado_anterior,
     fecha_cambio, motivo_cambio, modulo_origen, id_usuario)
VALUES
    (13, 3, 1, '2024-01-20 09:00:00+00', 'Inicio tratamiento antiparasitario', 'modulo2', 1),
    (13, 1, 3, '2024-01-25 09:00:00+00', 'Alta médica post tratamiento',        'modulo2', 1),
    (15, 4, 1, '2024-04-15 06:00:00+00', 'Ingreso a cuarentena post-compra',    'modulo2', 2),
    (15, 1, 4, '2024-04-30 08:00:00+00', 'Fin de cuarentena sin novedad',       'modulo2', 2),
    (14, 7, 1, '2024-03-05 07:30:00+00', 'Confirmación de preñez',              'modulo2', 2),
    (19, 2, 1, '2024-07-01 08:00:00+00', 'Lote cosechado - ciclo cerrado',      'modulo2', 1),
    (20,5, 1, '2024-08-15 09:00:00+00', 'Venta de activo al mercado',          'modulo2', 2);
 
 
-- ------------------------------------------------------------
-- 14. AUDITORÍA DE ACTIVOS INDIVIDUALES
-- ------------------------------------------------------------
INSERT INTO modulo2.auditoria_activos_biologicos_individuales
    (id_activo_biologico, id_usuario, campo_modificado,
     valor_anterior, valor_nuevo, fecha_cambio, modulo_origen)
VALUES
    (11, 1, 'id_infraestructura',
     '{"id_infraestructura": 1}', '{"id_infraestructura": 2}',
     '08:00:00+00', 'modulo2'),
 
    (12, 1, 'id_estado',
     '{"id_estado": 1}', '{"id_estado": 4}',
     '06:00:00+00', 'modulo2'),
 
    (13, 1, 'descripcion',
     '{"descripcion": "Toro en evaluación"}',
     '{"descripcion": "Toro reproductor Simmental"}',
     '09:00:00+00', 'modulo2'),
 
    (14, 2, 'id_estado',
     '{"id_estado": 1}', '{"id_estado": 7}',
     '07:30:00+00', 'modulo2'),
 
    (15, 2, 'costo_adquisicion',
     '{"costo_adquisicion": 2500000}', '{"costo_adquisicion": 2800000}',
     '10:00:00+00', 'modulo2');
 
 
-- ------------------------------------------------------------
-- 15. ASOCIACIONES ACTIVOS - SENSORES
-- ------------------------------------------------------------
INSERT INTO modulo2.asociaciones_activos_sensores
    (id_sensor, id_usuario, fecha_inicio, fecha_fin, motivo)
VALUES
    (1, 1, '2024-01-01 00:00:00+00', '2024-12-31 23:59:59+00',
     'Monitoreo temperatura corporal vaca Holstein'),
    (2, 1, '2024-01-01 00:00:00+00', '2024-06-30 23:59:59+00',
     'Sensor de actividad - detección de celo'),
    (3, 2, '2024-03-01 00:00:00+00', '2024-09-30 23:59:59+00',
     'Monitoreo oxígeno disuelto estanque tilapia'),
    (4, 2, '2024-04-15 00:00:00+00', '2024-08-15 23:59:59+00',
     'Sensor de temperatura ambiental galpón ponedoras');
 
 
-- ------------------------------------------------------------
-- 16. INDICADORES ZOOTÉCNICOS
-- ------------------------------------------------------------
INSERT INTO modulo2.indicadores_zootecnicos
    (id_activo_biologico, rango_fecha, tipo, paramtros_calculo)
VALUES
    (11,  '[2024-01-01, 2024-03-31]', 'produccion_promedio',
     '{"unidad": "litros/dia", "promedio": 22.5, "total_dias": 90}'),
 
    (12,  '[2024-01-01, 2024-03-31]', 'ganancia_peso',
     '{"peso_inicial_kg": 260.0, "peso_final_kg": 285.0, "dias": 90, "gpd_kg": 0.278}'),
 
    (16,  '[2024-01-15, 2024-03-15]', 'ganancia_peso',
     '{"peso_inicial_kg": 0.045, "peso_final_kg": 1.85, "dias": 59, "gpd_kg": 0.031}'),
 
    (16,  '[2024-01-15, 2024-03-15]', 'tasa_mortalidad',
     '{"cantidad_inicial": 5000, "muertes": 130, "porcentaje": 2.6}'),
 
    (17,  '[2024-01-01, 2024-03-31]', 'produccion_promedio',
     '{"unidad": "huevos/ave/dia", "promedio": 0.94, "total_aves": 2980}'),
 
    (18,  '[2024-03-01, 2024-06-30]', 'ganancia_peso',
     '{"peso_inicial_kg": 0.10, "peso_final_kg": 0.48, "dias": 121, "gpd_kg": 0.003}'),
 
    (13,  '[2024-01-01, 2024-06-30]', 'tasa_morbilidad',
     '{"eventos_sanitarios": 1, "total_dias": 181, "porcentaje": 0.55}');