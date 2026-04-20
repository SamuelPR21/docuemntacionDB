ALTER TABLE modulo9.finca
RENAME TO fincas;
-- ============================================================
-- 1. ESPECIES
-- ============================================================
INSERT INTO modulo9.especies (nombre, descripcion, fecha_creacion, fecha_actualizacion, es_activo) VALUES
('Tilapia nilótica',    'Especie de agua dulce ampliamente cultivada en sistemas de acuicultura tropical.',        NOW(), NOW(), true),
('Trucha arcoíris',     'Especie de agua fría cultivada en estanques de alta montaña y ríos oxigenados.',         NOW(), NOW(), true),
('Camarón blanco',      'Crustáceo marino de alto valor comercial cultivado en estanques costeros.',              NOW(), NOW(), true),
('Cachama blanca',      'Pez de agua dulce tropical con alta adaptabilidad a sistemas extensivos e intensivos.',  NOW(), NOW(), true),
('Mojarra plateada',    'Especie de ciclo corto utilizada en policultivos y sistemas de pequeña escala.',         NOW(), NOW(), true);
 
-- ============================================================
-- 2. PATOLOGIAS
-- ============================================================
INSERT INTO modulo9.patologias (nombre, descripcion) VALUES
('Ich (Ichthyophthirius)',   'Parásito protozoario que genera manchas blancas en piel y aletas. Alta mortalidad si no se trata.'),
('Vibriosis',                'Infección bacteriana por Vibrio spp. Frecuente en crustáceos marinos y peces en estrés.'),
('Columnaris',               'Enfermedad bacteriana por Flavobacterium columnare. Afecta piel, aletas y branquias.'),
('Saprolegniosis',           'Infección fúngica oportunista asociada a heridas o estrés. Visible como filamentos blancos.'),
('Síndrome de la mancha blanca', 'Enfermedad viral grave en camarones. Sin tratamiento, causa mortalidad masiva en 3-10 días.');
 
-- ============================================================
-- 3. ESPECIES_PATOLOGIAS
-- ============================================================
INSERT INTO modulo9.especies_patologias (id_especie, id_patologia) VALUES
(1, 1), -- Tilapia - Ich
(1, 3), -- Tilapia - Columnaris
(2, 1), -- Trucha - Ich
(2, 4), -- Trucha - Saprolegniosis
(3, 2), -- Camarón - Vibriosis
(3, 5), -- Camarón - Mancha blanca
(4, 1), -- Cachama - Ich
(4, 3), -- Cachama - Columnaris
(5, 1), -- Mojarra - Ich
(5, 4); -- Mojarra - Saprolegniosis
 
-- ============================================================
-- 4. CICLOS_BIOLOGICOS
-- ============================================================
INSERT INTO modulo9.ciclos_biologicos (nombre, descripcion, duracion_dias, id_especie) VALUES
('Fase larval tilapia',        'Período desde eclosión hasta absorción del saco vitelino. Alta sensibilidad ambiental.',      10,  1),
('Fase juvenil tilapia',       'Etapa de crecimiento activo con alta conversión alimenticia.',                                 45,  1),
('Fase engorde tilapia',       'Etapa final orientada a alcanzar peso comercial (400-600g).',                                  90,  1),
('Fase larval trucha',         'Periodo de alevinaje desde eclosión hasta primera alimentación exógena.',                     15,  2),
('Fase juvenil trucha',        'Crecimiento activo en agua fría con alta oxigenación requerida.',                             60,  2),
('Fase engorde trucha',        'Etapa de engorde hasta peso comercial (250-400g).',                                           90,  2),
('Fase postlarval camarón',    'Etapa inicial desde postlarva hasta adaptación al estanque.',                                 20,  3),
('Fase juvenil camarón',       'Crecimiento acelerado con alta demanda proteica.',                                            40,  3),
('Fase engorde camarón',       'Etapa final hasta talla comercial (12-20 g).',                                                40,  3),
('Fase juvenil cachama',       'Etapa de adaptación y crecimiento inicial en estanques.',                                     60,  4),
('Fase engorde cachama',       'Crecimiento hasta peso comercial (800g - 1.2kg).',                                           120, 4),
('Fase juvenil mojarra',       'Etapa de crecimiento inicial con buena conversión alimenticia.',                              45,  5),
('Fase engorde mojarra',       'Etapa de engorde hasta peso comercial (200-350g).',                                           75,  5);
 
