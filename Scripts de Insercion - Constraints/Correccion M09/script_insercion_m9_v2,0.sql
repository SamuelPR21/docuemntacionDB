-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 9
-- Versión: 2.0  (correcciones según revisión técnica test_M09.md)
-- ==============================================================
--
-- CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
--
-- [C1] ALTER TABLE modulo9.finca RENAME TO fincas:
--       La instrucción original fallaba si la tabla ya fue renombrada
--       previamente. Se reemplaza por un bloque DO que verifica la
--       existencia de la tabla 'finca' antes de renombrar.
--
-- [C2] patologias.categoria (modulo9.enum_patologia_categoria):
--       Se añade verificación del enum real. Los literales insertados
--       deben coincidir EXACTAMENTE con los valores del enum. Se
--       documenta la consulta de verificación y se mantienen los
--       valores en minúsculas con advertencia de ajuste.
--
-- [C3] niveles_alerta_ambientales.nivel (modulo9.enum_nivel_alerta):
--       Ídem que [C2]. Se mantienen 'normal','precaucion','critico'
--       con advertencia de verificar el enum antes de ejecutar.
--
-- [C4] sensores.categoria (modulo3.enum_reglas_alertas_tipo_sensor):
--       El enum pertenece a modulo3. Se añade bloque de verificación
--       y se proporciona instrucción de consulta. Si el enum no existe
--       o no contiene los literales usados, se debe ajustar antes de
--       ejecutar la sección de sensores.
--
-- [C5] Dependencia de modulo1.usuarios:
--       Se agrega verificación explícita al inicio del script para
--       garantizar que existan los usuarios con id=1 (Administrador)
--       e id=2 (Productor) antes de continuar.
--
-- ==============================================================


-- ==============================================================
-- PRECONDICIÓN 0 — VERIFICAR DEPENDENCIA DE MÓDULO 1
-- El script asume que modulo1.usuarios ya contiene al menos:
--   id=1 → Administrador
--   id=2 → Productor
-- Si esta consulta retorna 0, ejecutar primero script_insercion_m1.sql
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo1.usuarios WHERE id_usuario IN (1, 2)
        HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION
            'PRECONDICIÓN FALLIDA: modulo1.usuarios debe contener usuarios con id=1 e id=2. '
            'Ejecute primero el script de inserción del Módulo 1.';
    END IF;
END $$;


-- ==============================================================
-- PRECONDICIÓN 1 — VERIFICAR / RENOMBRAR TABLA finca → fincas
-- Se verifica si la tabla existe con el nombre antiguo antes de
-- intentar renombrarla. Si ya se llama 'fincas', no hace nada.
-- ==============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'modulo9'
           AND table_name   = 'finca'
    ) THEN
        ALTER TABLE modulo9.finca RENAME TO fincas;
        RAISE NOTICE 'Tabla modulo9.finca renombrada a modulo9.fincas';
    ELSE
        RAISE NOTICE 'La tabla modulo9.fincas ya existe con el nombre correcto. No se requiere renombrar.';
    END IF;
END $$;


-- ==============================================================
-- PRECONDICIÓN 2 — VERIFICAR ENUMS ANTES DE CONTINUAR
-- Ejecutar las siguientes consultas para confirmar que los
-- literales de los INSERTs coinciden con los enums definidos.
-- Si los valores difieren, ajustar los INSERTs correspondientes.
-- ==============================================================
-- Enum de categoría de patología:
--   SELECT enum_range(NULL::modulo9.enum_patologia_categoria);
--
-- Enum de nivel de alerta:
--   SELECT enum_range(NULL::modulo9.enum_nivel_alerta);
--
-- Enum de tipo de sensor (módulo 3):
--   SELECT enum_range(NULL::modulo3.enum_reglas_alertas_tipo_sensor);
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. ESPECIES  (RF-15)
-- Restricción: nombre único, longitud 3-50 caracteres, es_activo
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.especies (nombre, descripcion, fecha_creacion, fecha_actualizacion, es_activo) VALUES
('Tilapia nilótica',
 'Especie de agua dulce ampliamente cultivada en sistemas de acuicultura tropical.',
 NOW(), NOW(), true),
('Trucha arcoíris',
 'Especie de agua fría cultivada en estanques de alta montaña y ríos oxigenados.',
 NOW(), NOW(), true),
('Camarón blanco',
 'Crustáceo marino de alto valor comercial cultivado en estanques costeros.',
 NOW(), NOW(), true),
('Cachama blanca',
 'Pez de agua dulce tropical con alta adaptabilidad a sistemas extensivos e intensivos.',
 NOW(), NOW(), true),
('Mojarra plateada',
 'Especie de ciclo corto utilizada en policultivos y sistemas de pequeña escala.',
 NOW(), NOW(), true);


-- ─────────────────────────────────────────────────────────────
-- 2. PATOLOGIAS  (RF-16)
--
-- ADVERTENCIA [C2]: el campo 'categoria' es de tipo
-- modulo9.enum_patologia_categoria. Verificar con:
--   SELECT enum_range(NULL::modulo9.enum_patologia_categoria);
-- Los literales usados ('parasitaria','bacteriana','micotica','viral')
-- deben existir EXACTAMENTE en el enum. Ajustar si es necesario.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.patologias
    (nombre, descripcion, es_activo, nombre_tecnico, etiologia, categoria, codigo_cie)
