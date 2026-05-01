-- ================================================================
-- CONSTRAINTS — MÓDULO 2
-- ================================================================
--
-- CRITERIO DE INCLUSIÓN:
--   Solo se declaran constraints que NO existen ya en el backup
--   (backup3_1_1.sql). Los ya presentes en el backup son:
--
--     PKs: activos_biologicos_pkey, asociaciones_activos_sensores_pkey,
--           auditoria_activos_biologicos_individuales_pkey,
--           detalles_activos_biologicos_poblacionales_pkey,
--           detalles_activos_individuales_pkey,
--           estados_activos_biologicos_pkey, eventos_activos_pkey,
--           eventos_bajas_pkey, eventos_crecimeinto_pkey,
--           eventos_productivos_pkey, eventos_reproductivos_pkey,
--           eventos_sanitarios_pkey, gestiones_fases_pkey,
--           historicos_estados_activos_pkey,
--           indicadores_zootecnicos_pkey, movimientos_pkey
--
--     FKs (NOT VALID): activos_biologicos_id_estado_fkey,
--           activos_biologicos_id_infraestructura_fkey (→ modulo9),
--           activos_biologicos_id_usuario_fkey (→ modulo1),
--           auditoria_activos_biologicos_individua_id_activo_biologico_fkey,
--           auditoria_activos_biologicos_individuales_id_usuario_fkey,
--           detalles_activos_biologicos_poblaciona_id_activo_biologico_fkey,
--           detalles_activos_individuales_id_activo_biologico_fkey,
--           detalles_activos_individuales_id_usuario_fkey,
--           eventos_activos_id_activo_biologico_fkey,
--           eventos_activos_id_usuario_fkey,
--           eventos_bajas_id_evento_fkey,
--           eventos_crecimeinto_id_evento_fkey,
--           eventos_productivos_id_evento_fkey,
--           eventos_productivos_id_ciclo_productivo_fkey (→ modulo9),
--           eventos_reproductivos_id_evento_reproductivo_fkey,
--           eventos_reproductivos_id_madre_fkey,
--           eventos_reproductivos_id_padre_fkey,
--           eventos_sanitarios_id_evento_fkey,
--           fk_evento_metrica (→ modulo9.metricas_produccion),
--           fk_usuario (asociaciones → activos_biologicos),
--           gestiones_fases_id_activo_biologico_fkey,
--           gestiones_fases_id_ciclo_productiva_fkey (→ modulo9),
--           gestiones_fases_id_usuario_fkey,
--           historicos_estados_activos_id_activo_biologico_fkey,
--           historicos_estados_activos_id_estado_anterior_fkey,
--           historicos_estados_activos_id_estado_nuevo_fkey,
--           historicos_estados_activos_id_usuario_fkey,
--           indicadores_zootecnicos_id_activo_biologico_fkey,
--           movimientos_id_activo_biologico_fkey,
--           movimientos_id_infraestructura_destino_fkey (→ modulo9),
--           movimientos_id_infraestructura_origen_fkey (→ modulo9),
--           movimientos_id_usuario_fkey,
--           asociaciones_activos_sensores_id_sensor_fkey (→ modulo9),
--           asociaciones_activos_sensores_id_usuario_fkey
--
--   Se AGREGAN:
--     PARTE 1 — VALIDATE de FKs NOT VALID ya existentes
--     PARTE 2 — FKs genuinamente faltantes
--     PARTE 3 — UNIQUE constraints
--     PARTE 4 — CHECK constraints (con NOT VALID donde aplica)
--     PARTE 5 — Índices únicos parciales y de desempeño
--
-- NOTA SOBRE ENUMS:
--   Las columnas de tipo ENUM de PostgreSQL ya restringen los
--   valores posibles por definición de tipo. Agregar CHECK IN()
--   sobre ellas es redundante y puede causar errores de
--   compatibilidad. Dichos checks NO se incluyen en este script.
--   ENUMs del módulo 2:
--     modulo2.enum_activo_biologico_origen_financiero
--     modulo2.enum_activo_biologico_tipo
--     modulo2.enum_movimiento_tipo
--     modulo2.enum_evento_reproductivo_categoria
--     modulo2.enum_evento_bajas_tipo
--     modulo2.enum_indicador_zootecnico_tipo
--     modulo2.enum_asociaciones_activos_sensores_tipo
-- ================================================================

