-- ============================================================================= 
-- MÓDULO 9 — CONFIGURACIÓN Y PARAMETRIZACIÓN DEL SISTEMA 
-- Archivo: modulo9_triggers.sql 
-- Descripción: Triggers y funciones de trigger para garantizar integridad 
-- de datos, invariantes estructurales y reglas de negocio 
-- que deben ser protegidas a nivel de base de datos. 
-- Esquema: modulo9 
-- Motor: PostgreSQL 
-- Versión: 1.0 
-- ============================================================================= 

-- ÍNDICE 
-- TRG-M9-01 Unicidad de nombre de especie (case-insensitive) 
-- TRG-M9-02 Longitud y formato mínimo del nombre de especie 
-- TRG-M9-03 Auditoría automática de operaciones sobre especies 
-- TRG-M9-04 Protección de eliminación física de especies 
-- TRG-M9-05 Unicidad de nombre de ciclo biológico por especie (case-insensitive) 
-- TRG-M9-06 Validación de duración de ciclo biológico 
-- TRG-M9-07 Bloqueo de desactivación de etapa con activos biológicos vinculados 
-- TRG-M9-08 Unicidad de nombre de patología (case-insensitive, global) 
-- TRG-M9-09 Protección de eliminación física de patologías 
-- TRG-M9-10 Unicidad de nombre de métrica productiva (case-insensitive) 
-- TRG-M9-11 Unicidad activa de umbral ambiental por especie + variable 
-- TRG-M9-12 Validación de rango y especie activa en umbral ambiental 
-- TRG-M9-13 Validación de no solapamiento de niveles de alerta 
-- TRG-M9-14 Unicidad de configuración global activa 
-- TRG-M9-15 Validación de heartbeat y frecuencia de muestreo 
-- TRG-M9-16 Unicidad y validación de formato del nombre de finca 
-- TRG-M9-17 Validación de coordenadas y tamaño de finca 
-- TRG-M9-18 Protección de eliminación física de fincas 
-- TRG-M9-19 Unicidad de nombre de infraestructura por finca (case-insensitive) 
-- TRG-M9-20 Validación de superficie de infraestructura 
-- TRG-M9-21 Bloqueo de desactivación de infraestructura con dependencias operativas 
-- TRG-M9-22 Unicidad del serial de dispositivo IoT 
-- TRG-M9-23 Bloqueo de eliminación física de dispositivos IoT con datos históricos 
-- TRG-M9-24 Unicidad de asociación activa sensor-área 
-- TRG-M9-25 Validación de dispositivo activo para calibración 
-- TRG-M9-26 Unicidad de nombre de plantilla y versionado incremental automático 
-- TRG-M9-27 Inmutabilidad de plantillas (bloqueo de UPDATE y DELETE) 
-- TRG-M9-28 Auditoría de cambios en identidad visual 
-- TRG-M9-29 Validación de colores hexadecimales en identidad visual 
-- TRG-M9-30 Validación de theme_mode en temas visuales 
-- TRG-M9-31 Validación de configuración remota: lógica de tiempos 
-- TRG-M9-32 Unicidad de configuración remota PENDIENTE por dispositivo 

-- ============================================================================= 
-- TRG-M9-01 — Unicidad de nombre de especie (case-insensitive) 
-- Tabla: modulo9.especies 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_especies_nombre_unique_ci() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.especies 
    WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(NEW.nombre)) 
      AND id_especie <> COALESCE(NEW.id_especie, -1); 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_SPECIES: Ya existe una especie con el nombre "%" (validación case-insensitive). Use un nombre diferente.', NEW.nombre 
        USING ERRCODE = 'P0101'; 
    END IF; 
    
    -- Normalizar: primer carácter en mayúscula, resto en minúscula 
    NEW.nombre := INITCAP(TRIM(NEW.nombre)); 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_especies_nombre_unique_ci 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.especies 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_especies_nombre_unique_ci(); 

-- ============================================================================= 
-- TRG-M9-02 — Longitud y formato mínimo del nombre de especie 
-- Tabla: modulo9.especies 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_especies_nombre_formato() RETURNS TRIGGER AS $$ 
DECLARE 
    v_longitud INTEGER; 
BEGIN 
    NEW.nombre := TRIM(NEW.nombre); 
    v_longitud := LENGTH(NEW.nombre); 
    
    IF v_longitud < 3 OR v_longitud > 50 THEN 
        RAISE EXCEPTION 'INVALID_FORMAT: El nombre de la especie debe tener entre 3 y 50 caracteres. Longitud recibida: %.', v_longitud 
        USING ERRCODE = 'P0102'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_especies_nombre_formato 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.especies 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_especies_nombre_formato(); 

