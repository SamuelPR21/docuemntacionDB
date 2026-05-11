-- =============================================================================
-- MÓDULO 8 — INTELIGENCIA DE NEGOCIO Y REPORTES
-- Archivo: triggers_modulo8_v1_0.sql
-- Descripción: Triggers y funciones de trigger para garantizar integridad
--              de datos, invariantes estructurales y reglas de negocio
--              que deben ser protegidas a nivel de base de datos.
-- Esquema: modulo8
-- Motor: PostgreSQL
-- Versión: 1.0
-- =============================================================================

-- ÍNDICE
-- TGR-M08-01  Unicidad del dashboard predeterminado por usuario
-- TGR-M08-02  Validación de coherencia de umbrales de semáforo (min <= max por banda)
-- TGR-M08-03  Integridad del ciclo de vida del reporte regulatorio (estado y ruta_archivo)
-- TGR-M08-04  Hash SHA-256 obligatorio en reportes financieros con ruta_archivo
-- TGR-M08-05  Inmutabilidad de retroalimentaciones clínicas (append-only)
-- TGR-M08-06  Detección automática de conflictos en retroalimentación clínica
-- TGR-M08-07  Validación de rango de fechas en historial clínico (máximo 24 meses)
-- TGR-M08-08  Inmutabilidad del log de auditoría de acciones críticas (append-only)
-- TGR-M08-09  Consistencia entre requiere_confirmacion y confirmacion en acciones críticas
-- TGR-M08-10  Integridad geométrica de widgets del dashboard (posición y dimensiones)
-- TGR-M08-11  Validación del dominio de estado_final en auditorías de reportes
-- TGR-M08-12  Integridad temporal de snapshots de KPI (sin fechas futuras)

-- =============================================================================
-- TGR-M08-01 — Unicidad del dashboard predeterminado por usuario
-- Tabla:  modulo8.dashboards
-- Evento: BEFORE INSERT OR UPDATE OF es_predeterminado
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_01_prevent_dashboard_predeterminado_duplicado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.es_predeterminado = TRUE THEN
        UPDATE modulo8.dashboards
        SET    es_predeterminado = FALSE
        WHERE  id_usuario        = NEW.id_usuario
          AND  es_predeterminado = TRUE
          AND  id_dashboard IS DISTINCT FROM NEW.id_dashboard;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_01_prevent_dashboard_predeterminado_duplicado()
    IS 'Garantiza unicidad del dashboard predeterminado por usuario. Desactiva el anterior '
       'cuando se activa uno nuevo para el mismo usuario. Cubre la integridad de datos del '
       'campo es_predeterminado en RF-103.';

CREATE OR REPLACE TRIGGER trg_m08_01_prevent_dashboard_predeterminado_duplicado
    BEFORE INSERT OR UPDATE OF es_predeterminado
    ON modulo8.dashboards
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_01_prevent_dashboard_predeterminado_duplicado();

COMMENT ON TRIGGER trg_m08_01_prevent_dashboard_predeterminado_duplicado
    ON modulo8.dashboards
    IS 'TGR-M08-01 | RF-103 Restricción 6 | Unicidad del dashboard predeterminado por usuario. '
       'Previene que un usuario tenga más de un dashboard con es_predeterminado = TRUE. '
       'Garantiza atomicidad bajo concurrencia que el backend no puede asegurar por sí solo.';

