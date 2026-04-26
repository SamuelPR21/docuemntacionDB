-- ================================================================
-- CONSTRAINTS MÓDULO 9
-- ================================================================
-- CRITERIO DE INCLUSIÓN:
--   Solo se declaran aquí los constraints que NO existen ya en el
--   backup (backup2_1_0.sql). Los ya presentes en el backup son:
--     PKs: todas las tablas del módulo 9
--     UQ:  uq_especie_nombre, uq_infraestructura_nombre (nombre, id_finca),
--           uq_umbral_ambiental_nombre, uq_variable_ambiental_nombre
--     FKs: ciclos_biologicos_id_especie_fkey,
--           ciclos_productivos_biologicos_* (x2),
--           configuraciones_remotas_id_dispositivo_iot_fkey,
--           dispositivos_iot_id_infraestructura_fkey,
--           especies_patologias_* (x2), gestion_especies_* (x4),
--           identidad_visuales_id_finca_fkey,
--           infraestructuras_id_finca_fkey,
--           metricas_ciclo_productivo_* (x2),
--           plantillas_id_especie_fkey,
--           sensores_areas_asociadas_* (x3),
--           sensores_id_dispositivo_iot_fkey,
--           calibraciones_id_dispositivo_iot_fkey,
--           calibraciones_id_sensor_fkey,
--           aplicaciones_plantillas_id_plantilla_fkey
--     CHK: configuraciones_remotas_estado_check
--           → estado IN ('PENDIENTE','APLICADA','CANCELADA')
--
--   Se AGREGAN:
--     FK: umbrales_ambientales → variables_ambientales (faltante en backup)
--         umbrales_ambientales → especies (faltante en backup)
--         niveles_alerta_ambientales → umbrales_ambientales (faltante)
--         fincas → usuarios (faltante en backup)
--         configuraciones_globales → usuarios (faltante en backup)
--         ciclos_productivos → ciclos_biologicos (faltante)
--         sensores_areas_asociadas → usuarios (faltante)
--     CHK: dominio de nivel de alerta, rangos físicos variables,
--           duración ciclos, superficie infraestructura, tamaño finca,
--           frecuencia/heartbeat configuraciones, rango alertas
--     IDX parciales: umbral activo por especie+variable,
--                    sensor con una sola asociación activa,
--                    una sola configuración global activa
-- ================================================================

-- ----------------------------------------------------------------
-- 1. CLAVES FORÁNEAS FALTANTES EN EL BACKUP
-- ----------------------------------------------------------------

-- [RF-17] umbrales_ambientales → variables_ambientales
--   Garantiza que solo se configuren umbrales para variables existentes
ALTER TABLE modulo9.umbrales_ambientales
    ADD CONSTRAINT fk_umbral_variable_ambiental
        FOREIGN KEY (id_variable_ambiental)
        REFERENCES modulo9.variables_ambientales (id_variable_ambiental);

-- [RF-17] umbrales_ambientales → especies
--   Garantiza que los umbrales referencien especies activas (RF-17)
ALTER TABLE modulo9.umbrales_ambientales
    ADD CONSTRAINT fk_umbral_especie
        FOREIGN KEY (id_especie)
        REFERENCES modulo9.especies (id_especie);

-- [RF-17] umbrales_ambientales → usuarios (quien configura)
ALTER TABLE modulo9.umbrales_ambientales
    ADD CONSTRAINT fk_umbral_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- [RF-17] niveles_alerta_ambientales → umbrales_ambientales
--   Cada nivel de alerta debe pertenecer a un umbral existente
ALTER TABLE modulo9.niveles_alerta_ambientales
    ADD CONSTRAINT fk_nivel_alerta_umbral
        FOREIGN KEY (id_umbral_ambiental)
        REFERENCES modulo9.umbrales_ambientales (id_umbral_ambiental);