-- ============================================================
-- 5. CICLOS_PRODUCTIVOS
-- ============================================================
INSERT INTO modulo9.ciclos_productivos (nombre, duracion_dias, id_ciclo_biologico) VALUES
('Ciclo completo tilapia 2024-A',   145, 3),
('Ciclo completo trucha 2024-A',    165, 6),
('Ciclo completo camarón 2024-A',   100, 9),
('Ciclo completo cachama 2024-A',   180, 11),
('Ciclo completo mojarra 2024-A',   120, 13),
('Ciclo engorde rápido tilapia',     90, 3),
('Ciclo experimental camarón',      110, 9);
 
-- ============================================================
-- 6. CICLOS_PRODUCTIVOS_BIOLOGICOS
-- ============================================================
INSERT INTO modulo9.ciclos_productivos_biologicos (id_ciclo_biologico, id_ciclo_productivo) VALUES
(1,  1), -- larval tilapia    -> ciclo completo tilapia
(2,  1), -- juvenil tilapia   -> ciclo completo tilapia
(3,  1), -- engorde tilapia   -> ciclo completo tilapia
(4,  2), -- larval trucha     -> ciclo completo trucha
(5,  2), -- juvenil trucha    -> ciclo completo trucha
(6,  2), -- engorde trucha    -> ciclo completo trucha
(7,  3), -- postlarval camaron-> ciclo completo camarón
(8,  3), -- juvenil camarón   -> ciclo completo camarón
(9,  3), -- engorde camarón   -> ciclo completo camarón
(10, 4), -- juvenil cachama   -> ciclo completo cachama
(11, 4), -- engorde cachama   -> ciclo completo cachama
(12, 5), -- juvenil mojarra   -> ciclo completo mojarra
(13, 5), -- engorde mojarra   -> ciclo completo mojarra
(3,  6), -- engorde tilapia   -> ciclo rápido tilapia
(7,  7), -- postlarval camaron-> ciclo experimental
(8,  7), -- juvenil camarón   -> ciclo experimental
(9,  7); -- engorde camarón   -> ciclo experimental
 
-- ============================================================
-- 7. METRICAS_PRODUCCION
-- ============================================================
INSERT INTO modulo9.metricas_produccion (nombre, unidad_medida, tipo_medicion, tiene_estado) VALUES
('Peso promedio individual',  'g',      'manual',     true),
('Biomasa total',             'kg',     'calculada',  true),
('Tasa de mortalidad',        '%',      'calculada',  true),
('Factor conversión alimenticia (FCR)', 'ratio', 'calculada', true),
('Densidad de siembra',       'ind/m²', 'manual',     false),
('Tasa de crecimiento específico (SGR)', '%/día', 'calculada', true),
('Consumo de alimento diario','kg/día', 'manual',     false),
('Supervivencia acumulada',   '%',      'calculada',  true);
 
-- ============================================================
-- 8. METRICAS_CICLO_PRODUCTIVO
-- ============================================================
INSERT INTO modulo9.metricas_ciclo_productivo (id_ciclo_producitvo, id_metrica_produccion) VALUES
(1, 1),(1, 2),(1, 3),(1, 4),(1, 5),(1, 8), -- tilapia completo
(2, 1),(2, 2),(2, 3),(2, 4),(2, 6),(2, 8), -- trucha completo
(3, 1),(3, 2),(3, 3),(3, 4),(3, 5),(3, 8), -- camarón completo
(4, 1),(4, 2),(4, 3),(4, 7),(4, 8),        -- cachama completo
(5, 1),(5, 2),(5, 3),(5, 4),(5, 8),        -- mojarra completo
(6, 1),(6, 2),(6, 4),(6, 8),               -- tilapia rápido
(7, 1),(7, 2),(7, 3),(7, 5),(7, 8);        -- camarón experimental
 