-- ============================================================================= 
-- TRG-M9-03 — Auditoría automática de operaciones sobre especies 
-- Tabla: modulo9.especies 
-- Evento: AFTER INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_especies_audit() RETURNS TRIGGER AS $$ 
BEGIN 
    INSERT INTO modulo9.gestion_especies ( 
        id_usuario, 
        id_especie, 
        fecha_gestion, 
        id_umbral_ambiental 
    ) VALUES ( 
        NEW.id_especie, -- proxy hasta que el backend provea el usuario real via current_setting 
        NEW.id_especie, 
        now(), 
        NULL 
    ); 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_especies_audit 
AFTER INSERT OR UPDATE ON modulo9.especies 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_especies_audit(); 

-- ============================================================================= 
-- TRG-M9-04 — Protección de eliminación física de especies 
-- Tabla: modulo9.especies 
-- Evento: BEFORE DELETE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_especies_no_delete() RETURNS TRIGGER AS $$ 
BEGIN 
    RAISE EXCEPTION 'NO_PHYSICAL_DELETE: Las especies no pueden eliminarse físicamente. Use la desactivación lógica (es_activo = false). Especie afectada: "%".', OLD.nombre 
    USING ERRCODE = 'P0103'; 
    RETURN NULL; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_especies_no_delete 
BEFORE DELETE ON modulo9.especies 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_especies_no_delete(); 

-- ============================================================================= 
-- TRG-M9-05 — Unicidad de nombre de ciclo biológico (etapa) por especie, case-insensitive 
-- Tabla: modulo9.ciclos_biologicos 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_ciclos_biologicos_nombre_unique_ci() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.ciclos_biologicos 
    WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(NEW.nombre)) 
      AND id_especie = NEW.id_especie 
      AND id_ciclo_biologico <> COALESCE(NEW.id_ciclo_biologico, -1); 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_STAGE: Ya existe una etapa llamada "%" para esta especie. Los nombres de etapa deben ser únicos por especie (case-insensitive).', NEW.nombre 
        USING ERRCODE = 'P0104'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_ciclos_biologicos_nombre_unique_ci 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.ciclos_biologicos 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_ciclos_biologicos_nombre_unique_ci(); 

-- ============================================================================= 
-- TRG-M9-06 — Validación de duración de ciclo biológico (etapa) 
-- Tabla: modulo9.ciclos_biologicos 
-- Evento: BEFORE INSERT OR UPDATE OF duracion_dias 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_ciclos_biologicos_duracion_valida() RETURNS TRIGGER AS $$ 
BEGIN 
    IF NEW.duracion_dias IS NULL OR NEW.duracion_dias <= 0 THEN 
        RAISE EXCEPTION 'INVALID_DURATION: La duración de la etapa debe ser un número entero positivo mayor a 0. Valor recibido: %.', NEW.duracion_dias 
        USING ERRCODE = 'P0105'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_ciclos_biologicos_duracion_valida 
BEFORE INSERT OR UPDATE OF duracion_dias ON modulo9.ciclos_biologicos 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_ciclos_biologicos_duracion_valida(); 

-- ============================================================================= 
-- TRG-M9-07 — Bloqueo de desactivación de etapa con activos biológicos vinculados 
-- Tabla: modulo9.ciclos_biologicos 
-- Evento: BEFORE UPDATE OF es_activo 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_ciclos_biologicos_no_desactivar_en_uso() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    IF OLD.es_activo = TRUE AND NEW.es_activo = FALSE THEN 
        SELECT COUNT(*) INTO v_count 
        FROM modulo9.ciclos_productivos_biologicos 
        WHERE id_ciclo_biologico = OLD.id_ciclo_biologico; 
        
        IF v_count > 0 THEN 
            RAISE EXCEPTION 'STAGE_IN_USE: No se puede desactivar la etapa "%" porque tiene % ciclo(s) productivo(s) vinculado(s). Traslade los activos antes de proceder.', OLD.nombre, v_count 
            USING ERRCODE = 'P0106'; 
        END IF; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_ciclos_biologicos_no_desactivar_en_uso 
BEFORE UPDATE OF es_activo ON modulo9.ciclos_biologicos 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_ciclos_biologicos_no_desactivar_en_uso(); 

-- ============================================================================= 
-- TRG-M9-08 — Unicidad de nombre de patología (case-insensitive, global) 
-- Tabla: modulo9.patologias 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_patologias_nombre_unique_ci() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.patologias 
    WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(NEW.nombre)) 
      AND id_patologias <> COALESCE(NEW.id_patologias, -1); 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_PATHOLOGY: Ya existe una patología con el nombre "%" en el catálogo global (case-insensitive).', NEW.nombre 
        USING ERRCODE = 'P0107'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_patologias_nombre_unique_ci 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.patologias 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_patologias_nombre_unique_ci(); 

-- ============================================================================= 
-- TRG-M9-09 — Protección de eliminación física de patologías 
-- Tabla: modulo9.patologias 
-- Evento: BEFORE DELETE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_patologias_no_delete() RETURNS TRIGGER AS $$ 
BEGIN 
    RAISE EXCEPTION 'NO_PHYSICAL_DELETE: Las patologías no pueden eliminarse físicamente. Use la desactivación lógica (es_activo = false). Patología: "%".', OLD.nombre 
    USING ERRCODE = 'P0108'; 
    RETURN NULL; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_patologias_no_delete 