-- ----------------------------------------------------------------
-- BLOQUE 0 — PRECONDICIONES
-- Verificar y corregir datos inconsistentes ANTES de ejecutar
-- los índices parciales únicos. Descomentar y ejecutar si aplica.
-- ----------------------------------------------------------------

-- [P1] Garantizar solo UNA fase activa por activo (RF-37).
--      Si existen varias, desactivar las más antiguas:
--
-- UPDATE modulo2.gestiones_fases
--    SET es_activa = FALSE
--  WHERE es_activa = TRUE
--    AND id_gestion_fases NOT IN (
--        SELECT MAX(id_gestion_fases)
--          FROM modulo2.gestiones_fases
--         WHERE es_activa = TRUE
--         GROUP BY id_activo_biologico
--    );

-- [P2] Verificar que no haya indentficador duplicado en activos
--      INDIVIDUAL antes de crear el índice único parcial (RF-35):
--
-- SELECT indentficador, COUNT(*)
--   FROM modulo2.activos_biologicos
--  WHERE tipo = 'INDIVIDUAL'
--    AND indentficador IS NOT NULL
--  GROUP BY indentficador
--  HAVING COUNT(*) > 1;

-- [P3] Verificar que un mismo sensor no tenga dos asociaciones
--      vigentes con el mismo activo (fecha_fin IS NULL) (RF-49):
--
-- SELECT id_sensor, id_activo_biologico, COUNT(*)
--   FROM modulo2.asociaciones_activos_sensores
--  WHERE fecha_fin IS NULL
--  GROUP BY id_sensor, id_activo_biologico
--  HAVING COUNT(*) > 1;

-- ================================================================
-- PARTE 1 — VALIDACIÓN DE CLAVES FORÁNEAS YA EXISTENTES (NOT VALID)
-- Las siguientes FKs existen en el DDL del backup pero fueron
-- creadas con NOT VALID, por lo que no estaban activamente
-- verificadas. Se activan con VALIDATE CONSTRAINT.
-- ================================================================

ALTER TABLE modulo2.activos_biologicos
    VALIDATE CONSTRAINT activos_biologicos_id_estado_fkey;

ALTER TABLE modulo2.activos_biologicos
    VALIDATE CONSTRAINT activos_biologicos_id_infraestructura_fkey;

ALTER TABLE modulo2.activos_biologicos
    VALIDATE CONSTRAINT activos_biologicos_id_usuario_fkey;

ALTER TABLE modulo2.detalles_activos_individuales
    VALIDATE CONSTRAINT detalles_activos_individuales_id_activo_biologico_fkey;

ALTER TABLE modulo2.detalles_activos_individuales
    VALIDATE CONSTRAINT detalles_activos_individuales_id_usuario_fkey;

ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    VALIDATE CONSTRAINT detalles_activos_biologicos_poblaciona_id_activo_biologico_fkey;

ALTER TABLE modulo2.eventos_activos
    VALIDATE CONSTRAINT eventos_activos_id_activo_biologico_fkey;

ALTER TABLE modulo2.eventos_activos
    VALIDATE CONSTRAINT eventos_activos_id_usuario_fkey;

ALTER TABLE modulo2.eventos_bajas
    VALIDATE CONSTRAINT eventos_bajas_id_evento_fkey;

ALTER TABLE modulo2.eventos_crecimeinto
    VALIDATE CONSTRAINT eventos_crecimeinto_id_evento_fkey;

ALTER TABLE modulo2.eventos_sanitarios
    VALIDATE CONSTRAINT eventos_sanitarios_id_evento_fkey;

ALTER TABLE modulo2.eventos_productivos
    VALIDATE CONSTRAINT eventos_productivos_id_evento_fkey;

ALTER TABLE modulo2.eventos_productivos
    VALIDATE CONSTRAINT eventos_productivos_id_ciclo_productivo_fkey;

ALTER TABLE modulo2.eventos_reproductivos
    VALIDATE CONSTRAINT eventos_reproductivos_id_evento_reproductivo_fkey;

ALTER TABLE modulo2.eventos_reproductivos
    VALIDATE CONSTRAINT eventos_reproductivos_id_madre_fkey;

