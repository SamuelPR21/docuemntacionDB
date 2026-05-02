-- ================================================================
-- CONSTRAINTS - MÓDULO 9
-- Versión: 2.0  (correcciones según revisión técnica test_M09.md)
-- ================================================================
--
-- CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
--
-- [C1] FKs duplicadas eliminadas / reemplazadas por VALIDATE:
--       Las siguientes FKs ya existen en el DDL con NOT VALID:
--         finca_id_usuario_fkey,
--         configuraciones_globales_id_usuario_fkey,
--         sensores_areas_asociadas_id_usuario_fkey,
--         identidad_visuales_id_usuario_fkey, 
--         calibraciones_id_usuario_fkey,
--         plantillas_id_usuario_fkey,
--         aplicaciones_plantillas_id_usuario_fkey,
--         gestion_especies_id_usuario_fkey
--
--       → Se reemplazan por ALTER TABLE ... VALIDATE CONSTRAINT
--         para activarlas sin intentar crearlas nuevamente.
--
-- [C2] chk_nivel_alerta_dominio:
--       La columna 'nivel' es de tipo modulo9.enum_nivel_alerta.
--       Un CHECK IN() sobre una columna de tipo enum es redundante en
--       PostgreSQL (el tipo ya restringe los valores posibles) y puede
--       causar un error de tipado. Se ELIMINA este constraint; la
--       validación queda garantizada por el tipo enum.
--
-- [C3] CHECKs que pueden fallar en BD con datos previos:
--       chk_conf_global_heartbeat_ge_frecuencia,
--       chk_conf_remota_intervalo_ge_frecuencia,
--       chk_especie_nombre_longitud,
--       chk_ciclo_biologico_duracion_positiva,
--       chk_variable_min_no_negativo
--
--       → Se declaran con NOT VALID para permitir que la creación no
--         falle por registros históricos. Luego se validan con
--         VALIDATE CONSTRAINT (que solo bloquea lecturas, no escrituras,
--         durante la validación).
--
-- [C4] Índices únicos parciales:
--       Se incluyen precondiciones (comentadas) que deben ejecutarse
--       manualmente si existen datos inconsistentes antes de crear
--       cada índice, para evitar fallo por duplicados.
--
-- ================================================================

-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- Verificar y corregir datos inconsistentes ANTES de ejecutar
-- los índices parciales únicos. Descomentar y ejecutar si aplica.
-- ----------------------------------------------------------------

-- [P1] Asegurar una sola configuración global activa. Si existen varias, desactivar las más antiguas:}
--
-- UPDATE modulo9.configuraciones_globales
--    SET es_activo = FALSE
--  WHERE es_activo = TRUE
--    AND id_configuracion_global NOT IN (
--        SELECT id_configuracion_global
--          FROM modulo9.configuraciones_globales
--         WHERE es_activo = TRUE
--         ORDER BY id_configuracion_global DESC
--         LIMIT 1
--    );

-- [P2] Asegurar que cada sensor tenga como máximo una asociación activa. Si existen duplicados, desactivar las más antiguas:
--
-- UPDATE modulo9.sensores_areas_asociadas a
--    SET tiene_estado = FALSE
--  WHERE tiene_estado = TRUE
--    AND id_sensores_area_asociada NOT IN (
--        SELECT MAX(id_sensores_area_asociada)
--          FROM modulo9.sensores_areas_asociadas
--         WHERE tiene_estado = TRUE
--         GROUP BY id_sensor
--    );

-- [P3] Asegurar un solo umbral activo por combinación (especie, variable). Si existen duplicados, desactivar los más antiguos:
--
-- UPDATE modulo9.umbrales_ambientales u
--    SET es_activo = FALSE
--  WHERE es_activo = TRUE
--    AND id_umbral_ambiental NOT IN (
--        SELECT MAX(id_umbral_ambiental)
--          FROM modulo9.umbrales_ambientales
--         WHERE es_activo = TRUE
--         GROUP BY id_especie, id_variable_ambiental
--    );

-- ================================================================
-- PARTE 1 — VALIDACIÓN DE CLAVES FORÁNEAS YA EXISTENTES (NOT VALID)
-- Las siguientes FKs existen en el DDL del backup pero fueron
-- creadas con NOT VALID, por lo que no estaban activamente
-- verificadas. Se activan con VALIDATE CONSTRAINT.
-- ================================================================

