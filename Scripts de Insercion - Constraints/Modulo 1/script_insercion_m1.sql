-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 1
-- ==============================================================
-- ORDEN DE INSERCIÓN:
--   1. acciones
--   2. recursos
--   3. roles
--   4. estados_cuentas
--   5. permisos
--   6. tipos_eventos
--   7. notificaciones_canal
--   8. usuarios
--   9. cuentas_usuarios
--  10. tokens
--  11. sesiones
--  12. gestiones_cuenta
--  13. eventos
--  14. notificaciones
-- ==============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. ACCIONES
-- C=Crear  R=Leer  U=Actualizar  D=Eliminar  E=Ejecutar
-- La acción 'E' se reserva para procesos especiales del sistema.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.acciones (codigo, descripcion) VALUES
('C', 'Crear'),
('R', 'Leer'),
('U', 'Actualizar'),
('D', 'Eliminar'),
('E', 'Ejecutar');

-- ─────────────────────────────────────────────────────────────
-- 2. RECURSOS
-- es_proceso_especial = true → sólo admite acción 'E' (Ejecutar)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.recursos (nombre_recurso, descripcion, es_proceso_especial, fecha_creacion) VALUES
('usuarios',            'Gestión de usuarios del sistema',                            false, NOW()),
('roles',               'Gestión de roles y control de acceso',                       false, NOW()),
('permisos',            'Gestión de permisos RBAC',                                   false, NOW()),
('cuentas',             'Gestión de cuentas y estados de cuenta',                     false, NOW()),
('sesiones',            'Control de sesiones activas del sistema',                    false, NOW()),
('eventos',             'Registro de eventos de auditoría del sistema',               false, NOW()),
('notificaciones',      'Gestión de notificaciones al usuario',                       false, NOW()),
('especies',            'Catálogo de especies productivas',                           false, NOW()),
('fincas',              'Registro y gestión de fincas',                               false, NOW()),
('infraestructuras',    'Gestión de infraestructura productiva',                      false, NOW()),
('dispositivos_iot',    'Registro y gestión de dispositivos IoT',                     false, NOW()),
('sensores',            'Asociación de sensores a áreas productivas',                 false, NOW()),
('cierre_ciclo',        'Proceso especial: cierre de ciclo productivo',               true,  NOW()),
('ajuste_inventario',   'Proceso especial: ajustes de inventario',                    true,  NOW()),
('generacion_reportes', 'Proceso especial: generación de reportes del sistema',       true,  NOW()),
('exportacion_datos',   'Proceso especial: exportación de datos del sistema',         true,  NOW());