-- ============================================================
-- 9. VARIABLES_AMBIENTALES
-- ============================================================
INSERT INTO modulo9.variables_ambientales (nombre, unidad, valor_fisico_min, valor_fisco_min, es_activo) VALUES
('Temperatura del agua',    '°C',   0,   45,  true),
('pH del agua',             'pH',   0,   14,  true),
('Oxígeno disuelto',        'mg/L', 0,   20,  true),
('Amoniaco total',          'mg/L', 0,   10,  true),
('Nitrito',                 'mg/L', 0,   5,   true),
('Salinidad',               'ppt',  0,   45,  true),
('Turbidez',                'NTU',  0,   500, true),
('Conductividad eléctrica', 'µS/cm',0,   5000,true);
 
-- ============================================================
-- 10. UMBRALES_AMBIENTALES
-- (id_usuario = 1 asumiendo admin existente)
-- ============================================================
INSERT INTO modulo9.umbrales_ambientales (nombre, unidad_medida, descripcion, es_activo, id_especie, id_variable_ambiental, id_usuario) VALUES
('Temperatura óptima tilapia',       '°C',   'Rango térmico ideal para crecimiento de tilapia nilótica.',         true, 1, 1, 1),
('pH óptimo tilapia',                'pH',   'Rango de pH adecuado para metabolismo y bienestar de la tilapia.',  true, 1, 2, 1),
('Oxígeno disuelto tilapia',         'mg/L', 'Nivel mínimo y óptimo de OD para tilapia en engorde.',              true, 1, 3, 1),
('Temperatura óptima trucha',        '°C',   'Rango térmico crítico para trucha arcoíris. Sensible al calor.',    true, 2, 1, 1),
('pH óptimo trucha',                 'pH',   'Rango de pH requerido para trucha en sistemas de agua fría.',       true, 2, 2, 1),
('Oxígeno disuelto trucha',          'mg/L', 'Trucha requiere altos niveles de OD por su alta tasa metabólica.',  true, 2, 3, 1),
('Temperatura óptima camarón',       '°C',   'Rango térmico para camarón blanco en sistemas marinos.',            true, 3, 1, 1),
('Salinidad óptima camarón',         'ppt',  'Rango de salinidad adecuado para camarón blanco.',                  true, 3, 6, 1),
('Amoniaco máximo camarón',          'mg/L', 'Límite máximo de amoniaco total tolerable para camarón.',           true, 3, 4, 1),
('Temperatura óptima cachama',       '°C',   'Rango térmico óptimo para cachama blanca en estanques.',            true, 4, 1, 1),
('Oxígeno disuelto cachama',         'mg/L', 'Nivel mínimo de OD para cachama en sistema extensivo.',             true, 4, 3, 1),
('Temperatura óptima mojarra',       '°C',   'Rango térmico para mojarra plateada en policultivos.',              true, 5, 1, 1),
('pH óptimo mojarra',                'pH',   'Rango de pH tolerable para mojarra en estanques de tierra.',        true, 5, 2, 1);
 