-- [RF-19] fincas → usuarios (productor responsable)
ALTER TABLE modulo9.fincas
    ADD CONSTRAINT fk_finca_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- [RF-18] configuraciones_globales → usuarios (administrador)
ALTER TABLE modulo9.configuraciones_globales
    ADD CONSTRAINT fk_config_global_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- [RF-16] ciclos_productivos → ciclos_biologicos
--   La fase representativa del ciclo productivo debe existir
ALTER TABLE modulo9.ciclos_productivos
    ADD CONSTRAINT fk_ciclo_productivo_biologico
        FOREIGN KEY (id_ciclo_biologico)
        REFERENCES modulo9.ciclos_biologicos (id_ciclo_biologico);

-- [RF-22] sensores_areas_asociadas → usuarios (quien asocia)
ALTER TABLE modulo9.sensores_areas_asociadas
    ADD CONSTRAINT fk_sensor_area_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- [RF-21] sensores → especies (a través del dispositivo: integridad semántica)
--   El backup ya tiene sensores_id_dispositivo_iot_fkey, se completa
--   la relación identidad_visuales → usuarios faltante
ALTER TABLE modulo9.identidad_visuales
    ADD CONSTRAINT fk_identidad_visual_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- [RF-23] calibraciones → usuarios (quien calibra)
ALTER TABLE modulo9.calibraciones
    ADD CONSTRAINT fk_calibracion_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- Plantillas → usuarios (quien crea la plantilla)
ALTER TABLE modulo9.plantillas
    ADD CONSTRAINT fk_plantilla_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- Aplicaciones_plantillas → usuarios (quien aplica)
ALTER TABLE modulo9.aplicaciones_plantillas
    ADD CONSTRAINT fk_aplicacion_plantilla_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- Gestion_especies → usuarios (quien gestiona)
--   El backup tiene gestion_especies_id_especie_fkey (duplicado), pero
--   no la FK a usuarios dentro del schema modulo9
ALTER TABLE modulo9.gestion_especies
    ADD CONSTRAINT fk_gestion_especie_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);


-- ----------------------------------------------------------------
-- 2. CHECK CONSTRAINTS NUEVOS
-- ----------------------------------------------------------------

-- [RF-15] Nombre de especie: entre 3 y 50 caracteres (longitud)
--   Restricción explícita RF-15: "longitud entre 3 y 50 caracteres"
--   El backup tiene uq_especie_nombre pero no el CHECK de longitud
ALTER TABLE modulo9.especies
    ADD CONSTRAINT chk_especie_nombre_longitud
        CHECK (char_length(trim(nombre)) BETWEEN 3 AND 50);

-- [RF-16] Duración de ciclo biológico: entero positivo mayor a 0
--   Restricción explícita RF-16: "duración debe ser un número entero positivo mayor a 0"
ALTER TABLE modulo9.ciclos_biologicos
    ADD CONSTRAINT chk_ciclo_biologico_duracion_positiva
        CHECK (duracion_dias > 0);

-- [RF-17] Variable ambiental: límite físico mínimo < máximo
--   Restricción explícita RF-17: "Los valores mínimos deben ser estrictamente menores que los máximos"
ALTER TABLE modulo9.variables_ambientales
    ADD CONSTRAINT chk_variable_rango_fisico_coherente
        CHECK (valor_fisico_min < valor_fisico_max);

-- [RF-17] Variable ambiental: límite físico mínimo no negativo
ALTER TABLE modulo9.variables_ambientales
    ADD CONSTRAINT chk_variable_min_no_negativo
        CHECK (valor_fisico_min >= 0);

-- [RF-17] Nivel de alerta: dominio del campo nivel (semaforización)
--   Restricción explícita RF-17: "normal (verde), precaucion (amarillo), critico (rojo)"
--   El backup NO tiene este CHECK; solo existe la PK
ALTER TABLE modulo9.niveles_alerta_ambientales
    ADD CONSTRAINT chk_nivel_alerta_dominio
        CHECK (nivel IN ('normal', 'precaucion', 'critico'));