-- =============================================================================
-- TGR-M08-02 — Validación de coherencia de umbrales de semáforo (min <= max por banda)
-- Tabla:  modulo8.configuraciones_semaforo
-- Evento: BEFORE INSERT OR UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_02_validate_semaforo_umbrales_consistencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.umbral_verde_min IS NOT NULL AND NEW.umbral_verde_max IS NOT NULL THEN
        IF NEW.umbral_verde_min > NEW.umbral_verde_max THEN
            RAISE EXCEPTION
                '[TGR-M08-02] SEMAFORO_UMBRAL_INVALIDO: umbral_verde_min (%) no puede ser '
                'mayor que umbral_verde_max (%) para id_configuracion_semaforo=%. '
                'Una configuración con min > max hace imposible la evaluación de KPI. '
                'Requerimiento RF-103, Restricción 5 (lógica de semáforo).',
                NEW.umbral_verde_min, NEW.umbral_verde_max, NEW.id_configuracion_semaforo
            USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    IF NEW.umbral_amarillo_min IS NOT NULL AND NEW.umbral_amarillo_max IS NOT NULL THEN
        IF NEW.umbral_amarillo_min > NEW.umbral_amarillo_max THEN
            RAISE EXCEPTION
                '[TGR-M08-02] SEMAFORO_UMBRAL_INVALIDO: umbral_amarillo_min (%) no puede ser '
                'mayor que umbral_amarillo_max (%) para id_configuracion_semaforo=%. '
                'Una configuración con min > max hace imposible la evaluación de KPI. '
                'Requerimiento RF-103, Restricción 5 (lógica de semáforo).',
                NEW.umbral_amarillo_min, NEW.umbral_amarillo_max, NEW.id_configuracion_semaforo
            USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    IF NEW.umbral_rojo_min IS NOT NULL AND NEW.umbral_rojo_max IS NOT NULL THEN
        IF NEW.umbral_rojo_min > NEW.umbral_rojo_max THEN
            RAISE EXCEPTION
                '[TGR-M08-02] SEMAFORO_UMBRAL_INVALIDO: umbral_rojo_min (%) no puede ser '
                'mayor que umbral_rojo_max (%) para id_configuracion_semaforo=%. '
                'Una configuración con min > max hace imposible la evaluación de KPI. '
                'Requerimiento RF-103, Restricción 5 (lógica de semáforo).',
                NEW.umbral_rojo_min, NEW.umbral_rojo_max, NEW.id_configuracion_semaforo
            USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_02_validate_semaforo_umbrales_consistencia()
    IS 'Valida consistencia interna de los umbrales de semáforo (min <= max por banda). '
       'Evita configuraciones malformadas que generarían evaluaciones de KPI incorrectas. '
       'Cubre la integridad de datos requerida por la lógica de semáforo del Productor en RF-103.';

CREATE OR REPLACE TRIGGER trg_m08_02_validate_semaforo_umbrales_consistencia
    BEFORE INSERT OR UPDATE
    ON modulo8.configuraciones_semaforo
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_02_validate_semaforo_umbrales_consistencia();

COMMENT ON TRIGGER trg_m08_02_validate_semaforo_umbrales_consistencia
    ON modulo8.configuraciones_semaforo
    IS 'TGR-M08-02 | RF-103 Restricción 5 | Validación de coherencia de umbrales de semáforo. '
       'Rechaza configuraciones donde umbral_min > umbral_max en cualquier banda '
       '(verde / amarillo / rojo). Garantiza que los cálculos de snapshot de KPI sean correctos.';

-- =============================================================================
-- TGR-M08-03 — Integridad del ciclo de vida del reporte regulatorio (estado y ruta_archivo)
-- Tabla:  modulo8.reportes_regulatorios
-- Evento: BEFORE INSERT OR UPDATE OF estado, ruta_archivo
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_03_reporte_regulatorio_fecha_expiracion_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.estado::TEXT = 'COMPLETADO'
       AND (NEW.ruta_archivo IS NULL OR TRIM(NEW.ruta_archivo) = '')
    THEN
        RAISE EXCEPTION
            '[TGR-M08-03] REPORTE_SIN_RUTA: No se puede marcar el reporte regulatorio '
            '(id=%) como COMPLETADO sin ruta_archivo definida. Un reporte completado sin '
            'ruta de archivo es un estado corrupto que haría fallar cualquier intento de '
            'descarga. Requerimiento RF-104, ciclo de vida del reporte.',
            NEW.id_reporte_regulatorio
        USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'INSERT' AND NEW.fecha_generacion IS NULL THEN
        NEW.fecha_generacion = NOW();
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_03_reporte_regulatorio_fecha_expiracion_estado()
    IS 'Valida que un reporte regulatorio no pueda transicionar a COMPLETADO sin ruta_archivo. '
       'Garantiza integridad del ciclo de vida del reporte definido en RF-104. '
       'También asegura que fecha_generacion se asigne en el INSERT si no viene provista.';