VALUES
('Ich (Ichthyophthirius)',
 'Parásito protozoario que genera manchas blancas en piel y aletas. Alta mortalidad si no se trata.',
 true,
 'Ichthyophthirius multifiliis',
 'Protozoario ciliado obligatorio. Se transmite por contacto directo entre hospederos y a través del agua.',
 'parasitaria',   -- Verificar enum: modulo9.enum_patologia_categoria
 'B65'),

('Vibriosis',
 'Infección bacteriana por Vibrio spp. Frecuente en crustáceos marinos y peces en estrés.',
 true,
 'Vibriosis vulnificus',
 'Bacteria gramnegativa del género Vibrio. Oportunista en condiciones de estrés.',
 'bacteriana',    -- Verificar enum
 'B96.82'),

('Columnaris',
 'Enfermedad bacteriana por Flavobacterium columnare. Afecta piel, aletas y branquias.',
 true,
 'Columnariosis / Enfermedad sádica del agua',
 'Bacteria gramnegativa Flavobacterium columnare. Se propaga por agua y utensilios contaminados.',
 'bacteriana',    -- Verificar enum
 'B96.8'),

('Saprolegniosis',
 'Infección fúngica oportunista asociada a heridas o estrés. Visible como filamentos blancos.',
 true,
 'Saprolegniosis acuática',
 'Oomicetos del género Saprolegnia spp. Coloniza tejidos dañados o inmunocomprometidos.',
 'micotica',      -- Verificar enum (puede ser 'micotica' o 'fungica' según definición)
 'B48.8'),

('Síndrome de la mancha blanca',
 'Enfermedad viral grave en camarones. Sin tratamiento, causa mortalidad masiva en 3-10 días.',
 true,
 'White Spot Syndrome (WSS)',
 'Virus de doble cadena de ADN: WSSV. Se transmite horizontal y verticalmente.',
 'viral',         -- Verificar enum
 'B33.8');


-- ─────────────────────────────────────────────────────────────
-- 3. ESPECIES_PATOLOGIAS  (RF-16)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.especies_patologias (id_especie, id_patologia) VALUES
(1, 1), -- Tilapia     → Ich
(1, 3), -- Tilapia     → Columnaris
(2, 1), -- Trucha      → Ich
(2, 4), -- Trucha      → Saprolegniosis
(3, 2), -- Camarón     → Vibriosis
(3, 5), -- Camarón     → Síndrome mancha blanca
(4, 1), -- Cachama     → Ich
(4, 3), -- Cachama     → Columnaris
(5, 1), -- Mojarra     → Ich
(5, 4); -- Mojarra     → Saprolegniosis


-- ─────────────────────────────────────────────────────────────
-- 4. CICLOS_BIOLOGICOS  (RF-16)
-- Restricción: duracion_dias > 0, nombre longitud 3-100 caracteres
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.ciclos_biologicos
    (nombre, descripcion, duracion_dias, id_especie, es_activo)
VALUES
-- Tilapia nilótica (id_especie = 1)
('Fase larval tilapia',
 'Período desde eclosión hasta absorción del saco vitelino. Alta sensibilidad ambiental.',
 10, 1, true),
('Fase juvenil tilapia',
 'Etapa de crecimiento activo con alta conversión alimenticia.',
 45, 1, true),
('Fase engorde tilapia',
 'Etapa final orientada a alcanzar peso comercial (400-600 g).',
 90, 1, true),
-- Trucha arcoíris (id_especie = 2)
('Fase larval trucha',
 'Periodo de alevinaje desde eclosión hasta primera alimentación exógena.',
 15, 2, true),
('Fase juvenil trucha',
 'Crecimiento activo en agua fría con alta oxigenación requerida.',
 60, 2, true),
('Fase engorde trucha',
 'Etapa de engorde hasta peso comercial (250-400 g).',
 90, 2, true),
-- Camarón blanco (id_especie = 3)
('Fase postlarval camarón',
 'Etapa inicial desde postlarva hasta adaptación al estanque.',
 20, 3, true),
('Fase juvenil camarón',
 'Crecimiento acelerado con alta demanda proteica.',
 40, 3, true),
('Fase engorde camarón',
 'Etapa final hasta talla comercial (12-20 g).',
 40, 3, true),
-- Cachama blanca (id_especie = 4)
('Fase juvenil cachama',
 'Etapa de adaptación y crecimiento inicial en estanques.',
 60, 4, true),
('Fase engorde cachama',
 'Crecimiento hasta peso comercial (800 g - 1.2 kg).',
 120, 4, true),
-- Mojarra plateada (id_especie = 5)
('Fase juvenil mojarra',
 'Etapa de crecimiento inicial con buena conversión alimenticia.',
 45, 5, true),
('Fase engorde mojarra',
 'Etapa de engorde hasta peso comercial (200-350 g).',
 75, 5, true);