BEFORE DELETE ON modulo9.patologias 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_patologias_no_delete(); 

-- ============================================================================= 
-- TRG-M9-10 — Unicidad de nombre de métrica productiva (case-insensitive) 
-- Tabla: modulo9.metricas_produccion 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_metricas_produccion_nombre_unique_ci() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.metricas_produccion 
    WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(NEW.nombre)) 
      AND id_metrica_produccion <> COALESCE(NEW.id_metrica_produccion, -1); 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_METRIC: Ya existe una métrica productiva con el nombre "%" (case-insensitive).', NEW.nombre 
        USING ERRCODE = 'P0109'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_metricas_produccion_nombre_unique_ci 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.metricas_produccion 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_metricas_produccion_nombre_unique_ci(); 

-- ============================================================================= 
-- TRG-M9-11 — Unicidad activa de umbral ambiental por especie + variable 
-- Tabla: modulo9.umbrales_ambientales 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_umbral_ambiental_duplicado() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    IF NEW.es_activo = TRUE THEN 
        SELECT COUNT(*) INTO v_count 
        FROM modulo9.umbrales_ambientales 
        WHERE id_especie = NEW.id_especie 
          AND id_variable_ambiental = NEW.id_variable_ambiental 
          AND es_activo = TRUE 
          AND id_umbral_ambiental <> COALESCE(NEW.id_umbral_ambiental, -1); 
          
        IF v_count > 0 THEN 
            RAISE EXCEPTION 'DUPLICATE_THRESHOLD: Ya existe un umbral activo para esta combinación de especie y variable ambiental. Edite el umbral existente en lugar de crear uno nuevo.' 
            USING ERRCODE = 'P0110'; 
        END IF; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_umbral_ambiental_duplicado 
BEFORE INSERT OR UPDATE ON modulo9.umbrales_ambientales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_umbral_ambiental_duplicado(); 

-- ============================================================================= 
-- TRG-M9-12 — Validación de rango y especie activa en umbral ambiental 
-- Tabla: modulo9.umbrales_ambientales 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_umbral_ambiental_rango_valido() RETURNS TRIGGER AS $$ 
DECLARE 
    v_especie_activa BOOLEAN; 
BEGIN 
    -- Validar rango lógico 
    IF NEW.valor_min >= NEW.valor_max THEN 
        RAISE EXCEPTION 'INVALID_RANGE: El valor mínimo (%) no puede ser mayor o igual al valor máximo (%) para el umbral ambiental.', NEW.valor_min, NEW.valor_max 
        USING ERRCODE = 'P0111'; 
    END IF; 
    
    -- Validar que la especie esté activa 
    SELECT es_activo INTO v_especie_activa FROM modulo9.especies WHERE id_especie = NEW.id_especie; 
    
    IF v_especie_activa IS NULL OR v_especie_activa = FALSE THEN 
        RAISE EXCEPTION 'INACTIVE_SPECIES: No se puede configurar un umbral para la especie ID % porque está inactiva o no existe.', NEW.id_especie 
        USING ERRCODE = 'P0112'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_umbral_ambiental_rango_valido 
BEFORE INSERT OR UPDATE ON modulo9.umbrales_ambientales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_umbral_ambiental_rango_valido(); 

-- ============================================================================= 
-- TRG-M9-13 — Validación de no solapamiento de niveles de alerta 
-- Tabla: modulo9.niveles_alerta_ambientales 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_niveles_alerta_solapamiento() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    -- Validar coherencia interna del nivel 
    IF NEW.limite_inferior >= NEW.limite_superior THEN 
        RAISE EXCEPTION 'INVALID_ALERT_RANGE: El límite inferior (%) debe ser estrictamente menor al límite superior (%) del nivel de alerta.', NEW.limite_inferior, NEW.limite_superior 
        USING ERRCODE = 'P0113'; 
    END IF; 
    
    -- Detectar solapamiento con otros niveles del mismo umbral 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.niveles_alerta_ambientales 
    WHERE id_umbral_ambiental = NEW.id_umbral_ambiental 
      AND id_nivel_alerta_ambiental <> COALESCE(NEW.id_nivel_alerta_ambiental, -1) 
      AND ( NEW.limite_inferior < limite_superior AND NEW.limite_superior > limite_inferior ); 
      
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'OVERLAPPING_ALERT: El rango [%, %] del nuevo nivel de alerta se solapa con un rango ya existente para este umbral ambiental.', NEW.limite_inferior, NEW.limite_superior 
        USING ERRCODE = 'P0114'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_niveles_alerta_solapamiento 
BEFORE INSERT OR UPDATE ON modulo9.niveles_alerta_ambientales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_niveles_alerta_solapamiento(); 