CREATE OR REPLACE TRIGGER trg_m08_03_reporte_regulatorio_fecha_expiracion_estado
    BEFORE INSERT OR UPDATE OF estado, ruta_archivo
    ON modulo8.reportes_regulatorios
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_03_reporte_regulatorio_fecha_expiracion_estado();

COMMENT ON TRIGGER trg_m08_03_reporte_regulatorio_fecha_expiracion_estado
    ON modulo8.reportes_regulatorios
    IS 'TGR-M08-03 | RF-104 | Integridad del ciclo de vida del reporte regulatorio. '
       'Impide estado COMPLETADO sin ruta_archivo. Garantiza fecha_generacion en INSERT. '
       'Previene estados corruptos que bloquearían la descarga del archivo generado.';

-- =============================================================================
-- TGR-M08-04 — Hash SHA-256 obligatorio en reportes financieros con ruta_archivo
-- Tabla:  modulo8.reportes_financieros
-- Evento: BEFORE INSERT OR UPDATE OF ruta_archivo, sha256_archivo
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_04_reporte_financiero_hash_obligatorio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.ruta_archivo IS NOT NULL AND TRIM(NEW.ruta_archivo) <> '' THEN

        IF NEW.sha256_archivo IS NULL OR TRIM(NEW.sha256_archivo) = '' THEN
            RAISE EXCEPTION
                '[TGR-M08-04] REPORTE_HASH_FALTANTE: El reporte financiero (id=%) tiene '
                'ruta_archivo pero no tiene sha256_archivo. Todo archivo almacenado debe '
                'incluir su hash de integridad para permitir la verificación definida en '
                'RNF-10. Requerimiento RF-104 RNF-10 y Postcondiciones.',
                NEW.id_reporte_financiero
            USING ERRCODE = 'check_violation';
        END IF;

        IF LENGTH(NEW.sha256_archivo) <> 64 THEN
            RAISE EXCEPTION
                '[TGR-M08-04] REPORTE_HASH_INVALIDO: sha256_archivo debe tener exactamente '
                '64 caracteres hexadecimales. Recibido: % caracteres para '
                'id_reporte_financiero=%. Requerimiento RF-104 RNF-10.',
                LENGTH(NEW.sha256_archivo), NEW.id_reporte_financiero
            USING ERRCODE = 'check_violation';
        END IF;

        IF NEW.sha256_archivo !~ '^[a-fA-F0-9]{64}$' THEN
            RAISE EXCEPTION
                '[TGR-M08-04] REPORTE_HASH_FORMATO_INVALIDO: sha256_archivo contiene '
                'caracteres no hexadecimales en id_reporte_financiero=%. '
                'Solo se admiten dígitos hexadecimales (a-f, A-F, 0-9). '
                'Requerimiento RF-104 RNF-10.',
                NEW.id_reporte_financiero
            USING ERRCODE = 'check_violation';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_04_reporte_financiero_hash_obligatorio()
    IS 'Garantiza que todo reporte financiero con ruta_archivo tenga su sha256_archivo válido '
       '(64 caracteres hexadecimales). Cubre el RNF-10 de RF-104 sobre integridad de archivos. '
       'Un registro con ruta_archivo pero sin hash nunca podrá ser verificado antes de la descarga.';

CREATE OR REPLACE TRIGGER trg_m08_04_reporte_financiero_hash_obligatorio
    BEFORE INSERT OR UPDATE OF ruta_archivo, sha256_archivo
    ON modulo8.reportes_financieros
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_04_reporte_financiero_hash_obligatorio();