-- ─────────────────────────────────────────────────────────────
-- 5. CICLOS_PRODUCTIVOS  (RF-16)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.ciclos_productivos (nombre, duracion_dias, id_ciclo_biologico) VALUES
('Ciclo completo tilapia 2025-A',   145, 3),
('Ciclo completo trucha 2025-A',    165, 6),
('Ciclo completo camarón 2025-A',   100, 9),
('Ciclo completo cachama 2025-A',   180, 11),
('Ciclo completo mojarra 2025-A',   120, 13),
('Ciclo engorde rápido tilapia',     90, 3),
('Ciclo experimental camarón',      110, 9);


-- ─────────────────────────────────────────────────────────────
-- 6. CICLOS_PRODUCTIVOS_BIOLOGICOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.ciclos_productivos_biologicos
    (id_ciclo_biologico, id_ciclo_productivo)
VALUES
(1, 1), (2, 1), (3, 1),   -- Ciclo completo tilapia
(4, 2), (5, 2), (6, 2),   -- Ciclo completo trucha
(7, 3), (8, 3), (9, 3),   -- Ciclo completo camarón
(10, 4), (11, 4),          -- Ciclo completo cachama
(12, 5), (13, 5),          -- Ciclo completo mojarra
(3, 6),                    -- Ciclo engorde rápido tilapia
(7, 7), (8, 7), (9, 7);   -- Ciclo experimental camarón


-- ─────────────────────────────────────────────────────────────
-- 7. METRICAS_PRODUCCION  (RF-16)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.metricas_produccion
    (nombre, unidad_medida, tipo_medicion, tiene_estado)
VALUES
('Peso promedio individual',             'g',       'manual',    true),
('Biomasa total',                        'kg',      'calculada', true),
('Tasa de mortalidad',                   '%',       'calculada', true),
('Factor conversión alimenticia (FCR)',   'ratio',   'calculada', true),
('Densidad de siembra',                  'ind/m²',  'manual',    false),
('Tasa de crecimiento específico (SGR)', '%/día',   'calculada', true),
('Consumo de alimento diario',           'kg/día',  'manual',    false),
('Supervivencia acumulada',              '%',       'calculada', true);


-- ─────────────────────────────────────────────────────────────
-- 8. METRICAS_CICLO_PRODUCTIVO  (RF-16)
-- Sin duplicados por (id_ciclo_productivo, id_metrica_produccion)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.metricas_ciclo_productivo
    (id_ciclo_productivo, id_metrica_produccion)