-- ============================================================================= 
-- TRG-M9-14 — Unicidad de configuración global activa 
-- Tabla: modulo9.configuraciones_globales 
-- Evento: BEFORE INSERT 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_configuracion_global_unicidad() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    IF NEW.es_activo = TRUE THEN 
        SELECT COUNT(*) INTO v_count FROM modulo9.configuraciones_globales WHERE es_activo = TRUE; 
        IF v_count > 0 THEN 
            RAISE EXCEPTION 'DUPLICATE_GLOBAL_CONFIG: Ya existe una configuración global activa. Actualice la configuración vigente en lugar de crear una nueva.' 
            USING ERRCODE = 'P0115'; 
        END IF; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_configuracion_global_unicidad 
BEFORE INSERT ON modulo9.configuraciones_globales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_configuracion_global_unicidad(); 

-- ============================================================================= 
-- TRG-M9-15 — Validación de heartbeat y frecuencia de muestreo 
-- Tabla: modulo9.configuraciones_globales 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_configuracion_global_heartbeat_valido() RETURNS TRIGGER AS $$ 
BEGIN 
    IF NEW.frecuencia_muestreo IS NULL OR NEW.frecuencia_muestreo <= 0 THEN 
        RAISE EXCEPTION 'INVALID_CONFIG: La frecuencia de muestreo debe ser un entero positivo mayor a 0. Valor recibido: %.', NEW.frecuencia_muestreo 
        USING ERRCODE = 'P0116'; 
    END IF; 
    
    IF NEW.heartbeat IS NULL OR NEW.heartbeat <= 0 THEN 
        RAISE EXCEPTION 'INVALID_CONFIG: El heartbeat debe ser un entero positivo mayor a 0. Valor recibido: %.', NEW.heartbeat 
        USING ERRCODE = 'P0116'; 
    END IF; 
    
    IF NEW.heartbeat < NEW.frecuencia_muestreo THEN 
        RAISE EXCEPTION 'INVALID_CONFIG: El heartbeat (%) debe ser mayor o igual a la frecuencia de muestreo (%). No puede esperarse una señal antes del intervalo de envío.', NEW.heartbeat, NEW.frecuencia_muestreo 
        USING ERRCODE = 'P0117'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_configuracion_global_heartbeat_valido 
BEFORE INSERT OR UPDATE ON modulo9.configuraciones_globales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_configuracion_global_heartbeat_valido(); 

-- ============================================================================= 
-- TRG-M9-16 — Unicidad y validación de formato del nombre de finca 
-- Tabla: modulo9.fincas 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_finca_nombre_unique() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count_global INTEGER; 
    v_count_productor INTEGER; 
BEGIN 
    NEW.nombre := TRIM(NEW.nombre); 
    -- Validar formato: solo letras, espacios, acentos y ñ 
    IF NEW.nombre !~ '^[A-Za-záéíóúÁÉÍÓÚñÑüÜ\s]+$' THEN 
        RAISE EXCEPTION 'INVALID_FORMAT: El nombre de la finca solo permite letras, espacios y caracteres del español. No se admiten números ni símbolos. Valor: "%".', NEW.nombre 
        USING ERRCODE = 'P0118'; 
    END IF; 
    
    -- Validar unicidad global 
    SELECT COUNT(*) INTO v_count_global 
    FROM modulo9.fincas 
    WHERE LOWER(TRIM(nombre)) = LOWER(NEW.nombre) 
      AND id_finca <> COALESCE(NEW.id_finca, -1); 
      
    IF v_count_global > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_FARM_GLOBAL: Ya existe una finca con el nombre "%" en el sistema (unicidad global).', NEW.nombre 
        USING ERRCODE = 'P0119'; 
    END IF; 
    
    -- Validar unicidad por productor 
    IF NEW.id_usuario IS NOT NULL THEN 
        SELECT COUNT(*) INTO v_count_productor 
        FROM modulo9.fincas 
        WHERE LOWER(TRIM(nombre)) = LOWER(NEW.nombre) 
          AND id_usuario = NEW.id_usuario 
          AND id_finca <> COALESCE(NEW.id_finca, -1); 
          
        IF v_count_productor > 0 THEN 
            RAISE EXCEPTION 'DUPLICATE_FARM_PRODUCER: El productor ya tiene una finca registrada con el nombre "%".', NEW.nombre 
            USING ERRCODE = 'P0120'; 
        END IF; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_finca_nombre_unique 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.fincas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_finca_nombre_unique(); 

-- ============================================================================= 
-- TRG-M9-17 — Validación de coordenadas y tamaño de finca 
-- Tabla: modulo9.fincas 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_finca_coordenadas_validas() RETURNS TRIGGER AS $$ 
DECLARE 
    v_lat NUMERIC; 
    v_lng NUMERIC; 