COMMENT ON TRIGGER trg_m08_04_reporte_financiero_hash_obligatorio
    ON modulo8.reportes_financieros
    IS 'TGR-M08-04 | RF-104 RNF-10 | Integridad de hash SHA-256 en reportes financieros. '
       'Rechaza registros con ruta_archivo pero sin sha256_archivo válido de 64 caracteres '
       'hexadecimales. Garantiza que el checksum de integridad siempre esté presente y sea correcto.';

-- =============================================================================
-- TGR-M08-05 — Inmutabilidad de retroalimentaciones clínicas (append-only)
-- Tabla:  modulo8.retroalimentacion_feedback
-- Evento: BEFORE UPDATE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_05_retroalimentacion_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        '[TGR-M08-05] RETROALIMENTACION_INMUTABLE: Las retroalimentaciones clínicas son '
        'append-only. No se permite modificar el registro id=%. Para corregir, registre '
        'una nueva retroalimentación a través del formulario de RF-72. '
        'Requerimiento RF-106, Restricción 3 (RF-72 es append-only).',
        OLD.id_retroalimentacion_feedback
    USING ERRCODE = 'insufficient_privilege';
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_05_retroalimentacion_append_only()
    IS 'Impide UPDATE sobre retroalimentaciones clínicas. La tabla es append-only según RF-106 '
       '(RF-72 es append-only). Garantiza trazabilidad histórica de valoraciones clínicas '
       'y consistencia del cálculo de TVCO.';

CREATE OR REPLACE TRIGGER trg_m08_05_retroalimentacion_append_only
    BEFORE UPDATE
    ON modulo8.retroalimentacion_feedback
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_05_retroalimentacion_append_only();

COMMENT ON TRIGGER trg_m08_05_retroalimentacion_append_only
    ON modulo8.retroalimentacion_feedback
    IS 'TGR-M08-05 | RF-106 Restricción 3 | Inmutabilidad de retroalimentaciones clínicas. '
       'Bloquea cualquier UPDATE en retroalimentacion_feedback. Solo INSERT permitido (append-only). '
       'La pérdida de historial de valoraciones haría inconsistente el cálculo de TVCO.';

-- =============================================================================
-- TGR-M08-06 — Detección automática de conflictos en retroalimentación clínica
-- Tabla:  modulo8.retroalimentacion_feedback
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_06_retroalimentacion_conflicto_detector()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflicto_detectado BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM   modulo8.retroalimentacion_feedback
        WHERE  id_historial_clinico            = NEW.id_historial_clinico
          AND  estado IS DISTINCT FROM          NEW.estado
          AND  id_retroalimentacion_feedback IS DISTINCT FROM NEW.id_retroalimentacion_feedback
    ) INTO v_conflicto_detectado;

    IF v_conflicto_detectado THEN
        NEW.tiene_conflicto := TRUE;

        UPDATE modulo8.retroalimentacion_feedback
        SET    tiene_conflicto = TRUE
        WHERE  id_historial_clinico = NEW.id_historial_clinico
          AND  estado IS DISTINCT FROM NEW.estado;
    ELSE
        NEW.tiene_conflicto := FALSE;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_06_retroalimentacion_conflicto_detector()
    IS 'Detecta conflictos entre retroalimentaciones del mismo historial clínico con distintos estados. '
       'Actualiza tiene_conflicto=TRUE en la nueva fila y en las previas en conflicto. '
       'Garantiza consistencia del flag usado en el cálculo de TVCO en RF-106 Restricción 6.';

CREATE OR REPLACE TRIGGER trg_m08_06_retroalimentacion_conflicto_detector
    BEFORE INSERT
    ON modulo8.retroalimentacion_feedback
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_06_retroalimentacion_conflicto_detector();

COMMENT ON TRIGGER trg_m08_06_retroalimentacion_conflicto_detector
    ON modulo8.retroalimentacion_feedback
    IS 'TGR-M08-06 | RF-106 Restricción 6 | Detección automática de conflictos en retroalimentación clínica. '
       'Marca tiene_conflicto=TRUE cuando dos valoraciones distintas existen para el mismo historial. '
       'Garantiza que cualquier lectura posterior al INSERT ya refleje el estado de conflicto correcto.';

