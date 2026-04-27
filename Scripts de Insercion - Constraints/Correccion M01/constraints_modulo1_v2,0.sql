-- ================================================================
-- CONSTRAINTS MÓDULO 1
-- Versión: 2.0  (correcciones según revisión técnica Correccion_Modulo1.md)
-- ================================================================
--
-- CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
--
-- [C1] chk_sesiones_fechas_coherentes — CORRECCIÓN OBLIGATORIA:
--       fecha_inicio es timestamptz y fecha_finalizacion es timetz.
--       La comparación <= entre ambos tipos no es semánticamente
--       válida. Se agrega primero el ALTER COLUMN para cambiar el
--       tipo de fecha_finalizacion a timestamptz y luego se declara
--       el constraint con tipos compatibles.
--
-- [C2] chk_permisos_es_activo_not_null — ELIMINADO:
--       La columna es_activo ya tiene NOT NULL en el DDL de permisos.
--       El constraint era redundante y duplicaba la regla.
--
-- [C3] chk_usuarios_version_positiva — ELIMINADO:
--       La columna version tiene DEFAULT 1 NOT NULL en el DDL de
--       usuarios, lo que ya garantiza version >= 1 en toda inserción.
--
-- [C4] chk_notificaciones_es_leido_not_null — ELIMINADO:
--       La columna es_leido ya tiene NOT NULL en el DDL de
--       notificaciones. El constraint era redundante.
--
-- ================================================================


-- ================================================================
-- PASO 0 — CORRECCIÓN DE TIPO (OBLIGATORIA ANTES DEL CONSTRAINT)
-- Cambia fecha_finalizacion de timetz a timestamptz en sesiones.
-- Sin este cambio, chk_sesiones_fechas_coherentes falla por
-- incompatibilidad de tipos entre fecha_inicio (timestamptz) y
-- fecha_finalizacion (timetz).
-- ================================================================

ALTER TABLE modulo1.sesiones
    ALTER COLUMN fecha_finalizacion TYPE TIMESTAMPTZ
        USING fecha_finalizacion::TIME AT TIME ZONE 'UTC';

-- Nota: la expresión USING convierte los valores timetz existentes
-- a timestamptz usando la zona horaria UTC. Si la aplicación maneja
-- otra zona, reemplazar 'UTC' por la zona correspondiente
-- (ej. 'America/Bogota').


-- ================================================================
-- PARTE 1 — CHECK CONSTRAINTS NUEVOS
-- (los 4 chk_usuario_* ya están como inline en el DDL de usuarios)
-- ================================================================

-- ----------------------------------------------------------------
-- [RF-02] Intentos fallidos: no puede ser negativo ni exceder 5
-- Restricción explícita RF-02:
--   "El sistema permitirá un máximo de 5 intentos fallidos"
-- ----------------------------------------------------------------
ALTER TABLE modulo1.cuentas_usuarios
    ADD CONSTRAINT chk_cuentas_intentos_no_negativos
        CHECK (intentos_fallidos >= 0);

ALTER TABLE modulo1.cuentas_usuarios
    ADD CONSTRAINT chk_cuentas_intentos_max_cinco
        CHECK (intentos_fallidos <= 5);

-- ----------------------------------------------------------------
-- [RF-04] Código de acción RBAC: solo los valores del modelo
-- El backup tiene UNIQUE en codigo pero no CHECK de dominio.
-- Restricción explícita RF-04:
--   "Las acciones disponibles serán: C=Crear, R=Leer,
--    U=Actualizar, D=Eliminar, E=Ejecutar"
-- ----------------------------------------------------------------
ALTER TABLE modulo1.acciones
    ADD CONSTRAINT chk_acciones_codigo_dominio
        CHECK (codigo IN ('C', 'R', 'U', 'D', 'E'));