BEGIN 
    -- Validar tamaño de finca 
    IF NEW.tamano_h IS NULL OR NEW.tamano_h <= 0 THEN 
        RAISE EXCEPTION 'INVALID_SIZE: El tamaño de la finca debe ser un valor numérico positivo mayor a cero. Valor recibido: %.', NEW.tamano_h 
        USING ERRCODE = 'P0121'; 
    END IF; 
    
    -- Extraer y validar coordenadas del JSONB 
    IF NEW.ubicacion IS NOT NULL THEN 
        v_lat := (NEW.ubicacion->>'latitud')::NUMERIC; 
        v_lng := (NEW.ubicacion->>'longitud')::NUMERIC; 
        
        IF v_lat IS NOT NULL AND (v_lat < -90 OR v_lat > 90) THEN 
            RAISE EXCEPTION 'INVALID_COORDINATES: La latitud debe estar entre -90 y 90. Valor recibido: %.', v_lat 
            USING ERRCODE = 'P0122'; 
        END IF; 
        
        IF v_lng IS NOT NULL AND (v_lng < -180 OR v_lng > 180) THEN 
            RAISE EXCEPTION 'INVALID_COORDINATES: La longitud debe estar entre -180 y 180. Valor recibido: %.', v_lng 
            USING ERRCODE = 'P0122'; 
        END IF; 
    END IF; 
    
    RETURN NEW; 
EXCEPTION 
    WHEN invalid_text_representation THEN 
        RAISE EXCEPTION 'INVALID_JSON_COORDINATES: Las coordenadas en el campo ubicacion no tienen formato numérico válido.' 
        USING ERRCODE = 'P0123'; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_finca_coordenadas_validas 
BEFORE INSERT OR UPDATE ON modulo9.fincas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_finca_coordenadas_validas(); 

-- ============================================================================= 
-- TRG-M9-18 — Protección de eliminación física de fincas 
-- Tabla: modulo9.fincas 
-- Evento: BEFORE DELETE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_finca_no_delete_con_dependencias() RETURNS TRIGGER AS $$ 
DECLARE 
    v_infra_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_infra_count FROM modulo9.infraestructuras WHERE id_finca = OLD.id_finca; 
    
    IF v_infra_count > 0 THEN 
        RAISE EXCEPTION 'FARM_HAS_DEPENDENCIES: La finca "%" tiene % infraestructura(s) asociada(s) y no puede eliminarse físicamente. Use la desactivación lógica (es_activo = false).', OLD.nombre, v_infra_count 
        USING ERRCODE = 'P0124'; 
    END IF; 
    
    RAISE EXCEPTION 'NO_PHYSICAL_DELETE: Las fincas no pueden eliminarse físicamente del sistema. Use la desactivación lógica (es_activo = false). Finca: "%".', OLD.nombre 
    USING ERRCODE = 'P0124'; 
    RETURN NULL; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_finca_no_delete 
BEFORE DELETE ON modulo9.fincas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_finca_no_delete_con_dependencias(); 

-- ============================================================================= 
-- TRG-M9-19 — Unicidad de nombre de infraestructura por finca (case-insensitive) 
-- Tabla: modulo9.infraestructuras 
-- Evento: BEFORE INSERT OR UPDATE OF nombre 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_infraestructura_nombre_unique_ci() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.infraestructuras 
    WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(NEW.nombre)) 
      AND id_finca = NEW.id_finca 
      AND id_infraestructura <> COALESCE(NEW.id_infraestructura, -1); 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_AREA: Ya existe un área productiva con el nombre "%" en esta finca (case-insensitive).', NEW.nombre 
        USING ERRCODE = 'P0125'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_infraestructura_nombre_unique_ci 
BEFORE INSERT OR UPDATE OF nombre ON modulo9.infraestructuras 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_infraestructura_nombre_unique_ci(); 

-- ============================================================================= 
-- TRG-M9-20 — Validación de superficie de infraestructura 
-- Tabla: modulo9.infraestructuras 
-- Evento: BEFORE INSERT OR UPDATE OF superficie 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_infraestructura_superficie_valida() RETURNS TRIGGER AS $$ 
BEGIN 
    IF NEW.superficie IS NULL OR NEW.superficie <= 0 THEN 
        RAISE EXCEPTION 'INVALID_SURFACE: La superficie del área productiva debe ser un valor positivo mayor a cero. Valor recibido: %.', NEW.superficie 
        USING ERRCODE = 'P0126'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_infraestructura_superficie_valida 
BEFORE INSERT OR UPDATE OF superficie ON modulo9.infraestructuras 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_infraestructura_superficie_valida(); 

-- ============================================================================= 
-- TRG-M9-21 — Bloqueo de desactivación de infraestructura con dependencias operativas 
-- Tabla: modulo9.infraestructuras 
-- Evento: BEFORE UPDATE OF es_activo 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_infraestructura_no_desactivar_en_uso() RETURNS TRIGGER AS $$ 
DECLARE 
    v_dispositivos INTEGER; 
    v_sensores INTEGER; 