-- =============================================================================
-- TGR-M08-07 — Validación de rango de fechas en historial clínico (máximo 24 meses)
-- Tabla:  modulo8.historiales_clinicos
-- Evento: BEFORE INSERT OR UPDATE OF fecha_inicio, fecha_fin, procentaje_probabilidad
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_07_historial_clinico_fechas_consistencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha_inicio > NEW.fecha_fin THEN
        RAISE EXCEPTION
            '[TGR-M08-07] HISTORIAL_FECHAS_INVERTIDAS: fecha_inicio (%) no puede ser '
            'posterior a fecha_fin (%) en id_historial_clinicos=%. Un rango invertido '
            'produciría resultados vacíos e invalidaría la línea de tiempo clínica. '
            'Requerimiento RF-106, Restricción 2.',
            NEW.fecha_inicio, NEW.fecha_fin, NEW.id_historial_clinicos
        USING ERRCODE = 'check_violation';
    END IF;

    IF (NEW.fecha_fin - NEW.fecha_inicio) > 730 THEN
        RAISE EXCEPTION
            '[TGR-M08-07] HISTORIAL_RANGO_EXCEDIDO: El rango entre fecha_inicio (%) y '
            'fecha_fin (%) supera los 24 meses permitidos (% días) en id_historial_clinicos=%. '
            'Para historiales más largos, el Veterinario debe seleccionar un subrango. '
            'Requerimiento RF-106, Restricción 2 (rango máximo de 24 meses).',
            NEW.fecha_inicio, NEW.fecha_fin, (NEW.fecha_fin - NEW.fecha_inicio), NEW.id_historial_clinicos
        USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.procentaje_probabilidad < 0 OR NEW.procentaje_probabilidad > 100 THEN
        RAISE EXCEPTION
            '[TGR-M08-07] HISTORIAL_PROBABILIDAD_INVALIDA: procentaje_probabilidad (%) '
            'debe estar entre 0 y 100 en id_historial_clinicos=%. '
            'Requerimiento RF-106, integridad de datos del historial clínico.',
            NEW.procentaje_probabilidad, NEW.id_historial_clinicos
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_07_historial_clinico_fechas_consistencia()
    IS 'Valida coherencia de rango de fechas en historiales clínicos: fecha_inicio <= fecha_fin '
       'y rango máximo de 24 meses (730 días). También valida que procentaje_probabilidad '
       'esté entre 0 y 100. Cubre Restricción 2 de RF-106.';

CREATE OR REPLACE TRIGGER trg_m08_07_historial_clinico_fechas_consistencia
    BEFORE INSERT OR UPDATE OF fecha_inicio, fecha_fin, procentaje_probabilidad
    ON modulo8.historiales_clinicos
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_07_historial_clinico_fechas_consistencia();

COMMENT ON TRIGGER trg_m08_07_historial_clinico_fechas_consistencia
    ON modulo8.historiales_clinicos
    IS 'TGR-M08-07 | RF-106 Restricción 2 | Validación de rango de fechas en historial clínico. '
       'Rechaza fecha_inicio > fecha_fin y rangos superiores a 24 meses (730 días). '
       'También valida que procentaje_probabilidad esté en el rango [0, 100].';