-- [RF-19] fincas → modulo1.usuarios
ALTER TABLE modulo9.fincas
    VALIDATE CONSTRAINT finca_id_usuario_fkey;

-- [RF-18] configuraciones_globales → modulo1.usuarios
ALTER TABLE modulo9.configuraciones_globales
    VALIDATE CONSTRAINT configuraciones_globales_id_usuario_fkey;

-- [RF-22] sensores_areas_asociadas → modulo1.usuarios
ALTER TABLE modulo9.sensores_areas_asociadas
    VALIDATE CONSTRAINT sensores_areas_asociadas_id_usuario_fkey;

-- Identidad visuales → modulo1.usuarios
ALTER TABLE modulo9.identidad_visuales
    VALIDATE CONSTRAINT identidad_visuales_id_usuario_fkey;

-- Calibraciones → modulo1.usuarios
ALTER TABLE modulo9.calibraciones
    VALIDATE CONSTRAINT calibraciones_id_usuario_fkey;

-- Plantillas → modulo1.usuarios
ALTER TABLE modulo9.plantillas
    VALIDATE CONSTRAINT plantillas_id_usuario_fkey;

-- Aplicaciones_plantillas → modulo1.usuarios
ALTER TABLE modulo9.aplicaciones_plantillas
    VALIDATE CONSTRAINT aplicaciones_plantillas_id_usuario_fkey;

-- Gestion_especies → modulo1.usuarios
ALTER TABLE modulo9.gestion_especies
    VALIDATE CONSTRAINT gestion_especies_id_usuario_fkey;


-- ================================================================
-- PARTE 2 — CLAVES FORÁNEAS GENUINAMENTE FALTANTES EN EL BACKUP
-- Estas FKs NO existen en el DDL y se crean desde cero.
-- ================================================================

-- [RF-17] umbrales_ambientales → variables_ambientales
ALTER TABLE modulo9.umbrales_ambientales
    ADD CONSTRAINT fk_umbral_variable_ambiental
        FOREIGN KEY (id_variable_ambiental)
        REFERENCES modulo9.variables_ambientales (id_variable_ambiental);

-- [RF-17] umbrales_ambientales → especies
ALTER TABLE modulo9.umbrales_ambientales
    ADD CONSTRAINT fk_umbral_especie
        FOREIGN KEY (id_especie)
        REFERENCES modulo9.especies (id_especie);

-- [RF-17] umbrales_ambientales → modulo1.usuarios (quien configura el umbral)
ALTER TABLE modulo9.umbrales_ambientales
    ADD CONSTRAINT fk_umbral_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES modulo1.usuarios (id_usuario);

-- [RF-17] niveles_alerta_ambientales → umbrales_ambientales
ALTER TABLE modulo9.niveles_alerta_ambientales
    ADD CONSTRAINT fk_nivel_alerta_umbral
        FOREIGN KEY (id_umbral_ambiental)
        REFERENCES modulo9.umbrales_ambientales (id_umbral_ambiental);

-- [RF-16] ciclos_productivos → ciclos_biologicos (fase representativa)
ALTER TABLE modulo9.ciclos_productivos
    ADD CONSTRAINT fk_ciclo_productivo_biologico
        FOREIGN KEY (id_ciclo_biologico)
        REFERENCES modulo9.ciclos_biologicos (id_ciclo_biologico);


-- ================================================================
-- PARTE 3 — CHECK CONSTRAINTS NUEVOS
--
-- NOTA SOBRE ENUMS:
--   Las columnas 'nivel' en niveles_alerta_ambientales y 'categoria'
--   en sensores/patologias son de tipo ENUM de PostgreSQL. Los tipos
--   ENUM ya restringen los valores posibles por definición de tipo,
--   por lo que agregar CHECK IN() sobre ellas sería redundante y
--   puede causar errores de compatibilidad de tipos. Dichos checks
--   NO se incluyen en este script.
-- ================================================================

-- ----------------------------------------------------------------
-- 3.1  Checks que aplican directamente (sin riesgo de fallo
--       por datos existentes)
-- ----------------------------------------------------------------