-- ─────────────────────────────────────────────────────────────
-- 3. ROLES  (RF-03)
-- es_protegido = true → el rol no puede eliminarse.
-- El rol asignado por defecto al registrar un usuario es Productor
-- (RF-01: "El rol será asignado automáticamente por el sistema
-- con un valor por defecto, ej. PRODUCTOR").
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.roles (nombre_rol, descripcion, es_protegido, fecha_creacion, fecha_actualizacion) VALUES
('Administrador',
 'Rol con acceso total al sistema. Gestiona usuarios, roles, permisos y configuración global.',
 true, NOW(), NOW()),
('Productor',
 'Responsable de una o más unidades productivas. Accede a módulos de gestión de finca y activos biológicos. Rol asignado por defecto al registrar un nuevo usuario.',
 false, NOW(), NOW()),
('Veterinario',
 'Responsable del seguimiento sanitario de los activos biológicos. Accede a módulos de salud animal, monitoreo y configuración de especies.',
 false, NOW(), NOW()),
('Ingeniero de Campo',
 'Responsable del monitoreo ambiental, configuración de dispositivos IoT y asociación de sensores a infraestructura productiva.',
 false, NOW(), NOW()),
('Contador',
 'Acceso restringido a módulos financieros y de valoración de activos biológicos bajo NIC 41.',
 false, NOW(), NOW());

-- ─────────────────────────────────────────────────────────────
-- 4. ESTADOS DE CUENTA
-- Ciclo de estados permitido:
--   PENDIENTE_ACTIVACION → ACTIVO ↔ INACTIVO
--   ACTIVO / INACTIVO    → BLOQUEADO (automático tras 5 intentos)
--   BLOQUEADO            → ACTIVO (tras 15 min o acción admin)
--   Cualquiera           → ELIMINADO (irreversible)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.estados_cuentas (nombre, descripcion) VALUES
('PENDIENTE_ACTIVACION',
 'Cuenta recién creada, pendiente de confirmación mediante token enviado al correo electrónico registrado. El usuario no puede autenticarse hasta activar la cuenta.'),
('ACTIVO',
 'Cuenta activa y habilitada para autenticarse en el sistema.'),
('INACTIVO',
 'Cuenta desactivada por acción administrativa. El usuario no puede autenticarse.'),
('BLOQUEADO',
 'Cuenta bloqueada temporalmente por exceso de intentos fallidos de autenticación (máximo 5 consecutivos). Se libera automáticamente a los 15 minutos o por acción del administrador.'),
('ELIMINADO',
 'Cuenta eliminada lógicamente por acción administrativa. Estado irreversible. El usuario no puede autenticarse ni recuperar acceso al sistema.');

-- ─────────────────────────────────────────────────────────────
-- 5. PERMISOS  (catálogo RBAC inicial — RF-03, RF-04)
--
-- Convención de IDs asumidos por secuencia:
--   Roles:    1=Administrador  2=Productor  3=Veterinario
--             4=Ingeniero de Campo  5=Contador
--   Recursos: 1=usuarios  2=roles  3=permisos  4=cuentas
--             5=sesiones  6=eventos  7=notificaciones
--             8=especies  9=fincas  10=infraestructuras
--             11=dispositivos_iot  12=sensores
--             13=cierre_ciclo  14=ajuste_inventario
--             15=generacion_reportes  16=exportacion_datos
--   Acciones: 1=C  2=R  3=U  4=D  5=E
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.permisos (nombre, descripcion, es_activo, id_recurso, id_accion, id_rol, fecha_creacion, fecha_actualizacion) VALUES

-- ── Administrador: acceso total ───────────────────────────────
('admin_crear_usuario',         'Crear usuarios en el sistema',                          true, 1,  1, 1, NOW(), NOW()),
('admin_leer_usuario',          'Consultar usuarios del sistema',                        true, 1,  2, 1, NOW(), NOW()),
('admin_actualizar_usuario',    'Modificar datos de cualquier usuario',                  true, 1,  3, 1, NOW(), NOW()),
('admin_eliminar_usuario',      'Eliminar lógicamente usuarios del sistema',             true, 1,  4, 1, NOW(), NOW()),
('admin_crear_rol',             'Crear roles en el sistema',                             true, 2,  1, 1, NOW(), NOW()),
('admin_leer_rol',              'Consultar roles existentes',                            true, 2,  2, 1, NOW(), NOW()),
('admin_actualizar_rol',        'Modificar roles existentes',                            true, 2,  3, 1, NOW(), NOW()),
('admin_eliminar_rol',          'Eliminar roles no protegidos del sistema',              true, 2,  4, 1, NOW(), NOW()),
('admin_crear_permiso',         'Asignar permisos a roles',                              true, 3,  1, 1, NOW(), NOW()),
('admin_leer_permiso',          'Consultar permisos asignados',                          true, 3,  2, 1, NOW(), NOW()),
('admin_actualizar_permiso',    'Modificar permisos de roles existentes',                true, 3,  3, 1, NOW(), NOW()),
('admin_eliminar_permiso',      'Retirar permisos de roles',                             true, 3,  4, 1, NOW(), NOW()),
('admin_gestionar_cuenta',      'Activar, desactivar, bloquear y eliminar cuentas',      true, 4,  3, 1, NOW(), NOW()),
('admin_leer_cuenta',           'Consultar estado de cuentas de usuario',                true, 4,  2, 1, NOW(), NOW()),
('admin_leer_sesion',           'Consultar sesiones activas del sistema',                true, 5,  2, 1, NOW(), NOW()),
('admin_leer_evento',           'Consultar historial de auditoría del sistema',          true, 6,  2, 1, NOW(), NOW()),
('admin_leer_notificacion',     'Consultar notificaciones generadas por el sistema',     true, 7,  2, 1, NOW(), NOW()),
('admin_crear_finca',           'Registrar nuevas fincas en el sistema',                 true, 9,  1, 1, NOW(), NOW()),
('admin_leer_finca',            'Consultar fincas registradas',                          true, 9,  2, 1, NOW(), NOW()),
('admin_actualizar_finca',      'Modificar datos de fincas existentes',                  true, 9,  3, 1, NOW(), NOW()),
('admin_crear_infraestr',       'Registrar nuevas áreas productivas',                    true, 10, 1, 1, NOW(), NOW()),
('admin_leer_infraestr',        'Consultar áreas productivas',                           true, 10, 2, 1, NOW(), NOW()),
('admin_actualizar_infraestr',  'Modificar datos de áreas productivas',                  true, 10, 3, 1, NOW(), NOW()),
('admin_crear_iot',             'Registrar nuevos dispositivos IoT',                     true, 11, 1, 1, NOW(), NOW()),
('admin_leer_iot',              'Consultar dispositivos IoT registrados',                true, 11, 2, 1, NOW(), NOW()),
('admin_actualizar_iot',        'Modificar configuración de dispositivos IoT',           true, 11, 3, 1, NOW(), NOW()),
('admin_crear_sensor',          'Asociar sensores a áreas productivas',                  true, 12, 1, 1, NOW(), NOW()),
('admin_leer_sensor',           'Consultar asociaciones de sensores',                    true, 12, 2, 1, NOW(), NOW()),
('admin_actualizar_sensor',     'Reasignar sensores entre áreas productivas',            true, 12, 3, 1, NOW(), NOW()),
('admin_ejecutar_cierre',       'Ejecutar proceso de cierre de ciclo productivo',        true, 13, 5, 1, NOW(), NOW()),
('admin_ejecutar_ajuste',       'Ejecutar ajustes de inventario',                        true, 14, 5, 1, NOW(), NOW()),
('admin_ejecutar_reporte',      'Generar reportes del sistema',                          true, 15, 5, 1, NOW(), NOW()),
('admin_ejecutar_exportacion',  'Exportar datos del sistema',                            true, 16, 5, 1, NOW(), NOW()),
('admin_crear_especie',         'Crear nuevas especies en el catálogo productivo',       true, 8,  1, 1, NOW(), NOW()),
('admin_leer_especie',          'Consultar el catálogo de especies productivas',         true, 8,  2, 1, NOW(), NOW()),
('admin_actualizar_especie',    'Editar especies existentes en el catálogo',             true, 8,  3, 1, NOW(), NOW()),

-- ── Productor: gestión de su unidad productiva ────────────────
('prod_leer_usuario',           'Consultar su propio perfil de usuario',                 true, 1,  2, 2, NOW(), NOW()),
('prod_actualizar_usuario',     'Actualizar sus propios datos personales',               true, 1,  3, 2, NOW(), NOW()),
('prod_leer_finca',             'Consultar las fincas a las que está asignado',          true, 9,  2, 2, NOW(), NOW()),
('prod_leer_infraestr',         'Consultar las áreas productivas de su finca',           true, 10, 2, 2, NOW(), NOW()),
('prod_leer_iot',               'Consultar los dispositivos IoT de su finca',            true, 11, 2, 2, NOW(), NOW()),
('prod_leer_sensor',            'Consultar los sensores asociados a su finca',           true, 12, 2, 2, NOW(), NOW()),
('prod_leer_especie',           'Consultar el catálogo de especies productivas',         true, 8,  2, 2, NOW(), NOW()),
('prod_ejecutar_reporte',       'Generar reportes propios de su unidad productiva',      true, 15, 5, 2, NOW(), NOW()),

-- ── Veterinario: seguimiento sanitario ───────────────────────
('vet_leer_usuario',            'Consultar su propio perfil de usuario',                 true, 1,  2, 3, NOW(), NOW()),
('vet_actualizar_usuario',      'Actualizar sus propios datos personales',               true, 1,  3, 3, NOW(), NOW()),
('vet_leer_especie',            'Consultar el catálogo de especies productivas',         true, 8,  2, 3, NOW(), NOW()),
('vet_actualizar_especie',      'Editar la descripción y nombre de especies existentes', true, 8,  3, 3, NOW(), NOW()),
('vet_leer_finca',              'Consultar las fincas asignadas al veterinario',         true, 9,  2, 3, NOW(), NOW()),
('vet_leer_infraestr',          'Consultar la infraestructura de las fincas',            true, 10, 2, 3, NOW(), NOW()),
('vet_leer_sensor',             'Consultar los sensores y asociaciones vigentes',        true, 12, 2, 3, NOW(), NOW()),
('vet_ejecutar_reporte',        'Generar reportes sanitarios de los activos biológicos', true, 15, 5, 3, NOW(), NOW()),

-- ── Ingeniero de Campo: monitoreo e IoT ──────────────────────
('ing_leer_usuario',            'Consultar su propio perfil de usuario',                 true, 1,  2, 4, NOW(), NOW()),
('ing_actualizar_usuario',      'Actualizar sus propios datos personales',               true, 1,  3, 4, NOW(), NOW()),
('ing_leer_especie',            'Consultar el catálogo de especies productivas',         true, 8,  2, 4, NOW(), NOW()),
('ing_actualizar_especie',      'Editar descripción de especies (sin crear ni desactivar)', true, 8, 3, 4, NOW(), NOW()),
('ing_leer_finca',              'Consultar las fincas asignadas al ingeniero',           true, 9,  2, 4, NOW(), NOW()),
('ing_leer_infraestr',          'Consultar las áreas productivas de las fincas',         true, 10, 2, 4, NOW(), NOW()),
('ing_crear_iot',               'Registrar nuevos dispositivos IoT en el sistema',       true, 11, 1, 4, NOW(), NOW()),
('ing_leer_iot',                'Consultar los dispositivos IoT registrados',            true, 11, 2, 4, NOW(), NOW()),
('ing_actualizar_iot',          'Modificar la configuración remota de dispositivos IoT', true, 11, 3, 4, NOW(), NOW()),
('ing_crear_sensor',            'Asociar sensores a áreas productivas',                  true, 12, 1, 4, NOW(), NOW()),
('ing_leer_sensor',             'Consultar las asociaciones de sensores vigentes',       true, 12, 2, 4, NOW(), NOW()),
('ing_actualizar_sensor',       'Reasignar sensores a otra área productiva',             true, 12, 3, 4, NOW(), NOW()),

-- ── Contador: módulos financieros ────────────────────────────
('cont_leer_usuario',           'Consultar su propio perfil de usuario',                 true, 1,  2, 5, NOW(), NOW()),
('cont_actualizar_usuario',     'Actualizar sus propios datos personales',               true, 1,  3, 5, NOW(), NOW()),
('cont_leer_especie',           'Consultar el catálogo de especies (valoración NIC 41)', true, 8,  2, 5, NOW(), NOW()),
('cont_ejecutar_reporte',       'Generar reportes financieros de activos biológicos',    true, 15, 5, 5, NOW(), NOW()),
('cont_ejecutar_exportacion',   'Exportar datos financieros del sistema',                true, 16, 5, 5, NOW(), NOW());

-- ─────────────────────────────────────────────────────────────
-- 6. TIPOS DE EVENTOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.tipos_eventos (nombre, accion) VALUES
('REGISTRO_USUARIO',            'Creación de nueva cuenta de usuario en el sistema'),
('ACTIVACION_CUENTA',           'Activación de cuenta mediante token de verificación por correo'),
('LOGIN_EXITOSO',               'Inicio de sesión autenticado exitosamente'),
('LOGIN_FALLIDO',               'Intento de inicio de sesión con credenciales incorrectas'),
('CIERRE_SESION',               'Cierre de sesión realizado por el usuario o por el sistema'),
('CAMBIO_CONTRASENA',           'Cambio de contraseña por parte del usuario autenticado'),
('SOLICITUD_RECUPERACION',      'Solicitud de recuperación de contraseña por correo electrónico'),
('RESTABLECIMIENTO_CONTRASENA', 'Restablecimiento de contraseña mediante token de recuperación'),
('ACTUALIZACION_PERFIL',        'Modificación de datos personales del usuario'),
('CAMBIO_ESTADO_CUENTA',        'Cambio de estado de cuenta por acción administrativa'),
('CREACION_ROL',                'Creación de un nuevo rol en el sistema'),
('MODIFICACION_ROL',            'Modificación de un rol existente (nombre, descripción o permisos)'),
('ELIMINACION_ROL',             'Eliminación lógica de un rol del sistema'),
('ASIGNACION_PERMISO',          'Asignación de un permiso a un rol'),
('REVOCACION_PERMISO',          'Revocación de un permiso de un rol'),
('CONSULTA_AUDITORIA',          'Acceso al historial de eventos de auditoría del sistema');

-- ─────────────────────────────────────────────────────────────
-- 7. CANAL DE NOTIFICACIONES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.notificaciones_canal (canal, fecha_envio, nombre) VALUES
('en_cola', CURRENT_DATE, 'EMAIL'),
('en_cola', CURRENT_DATE, 'INTERNO');

-- ─────────────────────────────────────────────────────────────
-- 8. USUARIOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.usuarios
    (tipo_identificacion, numero_identificacion, nombre, apellidos,
     fecha_nacimiento, genero, correo_electronico, contrasena_cifrada,
     telefono, direccion, id_rol, fecha_registro, version, fecha_actualizacion)
VALUES
('CC', '10750001',
 'Carlos',    'Rodríguez Pérez',
 '1985-03-15', 'M',
 'admin@pecuaria.co',
 '$2b$12$hash_admin_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3001234567', 'Calle 10 # 5-20, Neiva, Huila',
 1, NOW(), 1, NOW()),

('CC', '10750002',
 'Laura',     'Gómez Torres',
 '1990-07-22', 'F',
 'productor@pecuaria.co',
 '$2b$12$hash_prod_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3119876543', 'Vereda El Paraíso, Neiva, Huila',
 2, NOW(), 1, NOW()),

('CE', '10750003',
 'Alejandro', 'Martínez Silva',
 '1988-11-05', 'M',
 'veterinario@pecuaria.co',
 '$2b$12$hash_vet_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3205551234', 'Carrera 7 # 12-45, Neiva, Huila',
 3, NOW(), 1, NOW()),

('CC', '10750004',
 'Valentina', 'López Herrera',
 '1993-04-18', 'F',
 'ingeniero@pecuaria.co',
 '$2b$12$hash_ing_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3153337890', 'Calle 23 # 18-10, Neiva, Huila',
 4, NOW(), 1, NOW()),

('Pasaporte', '10750005',
 'Miguel',    'Vargas Ospina',
 '1987-09-30', 'M',
 'contador@pecuaria.co',
 '$2b$12$hash_cont_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3002229876', 'Avenida Circunvalar # 40-15, Neiva, Huila',
 5, NOW(), 1, NOW());

-- ─────────────────────────────────────────────────────────────
-- 9. CUENTAS DE USUARIO
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.cuentas_usuarios
    (id_usuario, id_estado_cuenta, tiene_correo_verificado,
     fecha_verificacion, ultimo_acceso, intentos_fallidos,
     bloqueado_hasta, ultimo_intento_fallido,
     token_activacion_actual, fecha_cambio_estado, motivo_ultimo_cambio)
VALUES
(1, 2, true,
 NOW() - INTERVAL '90 days', NOW() - INTERVAL '1 hour',
 0, NULL, NULL, NULL,
 NOW() - INTERVAL '90 days',
 'Cuenta de administrador configurada en instalación inicial del sistema'),

(2, 2, true,
 NOW() - INTERVAL '60 days', NOW() - INTERVAL '2 hours',
 0, NULL, NULL, NULL,
 NOW() - INTERVAL '60 days',
 'Activación por token de verificación de correo electrónico'),

(3, 2, true,
 NOW() - INTERVAL '45 days', NOW() - INTERVAL '3 hours',
 0, NULL, NULL, NULL,
 NOW() - INTERVAL '45 days',
 'Activación por token de verificación de correo electrónico'),

(4, 2, true,
 NOW() - INTERVAL '30 days', NOW() - INTERVAL '5 hours',
 0, NULL, NULL, NULL,
 NOW() - INTERVAL '30 days',
 'Activación por token de verificación de correo electrónico'),

(5, 2, true,
 NOW() - INTERVAL '20 days', NOW() - INTERVAL '1 day',
 0, NULL, NULL, NULL,
 NOW() - INTERVAL '20 days',
 'Activación por token de verificación de correo electrónico');

-- ─────────────────────────────────────────────────────────────
-- 10. TOKENS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.tokens (token_tipo, fecha_expiracion, fecha_uso, fecha_creacion) VALUES
('verificacion_correo',
 NOW() - INTERVAL '89 days 23 hours',
 NOW() - INTERVAL '90 days',
 NOW() - INTERVAL '91 days'),

('verificacion_correo',
 NOW() - INTERVAL '59 days 23 hours',
 NOW() - INTERVAL '60 days',
 NOW() - INTERVAL '61 days'),

('verificacion_correo',
 NOW() - INTERVAL '44 days 23 hours',
 NOW() - INTERVAL '45 days',
 NOW() - INTERVAL '46 days'),

('verificacion_correo',
 NOW() - INTERVAL '29 days 23 hours',
 NOW() - INTERVAL '30 days',
 NOW() - INTERVAL '31 days'),

('verificacion_correo',
 NOW() - INTERVAL '19 days 23 hours',
 NOW() - INTERVAL '20 days',
 NOW() - INTERVAL '21 days'),

('acceso',
 NOW() + INTERVAL '7 hours',
 NULL,
 NOW());

-- ─────────────────────────────────────────────────────────────
-- 11. SESIONES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.sesiones
    (id_token, direccion_ip, agente_usuario,
     fecha_inicio, fecha_finalizacion, es_activa, id_cuenta_usuario)
VALUES
(6,
 '192.168.1.100',
 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0',
 NOW(),
 NOW() + INTERVAL '8 hours',
 true,
 1);

-- ─────────────────────────────────────────────────────────────
-- 12. GESTIONES DE CUENTA
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.gestiones_cuenta
    (accion_cuenta, motivo_accion, fecha_accion,
     id_usuario_responsable, id_cuenta_usuario)
VALUES
('activar',
 'Configuración inicial del sistema. Cuenta de administrador activada manualmente.',
 NOW() - INTERVAL '90 days', 1, 1),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro (RF-01).',
 NOW() - INTERVAL '60 days', 1, 2),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro (RF-01).',
 NOW() - INTERVAL '45 days', 1, 3),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro (RF-01).',
 NOW() - INTERVAL '30 days', 1, 4),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro (RF-01).',
 NOW() - INTERVAL '20 days', 1, 5);