-- =============================================================================
-- TGR-M08-08 — Inmutabilidad del log de auditoría de acciones críticas (append-only)
-- Tabla:  modulo8.acciones_critica_log
-- Evento: BEFORE UPDATE OR DELETE
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_08_accion_critica_log_inmutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION
            '[TGR-M08-08] AUDIT_LOG_INMUTABLE: El registro de auditoría de acción crítica '
            '(id=%) no puede ser modificado. Los logs de auditoría son registros forenses '
            'inmutables. Operación bloqueada: UPDATE. '
            'Requerimiento RF-107 Postcondiciones y RF-104 CA-15.',
            OLD.id_accion_critica_log
        USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            '[TGR-M08-08] AUDIT_LOG_INMUTABLE: El registro de auditoría de acción crítica '
            '(id=%) no puede ser eliminado. Los logs de auditoría son registros forenses '
            'inmutables. Operación bloqueada: DELETE. '
            'Requerimiento RF-107 Postcondiciones y RF-104 CA-15.',
            OLD.id_accion_critica_log
        USING ERRCODE = 'insufficient_privilege';
    END IF;

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_08_accion_critica_log_inmutable()
    IS 'Protege la inmutabilidad de la bitácora de auditoría de acciones críticas. '
       'Bloquea UPDATE y DELETE en acciones_critica_log. Solo INSERT permitido. '
       'Cubre la trazabilidad forense requerida por RF-107 Postcondiciones y RF-104 CA-15.';

CREATE OR REPLACE TRIGGER trg_m08_08_accion_critica_log_inmutable
    BEFORE UPDATE OR DELETE
    ON modulo8.acciones_critica_log
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_08_accion_critica_log_inmutable();

COMMENT ON TRIGGER trg_m08_08_accion_critica_log_inmutable
    ON modulo8.acciones_critica_log
    IS 'TGR-M08-08 | RF-107 Postcondiciones | Inmutabilidad del log de auditoría de acciones críticas. '
       'Bloquea UPDATE y DELETE. Garantiza integridad forense del registro de auditoría. '
       'Un log modificable pierde todo valor como evidencia de trazabilidad.';

-- =============================================================================
-- TGR-M08-09 — Consistencia entre requiere_confirmacion y confirmacion en acciones críticas
-- Tabla:  modulo8.acciones_critica_log
-- Evento: BEFORE INSERT OR UPDATE OF resultado_operacion, confirmacion, requiere_confirmacion
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_09_accion_critica_requiere_confirmacion_consistencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.requiere_confirmacion = TRUE
       AND NEW.resultado_operacion IS NOT NULL
       AND NEW.resultado_operacion::TEXT <> 'EN_CURSO'
       AND NEW.confirmacion IS NULL
    THEN
        RAISE EXCEPTION
            '[TGR-M08-09] ACCION_CRITICA_SIN_CONFIRMACION: La acción crítica tipo=% '
            '(id_operacion=%) requiere confirmacion explícita pero fue registrada sin el '
            'campo confirmacion. Posible bypass del modal de confirmación. '
            'Requerimiento RF-107, Sección 8.1 (fuente de verdad única de requiere_confirmacion).',
            NEW.tipo_accion, NEW.id_operacion
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_09_accion_critica_requiere_confirmacion_consistencia()
    IS 'Valida que toda acción crítica con requiere_confirmacion=TRUE tenga el campo confirmacion '
       'definido al registrar resultado final. Detecta bypasses del modal de confirmación en RF-107 '
       'Sección 8.1. Solo aplica a operaciones con resultado distinto de EN_CURSO.';

CREATE OR REPLACE TRIGGER trg_m08_09_accion_critica_requiere_confirmacion_consistencia
    BEFORE INSERT OR UPDATE OF resultado_operacion, confirmacion, requiere_confirmacion
    ON modulo8.acciones_critica_log
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_09_accion_critica_requiere_confirmacion_consistencia();

COMMENT ON TRIGGER trg_m08_09_accion_critica_requiere_confirmacion_consistencia
    ON modulo8.acciones_critica_log
    IS 'TGR-M08-09 | RF-107 Sección 8.1 | Consistencia entre requiere_confirmacion y confirmacion. '
       'Rechaza registros donde una acción crítica finaliza sin evidencia de confirmación del usuario. '
       'Las cinco acciones de la lista fija tienen requiere_confirmacion=TRUE de forma permanente.';