VALUES
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 8),  -- Tilapia completo
(2, 1), (2, 2), (2, 3), (2, 4), (2, 6), (2, 8),  -- Trucha completo
(3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (3, 8),  -- Camarón completo
(4, 1), (4, 2), (4, 3), (4, 8),                   -- Cachama completo
(5, 1), (5, 2), (5, 3), (5, 7), (5, 8),           -- Mojarra completo
(6, 1), (6, 2), (6, 3), (6, 7),                   -- Engorde rápido tilapia
(7, 1), (7, 2), (7, 3), (7, 7), (7, 8);           -- Experimental camarón


-- ─────────────────────────────────────────────────────────────
-- 9. VARIABLES_AMBIENTALES  (RF-17)
-- Restricción: valor_fisico_min < valor_fisico_max, min >= 0
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.variables_ambientales
    (nombre, unidad, valor_fisico_min, valor_fisico_max, es_activo)
VALUES
('Temperatura del agua',    '°C',    0,    45,   true),
('pH del agua',             'pH',    0,    14,   true),
('Oxígeno disuelto',        'mg/L',  0,    20,   true),
('Amoniaco total',          'mg/L',  0,    10,   true),
('Nitrito',                 'mg/L',  0,    5,    true),
('Salinidad',               'ppt',   0,    45,   true),
('Turbidez',                'NTU',   0,    500,  true),
('Conductividad eléctrica', 'µS/cm', 0,    5000, true);


-- ─────────────────────────────────────────────────────────────
-- 10. UMBRALES_AMBIENTALES  (RF-17)
-- id_usuario = 1 → Administrador (debe existir en modulo1.usuarios)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.umbrales_ambientales
    (nombre, unidad_medida, descripcion, es_activo,
     id_especie, id_variable_ambiental, id_usuario)
VALUES
('Temperatura óptima tilapia', '°C',
 'Rango térmico ideal para crecimiento de tilapia nilótica.',         true, 1, 1, 1),
('pH óptimo tilapia',          'pH',
 'Rango de pH adecuado para metabolismo y bienestar de la tilapia.',  true, 1, 2, 1),
('Oxígeno disuelto tilapia',   'mg/L',
 'Nivel mínimo y óptimo de OD para tilapia en engorde.',              true, 1, 3, 1),
('Temperatura óptima trucha',  '°C',
 'Rango térmico crítico para trucha arcoíris. Sensible al calor.',    true, 2, 1, 1),
('pH óptimo trucha',           'pH',
 'Rango de pH requerido para trucha en sistemas de agua fría.',       true, 2, 2, 1),
('Oxígeno disuelto trucha',    'mg/L',
 'Trucha requiere altos niveles de OD por su alta tasa metabólica.',  true, 2, 3, 1),
('Temperatura óptima camarón', '°C',
 'Rango térmico para camarón blanco en sistemas marinos.',            true, 3, 1, 1),
('Salinidad óptima camarón',   'ppt',
 'Rango de salinidad adecuado para camarón blanco.',                  true, 3, 6, 1),
('Amoniaco máximo camarón',    'mg/L',
 'Límite máximo de amoniaco total tolerable para camarón.',           true, 3, 4, 1),
('Temperatura óptima cachama', '°C',
 'Rango térmico óptimo para cachama blanca en estanques.',            true, 4, 1, 1),
('Oxígeno disuelto cachama',   'mg/L',
 'Nivel mínimo de OD para cachama en sistema extensivo.',             true, 4, 3, 1),
('Temperatura óptima mojarra', '°C',
 'Rango térmico para mojarra plateada en policultivos.',              true, 5, 1, 1),
('pH óptimo mojarra',          'pH',
 'Rango de pH tolerable para mojarra en estanques de tierra.',        true, 5, 2, 1);


-- ─────────────────────────────────────────────────────────────
-- 11. NIVELES_ALERTA_AMBIENTALES  (RF-17)
--
-- ADVERTENCIA [C3]: el campo 'nivel' es de tipo
-- modulo9.enum_nivel_alerta. Verificar con:
--   SELECT enum_range(NULL::modulo9.enum_nivel_alerta);
-- Los literales 'normal','precaucion','critico' deben existir
-- exactamente en el enum. Ajustar si difieren.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.niveles_alerta_ambientales
    (id_umbral_ambiental, nivel, limite_inferior, limite_superior)
VALUES
-- Umbral 1: Temperatura tilapia
(1, 'normal',    25, 30),
(1, 'precaucion',20, 25),
(1, 'critico',    0, 20),
-- Umbral 2: pH tilapia
(2, 'normal',     6,  8),
(2, 'precaucion', 5,  6),
(2, 'critico',    0,  5),
-- Umbral 3: OD tilapia
(3, 'normal',     5, 12),
(3, 'precaucion', 3,  5),
(3, 'critico',    0,  3),
-- Umbral 4: Temperatura trucha
(4, 'normal',    12, 18),
(4, 'precaucion', 8, 12),
(4, 'critico',   18, 25),
-- Umbral 5: pH trucha
(5, 'normal',     6,  8),
(5, 'precaucion', 5,  6),
(5, 'critico',    0,  5),
-- Umbral 6: OD trucha
(6, 'normal',     8, 14),
(6, 'precaucion', 6,  8),
(6, 'critico',    0,  6),
-- Umbral 7: Temperatura camarón
(7, 'normal',    23, 30),
(7, 'precaucion',20, 23),
(7, 'critico',    0, 20),
-- Umbral 8: Salinidad camarón
(8, 'normal',    10, 25),
(8, 'precaucion', 5, 10),
(8, 'critico',    0,  5),
-- Umbral 9: Amoniaco camarón
(9, 'normal',     0,  1),
(9, 'precaucion', 1,  2),
(9, 'critico',    2, 10),
-- Umbral 10: Temperatura cachama
(10,'normal',    26, 32),
(10,'precaucion',22, 26),
(10,'critico',    0, 22),
-- Umbral 11: OD cachama
(11,'normal',     4, 12),
(11,'precaucion', 2,  4),
(11,'critico',    0,  2),
-- Umbral 12: Temperatura mojarra
(12,'normal',    24, 30),
(12,'precaucion',20, 24),
(12,'critico',    0, 20),
-- Umbral 13: pH mojarra
(13,'normal',     6,  9),
(13,'precaucion', 5,  6),
(13,'critico',    0,  5);


-- ─────────────────────────────────────────────────────────────
-- 12. FINCAS  (RF-19)
-- Restricción: tamano_h > 0, id_usuario referencia modulo1.usuarios
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.fincas
    (nombre, ubicacion, tamano_h, fecha_actualizacion, fecha_creacion, id_usuario, es_activo)
VALUES
('Finca Acuícola El Remanso',
 '{"lat": 2.9273, "lng": -75.2819, "municipio": "Neiva", "departamento": "Huila"}',
 12.50, NOW(), NOW(), 2, true),

('Piscícola Los Esteros',
 '{"lat": 3.8654, "lng": -76.4920, "municipio": "Cartago", "departamento": "Valle del Cauca"}',
 8.75, NOW(), NOW(), 2, true),

('Camaronera Costa Azul',
 '{"lat": 8.7479, "lng": -75.8814, "municipio": "Montería", "departamento": "Córdoba"}',
 25.00, NOW(), NOW(), 2, true),

('Granja Piscícola La Esperanza',
 '{"lat": 5.0689, "lng": -75.5174, "municipio": "Manizales", "departamento": "Caldas"}',
 6.30, NOW(), NOW(), 2, true);


-- ─────────────────────────────────────────────────────────────
-- 13. INFRAESTRUCTURAS  (RF-20)
-- Restricción: superficie > 0, nombre único por finca
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.infraestructuras
    (descripcion, nombre, id_finca, superficie, es_activo, tipo)
VALUES
('Estanque principal de engorde de tilapia con aireación artificial',
 'Estanque-01',       1, 2500.00, true, 'estanque'),
('Estanque secundario para fase juvenil de tilapia',
 'Estanque-02',       1, 1800.00, true, 'estanque'),
('Área de alevinaje y larvicultura de tilapia',
 'Alevinera-01',      1,  500.00, true, 'estanque'),
('Estanque de trucha arcoíris con flujo de agua continuo',
 'Canal-Trucha-01',   2, 1200.00, true, 'estanque'),
('Estanque de engorde de trucha con alta oxigenación',
 'Canal-Trucha-02',   2, 1200.00, true, 'estanque'),
('Estanque de engorde de camarón blanco con recirculación parcial',
 'Piscina-Cam-01',    3, 5000.00, true, 'estanque'),
('Piscina de reserva y aclimatación de postlarvas de camarón',
 'Piscina-Cam-02',    3, 3000.00, true, 'estanque'),
('Estanque de cachama en sistema semi-intensivo',
 'Estanque-Cache-01', 4, 3200.00, true, 'estanque'),
('Estanque de mojarra en policultivo',
 'Estanque-Moj-01',   4, 2800.00, true, 'estanque');


-- ─────────────────────────────────────────────────────────────
-- 14. DISPOSITIVOS_IOT  (RF-21)
-- Restricción: serial único globalmente
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.dispositivos_iot
    (serial, descripcion, id_infraestructura, es_activo, fecha_creacion)
VALUES
('IOT-EST01-HLA-001',
 'Nodo IoT principal estanque 01, gateway LoRaWAN con batería solar', 1, true, NOW()),
('IOT-EST02-HLA-002',
 'Nodo IoT estanque 02, módulo WiFi con fuente de red',               2, true, NOW()),
('IOT-ALE01-HLA-003',
 'Nodo IoT alevinera, módulo compacto de bajo consumo',               3, true, NOW()),
('IOT-TRU01-VLC-001',
 'Nodo IoT estanque trucha 01, resistente a bajas temperaturas',      4, true, NOW()),
('IOT-TRU02-VLC-002',
 'Nodo IoT estanque trucha 02, con alarma local integrada',           5, true, NOW()),
('IOT-CAM01-COR-001',
 'Nodo IoT piscina camarón 01, gateway LoRaWAN costero',              6, true, NOW()),
('IOT-CAM02-COR-002',
 'Nodo IoT piscina camarón 02, módulo de respaldo',                   7, true, NOW()),
('IOT-CAC01-CAL-001',
 'Nodo IoT estanque cachama, módulo estándar de campo',               8, true, NOW()),
('IOT-MOJ01-CAL-002',
 'Nodo IoT estanque mojarra, módulo estándar de campo',               9, true, NOW());


-- ─────────────────────────────────────────────────────────────
-- 15. SENSORES  (RF-22)
--
-- ADVERTENCIA [C4]: el campo 'categoria' es de tipo
-- modulo3.enum_reglas_alertas_tipo_sensor. Verificar con:
--   SELECT enum_range(NULL::modulo3.enum_reglas_alertas_tipo_sensor);
-- Los literales usados deben coincidir exactamente con el enum.
-- Ajustar si difieren antes de ejecutar este bloque.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.sensores (id_dispositivo_iot, es_activo, nombre, categoria) VALUES
-- Dispositivo 1 — Estanque-01 (Finca El Remanso)
(1, true, 'Sensor temperatura estanque-01',          'temperatura'),
(1, true, 'Sensor pH estanque-01',                   'ph'),
(1, true, 'Sensor oxígeno disuelto estanque-01',     'oxigeno_disuelto'),
-- Dispositivo 2 — Estanque-02
(2, true, 'Sensor temperatura estanque-02',          'temperatura'),
(2, true, 'Sensor pH estanque-02',                   'ph'),
-- Dispositivo 3 — Alevinera-01
(3, true, 'Sensor temperatura alevinera-01',         'temperatura'),
(3, true, 'Sensor oxígeno disuelto alevinera-01',    'oxigeno_disuelto'),
-- Dispositivo 4 — Canal-Trucha-01
(4, true, 'Sensor temperatura canal-trucha-01',      'temperatura'),
(4, true, 'Sensor oxígeno disuelto canal-trucha-01', 'oxigeno_disuelto'),
-- Dispositivo 5 — Canal-Trucha-02
(5, true, 'Sensor temperatura canal-trucha-02',      'temperatura'),
(5, true, 'Sensor pH canal-trucha-02',               'ph'),
-- Dispositivo 6 — Piscina-Cam-01
(6, true, 'Sensor temperatura piscina-cam-01',       'temperatura'),
(6, true, 'Sensor salinidad piscina-cam-01',         'salinidad'),
(6, true, 'Sensor amoniaco piscina-cam-01',          'amoniaco'),
-- Dispositivo 7 — Piscina-Cam-02
(7, true, 'Sensor temperatura piscina-cam-02',       'temperatura'),
(7, true, 'Sensor salinidad piscina-cam-02',         'salinidad'),
-- Dispositivo 8 — Estanque-Cache-01
(8, true, 'Sensor temperatura estanque-cache-01',    'temperatura'),
(8, true, 'Sensor oxígeno disuelto estanque-cache-01','oxigeno_disuelto'),
-- Dispositivo 9 — Estanque-Moj-01
(9, true, 'Sensor temperatura estanque-moj-01',      'temperatura'),
(9, true, 'Sensor pH estanque-moj-01',               'ph');


-- ─────────────────────────────────────────────────────────────
-- 16. SENSORES_AREAS_ASOCIADAS  (RF-22)
-- Restricción: un sensor → una sola área activa (tiene_estado=TRUE)
-- id_usuario = 2 → Productor responsable de la asociación
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.sensores_areas_asociadas
    (id_sensor, id_dispositivo_iot, id_infraestructura,
     punto_instalacion, tiene_estado, fecha_asociacion, fecha_finalizacion, id_usuario)
VALUES
(1,  1, 1, 'Entrada de agua, profundidad 30 cm',         true, NOW(), NULL, 2),
(2,  1, 1, 'Centro del estanque, profundidad 50 cm',     true, NOW(), NULL, 2),
(3,  1, 1, 'Salida de agua, profundidad 40 cm',          true, NOW(), NULL, 2),
(4,  2, 2, 'Entrada de agua, profundidad 30 cm',         true, NOW(), NULL, 2),
(5,  2, 2, 'Centro del estanque, profundidad 40 cm',     true, NOW(), NULL, 2),
(6,  3, 3, 'Zona de incubación, profundidad 15 cm',      true, NOW(), NULL, 2),
(7,  3, 3, 'Zona de alevinaje, profundidad 20 cm',       true, NOW(), NULL, 2),
(8,  4, 4, 'Entrada canal, profundidad 20 cm',           true, NOW(), NULL, 2),
(9,  4, 4, 'Mitad del canal, profundidad 25 cm',         true, NOW(), NULL, 2),
(10, 5, 5, 'Entrada canal trucha 02',                    true, NOW(), NULL, 2),
(11, 5, 5, 'Centro canal trucha 02',                     true, NOW(), NULL, 2),
(12, 6, 6, 'Zona sur piscina, profundidad 60 cm',        true, NOW(), NULL, 2),
(13, 6, 6, 'Zona norte piscina, profundidad 50 cm',      true, NOW(), NULL, 2),
(14, 6, 6, 'Punto de aireación central',                 true, NOW(), NULL, 2),
(15, 7, 7, 'Zona de aclimatación, profundidad 40 cm',    true, NOW(), NULL, 2),
(16, 7, 7, 'Centro piscina reserva',                     true, NOW(), NULL, 2),
(17, 8, 8, 'Entrada agua estanque cachama',              true, NOW(), NULL, 2),
(18, 8, 8, 'Centro estanque cachama, profundidad 60 cm', true, NOW(), NULL, 2),
(19, 9, 9, 'Entrada agua estanque mojarra',              true, NOW(), NULL, 2),
(20, 9, 9, 'Centro estanque mojarra',                    true, NOW(), NULL, 2);


-- ─────────────────────────────────────────────────────────────
-- 17. CONFIGURACIONES_REMOTAS  (RF-23)
-- Restricción: frecuencia_captura > 0, intervalo_transmision >= frecuencia_captura
-- estado IN ('PENDIENTE','APLICADA','CANCELADA') — tipo enum del DDL
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.configuraciones_remotas
    (frecuencia_captura, intervalo_transmision, id_dispositivo_iot,
     estado, id_usuario, fecha_creacion, fecha_aplicacion)
VALUES
(30,  300, 1, 'APLICADA', 1, NOW() - INTERVAL '30 days', NOW() - INTERVAL '29 days'),
(30,  300, 2, 'APLICADA', 1, NOW() - INTERVAL '30 days', NOW() - INTERVAL '29 days'),
(60,  600, 3, 'APLICADA', 1, NOW() - INTERVAL '30 days', NOW() - INTERVAL '29 days'),
(30,  300, 4, 'APLICADA', 1, NOW() - INTERVAL '15 days', NOW() - INTERVAL '14 days'),
(30,  300, 5, 'APLICADA', 1, NOW() - INTERVAL '15 days', NOW() - INTERVAL '14 days'),
(15,  180, 6, 'APLICADA', 1, NOW() - INTERVAL '7 days',  NOW() - INTERVAL '6 days'),
(15,  180, 7, 'APLICADA', 1, NOW() - INTERVAL '7 days',  NOW() - INTERVAL '6 days'),
(60,  600, 8, 'APLICADA', 1, NOW() - INTERVAL '30 days', NOW() - INTERVAL '29 days'),
(60,  600, 9, 'APLICADA', 1, NOW() - INTERVAL '30 days', NOW() - INTERVAL '29 days');


-- ─────────────────────────────────────────────────────────────
-- 18. CONFIGURACIONES_GLOBALES  (RF-18)
-- Restricción: solo una activa (índice uix_conf_global_unica_activa)
-- Verificar que no exista otra configuración con es_activo = TRUE
-- antes de ejecutar.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.configuraciones_globales
    (frecuencia_muestreo, heartbeat, fecha_actualizacion, id_usuario, es_activo)
VALUES
(60, 120, NOW(), 1, true);


-- ─────────────────────────────────────────────────────────────
-- 19. CALIBRACIONES  (RF-23)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.calibraciones
    (id_dispositivo_iot, fecha_calibracion, id_sensor,
     valor_referencia, observaciones, id_usuario)
VALUES
(1, NOW() - INTERVAL '30 days', 1,  25.0,
 'Calibración inicial con termómetro patrón certificado NIST.', 1),
(1, NOW() - INTERVAL '30 days', 2,   7.0,
 'Calibración con buffer pH 7.0 y 4.0. Electrodo en buen estado.', 1),
(1, NOW() - INTERVAL '30 days', 3,   8.5,
 'Calibración con solución saturada. Membrana nueva.', 1),
(4, NOW() - INTERVAL '15 days', 8,  14.0,
 'Calibración con termómetro de referencia para agua fría.', 1),
(4, NOW() - INTERVAL '15 days', 9,  10.0,
 'OD calibrado al 100% de saturación a 14 °C.', 1),
(6, NOW() - INTERVAL '7 days', 12,  27.0,
 'Calibración post-instalación sistema costero.', 1),
(6, NOW() - INTERVAL '7 days', 13,  15.0,
 'Calibración salinidad con refractómetro de referencia.', 1);


-- ─────────────────────────────────────────────────────────────
-- 20. GESTION_ESPECIES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.gestion_especies
    (id_usuario, id_especie, fecha_gestion, id_umbral_ambiental)
VALUES
(1, 1, NOW() - INTERVAL '60 days', 1),
(1, 1, NOW() - INTERVAL '60 days', 2),
(1, 1, NOW() - INTERVAL '60 days', 3),
(1, 2, NOW() - INTERVAL '55 days', 4),
(1, 2, NOW() - INTERVAL '55 days', 5),
(1, 2, NOW() - INTERVAL '55 days', 6),
(1, 3, NOW() - INTERVAL '45 days', 7),
(1, 3, NOW() - INTERVAL '45 days', 8),
(1, 3, NOW() - INTERVAL '45 days', 9),
(1, 4, NOW() - INTERVAL '30 days', 10),
(1, 4, NOW() - INTERVAL '30 days', 11),
(1, 5, NOW() - INTERVAL '20 days', 12),
(1, 5, NOW() - INTERVAL '20 days', 13);


-- ─────────────────────────────────────────────────────────────
-- 21. IDENTIDAD_VISUALES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.identidad_visuales
    (id_finca, id_usuario, logo_path, primary_color, secondary_color,
     org_display_name, version, fecha_creacion)
VALUES
(1, 1, '/assets/logos/remanso.png',   '#1A6B3C', '#A8D5B5', 'Acuícola El Remanso',   1, NOW()),
(2, 1, '/assets/logos/esteros.png',   '#0D4E8A', '#82B4D8', 'Piscícola Los Esteros', 1, NOW()),
(3, 1, '/assets/logos/costaazul.png', '#007B8A', '#7FD3DC', 'Camaronera Costa Azul', 1, NOW()),
(4, 1, '/assets/logos/esperanza.png', '#4A7C2F', '#B4D49A', 'Granja La Esperanza',   1, NOW());


-- ─────────────────────────────────────────────────────────────
-- 22. TEMAS_VISUALES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.temas_visuales
    (id_usuario, theme_mode, es_global, fecha_actualizacion)
VALUES
(1, 1, true,  NOW()),
(2, 2, false, NOW()),
(3, 3, false, NOW()),
(4, 1, false, NOW());


-- ─────────────────────────────────────────────────────────────
-- 23. DASHBOARD_LAYOUTS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.dashboard_layouts
    (id_usuario, config, active_widget, fecha_actualizacion)
VALUES
(1,
 '{"grid": [
   {"id_widget": 1, "fila": 1, "columna": 1, "span": 2, "visible": true},
   {"id_widget": 2, "fila": 1, "columna": 3, "span": 1, "visible": true},
   {"id_widget": 3, "fila": 1, "columna": 4, "span": 1, "visible": true},
   {"id_widget": 4, "fila": 2, "columna": 1, "span": 1, "visible": true},
   {"id_widget": 5, "fila": 2, "columna": 2, "span": 2, "visible": true}
 ]}',
 ARRAY['temperatura', 'ph', 'oxigeno', 'alertas', 'dispositivos'],
 NOW()),