-- [RF-17] Nivel de alerta: limite_inferior < limite_superior
--   Garantiza que cada banda del semáforo sea un rango válido
ALTER TABLE modulo9.niveles_alerta_ambientales
    ADD CONSTRAINT chk_nivel_alerta_rango_coherente
        CHECK (limite_inferior < limite_superior);

-- [RF-20] Superficie del área productiva: debe ser positiva
--   Restricción explícita RF-20: "superficie debe ser un valor numérico positivo"
ALTER TABLE modulo9.infraestructuras
    ADD CONSTRAINT chk_infraestructura_superficie_positiva
        CHECK (superficie > 0);

-- [RF-19] Tamaño de finca: mayor a cero
--   Restricción explícita RF-19: "El tamaño de la finca debe ser mayor a cero"
ALTER TABLE modulo9.fincas
    ADD CONSTRAINT chk_finca_tamano_positivo
        CHECK (tamano_h > 0);

-- [RF-23] Configuración remota: frecuencia de captura positiva (segundos)
--   El backup tiene configuraciones_remotas_estado_check para el enum estado,
--   pero no valida los valores numéricos
ALTER TABLE modulo9.configuraciones_remotas
    ADD CONSTRAINT chk_conf_remota_frecuencia_positiva
        CHECK (frecuencia_captura > 0);

-- [RF-23] Configuración remota: intervalo de transmisión positivo (segundos)
ALTER TABLE modulo9.configuraciones_remotas
    ADD CONSTRAINT chk_conf_remota_intervalo_positivo
        CHECK (intervalo_transmision > 0);

-- [RF-23] Intervalo de transmisión >= frecuencia de captura
--   No tiene sentido transmitir con mayor frecuencia de la que se captura
ALTER TABLE modulo9.configuraciones_remotas
    ADD CONSTRAINT chk_conf_remota_intervalo_ge_frecuencia
        CHECK (intervalo_transmision >= frecuencia_captura);

-- [RF-18] Configuración global: frecuencia_muestreo positiva (minutos)
--   Restricción explícita RF-18: "valores enteros positivos"
ALTER TABLE modulo9.configuraciones_globales
    ADD CONSTRAINT chk_conf_global_frecuencia_positiva
        CHECK (frecuencia_muestreo > 0);

-- [RF-18] Configuración global: heartbeat >= frecuencia_muestreo
--   Restricción explícita RF-18: "heartbeat debe ser mayor o igual a la frecuencia de muestreo"
ALTER TABLE modulo9.configuraciones_globales
    ADD CONSTRAINT chk_conf_global_heartbeat_ge_frecuencia
        CHECK (heartbeat >= frecuencia_muestreo);

-- [RF-16] Nombre de ciclo biológico: entre 3 y 100 caracteres
ALTER TABLE modulo9.ciclos_biologicos
    ADD CONSTRAINT chk_ciclo_biologico_nombre_longitud
        CHECK (char_length(trim(nombre)) BETWEEN 3 AND 100);

-- [RF-16] Nombre de patología: entre 3 y 100 caracteres
--   Restricción explícita RF-16: "longitud entre 3 y 100 caracteres para patologías"
ALTER TABLE modulo9.patologias
    ADD CONSTRAINT chk_patologia_nombre_longitud
        CHECK (char_length(trim(nombre)) BETWEEN 3 AND 100);


-- ----------------------------------------------------------------
-- 3. ÍNDICES ÚNICOS PARCIALES (NUEVOS)
-- ----------------------------------------------------------------

-- [RF-18] Solo puede existir UNA configuración global activa
--   Restricción explícita RF-18: "No se permite la existencia de múltiples
--   configuraciones activas simultáneamente"
CREATE UNIQUE INDEX IF NOT EXISTS uix_conf_global_unica_activa
    ON modulo9.configuraciones_globales (es_activo)
    WHERE es_activo = TRUE;