-- [RF-15] Nombre de especie: entre 3 y 50 caracteres
ALTER TABLE modulo9.especies
    ADD CONSTRAINT chk_especie_nombre_longitud
        CHECK (char_length(trim(nombre)) BETWEEN 3 AND 50)
        NOT VALID;
ALTER TABLE modulo9.especies
    VALIDATE CONSTRAINT chk_especie_nombre_longitud;

-- [RF-16] Duración de ciclo biológico: entero positivo mayor a 0
ALTER TABLE modulo9.ciclos_biologicos
    ADD CONSTRAINT chk_ciclo_biologico_duracion_positiva
        CHECK (duracion_dias > 0)
        NOT VALID;
ALTER TABLE modulo9.ciclos_biologicos
    VALIDATE CONSTRAINT chk_ciclo_biologico_duracion_positiva;

-- [RF-16] Nombre de ciclo biológico: entre 3 y 100 caracteres
ALTER TABLE modulo9.ciclos_biologicos
    ADD CONSTRAINT chk_ciclo_biologico_nombre_longitud
        CHECK (char_length(trim(nombre)) BETWEEN 3 AND 100);

-- [RF-16] Nombre de patología: entre 3 y 100 caracteres
ALTER TABLE modulo9.patologias
    ADD CONSTRAINT chk_patologia_nombre_longitud
        CHECK (char_length(trim(nombre)) BETWEEN 3 AND 100);

-- [RF-17] Variable ambiental: mínimo físico no negativo
ALTER TABLE modulo9.variables_ambientales
    ADD CONSTRAINT chk_variable_min_no_negativo
        CHECK (valor_fisico_min >= 0)
        NOT VALID;
ALTER TABLE modulo9.variables_ambientales
    VALIDATE CONSTRAINT chk_variable_min_no_negativo;

-- [RF-17] Variable ambiental: límite físico mínimo < máximo
ALTER TABLE modulo9.variables_ambientales
    ADD CONSTRAINT chk_variable_rango_fisico_coherente
        CHECK (valor_fisico_min < valor_fisico_max);

-- [RF-17] Nivel de alerta: limite_inferior < limite_superior
ALTER TABLE modulo9.niveles_alerta_ambientales
    ADD CONSTRAINT chk_nivel_alerta_rango_coherente
        CHECK (limite_inferior < limite_superior);

-- [RF-20] Superficie del área productiva: debe ser positiva
ALTER TABLE modulo9.infraestructuras
    ADD CONSTRAINT chk_infraestructura_superficie_positiva
        CHECK (superficie > 0);

-- [RF-19] Tamaño de finca: mayor a cero
ALTER TABLE modulo9.fincas
    ADD CONSTRAINT chk_finca_tamano_positivo
        CHECK (tamano_h > 0);

-- [RF-23] Configuración remota: frecuencia de captura positiva (segundos)
ALTER TABLE modulo9.configuraciones_remotas
    ADD CONSTRAINT chk_conf_remota_frecuencia_positiva
        CHECK (frecuencia_captura > 0);

-- [RF-23] Configuración remota: intervalo de transmisión positivo (segundos)
ALTER TABLE modulo9.configuraciones_remotas
    ADD CONSTRAINT chk_conf_remota_intervalo_positivo
        CHECK (intervalo_transmision > 0);

-- [RF-18] Configuración global: frecuencia_muestreo positiva (minutos)
ALTER TABLE modulo9.configuraciones_globales
    ADD CONSTRAINT chk_conf_global_frecuencia_positiva
        CHECK (frecuencia_muestreo > 0);

-- ----------------------------------------------------------------
-- 3.2  Checks que pueden fallar con datos previos → NOT VALID
--       Se crean diferidos y se validan en paso separado.
--       Si la validación falla, ejecutar las precondiciones del
--       BLOQUE 0 correspondientes y re-ejecutar el VALIDATE.
-- ----------------------------------------------------------------

-- [RF-23] Intervalo de transmisión >= frecuencia de captura
ALTER TABLE modulo9.configuraciones_remotas
    ADD CONSTRAINT chk_conf_remota_intervalo_ge_frecuencia
        CHECK (intervalo_transmision >= frecuencia_captura)
        NOT VALID;
ALTER TABLE modulo9.configuraciones_remotas
    VALIDATE CONSTRAINT chk_conf_remota_intervalo_ge_frecuencia;