-- ─────────────────────────────────────────────────────────────
-- 13. EVENTOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.eventos
    (tipo_evento, descripcion, fecha_evento, modulo,
     resultado, detalle, id_usuario, categoria, estado)
VALUES
(1,
 'Creación de cuenta de administrador del sistema durante la instalación inicial.',
 NOW() - INTERVAL '91 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "id_usuario": 1, "correo": "admin@pecuaria.co"}',
 1, 'SEGURIDAD', 'procesado'),

(2,
 'Cuenta de administrador activada. Correo electrónico verificado exitosamente.',
 NOW() - INTERVAL '90 days', 'modulo1', 'exitoso',
 '{"accion": "ACTIVACION_CUENTA", "id_cuenta": 1, "metodo": "manual"}',
 1, 'SEGURIDAD', 'procesado'),

(1,
 'Registro de nuevo usuario con rol Productor (rol asignado automáticamente por el sistema).',
 NOW() - INTERVAL '61 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "id_usuario": 2, "correo": "productor@pecuaria.co", "rol_asignado": "Productor"}',
 1, 'SEGURIDAD', 'procesado'),

(2,
 'Cuenta de Productor activada. Correo electrónico verificado mediante token de 24 horas.',
 NOW() - INTERVAL '60 days', 'modulo1', 'exitoso',
 '{"accion": "ACTIVACION_CUENTA", "id_cuenta": 2, "metodo": "token"}',
 2, 'SEGURIDAD', 'procesado'),