-- ============================================================
-- 11. NIVELES_ALERTA_AMBIENTALES
-- ============================================================
INSERT INTO modulo9.niveles_alerta_ambientales (id_umbral_ambiental, nivel, limite_inferior, limite_superior) VALUES
-- Temperatura tilapia (umbral 1)
(1, 'NORMAL',    25, 30),
(1, 'PRECAUCION',20, 25),
(1, 'CRITICO',   0,  20),
-- pH tilapia (umbral 2)
(2, 'NORMAL',    6,  8),
(2, 'PRECAUCION',5,  6),
(2, 'CRITICO',   0,  5),
-- OD tilapia (umbral 3)
(3, 'NORMAL',    5,  12),
(3, 'PRECAUCION',3,  5),
(3, 'CRITICO',   0,  3),
-- Temperatura trucha (umbral 4)
(4, 'NORMAL',    12, 18),
(4, 'PRECAUCION',8,  12),
(4, 'CRITICO',   18, 25),
-- pH trucha (umbral 5)
(5, 'NORMAL',    6,  8),
(5, 'PRECAUCION',5,  6),
(5, 'CRITICO',   0,  5),
-- OD trucha (umbral 6)
(6, 'NORMAL',    8,  14),
(6, 'PRECAUCION',6,  8),
(6, 'CRITICO',   0,  6),
-- Temperatura camarón (umbral 7)
(7, 'NORMAL',    23, 30),
(7, 'PRECAUCION',20, 23),
(7, 'CRITICO',   0,  20),
-- Salinidad camarón (umbral 8)
(8, 'NORMAL',    10, 25),
(8, 'PRECAUCION',5,  10),
(8, 'CRITICO',   0,  5),
-- Amoniaco camarón (umbral 9)
(9, 'NORMAL',    0,  1),
(9, 'PRECAUCION',1,  2),
(9, 'CRITICO',   2,  10),
-- Temperatura cachama (umbral 10)
(10,'NORMAL',    26, 32),
(10,'PRECAUCION',22, 26),
(10,'CRITICO',   0,  22),
-- OD cachama (umbral 11)
(11,'NORMAL',    4,  12),
(11,'PRECAUCION',2,  4),
(11,'CRITICO',   0,  2),
-- Temperatura mojarra (umbral 12)
(12,'NORMAL',    24, 30),
(12,'PRECAUCION',20, 24),
(12,'CRITICO',   0,  20),
-- pH mojarra (umbral 13)
(13,'NORMAL',    6,  9),
(13,'PRECAUCION',5,  6),
(13,'CRITICO',   0,  5);
 
-- ============================================================
-- 12. FINCA
-- (id_usuario = 2 asumiendo usuario con rol Productor existente)
-- ============================================================
INSERT INTO modulo9.finca (nombre, ubicacion, tamano_h, fecha_actualizacion, fecha_creacion, id_usuario, es_activo) VALUES
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
 
-- ============================================================
-- 13. INFRAESTRUCTURAS
-- ============================================================
INSERT INTO modulo9.infraestructuras (descripcion, nombre, id_finca, superfice, es_activo, tipo) VALUES
('Estanque principal de engorde de tilapia con aireación artificial',        'Estanque-01',    1, 2500.00, true,  'ESTANQUE'),
('Estanque secundario para fase juvenil de tilapia',                         'Estanque-02',    1, 1800.00, true,  'ESTANQUE'),
('Área de alevinaje y larvicultura de tilapia',                              'Alevinera-01',   1,  500.00, true,  'ESTANQUE'),
('Estanque de trucha arcoíris con flujo de agua continuo',                   'Canal-Trucha-01',2, 1200.00, true,  'CANAL'),
('Estanque de engorde de trucha con alta oxigenación',                       'Canal-Trucha-02',2, 1200.00, true,  'CANAL'),
('Estanque de engorde de camarón blanco con recirculación parcial',          'Piscina-Cam-01', 3, 5000.00, true,  'ESTANQUE'),
('Piscina de reserva y aclimatación de postlarvas de camarón',               'Piscina-Cam-02', 3, 3000.00, true,  'ESTANQUE'),
('Estanque de cachama en sistema semi-intensivo',                            'Estanque-Cache-01',4,3200.00,true,  'ESTANQUE'),
('Estanque de mojarra en policultivo',                                       'Estanque-Moj-01',4, 2800.00, true,  'ESTANQUE');
 
-- ============================================================
-- 14. DISPOSITIVOS_IOT
-- ============================================================
INSERT INTO modulo9.dispositivos_iot (serial, descripcion, id_infraestructura, es_activo, fecha_creacion) VALUES
('IOT-EST01-HLA-001', 'Nodo IoT principal estanque 01, gateway LoRaWAN con batería solar',      1, true, NOW()),
('IOT-EST02-HLA-002', 'Nodo IoT estanque 02, módulo WiFi con fuente de red',                   2, true, NOW()),
('IOT-ALE01-HLA-003', 'Nodo IoT alevinera, módulo compacto de bajo consumo',                   3, true, NOW()),
('IOT-TRU01-VLC-001', 'Nodo IoT canal trucha 01, resistente a bajas temperaturas',             4, true, NOW()),
('IOT-TRU02-VLC-002', 'Nodo IoT canal trucha 02, con alarma local integrada',                  5, true, NOW()),
('IOT-CAM01-COR-001', 'Nodo IoT piscina camarón 01, gateway LoRaWAN costero',                  6, true, NOW()),
('IOT-CAM02-COR-002', 'Nodo IoT piscina camarón 02, módulo de respaldo',                       7, true, NOW()),
('IOT-CAC01-CAL-001', 'Nodo IoT estanque cachama, módulo estándar de campo',                   8, true, NOW()),
('IOT-MOJ01-CAL-002', 'Nodo IoT estanque mojarra, módulo estándar de campo',                   9, true, NOW());
 