ALTER TABLE modulo2.eventos_reproductivos
    VALIDATE CONSTRAINT eventos_reproductivos_id_padre_fkey;

ALTER TABLE modulo2.gestiones_fases
    VALIDATE CONSTRAINT gestiones_fases_id_activo_biologico_fkey;

ALTER TABLE modulo2.gestiones_fases
    VALIDATE CONSTRAINT gestiones_fases_id_ciclo_productiva_fkey;

ALTER TABLE modulo2.gestiones_fases
    VALIDATE CONSTRAINT gestiones_fases_id_usuario_fkey;

ALTER TABLE modulo2.historicos_estados_activos
    VALIDATE CONSTRAINT historicos_estados_activos_id_activo_biologico_fkey;

ALTER TABLE modulo2.historicos_estados_activos
    VALIDATE CONSTRAINT historicos_estados_activos_id_estado_anterior_fkey;

ALTER TABLE modulo2.historicos_estados_activos
    VALIDATE CONSTRAINT historicos_estados_activos_id_estado_nuevo_fkey;

ALTER TABLE modulo2.historicos_estados_activos
    VALIDATE CONSTRAINT historicos_estados_activos_id_usuario_fkey;

ALTER TABLE modulo2.indicadores_zootecnicos
    VALIDATE CONSTRAINT indicadores_zootecnicos_id_activo_biologico_fkey;

ALTER TABLE modulo2.movimientos
    VALIDATE CONSTRAINT movimientos_id_activo_biologico_fkey;

ALTER TABLE modulo2.movimientos
    VALIDATE CONSTRAINT movimientos_id_infraestructura_destino_fkey;

ALTER TABLE modulo2.movimientos
    VALIDATE CONSTRAINT movimientos_id_infraestructura_origen_fkey;

ALTER TABLE modulo2.movimientos
    VALIDATE CONSTRAINT movimientos_id_usuario_fkey;

ALTER TABLE modulo2.asociaciones_activos_sensores
    VALIDATE CONSTRAINT asociaciones_activos_sensores_id_sensor_fkey;

ALTER TABLE modulo2.asociaciones_activos_sensores
    VALIDATE CONSTRAINT asociaciones_activos_sensores_id_usuario_fkey;

ALTER TABLE modulo2.auditoria_activos_biologicos_individuales
    VALIDATE CONSTRAINT auditoria_activos_biologicos_individua_id_activo_biologico_fkey;

ALTER TABLE modulo2.auditoria_activos_biologicos_individuales
    VALIDATE CONSTRAINT auditoria_activos_biologicos_individuales_id_usuario_fkey;


-- ================================================================
-- PARTE 2 — CLAVES FORÁNEAS GENUINAMENTE FALTANTES EN EL BACKUP
-- Estas FKs NO existen en el DDL y se crean desde cero.
-- ================================================================

-- [RF-49] La FK fk_usuario del backup asociaciones → activos_biologicos
--   tiene nombre confuso. Se agrega con nombre semánticamente correcto.
ALTER TABLE modulo2.asociaciones_activos_sensores
    ADD CONSTRAINT fk_asociacion_activo_biologico
        FOREIGN KEY (id_activo_biologico)
        REFERENCES modulo2.activos_biologicos (id_activo_biologico);

-- ================================================================
-- PARTE 3 — UNIQUE CONSTRAINTS NUEVOS
-- ================================================================

-- [RF-44] Nombre de estado único (catálogo controlado)
ALTER TABLE modulo2.estados_activos_biologicos
    ADD CONSTRAINT uq_estado_nombre
        UNIQUE (nombre);

-- ================================================================
-- PARTE 4 — CHECK CONSTRAINTS NUEVOS
--
-- Los CHECKs se dividen en dos grupos:
--   4.1 CHECKs que aplican directamente (sin riesgo de fallo
--       por datos existentes)
--   4.2 CHECKs que pueden fallar con datos previos → NOT VALID
--       Se crean diferidos y se validan en paso separado.
--       Si la validación falla, ejecutar las precondiciones del
--       BLOQUE 0 correspondientes y re-ejecutar el VALIDATE.
-- ================================================================

-- ----------------------------------------------------------------
-- 4.1  CHECKs directos
-- ----------------------------------------------------------------