(1,
 'Registro de nuevo usuario con rol Veterinario.',
 NOW() - INTERVAL '46 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "id_usuario": 3, "correo": "veterinario@pecuaria.co", "rol_asignado": "Veterinario"}',
 1, 'SEGURIDAD', 'procesado'),

(1,
 'Registro de nuevo usuario con rol Ingeniero de Campo.',
 NOW() - INTERVAL '31 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "id_usuario": 4, "correo": "ingeniero@pecuaria.co", "rol_asignado": "Ingeniero de Campo"}',
 1, 'SEGURIDAD', 'procesado'),

(1,
 'Registro de nuevo usuario con rol Contador.',
 NOW() - INTERVAL '21 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "id_usuario": 5, "correo": "contador@pecuaria.co", "rol_asignado": "Contador"}',
 1, 'SEGURIDAD', 'procesado'),

(3,
 'Inicio de sesión exitoso del Administrador. IP: 192.168.1.100.',
 NOW(), 'modulo1', 'exitoso',
 '{"accion": "LOGIN_EXITOSO", "id_cuenta": 1, "ip": "192.168.1.100", "user_agent": "Chrome/124.0", "id_sesion": 1}',
 1, 'ACCESO', 'procesado'),

(4,
 'Intento fallido de inicio de sesión para correo productor@pecuaria.co. Contraseña incorrecta. Intento 1 de 5.',
 NOW() - INTERVAL '5 days', 'modulo1', 'fallido',
 '{"accion": "LOGIN_FALLIDO", "correo": "productor@pecuaria.co", "intento_numero": 1, "ip": "10.0.0.55", "user_agent": "Firefox/125.0"}',
 2, 'SEGURIDAD', 'procesado'),