BEGIN 
    IF OLD.es_activo = TRUE AND NEW.es_activo = FALSE THEN 
        SELECT COUNT(*) INTO v_dispositivos FROM modulo9.dispositivos_iot 
        WHERE id_infraestructura = OLD.id_infraestructura AND es_activo = TRUE; 
        
        SELECT COUNT(*) INTO v_sensores FROM modulo9.sensores_areas_asociadas 
        WHERE id_infraestructura = OLD.id_infraestructura AND tiene_estado = TRUE; 
        
        IF v_dispositivos > 0 OR v_sensores > 0 THEN 
            RAISE EXCEPTION 'AREA_IN_USE: El área "%" tiene % dispositivo(s) activo(s) y % sensor(es) asociado(s). Desvincule los recursos antes de desactivar la infraestructura.', OLD.nombre, v_dispositivos, v_sensores 
            USING ERRCODE = 'P0127'; 
        END IF; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_infraestructura_no_desactivar_en_uso 
BEFORE UPDATE OF es_activo ON modulo9.infraestructuras 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_infraestructura_no_desactivar_en_uso(); 

-- ============================================================================= 
-- TRG-M9-22 — Unicidad del serial de dispositivo IoT 
-- Tabla: modulo9.dispositivos_iot 
-- Evento: BEFORE INSERT 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_dispositivo_serial_unique() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count FROM modulo9.dispositivos_iot WHERE TRIM(serial) = TRIM(NEW.serial); 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'DUPLICATE_SERIAL: El número de serie "%" ya está registrado en el sistema. Cada dispositivo físico debe tener un único registro.', NEW.serial 
        USING ERRCODE = 'P0128'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_dispositivo_serial_unique 
BEFORE INSERT ON modulo9.dispositivos_iot 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_dispositivo_serial_unique(); 

-- ============================================================================= 
-- TRG-M9-23 — Bloqueo de eliminación física de dispositivos IoT con datos históricos 
-- Tabla: modulo9.dispositivos_iot 
-- Evento: BEFORE DELETE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_dispositivo_no_delete_con_historial() RETURNS TRIGGER AS $$ 
DECLARE 
    v_calibraciones INTEGER; 
    v_configuraciones INTEGER; 
    v_sensores INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_calibraciones FROM modulo9.calibraciones WHERE id_dispositivo_iot = OLD.id_dispositivo_iot; 
    SELECT COUNT(*) INTO v_configuraciones FROM modulo9.configuraciones_remotas WHERE id_dispositivo_iot = OLD.id_dispositivo_iot; 
    SELECT COUNT(*) INTO v_sensores FROM modulo9.sensores WHERE id_dispositivo_iot = OLD.id_dispositivo_iot; 
    
    IF v_calibraciones > 0 OR v_configuraciones > 0 OR v_sensores > 0 THEN 
        RAISE EXCEPTION 'DEVICE_HAS_HISTORY: El dispositivo con serial "%" tiene datos históricos asociados (% calibración(es), % configuración(es), % sensor(es)). Use la desactivación lógica (es_activo = false).', OLD.serial, v_calibraciones, v_configuraciones, v_sensores 
        USING ERRCODE = 'P0129'; 
    END IF; 
    
    RAISE EXCEPTION 'NO_PHYSICAL_DELETE: Los dispositivos IoT no pueden eliminarse físicamente. Use la desactivación lógica (es_activo = false). Serial: "%".', OLD.serial 
    USING ERRCODE = 'P0129'; 
    RETURN NULL; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_dispositivo_no_delete 
BEFORE DELETE ON modulo9.dispositivos_iot 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_dispositivo_no_delete_con_historial(); 

-- ============================================================================= 
-- TRG-M9-24 — Unicidad de asociación activa sensor-área 
-- Tabla: modulo9.sensores_areas_asociadas 
-- Evento: BEFORE INSERT 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_sensor_asociacion_unica_activa() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
    v_nombre_area VARCHAR(50); 
BEGIN 
    SELECT COUNT(*), MAX(i.nombre) INTO v_count, v_nombre_area 
    FROM modulo9.sensores_areas_asociadas saa 
    JOIN modulo9.infraestructuras i ON i.id_infraestructura = saa.id_infraestructura 
    WHERE saa.id_sensor = NEW.id_sensor AND saa.tiene_estado = TRUE; 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'SENSOR_ALREADY_ASSIGNED: El sensor ID % ya está activo en el área "%". Finalice la asociación actual antes de reasignarlo.', NEW.id_sensor, v_nombre_area 
        USING ERRCODE = 'P0130'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_sensor_asociacion_unica_activa 
BEFORE INSERT ON modulo9.sensores_areas_asociadas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_sensor_asociacion_unica_activa(); 