-- [RF-33] fecha_inicio_ciclo: año válido >= 1970
ALTER TABLE modulo2.activos_biologicos
    ADD CONSTRAINT chk_activos_fecha_inicio_ciclo_valida
        CHECK (fecha_inicio_ciclo >= 1970);

-- [RF-33] costo_adquisicion no negativo (0 válido en nacimientos)
ALTER TABLE modulo2.activos_biologicos
    ADD CONSTRAINT chk_activos_costo_no_negativo
        CHECK (costo_adquisicion >= 0);

-- [RF-35] Sexo: solo valores biológicos válidos
ALTER TABLE modulo2.detalles_activos_individuales
    ADD CONSTRAINT chk_detalle_individual_sexo_valido
        CHECK (sexo IN ('Macho', 'Hembra'));

-- [RF-35] Peso inicial no negativo (0 válido en neonatos sin medición)
ALTER TABLE modulo2.detalles_activos_individuales
    ADD CONSTRAINT chk_detalle_individual_peso_inicial_no_negativo
        CHECK (peso_inicial >= 0);

-- [RF-35] Raza no puede ser cadena vacía
ALTER TABLE modulo2.detalles_activos_individuales
    ADD CONSTRAINT chk_detalle_raza_no_vacia
        CHECK (char_length(trim(raza)) > 0);

-- [RF-36] Cantidad inicial obligatoria y positiva > 0
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    ADD CONSTRAINT chk_poblacional_cantidad_inicial_positiva
        CHECK (cantidad_inicial > 0);

-- [RF-36] Cantidad actual no negativa
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    ADD CONSTRAINT chk_poblacional_cantidad_actual_no_negativa
        CHECK (cantidad_actual >= 0);

-- [RF-36] Cantidad actual no puede superar la inicial
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    ADD CONSTRAINT chk_poblacional_cantidad_actual_coherente
        CHECK (cantidad_actual <= cantidad_inicial);

-- [RF-36] Peso promedio no negativo
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    ADD CONSTRAINT chk_poblacional_peso_promedio_no_negativo
        CHECK (peso_promedio >= 0);

-- [RF-36] Densidad no negativa (puede ser 0 al vaciar el lote)
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    ADD CONSTRAINT chk_poblacional_densidad_no_negativa
        CHECK (densidad >= 0);

-- [RF-48] Infraestructura origen diferente de destino
ALTER TABLE modulo2.movimientos
    ADD CONSTRAINT chk_movimiento_origen_diferente_destino
        CHECK (id_infraestructura_origen <> id_infraestructura_destino);

-- [RF-40] Valor de medición positivo (mayor a 0)
ALTER TABLE modulo2.eventos_crecimeinto
    ADD CONSTRAINT chk_crecimiento_valor_positivo
        CHECK (valor_medicion > 0);

-- [RF-40] Unidad de medida dentro del dominio válido por tipo
--   peso → 'kg', 'gr', 'lb'
--   altura → 'cm', 'm'
--   densidad → 'kg/m2'
ALTER TABLE modulo2.eventos_crecimeinto
    ADD CONSTRAINT chk_crecimiento_unidad_valida
        CHECK (unidad_medida IN ('kg', 'gr', 'lb', 'cm', 'm', 'kg/m2'));

-- [RF-41] Dosis positiva
ALTER TABLE modulo2.eventos_sanitarios
    ADD CONSTRAINT chk_sanitario_dosis_positiva
        CHECK (dosis > 0);

-- [RF-41] Frecuencia positiva cuando está definida
ALTER TABLE modulo2.eventos_sanitarios
    ADD CONSTRAINT chk_sanitario_frecuencia_positiva
        CHECK (frecuencia IS NULL OR frecuencia > 0);

-- [RF-42] Número de crías no negativo
ALTER TABLE modulo2.eventos_reproductivos
    ADD CONSTRAINT chk_reproductivo_numero_cria_no_negativo
        CHECK (numero_cria >= 0);

-- [RF-42] Padre e madre deben ser activos distintos
ALTER TABLE modulo2.eventos_reproductivos
    ADD CONSTRAINT chk_reproductivo_padre_diferente_madre
        CHECK (id_padre <> id_madre OR id_madre IS NULL);