(16,
 'El Administrador consultó el historial de eventos de auditoría del módulo 1.',
 NOW() - INTERVAL '2 days', 'modulo1', 'exitoso',
 '{"accion": "CONSULTA_AUDITORIA", "filtros": {"modulo": "modulo1", "tipo_evento": null}, "pagina": 1, "registros_retornados": 9}',
 1, 'ADMINISTRACION', 'procesado');

-- ─────────────────────────────────────────────────────────────
-- 14. NOTIFICACIONES  (RF-14)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.notificaciones
    (id_evento, mensaje, fecha_envio, es_leido,
     id_notificacion_canal, id_usuario)
VALUES
(1,
 'Bienvenido al sistema de gestión pecuaria. Su cuenta de administrador ha sido configurada exitosamente. Puede iniciar sesión en la plataforma.',
 NOW() - INTERVAL '91 days', true, 2, 1),

(2,
 'Su cuenta ha sido activada correctamente. Ya puede iniciar sesión en la plataforma con sus credenciales registradas.',
 NOW() - INTERVAL '90 days', true, 1, 1),

(3,
 'Bienvenido a la plataforma. Su cuenta ha sido registrada exitosamente. Por favor, verifique su correo electrónico para activar su acceso al sistema.',
 NOW() - INTERVAL '61 days', true, 2, 2),