-- =============================================================================
-- TGR-M08-10 — Integridad geométrica de widgets del dashboard (posición y dimensiones)
-- Tabla:  modulo8.widgets_dashboard
-- Evento: BEFORE INSERT OR UPDATE OF posicion_x, posicion_y, ancho, alto
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_10_widget_posicion_no_negativa()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.posicion_x < 0 THEN
        RAISE EXCEPTION
            '[TGR-M08-10] WIDGET_POSICION_INVALIDA: posicion_x (%) no puede ser negativa '
            'en id_widget_dashboard=%. Un widget con posición negativa queda fuera de la '
            'pantalla. Requerimiento RF-103, integridad geométrica de widgets.',
            NEW.posicion_x, NEW.id_widget_dashboard
        USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.posicion_y < 0 THEN
        RAISE EXCEPTION
            '[TGR-M08-10] WIDGET_POSICION_INVALIDA: posicion_y (%) no puede ser negativa '
            'en id_widget_dashboard=%. Un widget con posición negativa queda fuera de la '
            'pantalla. Requerimiento RF-103, integridad geométrica de widgets.',
            NEW.posicion_y, NEW.id_widget_dashboard
        USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.ancho < 1 THEN
        RAISE EXCEPTION
            '[TGR-M08-10] WIDGET_DIMENSION_INVALIDA: ancho (%) debe ser al menos 1 unidad '
            'de grid en id_widget_dashboard=%. Un widget con ancho=0 es invisible en el '
            'dashboard. Requerimiento RF-103, integridad geométrica de widgets.',
            NEW.ancho, NEW.id_widget_dashboard
        USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.alto < 1 THEN
        RAISE EXCEPTION
            '[TGR-M08-10] WIDGET_DIMENSION_INVALIDA: alto (%) debe ser al menos 1 unidad '
            'de grid en id_widget_dashboard=%. Un widget con alto=0 es invisible en el '
            'dashboard. Requerimiento RF-103, integridad geométrica de widgets.',
            NEW.alto, NEW.id_widget_dashboard
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_10_widget_posicion_no_negativa()
    IS 'Valida integridad geométrica de widgets en el dashboard: posicion_x/y >= 0, '
       'ancho/alto >= 1. Previene widgets invisibles o fuera de pantalla. Cubre RF-103 '
       'configuración de widgets del dashboard operativo por rol.';

CREATE OR REPLACE TRIGGER trg_m08_10_widget_posicion_no_negativa
    BEFORE INSERT OR UPDATE OF posicion_x, posicion_y, ancho, alto
    ON modulo8.widgets_dashboard
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_10_widget_posicion_no_negativa();

COMMENT ON TRIGGER trg_m08_10_widget_posicion_no_negativa
    ON modulo8.widgets_dashboard
    IS 'TGR-M08-10 | RF-103 | Integridad geométrica de widgets del dashboard. '
       'Valida posicion_x/y >= 0 y ancho/alto >= 1. Previene widgets inválidos en el grid. '
       'Errores geométricos no son detectados por el backend hasta el intento de renderizado.';

-- =============================================================================
-- TGR-M08-11 — Validación del dominio de estado_final en auditorías de reportes
-- Tabla:  modulo8.auditorias_reportes
-- Evento: BEFORE INSERT OR UPDATE OF estado_final
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_11_auditoria_reporte_estado_valido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.estado_final IS NOT NULL
       AND NEW.estado_final NOT IN ('GENERADO', 'EN_PROCESO', 'FALLIDO', 'CANCELADO', 'EXPIRADO')
    THEN
        RAISE EXCEPTION
            '[TGR-M08-11] AUDITORIA_ESTADO_INVALIDO: estado_final="%" no es un valor válido. '
            'Valores permitidos: GENERADO, EN_PROCESO, FALLIDO, CANCELADO, EXPIRADO. '
            '(id_auditoria_reporte=%). La columna es VARCHAR sin ENUM; la BD actúa como '
            'guardián del dominio. Requerimiento RF-104, Salida (ciclo de vida del reporte).',
            NEW.estado_final, NEW.id_auditoria_reporte
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_11_auditoria_reporte_estado_valido()
    IS 'Valida que estado_final en auditorias_reportes pertenezca al dominio definido en RF-104: '
       'GENERADO, EN_PROCESO, FALLIDO, CANCELADO, EXPIRADO. '
       'Cubre la integridad del ciclo de vida de reportes ante el uso de VARCHAR sin ENUM.';