-- [RF-43] Cantidad producida: decimal positivo mayor a cero
ALTER TABLE modulo2.eventos_productivos
    ADD CONSTRAINT chk_productivo_cantidad_positiva
        CHECK (cantidad > 0);

-- [RF-45] Cantidad afectada positiva
ALTER TABLE modulo2.eventos_bajas
    ADD CONSTRAINT chk_baja_cantidad_positiva
        CHECK (cantidad_afectada > 0);

-- [RF-44] Estado nuevo diferente del anterior (sin cambio redundante)
ALTER TABLE modulo2.historicos_estados_activos
    ADD CONSTRAINT chk_historico_estado_cambio_real
        CHECK (id_estado_nuevo <> id_estado_anterior);

-- [RF-44] Módulo origen dentro del vocabulario del sistema
ALTER TABLE modulo2.historicos_estados_activos
    ADD CONSTRAINT chk_historico_modulo_origen_valido
        CHECK (modulo_origen IN ('modulo1', 'modulo2', 'modulo3',
                                  'modulo4', 'modulo5', 'modulo6',
                                  'modulo7', 'modulo8', 'modulo9'));

-- [RF-49] fecha_inicio debe ser estrictamente anterior a fecha_fin
ALTER TABLE modulo2.asociaciones_activos_sensores
    ADD CONSTRAINT chk_asociacion_fechas_coherentes
        CHECK (fecha_inicio < fecha_fin);

-- ----------------------------------------------------------------
-- 4.2  CHECKs que pueden fallar con datos previos → NOT VALID
--       Se crean diferidos y se validan en paso separado.
--       Si la validación falla, corregir los datos y
--       re-ejecutar el VALIDATE correspondiente.
-- ----------------------------------------------------------------

-- [RF-39] La fecha del evento no puede ser futura
ALTER TABLE modulo2.eventos_activos
    ADD CONSTRAINT chk_eventos_fecha_no_futura
        CHECK (fecha <= NOW())
        NOT VALID;
ALTER TABLE modulo2.eventos_activos
    VALIDATE CONSTRAINT chk_eventos_fecha_no_futura;

-- [RF-33] Fecha de inicio de ciclo no superior al año actual
ALTER TABLE modulo2.activos_biologicos
    ADD CONSTRAINT chk_activos_fecha_inicio_ciclo_no_futura
        CHECK (fecha_inicio_ciclo <= EXTRACT(YEAR FROM NOW()))
        NOT VALID;
ALTER TABLE modulo2.activos_biologicos
    VALIDATE CONSTRAINT chk_activos_fecha_inicio_ciclo_no_futura;

-- [RF-40] Coherencia biomasa_total ≈ cantidad_actual × peso_promedio
--   Tolerancia del 5% para errores de redondeo en el cálculo
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    ADD CONSTRAINT chk_poblacional_biomasa_coherente
        CHECK (
            cantidad_actual = 0
            OR ABS(biomasa_total - (cantidad_actual * peso_promedio))
               <= (cantidad_actual * peso_promedio * 0.05)
        )
        NOT VALID;
ALTER TABLE modulo2.detalles_activos_biologicos_poblacionales
    VALIDATE CONSTRAINT chk_poblacional_biomasa_coherente;

-- ================================================================
-- PARTE 5 — ÍNDICES ÚNICOS PARCIALES Y DE DESEMPEÑO
-- IMPORTANTE: Ejecutar las precondiciones del BLOQUE 0 antes de
-- correr esta sección si la base de datos ya contiene datos.
-- ================================================================

-- [RF-35] Identificador único para activos tipo INDIVIDUAL
--   Ejecutar [P2] del BLOQUE 0 si existen duplicados previos.
CREATE UNIQUE INDEX IF NOT EXISTS uix_activo_indentficador_individual
    ON modulo2.activos_biologicos (indentficador)
    WHERE tipo = 'INDIVIDUAL';

-- [RF-37] Solo UNA fase activa por activo biológico
--   Ejecutar [P1] del BLOQUE 0 si existen múltiples fases activas.
CREATE UNIQUE INDEX IF NOT EXISTS uix_gestion_fase_activa_por_activo
    ON modulo2.gestiones_fases (id_activo_biologico)
    WHERE es_activa = TRUE;