-- ============================================================
-- 15. SESNSORES (nombre tal cual en el DDL)
-- ============================================================
INSERT INTO modulo9.sesnsores (id_dispositivo_iot, es_activo, nombre) VALUES
(1, true,  'Sensor temperatura estanque-01'),
(1, true,  'Sensor pH estanque-01'),
(1, true,  'Sensor oxígeno disuelto estanque-01'),
(2, true,  'Sensor temperatura estanque-02'),
(2, true,  'Sensor pH estanque-02'),
(3, true,  'Sensor temperatura alevinera-01'),
(3, true,  'Sensor oxígeno disuelto alevinera-01'),
(4, true,  'Sensor temperatura canal-trucha-01'),
(4, true,  'Sensor oxígeno disuelto canal-trucha-01'),
(5, true,  'Sensor temperatura canal-trucha-02'),
(5, true,  'Sensor pH canal-trucha-02'),
(6, true,  'Sensor temperatura piscina-cam-01'),
(6, true,  'Sensor salinidad piscina-cam-01'),
(6, true,  'Sensor amoniaco piscina-cam-01'),
(7, true,  'Sensor temperatura piscina-cam-02'),
(7, true,  'Sensor salinidad piscina-cam-02'),
(8, true,  'Sensor temperatura estanque-cache-01'),
(8, true,  'Sensor oxígeno disuelto estanque-cache-01'),
(9, true,  'Sensor temperatura estanque-moj-01'),
(9, true,  'Sensor pH estanque-moj-01');
 
-- ============================================================
-- 16. SENSORES_AREAS_ASOCIDAS (nombre tal cual en el DDL)
-- ============================================================
INSERT INTO modulo9.sensores_areas_asocidas
(id_sensor, id_dispositivo_iot, id_infraestructura, punto_instalacion, tiene_estado, fecha_asociacion, fecha_finalizacion, id_usuario) VALUES
(1,  1, 1, 'Entrada de agua, profundidad 30cm',        true, NOW(), NULL, 2),
(2,  1, 1, 'Centro del estanque, profundidad 50cm',    true, NOW(), NULL, 2),
(3,  1, 1, 'Salida de agua, profundidad 40cm',         true, NOW(), NULL, 2),
(4,  2, 2, 'Entrada de agua, profundidad 30cm',        true, NOW(), NULL, 2),
(5,  2, 2, 'Centro del estanque, profundidad 40cm',    true, NOW(), NULL, 2),
(6,  3, 3, 'Zona de incubación, profundidad 15cm',     true, NOW(), NULL, 2),
(7,  3, 3, 'Zona de alevinaje, profundidad 20cm',      true, NOW(), NULL, 2),
(8,  4, 4, 'Entrada canal, profundidad 20cm',          true, NOW(), NULL, 2),
(9,  4, 4, 'Mitad del canal, profundidad 25cm',        true, NOW(), NULL, 2),
(10, 5, 5, 'Entrada canal trucha 02',                  true, NOW(), NULL, 2),
(11, 5, 5, 'Centro canal trucha 02',                   true, NOW(), NULL, 2),
(12, 6, 6, 'Zona sur piscina, profundidad 60cm',       true, NOW(), NULL, 2),
(13, 6, 6, 'Zona norte piscina, profundidad 50cm',     true, NOW(), NULL, 2),
(14, 6, 6, 'Punto de aireación central',               true, NOW(), NULL, 2),
(15, 7, 7, 'Zona de aclimatación, profundidad 40cm',   true, NOW(), NULL, 2),
(16, 7, 7, 'Centro piscina reserva',                   true, NOW(), NULL, 2),
(17, 8, 8, 'Entrada agua estanque cachama',            true, NOW(), NULL, 2),
(18, 8, 8, 'Centro estanque cachama, profundidad 60cm',true, NOW(), NULL, 2),
(19, 9, 9, 'Entrada agua estanque mojarra',            true, NOW(), NULL, 2),
(20, 9, 9, 'Centro estanque mojarra',                  true, NOW(), NULL, 2);
 