(2,
 '{"grid": [
   {"id_widget": 1, "fila": 1, "columna": 1, "span": 2, "visible": true},
   {"id_widget": 6, "fila": 1, "columna": 3, "span": 2, "visible": true},
   {"id_widget": 7, "fila": 2, "columna": 1, "span": 1, "visible": true}
 ]}',
 ARRAY['temperatura', 'alertas_criticas', 'estado_finca'],
 NOW()),

(3,
 '{"grid": [
   {"id_widget": 1, "fila": 1, "columna": 1, "span": 1, "visible": true},
   {"id_widget": 2, "fila": 1, "columna": 2, "span": 1, "visible": true},
   {"id_widget": 3, "fila": 1, "columna": 3, "span": 1, "visible": true},
   {"id_widget": 8, "fila": 2, "columna": 1, "span": 2, "visible": true},
   {"id_widget": 9, "fila": 2, "columna": 3, "span": 2, "visible": true}
 ]}',
 ARRAY['temperatura', 'ph', 'oxigeno', 'historico_sensores', 'umbrales'],
 NOW());


-- ─────────────────────────────────────────────────────────────
-- 24. PREFERENCIAS_IDIOMAS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.preferencias_idiomas
    (id_usuario, locale_code, es_por_defecto, fecha_actualizacion)