-- [RF-49] Un mismo sensor no puede tener dos asociaciones vigentes
--   con el mismo activo simultáneamente (fecha_fin IS NULL = vigente)
--   Ejecutar [P3] del BLOQUE 0 si existen duplicados previos.
CREATE UNIQUE INDEX IF NOT EXISTS uix_asociacion_sensor_activo_vigente
    ON modulo2.asociaciones_activos_sensores (id_sensor, id_activo_biologico)
    WHERE fecha_fin IS NULL;

-- Índice de desempeño: historial de estados por activo (RF-46)
CREATE INDEX IF NOT EXISTS idx_historicos_estados_activo_fecha
    ON modulo2.historicos_estados_activos (id_activo_biologico, fecha_cambio DESC);

-- Índice de desempeño: eventos por activo ordenados por fecha (RF-47)
CREATE INDEX IF NOT EXISTS idx_eventos_activos_activo_fecha
    ON modulo2.eventos_activos (id_activo_biologico, fecha DESC);

-- Índice de desempeño: activos por infraestructura y estado (RF-34)
CREATE INDEX IF NOT EXISTS idx_activos_biologicos_infraestructura
    ON modulo2.activos_biologicos (id_infraestructura, id_estado);

-- ================================================================
-- REFERENCIA: CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (no se re-ejecutan; listados para consulta)
-- ================================================================
--
-- Claves Primarias (ya en backup — 16 tablas):
--   activos_biologicos_pkey, asociaciones_activos_sensores_pkey,
--   auditoria_activos_biologicos_individuales_pkey,
--   detalles_activos_biologicos_poblacionales_pkey,
--   detalles_activos_individuales_pkey,
--   estados_activos_biologicos_pkey, eventos_activos_pkey,
--   eventos_bajas_pkey, eventos_crecimeinto_pkey,
--   eventos_productivos_pkey, eventos_reproductivos_pkey,
--   eventos_sanitarios_pkey, gestiones_fases_pkey,
--   historicos_estados_activos_pkey,
--   indicadores_zootecnicos_pkey, movimientos_pkey
--
-- Claves Foráneas (ya en backup, activadas en PARTE 1):
--   activos_biologicos_id_estado_fkey
--   activos_biologicos_id_infraestructura_fkey (→ modulo9)
--   activos_biologicos_id_usuario_fkey (→ modulo1)
--   auditoria_activos_biologicos_individua_id_activo_biologico_fkey
--   auditoria_activos_biologicos_individuales_id_usuario_fkey
--   detalles_activos_biologicos_poblaciona_id_activo_biologico_fkey
--   detalles_activos_individuales_id_activo_biologico_fkey
--   detalles_activos_individuales_id_usuario_fkey
--   eventos_activos_id_activo_biologico_fkey
--   eventos_activos_id_usuario_fkey
--   eventos_bajas_id_evento_fkey
--   eventos_crecimeinto_id_evento_fkey
--   eventos_productivos_id_evento_fkey
--   eventos_productivos_id_ciclo_productivo_fkey (→ modulo9)
--   eventos_reproductivos_id_evento_reproductivo_fkey
--   eventos_reproductivos_id_madre_fkey
--   eventos_reproductivos_id_padre_fkey
--   eventos_sanitarios_id_evento_fkey
--   fk_evento_metrica (→ modulo9.metricas_produccion)
--   fk_usuario (asociaciones → activos_biologicos, nombre confuso
--               → sustituida semánticamente en PARTE 2)
--   gestiones_fases_id_activo_biologico_fkey
--   gestiones_fases_id_ciclo_productiva_fkey (→ modulo9)
--   gestiones_fases_id_usuario_fkey
--   historicos_estados_activos_id_activo_biologico_fkey
--   historicos_estados_activos_id_estado_anterior_fkey
--   historicos_estados_activos_id_estado_nuevo_fkey
--   historicos_estados_activos_id_usuario_fkey
--   indicadores_zootecnicos_id_activo_biologico_fkey
--   movimientos_id_activo_biologico_fkey
--   movimientos_id_infraestructura_destino_fkey (→ modulo9)
--   movimientos_id_infraestructura_origen_fkey (→ modulo9)
--   movimientos_id_usuario_fkey
--   asociaciones_activos_sensores_id_sensor_fkey (→ modulo9)
--   asociaciones_activos_sensores_id_usuario_fkey
-- ================================================================