-- ============================================================
-- 17. CONFIGURACIONES_REMOTAS
-- ============================================================
INSERT INTO modulo9.configuraciones_remotas (frecuencia_captura, intervalo_transmision, id_dispositivo_iot) VALUES
(30,  300,  1),
(30,  300,  2),
(60,  600,  3),
(30,  300,  4),
(30,  300,  5),
(15,  180,  6),
(15,  180,  7),
(60,  600,  8),
(60,  600,  9);
 
-- ============================================================
-- 18. CONFIGURACIONES_GLOBALES
-- (id_usuario = 1 asumiendo admin existente)
-- ============================================================
INSERT INTO modulo9.configuraciones_globales (frecuencia_muestreo, hearbeat, fecha_actulizacion, id_usuario, es_activo) VALUES
(60,  120, NOW(), 1, true);
 
-- ============================================================
-- 19. CALIBRACIONES
-- ============================================================
INSERT INTO public.calibraciones (id_dispositivo_iot, fecha_calibracion, id_sensor, valor_referencia, observaciones, id_usuario) VALUES
(1, NOW() - INTERVAL '30 days', 1,  25.0, 'Calibración inicial con termómetro patrón certificado NIST.',   1),
(1, NOW() - INTERVAL '30 days', 2,   7.0, 'Calibración con buffer pH 7.0 y 4.0. Electrodo en buen estado.',1),
(1, NOW() - INTERVAL '30 days', 3,   8.5, 'Calibración con solución saturada. Membrana nueva.',             1),
(4, NOW() - INTERVAL '15 days', 8,  14.0, 'Calibración con termómetro de referencia para agua fría.',       1),
(4, NOW() - INTERVAL '15 days', 9,  10.0, 'OD calibrado al 100% de saturación a 14°C.',                    1),
(6, NOW() - INTERVAL '7 days',  12, 27.0, 'Calibración post-instalación sistema costero.',                  1),
(6, NOW() - INTERVAL '7 days',  13, 15.0, 'Calibración salinidad con refractómetro de referencia.',         1);
 
-- ============================================================
-- 20. GESTION_ESPECIES
-- (id_usuario = 1 asumiendo admin existente)
-- ============================================================
INSERT INTO modulo9.gestion_especies (id_usuario, id_especie, fecha_gestion, id_umbral_ambiental) VALUES
(1, 1,  NOW() - INTERVAL '60 days', 1),
(1, 1,  NOW() - INTERVAL '60 days', 2),
(1, 1,  NOW() - INTERVAL '60 days', 3),
(1, 2,  NOW() - INTERVAL '55 days', 4),
(1, 2,  NOW() - INTERVAL '55 days', 5),
(1, 2,  NOW() - INTERVAL '55 days', 6),
(1, 3,  NOW() - INTERVAL '45 days', 7),
(1, 3,  NOW() - INTERVAL '45 days', 8),
(1, 3,  NOW() - INTERVAL '45 days', 9),
(1, 4,  NOW() - INTERVAL '30 days', 10),
(1, 4,  NOW() - INTERVAL '30 days', 11),
(1, 5,  NOW() - INTERVAL '20 days', 12),
(1, 5,  NOW() - INTERVAL '20 days', 13);
 