VALUES
(1, 'es-CO', true,  NOW()),
(2, 'es-CO', false, NOW()),
(3, 'en-US', false, NOW()),
(4, 'es-CO', false, NOW());


-- ─────────────────────────────────────────────────────────────
-- 25. AUDITORIAS_VISUALES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.auditorias_visuales
    (id_usuario, fecha_creacion, valor_anterior, valor_nuevo)
VALUES
(1, NOW() - INTERVAL '10 days',
 '{"primary_color": "#2A7AE4", "org_display_name": "El Remanso"}',
 '{"primary_color": "#1A6B3C", "org_display_name": "Acuícola El Remanso"}'),
(1, NOW() - INTERVAL '5 days',
 '{"theme_mode": 3}',
 '{"theme_mode": 1}'),
(1, NOW() - INTERVAL '2 days',
 '{"active_widget": ["temperatura", "ph"]}',
 '{"active_widget": ["temperatura", "ph", "oxigeno", "alertas", "dispositivos"]}');


-- ─────────────────────────────────────────────────────────────
-- 26. PLANTILLAS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.plantillas
    (id_especie, id_usuario, template_name, params_snapshot, version, fecha_creacion)
VALUES
(1, 1, 'Plantilla estándar tilapia',
 '{
   "umbrales": [
     {"id": 1, "nombre": "Temperatura óptima tilapia", "min": 25, "max": 30},
     {"id": 2, "nombre": "pH óptimo tilapia",          "min": 6,  "max": 8},
     {"id": 3, "nombre": "Oxígeno disuelto tilapia",   "min": 5,  "max": 12}
   ],
   "ciclos_biologicos": [1, 2, 3],
   "metricas": [1, 2, 3, 4, 8]
 }',
 1, NOW()),