CREATE OR REPLACE TRIGGER trg_m08_11_auditoria_reporte_estado_valido
    BEFORE INSERT OR UPDATE OF estado_final
    ON modulo8.auditorias_reportes
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_11_auditoria_reporte_estado_valido();

COMMENT ON TRIGGER trg_m08_11_auditoria_reporte_estado_valido
    ON modulo8.auditorias_reportes
    IS 'TGR-M08-11 | RF-104 Salida | Validación del dominio de estado_final en auditorías de reportes. '
       'Garantiza que solo entren valores del ciclo de vida definido en RF-104. '
       'Actúa como constraint de dominio ante la ausencia de tipo ENUM en la columna.';

-- =============================================================================
-- TGR-M08-12 — Integridad temporal de snapshots de KPI (sin fechas futuras)
-- Tabla:  modulo8.snapshots_kpi
-- Evento: BEFORE INSERT
-- =============================================================================
CREATE OR REPLACE FUNCTION modulo8.fn_trg_m08_12_snapshot_kpi_fecha_no_futura()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha_calculo > (NOW() + INTERVAL '5 minutes') THEN
        RAISE EXCEPTION
            '[TGR-M08-12] SNAPSHOT_FECHA_FUTURA: fecha_calculo (%) es una fecha futura. '
            'Los snapshots de KPI solo pueden registrarse para el momento actual o pasado. '
            'Tolerancia de 5 minutos para compensar latencias de procesamiento. '
            'id_snapshot_kpi=%. Requerimiento RF-103, integridad temporal de snapshots.',
            NEW.fecha_calculo, NEW.id_snapshot_kpi
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION modulo8.fn_trg_m08_12_snapshot_kpi_fecha_no_futura()
    IS 'Impide el registro de snapshots de KPI con fecha_calculo en el futuro. '
       'Un snapshot representa el estado medido en un momento pasado o presente. '
       'Tolerancia de 5 minutos para compensar latencias de procesamiento. Cubre RF-103.';

CREATE OR REPLACE TRIGGER trg_m08_12_snapshot_kpi_fecha_no_futura
    BEFORE INSERT
    ON modulo8.snapshots_kpi
    FOR EACH ROW
    EXECUTE FUNCTION modulo8.fn_trg_m08_12_snapshot_kpi_fecha_no_futura();

COMMENT ON TRIGGER trg_m08_12_snapshot_kpi_fecha_no_futura
    ON modulo8.snapshots_kpi
    IS 'TGR-M08-12 | RF-103 | Integridad temporal de snapshots de KPI. '
       'Rechaza fecha_calculo > NOW() + 5 min. Los snapshots solo registran estados pasados '
       'o presentes. Un snapshot futuro contaminaría históricos y tendencias del dashboard.';

-- =============================================================================
-- Total de funciones de trigger: 12 (1 por cada trigger, sin funciones compartidas)
-- Total de triggers registrados: 12
--   TGR-M08-01  dashboards
--   TGR-M08-02  configuraciones_semaforo
--   TGR-M08-03  reportes_regulatorios
--   TGR-M08-04  reportes_financieros
--   TGR-M08-05  retroalimentacion_feedback
--   TGR-M08-06  retroalimentacion_feedback
--   TGR-M08-07  historiales_clinicos
--   TGR-M08-08  acciones_critica_log
--   TGR-M08-09  acciones_critica_log
--   TGR-M08-10  widgets_dashboard
--   TGR-M08-11  auditorias_reportes
--   TGR-M08-12  snapshots_kpi
-- =============================================================================