-- ============================================================================= 
-- TRG-M9-25 — Validación de dispositivo activo para calibración 
-- Tabla: modulo9.calibraciones 
-- Evento: BEFORE INSERT 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_calibracion_dispositivo_activo() RETURNS TRIGGER AS $$ 
DECLARE 
    v_es_activo BOOLEAN; 
    v_serial VARCHAR(50); 
BEGIN 
    SELECT es_activo, serial INTO v_es_activo, v_serial 
    FROM modulo9.dispositivos_iot 
    WHERE id_dispositivo_iot = NEW.id_dispositivo_iot; 
    
    IF NOT FOUND THEN 
        RAISE EXCEPTION 'DEVICE_NOT_FOUND: El dispositivo IoT con ID % no existe en el sistema.', NEW.id_dispositivo_iot 
        USING ERRCODE = 'P0131'; 
    END IF; 
    
    IF v_es_activo = FALSE THEN 
        RAISE EXCEPTION 'INACTIVE_DEVICE: No se puede registrar una calibración para el dispositivo "%" porque está inactivo. Active el dispositivo antes de calibrar.', v_serial 
        USING ERRCODE = 'P0132'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_calibracion_dispositivo_activo 
BEFORE INSERT ON modulo9.calibraciones 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_calibracion_dispositivo_activo(); 

-- ============================================================================= 
-- TRG-M9-26 — Unicidad de nombre de plantilla y versionado incremental automático 
-- Tabla: modulo9.plantillas 
-- Evento: BEFORE INSERT 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_plantilla_version_incremental() RETURNS TRIGGER AS $$ 
DECLARE 
    v_max_version INTEGER; 
BEGIN 
    SELECT MAX(version) INTO v_max_version 
    FROM modulo9.plantillas 
    WHERE LOWER(TRIM(template_name)) = LOWER(TRIM(NEW.template_name)); 
    
    IF v_max_version IS NULL THEN 
        NEW.version := 1; 
    ELSE 
        NEW.version := v_max_version + 1; 
    END IF; 
    
    NEW.fecha_creacion := now(); 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_plantilla_version_incremental 
BEFORE INSERT ON modulo9.plantillas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_plantilla_version_incremental(); 

-- ============================================================================= 
-- TRG-M9-27 — Inmutabilidad de plantillas (bloqueo de UPDATE y DELETE) 
-- Tabla: modulo9.plantillas 
-- Evento: BEFORE UPDATE / BEFORE DELETE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_plantilla_inmutable() RETURNS TRIGGER AS $$ 
BEGIN 
    IF TG_OP = 'DELETE' THEN 
        RAISE EXCEPTION 'IMMUTABLE_TEMPLATE: La plantilla "%" (v%) es inmutable y no puede eliminarse. Las plantillas son registros permanentes.', OLD.template_name, OLD.version 
        USING ERRCODE = 'P0134'; 
    END IF; 
    
    IF TG_OP = 'UPDATE' THEN 
        RAISE EXCEPTION 'IMMUTABLE_TEMPLATE: La plantilla "%" (v%) es inmutable. Para actualizar, genere una nueva versión mediante INSERT.', OLD.template_name, OLD.version 
        USING ERRCODE = 'P0134'; 
    END IF; 
    
    RETURN NULL; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_plantilla_inmutable_update 
BEFORE UPDATE ON modulo9.plantillas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_plantilla_inmutable(); 

CREATE TRIGGER trg_plantilla_inmutable_delete 
BEFORE DELETE ON modulo9.plantillas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_plantilla_inmutable(); 

-- ============================================================================= 
-- TRG-M9-28 — Auditoría de cambios en identidad visual 
-- Tabla: modulo9.identidad_visuales 
-- Evento: AFTER UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_identidad_visual_audit() RETURNS TRIGGER AS $$ 
BEGIN 
    INSERT INTO modulo9.auditorias_visuales ( 
        id_usuario, 
        fecha_creacion, 
        valor_anterior, 
        valor_nuevo 
    ) VALUES ( 
        NEW.id_usuario, 
        now(), 
        jsonb_build_object( 
            'logo_path', OLD.logo_path, 
            'primary_color', OLD.primary_color, 
            'secondary_color', OLD.secondary_color, 
            'org_display_name', OLD.org_display_name, 
            'version', OLD.version 
        ), 
        jsonb_build_object( 
            'logo_path', NEW.logo_path, 
            'primary_color', NEW.primary_color, 
            'secondary_color', NEW.secondary_color, 
            'org_display_name', NEW.org_display_name, 
            'version', NEW.version 
        ) 
    ); 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_identidad_visual_audit 
AFTER UPDATE ON modulo9.identidad_visuales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_identidad_visual_audit(); 