(2, 1, 'Plantilla estándar trucha',
 '{
   "umbrales": [
     {"id": 4, "nombre": "Temperatura óptima trucha", "min": 12, "max": 18},
     {"id": 5, "nombre": "pH óptimo trucha",          "min": 6,  "max": 8},
     {"id": 6, "nombre": "Oxígeno disuelto trucha",   "min": 8,  "max": 14}
   ],
   "ciclos_biologicos": [4, 5, 6],
   "metricas": [1, 2, 3, 4, 6, 8]
 }',
 1, NOW()),

(3, 1, 'Plantilla estándar camarón',
 '{
   "umbrales": [
     {"id": 7, "nombre": "Temperatura óptima camarón", "min": 23, "max": 30},
     {"id": 8, "nombre": "Salinidad óptima camarón",   "min": 10, "max": 25},
     {"id": 9, "nombre": "Amoniaco máximo camarón",    "min": 0,  "max": 1}
   ],
   "ciclos_biologicos": [7, 8, 9],
   "metricas": [1, 2, 3, 4, 5, 8]
 }',
 1, NOW());


-- ─────────────────────────────────────────────────────────────
-- 27. APLICACIONES_PLANTILLAS
-- Dependencia: plantillas (pasos 26) y modulo1.usuarios (id=1)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo9.aplicaciones_plantillas
    (id_usuario, id_plantilla, target_config,
     before_snapshot, after_snapshot, fecha_aplicacion)