-- ----------------------------------------------------------------
-- [RF-02] Sesión: fecha_inicio <= fecha_finalizacion
-- Ahora válido porque ambas columnas son timestamptz (ver PASO 0).
-- Restricción explícita RF-02:
--   "El token tendrá una vigencia máxima de 8 horas"
-- ----------------------------------------------------------------
ALTER TABLE modulo1.sesiones
    ADD CONSTRAINT chk_sesiones_fechas_coherentes
        CHECK (fecha_inicio <= fecha_finalizacion);


-- ================================================================
-- PARTE 2 — ÍNDICE PARCIAL ÚNICO
-- Garantiza que solo exista UNA sesión activa por cuenta de usuario
-- en un momento dado.
-- Restricción explícita RF-02:
--   "Un usuario solo podrá tener una sesión activa simultáneamente.
--    Si inicia sesión en otro dispositivo, se invalidará la anterior."
-- ================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uix_sesiones_activa_por_cuenta
    ON modulo1.sesiones (id_cuenta_usuario)
    WHERE es_activa = TRUE;


-- ================================================================
-- REFERENCIA: CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (no se re-ejecutan; listados para consulta)
-- ================================================================
--
-- Claves Primarias (ya en backup):
--   acciones_pkey, estados_cuenta_pkey, eventos_pkey,
--   gestiones_cuenta_pkey, notificaciones_canal_pkey,
--   notificaciones_pkey, permisos_pkey, recursos_pkey,
--   roles_pkey, sesiones_pkey, tipos_evento_pkey,
--   tokens_pkey, usuarios_pkey, uq_usuario_id (PK cuentas_usuarios)
--
-- Claves Únicas (ya en backup):
--   acciones_codigo_key             → UNIQUE (codigo)
--   sesiones_id_token_id_token1_key → UNIQUE (id_token)
--   uq_estados_cuenta_nombre        → UNIQUE (nombre)
--   uq_nombre                       → UNIQUE (nombre_rol)
--   uq_nombre_recurso               → UNIQUE (nombre_recurso)
--   uq_permiso_unico                → UNIQUE (id_rol, id_recurso, id_accion)
--   uq_tipos_evento_nombre          → UNIQUE (nombre)
--   uq_usuario                      → UNIQUE (id_usuario) en cuentas_usuarios
--   uq_usuario_correo_electronico   → UNIQUE (correo_electronico)
--   uq_usuario_numero_identificacion → UNIQUE (numero_identificacion)
--
-- Claves Foráneas (ya en backup):
--   fk_accion_permiso     permisos(id_accion)      → acciones
--   fk_cuenta             gestiones_cuenta          → cuentas_usuarios
--   fk_cuenta_usuario     sesiones                  → cuentas_usuarios
--   fk_estado_cuenta      cuentas_usuarios          → estados_cuentas
--   fk_evento             notificaciones            → eventos
--   fk_notificacion_canal notificaciones            → notificaciones_canal
--   fk_recurso_permiso    permisos(id_recurso)      → recursos
--   fk_recurso_rol        permisos(id_rol)          → roles
--   fk_rol                usuarios                  → roles
--   fk_tipo_evento        eventos                   → tipos_eventos
--   fk_token              sesiones                  → tokens
--   fk_usuario            cuentas_usuarios          → usuarios
--   fk_usuario            eventos                   → usuarios
--   fk_usuario            notificaciones            → usuarios
--   fk_usuario_responsable gestiones_cuenta         → usuarios
--
-- CHECK Constraints inline en DDL de usuarios (ya en backup):
--   chk_usuario_tipo_identificacion → IN ('CC','CE','Pasaporte')
--   chk_usuario_formato_correo      → regex de email
--   chk_usuario_nombre_validos      → regex letras y español
--   chk_usuario_apellidos_validos   → regex letras y español
--
-- Constraints eliminados en v2.0 (eran redundantes con el DDL):
--   chk_permisos_es_activo_not_null  → es_activo ya tiene NOT NULL
--   chk_usuarios_version_positiva    → version tiene DEFAULT 1 NOT NULL
--   chk_notificaciones_es_leido_not_null → es_leido ya tiene NOT NULL
-- ================================================================