(4,
 'Su cuenta ha sido activada exitosamente. Ya puede iniciar sesión con su correo y contraseña registrados.',
 NOW() - INTERVAL '60 days', true, 1, 2),

(5,
 'Bienvenido a la plataforma. Su cuenta ha sido registrada exitosamente. Por favor, verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '46 days', true, 2, 3),

(6,
 'Bienvenido a la plataforma. Su cuenta ha sido registrada exitosamente. Por favor, verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '31 days', false, 2, 4),

(7,
 'Bienvenido a la plataforma. Su cuenta ha sido registrada exitosamente. Por favor, verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '21 days', false, 2, 5),

(8,
 'Nuevo inicio de sesión detectado en su cuenta desde la dirección IP 192.168.1.100. Si no fue usted, contacte al soporte técnico inmediatamente.',
 NOW(), false, 2, 1),

(9,
 'Se registró un intento fallido de inicio de sesión en su cuenta (intento 1 de 5). Si no fue usted, le recomendamos cambiar su contraseña inmediatamente.',
 NOW() - INTERVAL '5 days', true, 1, 2),

(9,
 'Alerta de seguridad: intento de acceso fallido detectado en su cuenta. Verifique si fue usted o contacte al administrador.',
 NOW() - INTERVAL '5 days', true, 2, 2);