VALUES
(1, 1,
 '{"tipo": "finca", "id_finca": 1, "nombre": "Finca Acuícola El Remanso"}',
 '{"umbrales": [], "ciclos_biologicos": [], "metricas": []}',
 '{
   "umbrales": [
     {"id": 1, "nombre": "Temperatura óptima tilapia", "min": 25, "max": 30},
     {"id": 2, "nombre": "pH óptimo tilapia",          "min": 6,  "max": 8},
     {"id": 3, "nombre": "Oxígeno disuelto tilapia",   "min": 5,  "max": 12}
   ],
   "ciclos_biologicos": [1, 2, 3],
   "metricas": [1, 2, 3, 4, 8]
 }',
 NOW() - INTERVAL '45 days'),

(1, 2,
 '{"tipo": "finca", "id_finca": 2, "nombre": "Piscícola Los Esteros"}',
 '{"umbrales": [], "ciclos_biologicos": [], "metricas": []}',
 '{
   "umbrales": [
     {"id": 4, "nombre": "Temperatura óptima trucha", "min": 12, "max": 18},
     {"id": 5, "nombre": "pH óptimo trucha",          "min": 6,  "max": 8},
     {"id": 6, "nombre": "Oxígeno disuelto trucha",   "min": 8,  "max": 14}
   ],
   "ciclos_biologicos": [4, 5, 6],
   "metricas": [1, 2, 3, 4, 6, 8]
 }',
 NOW() - INTERVAL '40 days'),

(1, 3,
 '{"tipo": "finca", "id_finca": 3, "nombre": "Camaronera Costa Azul"}',
 '{"umbrales": [], "ciclos_biologicos": [], "metricas": []}',
 '{
   "umbrales": [
     {"id": 7, "nombre": "Temperatura óptima camarón", "min": 23, "max": 30},
     {"id": 8, "nombre": "Salinidad óptima camarón",   "min": 10, "max": 25},
     {"id": 9, "nombre": "Amoniaco máximo camarón",    "min": 0,  "max": 1}
   ],
   "ciclos_biologicos": [7, 8, 9],
   "metricas": [1, 2, 3, 4, 5, 8]
 }',
 NOW() - INTERVAL '30 days');