-- [RF-22] Un sensor solo puede tener UNA asociación activa a la vez
--   Restricción explícita RF-22: "Un sensor solo puede estar asociado a
--   una única área productiva activa a la vez"
CREATE UNIQUE INDEX IF NOT EXISTS uix_sensor_asociacion_activa
    ON modulo9.sensores_areas_asociadas (id_sensor)
    WHERE tiene_estado = TRUE;

-- [RF-17] Solo puede existir UN umbral activo por especie + variable ambiental
--   Restricción explícita RF-17: "No se permitirá la existencia de múltiples
--   configuraciones activas para la misma combinación de especie y variable"
CREATE UNIQUE INDEX IF NOT EXISTS uix_umbral_activo_especie_variable
    ON modulo9.umbrales_ambientales (id_especie, id_variable_ambiental)
    WHERE es_activo = TRUE;


-- ================================================================
-- NOTA SOBRE CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (listados para referencia)
-- ================================================================
--
-- Claves Primarias (ya en backup — todas las tablas del módulo 9):
--   aplicaciones_plantillas_pkey, calibraciones_pkey,
--   ciclos_biologicos_pkey, ciclos_productivos_biologicos_pkey,
--   ciclos_productivos_pkey, configuraciones_globales_pkey,
--   configuraciones_remotas_pkey, dashboard_layouts_pkey,
--   dispositivos_iot_pkey, especies_patologias_pkey, especies_pkey,
--   finca_pkey (renombrada a fincas), gestion_especies_pkey,
--   identidad_visuales_pkey, infraestructuras_pkey,
--   metricas_ciclo_productivo_pkey, metricas_produccion_pkey,
--   niveles_alerta_ambientales_pkey, patologias_pkey,
--   plantillas_pkey, preferencias_idiomas_pkey,
--   sensores_areas_asociadas_pkey, sensores_pkey,
--   temas_visuales_pkey, umbrales_ambientales_pkey,
--   variables_ambientales_pkey
--
-- Claves Únicas (ya en backup):
--   uq_especie_nombre           → UNIQUE (nombre)
--   uq_infraestructura_nombre   → UNIQUE (nombre, id_finca)
--   uq_umbral_ambiental_nombre  → UNIQUE (nombre)
--   uq_variable_ambiental_nombre → UNIQUE (nombre)
--
-- Claves Foráneas (ya en backup — selección relevante):
--   ciclos_biologicos_id_especie_fkey
--   ciclos_productivos_biologicos_id_ciclo_biologico_fkey
--   ciclos_productivos_biologicos_id_ciclo_productivo_fkey
--   configuraciones_remotas_id_dispositivo_iot_fkey
--   dispositivos_iot_id_infraestructura_fkey
--   especies_patologias_id_especie_fkey
--   especies_patologias_id_patologia_fkey
--   gestion_especies_id_especie_fkey / fkey1
--   gestion_especies_id_umbral_ambiental_fkey / fkey1
--   identidad_visuales_id_finca_fkey
--   infraestructuras_id_finca_fkey
--   metricas_ciclo_productivo_id_ciclo_productivo_fkey
--   metricas_ciclo_productivo_id_metrica_produccion_fkey (fk_evento_metrica)
--   plantillas_id_especie_fkey
--   sensores_areas_asociadas_id_dispositivo_iot_fkey
--   sensores_areas_asociadas_id_infraestructura_fkey
--   sensores_areas_asociadas_id_sensor_fkey
--   sensores_id_dispositivo_iot_fkey
--   calibraciones_id_dispositivo_iot_fkey
--   calibraciones_id_sensor_fkey
--   aplicaciones_plantillas_id_plantilla_fkey
--
-- CHECK Constraints (ya en backup):
--   configuraciones_remotas_estado_check
--     → estado IN ('PENDIENTE','APLICADA','CANCELADA')
-- ================================================================