-- ============================================================================= 
-- TRG-M9-29 — Validación de colores hexadecimales en identidad visual 
-- Tabla: modulo9.identidad_visuales 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_identidad_visual_colores_validos() RETURNS TRIGGER AS $$ 
BEGIN 
    IF NEW.primary_color IS NOT NULL AND NEW.primary_color !~ '^#[0-9A-Fa-f]{6}$' THEN 
        RAISE EXCEPTION 'INVALID_COLOR: El color primario "%" no tiene formato hexadecimal válido (#RRGGBB de 6 dígitos).', NEW.primary_color 
        USING ERRCODE = 'P0135'; 
    END IF; 
    
    IF NEW.secondary_color IS NOT NULL AND NEW.secondary_color !~ '^#[0-9A-Fa-f]{6}$' THEN 
        RAISE EXCEPTION 'INVALID_COLOR: El color secundario "%" no tiene formato hexadecimal válido (#RRGGBB de 6 dígitos).', NEW.secondary_color 
        USING ERRCODE = 'P0135'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_identidad_visual_colores_validos 
BEFORE INSERT OR UPDATE ON modulo9.identidad_visuales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_identidad_visual_colores_validos(); 

-- ============================================================================= 
-- TRG-M9-30 — Validación de theme_mode en temas visuales 
-- Tabla: modulo9.temas_visuales 
-- Evento: BEFORE INSERT OR UPDATE OF theme_mode 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_tema_visual_valor_valido() RETURNS TRIGGER AS $$ 
BEGIN 
    IF NEW.theme_mode NOT IN (1, 2, 3) THEN 
        RAISE EXCEPTION 'INVALID_THEME: El tema visual "%" no es válido. Los valores permitidos son: 1 (Claro), 2 (Oscuro), 3 (Automático/Sistema).', NEW.theme_mode 
        USING ERRCODE = 'P0136'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_tema_visual_valor_valido 
BEFORE INSERT OR UPDATE OF theme_mode ON modulo9.temas_visuales 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_tema_visual_valor_valido(); 

-- ============================================================================= 
-- TRG-M9-31 — Validación de configuración remota: lógica de tiempos 
-- Tabla: modulo9.configuraciones_remotas 
-- Evento: BEFORE INSERT OR UPDATE 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_configuracion_remota_tiempos_validos() RETURNS TRIGGER AS $$ 
BEGIN 
    IF NEW.frecuencia_captura IS NULL OR NEW.frecuencia_captura <= 0 THEN 
        RAISE EXCEPTION 'INVALID_CONFIG: La frecuencia de captura debe ser un entero positivo mayor a 0. Valor recibido: %.', NEW.frecuencia_captura 
        USING ERRCODE = 'P0137'; 
    END IF; 
    
    IF NEW.intervalo_transmision IS NULL OR NEW.intervalo_transmision <= 0 THEN 
        RAISE EXCEPTION 'INVALID_CONFIG: El intervalo de transmisión debe ser un entero positivo mayor a 0. Valor recibido: %.', NEW.intervalo_transmision 
        USING ERRCODE = 'P0137'; 
    END IF; 
    
    IF NEW.intervalo_transmision < NEW.frecuencia_captura THEN 
        RAISE EXCEPTION 'INVALID_CONFIG: El intervalo de transmisión (%) no puede ser menor a la frecuencia de captura (%). No se puede transmitir antes de capturar.', NEW.intervalo_transmision, NEW.frecuencia_captura 
        USING ERRCODE = 'P0138'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_configuracion_remota_tiempos_validos 
BEFORE INSERT OR UPDATE ON modulo9.configuraciones_remotas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_configuracion_remota_tiempos_validos(); 

-- ============================================================================= 
-- TRG-M9-32 — Unicidad de configuración remota PENDIENTE por dispositivo 
-- Tabla: modulo9.configuraciones_remotas 
-- Evento: BEFORE INSERT 
-- ============================================================================= 
CREATE OR REPLACE FUNCTION modulo9.trg_fn_configuracion_remota_sin_pendiente() RETURNS TRIGGER AS $$ 
DECLARE 
    v_count INTEGER; 
BEGIN 
    SELECT COUNT(*) INTO v_count 
    FROM modulo9.configuraciones_remotas 
    WHERE id_dispositivo_iot = NEW.id_dispositivo_iot AND estado = 'PENDIENTE'; 
    
    IF v_count > 0 THEN 
        RAISE EXCEPTION 'PENDING_CONFIG_EXISTS: Ya existe una configuración PENDIENTE para el dispositivo ID %. Espere a que se aplique o cancélela antes de enviar una nueva.', NEW.id_dispositivo_iot 
        USING ERRCODE = 'P0139'; 
    END IF; 
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql; 

CREATE TRIGGER trg_configuracion_remota_sin_pendiente 
BEFORE INSERT ON modulo9.configuraciones_remotas 
FOR EACH ROW EXECUTE FUNCTION modulo9.trg_fn_configuracion_remota_sin_pendiente(); 

-- ============================================================================= 
-- Total de funciones de trigger: 32 
-- Total de triggers registrados: 34 
-- (TRG-M9-27 crea 2 triggers con 1 función: update + delete) 
-- =============================================================================