-- [RF-18] heartbeat >= frecuencia_muestreo
ALTER TABLE modulo9.configuraciones_globales
    ADD CONSTRAINT chk_conf_global_heartbeat_ge_frecuencia
        CHECK (heartbeat >= frecuencia_muestreo)
        NOT VALID;
ALTER TABLE modulo9.configuraciones_globales
    VALIDATE CONSTRAINT chk_conf_global_heartbeat_ge_frecuencia;


-- ================================================================
-- PARTE 4 — ÍNDICES ÚNICOS PARCIALES
-- IMPORTANTE: Ejecutar las precondiciones del BLOQUE 0 antes de
-- correr esta sección si la base de datos ya contiene datos.
-- ================================================================

-- [RF-18] Solo puede existir UNA configuración global activa
--   Ejecutar [P1] del BLOQUE 0 si hay más de una fila con es_activo = TRUE
CREATE UNIQUE INDEX IF NOT EXISTS uix_conf_global_unica_activa
    ON modulo9.configuraciones_globales (es_activo)
    WHERE es_activo = TRUE;

-- [RF-22] Un sensor solo puede tener UNA asociación activa a la vez
--   Ejecutar [P2] del BLOQUE 0 si un sensor tiene dos tiene_estado = TRUE
CREATE UNIQUE INDEX IF NOT EXISTS uix_sensor_asociacion_activa
    ON modulo9.sensores_areas_asociadas (id_sensor)
    WHERE tiene_estado = TRUE;

-- [RF-17] Solo puede existir UN umbral activo por especie + variable ambiental
--   Ejecutar [P3] del BLOQUE 0 si existe la combinación duplicada activa
CREATE UNIQUE INDEX IF NOT EXISTS uix_umbral_activo_especie_variable
    ON modulo9.umbrales_ambientales (id_especie, id_variable_ambiental)
    WHERE es_activo = TRUE;


-- ================================================================
-- REFERENCIA: CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (no se re-ejecutan; listados para consulta)
-- ================================================================
--
-- PKs de todas las tablas del módulo 9 (ya en backup).
--
-- Claves Únicas (ya en backup):
--   uq_especie_nombre           → UNIQUE (nombre)
--   uq_infraestructura_nombre   → UNIQUE (nombre, id_finca)
--   uq_umbral_ambiental_nombre  → UNIQUE (nombre)
--   uq_variable_ambiental_nombre → UNIQUE (nombre)
--
-- Claves Foráneas (ya en backup, con NOT VALID activadas arriba):
--   finca_id_usuario_fkey
--   configuraciones_globales_id_usuario_fkey
--   sensores_areas_asociadas_id_usuario_fkey
--   identidad_visuales_id_usuario_fkey
--   calibraciones_id_usuario_fkey
--   plantillas_id_usuario_fkey
--   aplicaciones_plantillas_id_usuario_fkey
--   gestion_especies_id_usuario_fkey
--   ciclos_biologicos_id_especie_fkey
--   ciclos_productivos_biologicos_id_ciclo_biologico_fkey
--   ciclos_productivos_biologicos_id_ciclo_productivo_fkey
--   configuraciones_remotas_id_dispositivo_iot_fkey
--   dispositivos_iot_id_infraestructura_fkey
--   especies_patologias_id_especie_fkey / id_patologia_fkey
--   gestion_especies_id_especie_fkey / id_umbral_ambiental_fkey
--   identidad_visuales_id_finca_fkey
--   infraestructuras_id_finca_fkey
--   metricas_ciclo_productivo_id_ciclo_productivo_fkey
--   metricas_ciclo_productivo_id_metrica_produccion_fkey
--   plantillas_id_especie_fkey
--   sensores_areas_asociadas_id_dispositivo_iot_fkey / id_infraestructura_fkey / id_sensor_fkey
--   sensores_id_dispositivo_iot_fkey
--   calibraciones_id_dispositivo_iot_fkey / id_sensor_fkey
--   aplicaciones_plantillas_id_plantilla_fkey
--
-- CHECK (ya en backup):
--   configuraciones_remotas_estado_check
--     → estado IN ('PENDIENTE','APLICADA','CANCELADA')
-- ================================================================
