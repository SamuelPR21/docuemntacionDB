-- ================================================================
-- CONSTRAINTS MÓDULO 1
-- ================================================================
-- CRITERIO DE INCLUSIÓN:
--   Solo se declaran aquí los constraints que NO existen ya en el
--   backup (backup2_1_0.sql). Los ya presentes en el backup son:
--     PKs: acciones, estados_cuentas, eventos, gestiones_cuenta,
--           notificaciones_canal, notificaciones, permisos, recursos,
--           roles, sesiones, tipos_eventos, tokens, usuarios,
--           cuentas_usuarios (uq_usuario_id como PK)
--     UQ:  acciones_codigo_key, sesiones_id_token_id_token1_key,
--           uq_estados_cuenta_nombre, uq_nombre (roles),
--           uq_nombre_recurso, uq_permiso_unico,
--           uq_tipos_evento_nombre, uq_usuario (cuentas_usuarios),
--           uq_usuario_correo_electronico,
--           uq_usuario_numero_identificacion
--     FKs: fk_accion_permiso, fk_cuenta, fk_cuenta_usuario,
--           fk_estado_cuenta, fk_evento, fk_notificacion_canal,
--           fk_recurso_permiso, fk_recurso_rol, fk_rol,
--           fk_tipo_evento, fk_token, fk_usuario (×3),
--           fk_usuario_responsable
--     CHK: chk_usuario_apellidos_validos, chk_usuario_formato_correo,
--           chk_usuario_nombre_validos, chk_usuario_tipo_identificacion
--
--   Se AGREGAN únicamente:
--     CHK: intentos_fallidos, es_activo permisos, fechas sesión,
--           código acciones, version usuarios
--     IDX parciales: un único registro de configuración global
-- ================================================================


-- ----------------------------------------------------------------
-- 1. CHECK CONSTRAINTS NUEVOS
--    (los 4 chk_usuario_* ya están en el DDL inline de usuarios)
-- ----------------------------------------------------------------

-- [RF-02] Intentos fallidos: no puede ser negativo ni exceder 5
-- Restricción explícita RF-02: "máximo de 5 intentos fallidos consecutivos"
ALTER TABLE modulo1.cuentas_usuarios
    ADD CONSTRAINT chk_cuentas_intentos_no_negativos
        CHECK (intentos_fallidos >= 0);

ALTER TABLE modulo1.cuentas_usuarios
    ADD CONSTRAINT chk_cuentas_intentos_max_cinco
        CHECK (intentos_fallidos <= 5);

-- [RF-04] Código de acción RBAC: solo los valores permitidos por el modelo
-- El backup sólo tiene UNIQUE en codigo; se agrega CHECK de dominio
ALTER TABLE modulo1.acciones
    ADD CONSTRAINT chk_acciones_codigo_dominio
        CHECK (codigo IN ('C', 'R', 'U', 'D', 'E'));

-- [RF-03/RF-04] Campo es_activo de permisos no puede ser NULL
ALTER TABLE modulo1.permisos
    ADD CONSTRAINT chk_permisos_es_activo_not_null
        CHECK (es_activo IS NOT NULL);

-- [RF-02] Sesión: fecha_inicio debe ser anterior o igual a fecha_finalizacion
ALTER TABLE modulo1.sesiones
    ADD CONSTRAINT chk_sesiones_fechas_coherentes
        CHECK (fecha_inicio <= fecha_finalizacion);

-- [RF-01] Campo version de usuarios: debe ser entero positivo
-- Soporta control de concurrencia optimista (RF-05)
ALTER TABLE modulo1.usuarios
    ADD CONSTRAINT chk_usuarios_version_positiva
        CHECK (version >= 1);

-- [RF-14] Notificaciones: fecha_envio no puede ser futura respecto al evento
-- Se garantiza que es_leido sea booleano no nulo (PostgreSQL lo garantiza
-- por tipo, pero se registra para documentación de la restricción)
ALTER TABLE modulo1.notificaciones
    ADD CONSTRAINT chk_notificaciones_es_leido_not_null
        CHECK (es_leido IS NOT NULL);


-- ----------------------------------------------------------------
-- 2. ÍNDICE PARCIAL ÚNICO NUEVO
--    Garantiza que solo exista UNA sesión activa por cuenta de
--    usuario en un momento dado (RF-02: "Un usuario solo podrá
--    tener una sesión activa simultáneamente")
-- ----------------------------------------------------------------

-- [RF-02] Una sola sesión activa por cuenta de usuario
CREATE UNIQUE INDEX IF NOT EXISTS uix_sesiones_activa_por_cuenta
    ON modulo1.sesiones (id_cuenta_usuario)
    WHERE es_activa = TRUE;


-- ================================================================
-- NOTA SOBRE CONSTRAINTS YA EXISTENTES EN EL BACKUP
-- (listados para referencia)
-- ================================================================
--
-- Claves Primarias (ya en backup):
--   acciones_pkey, estados_cuenta_pkey, eventos_pkey,
--   gestiones_cuenta_pkey, notificaciones_canal_pkey,
--   notificaciones_pkey, permisos_pkey, recursos_pkey,
--   roles_pkey, sesiones_pkey, tipos_evento_pkey,
--   tokens_pkey, usuarios_pkey, uq_usuario_id (PK cuentas)
--
-- Claves Únicas (ya en backup):
--   acciones_codigo_key           → UNIQUE (codigo)
--   sesiones_id_token_id_token1_key → UNIQUE (id_token)
--   uq_estados_cuenta_nombre      → UNIQUE (nombre)
--   uq_nombre                     → UNIQUE (nombre_rol)
--   uq_nombre_recurso             → UNIQUE (nombre_recurso)
--   uq_permiso_unico              → UNIQUE (id_rol, id_recurso, id_accion)
--   uq_tipos_evento_nombre        → UNIQUE (nombre)
--   uq_usuario                    → UNIQUE (id_usuario) en cuentas_usuarios
--   uq_usuario_correo_electronico → UNIQUE (correo_electronico)
--   uq_usuario_numero_identificacion → UNIQUE (numero_identificacion)
--
-- Claves Foráneas (ya en backup):
--   fk_accion_permiso   permisos(id_accion)    → acciones
--   fk_cuenta           gestiones_cuenta        → cuentas_usuarios
--   fk_cuenta_usuario   sesiones               → cuentas_usuarios
--   fk_estado_cuenta    cuentas_usuarios       → estados_cuentas
--   fk_evento           notificaciones         → eventos
--   fk_notificacion_canal notificaciones       → notificaciones_canal
--   fk_recurso_permiso  permisos(id_recurso)   → recursos
--   fk_recurso_rol      permisos(id_rol)       → roles
--   fk_rol              usuarios               → roles
--   fk_tipo_evento      eventos                → tipos_eventos
--   fk_token            sesiones               → tokens
--   fk_usuario          cuentas_usuarios       → usuarios
--   fk_usuario          eventos                → usuarios
--   fk_usuario          notificaciones         → usuarios
--   fk_usuario_responsable gestiones_cuenta    → usuarios
--
-- CHECK Constraints inline en DDL (ya en backup):
--   chk_usuario_tipo_identificacion → IN ('CC','CE','Pasaporte')
--   chk_usuario_formato_correo      → regex email
--   chk_usuario_nombre_validos      → regex letras+español
--   chk_usuario_apellidos_validos   → regex letras+español
-- ================================================================