-- ============================================================
-- 21. IDENTIDAD_VISUALES
-- ============================================================
INSERT INTO modulo9.identidad_visuales (id_finca, id_usuario, logo_path, primary_color, org_display_name, version, fecha_creacion) VALUES
(1, 1, '/assets/logos/remanso.png',    '#1A6B3C', 'Acuícola El Remanso',    1, NOW()),
(2, 1, '/assets/logos/esteros.png',    '#0D4E8A', 'Piscícola Los Esteros',  1, NOW()),
(3, 1, '/assets/logos/costaazul.png',  '#007B8A', 'Camaronera Costa Azul',  1, NOW()),
(4, 1, '/assets/logos/esperanza.png',  '#4A7C2F', 'Granja La Esperanza',    1, NOW());
 
-- ============================================================
-- 22. TEMAS_VISUALES
-- (id_user tal cual en el DDL)
-- ============================================================
INSERT INTO modulo9.temas_visuales (id_user, theme_mode, es_global, fecha_actualizacion) VALUES
(1, 1, true,  NOW()),  -- Admin: claro, global
(2, 2, false, NOW()),  -- Productor: oscuro, personal
(3, 3, false, NOW()),  -- Usuario 3: automático, personal
(4, 1, false, NOW());  -- Usuario 4: claro, personal
 
-- ============================================================
-- 23. DASHBOARD_LAYOUTS
-- (id_user tal cual en el DDL)
-- ============================================================
INSERT INTO modulo9.dashboard_layouts (id_user, config, active_widget, fecha_actualizacion) VALUES
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
 
-- ============================================================
-- 24. PREFERENCIAS_IDIOMAS
-- (id_ususario tal cual en el DDL)
-- ============================================================
INSERT INTO modulo9.preferencias_idiomas (id_ususario, local_code, es_por_defecto, fecha_actulizacion) VALUES
(1, 'es-CO', true,  NOW()),
(2, 'es-CO', false, NOW()),
(3, 'en-US', false, NOW()),
(4, 'es-CO', false, NOW());
 
-- ============================================================
-- 25. AUDITORIAS_VISUALES
-- ============================================================
INSERT INTO modulo9.auditorias_visuales (id_usuario, fecha_creacion, valor_anterior, valor_nuevo) VALUES
(1, NOW() - INTERVAL '10 days',
 '{"primary_color": "#2A7AE4", "org_display_name": "El Remanso"}',
 '{"primary_color": "#1A6B3C", "org_display_name": "Acuícola El Remanso"}'),
 
(1, NOW() - INTERVAL '5 days',
 '{"theme_mode": 3}',
 '{"theme_mode": 1}'),
 
(1, NOW() - INTERVAL '2 days',
 '{"active_widget": ["temperatura", "ph"]}',
 '{"active_widget": ["temperatura", "ph", "oxigeno", "alertas", "dispositivos"]}');
 
-- ============================================================
-- 26. PLATILLAS (nombre tal cual en el DDL)
-- ============================================================
INSERT INTO modulo9.platillas (id_especie, id_usuario, template_name, params_snapshot, version, fecha_creacion) VALUES
(1, 1,
 'Plantilla estándar tilapia',
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
 
(2, 1,
 'Plantilla estándar trucha',
 '{
   "umbrales": [
     {"id": 4, "nombre": "Temperatura óptima trucha",  "min": 12, "max": 18},
     {"id": 5, "nombre": "pH óptimo trucha",           "min": 6,  "max": 8},
     {"id": 6, "nombre": "Oxígeno disuelto trucha",    "min": 8,  "max": 14}
   ],
   "ciclos_biologicos": [4, 5, 6],
   "metricas": [1, 2, 3, 4, 6, 8]
 }',
 1, NOW()),
 
(3, 1,
 'Plantilla estándar camarón',
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
 
-- ============================================================
-- 27. APLICACIONES_PLANTILLAS
-- ============================================================
INSERT INTO modulo9.aplicaciones_plantillas (id_usuario, id_plantilla, target_config, before_snapshot, after_snapshot, fecha_aplicacion) VALUES
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
     {"id": 4, "nombre": "Temperatura óptima trucha",  "min": 12, "max": 18},
     {"id": 5, "nombre": "pH óptimo trucha",           "min": 6,  "max": 8},
     {"id": 6, "nombre": "Oxígeno disuelto trucha",    "min": 8,  "max": 14}
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