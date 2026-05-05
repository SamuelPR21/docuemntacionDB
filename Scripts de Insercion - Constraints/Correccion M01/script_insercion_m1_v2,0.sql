-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 1
-- Versión: 2.0  (correcciones según revisión técnica Correccion_Modulo1.md)
-- ==============================================================
--
-- CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
--
-- [C1] gestiones_cuenta — nombre de columna con espacio:
--       El DDL real define la columna como "accion_cuenta " (con
--       espacio al final). Se corrige usando comillas dobles:
--       "accion_cuenta " para referenciarla exactamente.
--
--       La tabla notificaciones tiene la columna
--       Se agrega a todos los INSERTs con el valor correspondiente
--       al tipo de evento de cada notificación.
--
-- [C2] sesiones — incompatibilidad de tipo en fecha_finalizacion:
--       fecha_finalizacion es timetz (hora sin fecha) en el DDL.
--       NOW() + INTERVAL '8 hours' produce timestamptz.
--       Se corrige usando CURRENT_TIME + INTERVAL '8 hours' para
--       insertar únicamente la parte de hora en timetz.
--       NOTA: el script de constraints v2.0 incluye ALTER COLUMN
--       para cambiar este campo a timestamptz, que es el tipo
--       correcto para una fecha+hora de finalización. Si ese
--       script se ejecutó primero, usar NOW() + INTERVAL '8 hours'
--       directamente es válido (ver comentario en sección 11).
--
-- [C3] permisos — IDs resueltos por subconsulta:
--       Se reemplazan los valores literales de id_recurso, id_accion
--       e id_rol por subconsultas que obtienen el ID real por nombre/
--       código. Esto garantiza correctitud independientemente del
--       valor que la secuencia haya asignado a cada registro.
--
-- ==============================================================

-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK):
--   1.  acciones
--   2.  recursos
--   3.  roles
--   4.  estados_cuentas
--   5.  permisos          ← usa subconsultas a acciones/recursos/roles
--   6.  tipos_eventos
--   7.  notificaciones_canal
--   8.  usuarios
--   9.  cuentas_usuarios
--   10. tokens
--   11. sesiones          ← fecha_finalizacion corregida
--   12. gestiones_cuenta  ← columna "accion_cuenta " con espacio
--   13. eventos
--   14. notificaciones
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. ACCIONES
-- C=Crear  R=Leer  U=Actualizar  D=Eliminar  E=Ejecutar
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.acciones (codigo, descripcion) VALUES
('C', 'Crear'),
('R', 'Leer'),
('U', 'Actualizar'),
('D', 'Eliminar'),
('E', 'Ejecutar');


-- ─────────────────────────────────────────────────────────────
-- 2. RECURSOS
-- es_proceso_especial = true → solo admite acción 'E' (Ejecutar)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.recursos
    (nombre_recurso, descripcion, es_proceso_especial, fecha_creacion)
VALUES
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
-- es_protegido = true → el rol Administrador no puede eliminarse.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.roles
    (nombre_rol, descripcion, es_protegido, fecha_creacion, fecha_actualizacion)
VALUES
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
-- 4. ESTADOS DE CUENTA  (RF-06)
-- Ciclo: PENDIENTE_ACTIVACION → ACTIVO ↔ INACTIVO / BLOQUEADO
--        Cualquiera → ELIMINADO (irreversible)
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
-- 5. PERMISOS  (RF-03, RF-04)
--
-- [C3] CORRECCIÓN: se reemplazan IDs literales por subconsultas
-- que resuelven el ID real por nombre/código. Esto garantiza
-- que los INSERT sean correctos independientemente del valor
-- que la secuencia haya asignado.
--
-- Subconsultas usadas:
--   (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'X')
--   (SELECT id_recurso FROM modulo1.recursos  WHERE nombre_recurso = 'Y')
--   (SELECT id_rol     FROM modulo1.roles     WHERE nombre_rol = 'Z')
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.permisos
    (nombre, descripcion, es_activo, id_recurso, id_accion, id_rol,
     fecha_creacion, fecha_actualizacion)
VALUES

-- ── Administrador: acceso total ───────────────────────────────
('admin_crear_usuario',
 'Crear usuarios en el sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_usuario',
 'Consultar usuarios del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_usuario',
 'Modificar datos de cualquier usuario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_eliminar_usuario',
 'Eliminar lógicamente usuarios del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'D'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_rol',
 'Crear roles en el sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'roles'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_rol',
 'Consultar roles existentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'roles'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_rol',
 'Modificar roles existentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'roles'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_eliminar_rol',
 'Eliminar roles no protegidos del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'roles'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'D'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_permiso',
 'Asignar permisos a roles', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'permisos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_permiso',
 'Consultar permisos asignados', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'permisos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_permiso',
 'Modificar permisos de roles existentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'permisos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_eliminar_permiso',
 'Retirar permisos de roles', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'permisos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'D'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_gestionar_cuenta',
 'Activar, desactivar, bloquear y eliminar cuentas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'cuentas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_cuenta',
 'Consultar estado de cuentas de usuario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'cuentas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_sesion',
 'Consultar sesiones activas del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sesiones'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_evento',
 'Consultar historial de auditoría del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'eventos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_notificacion',
 'Consultar notificaciones generadas por el sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'notificaciones'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_finca',
 'Registrar nuevas fincas en el sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'fincas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_finca',
 'Consultar fincas registradas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'fincas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_finca',
 'Modificar datos de fincas existentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'fincas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_infraestr',
 'Registrar nuevas áreas productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'infraestructuras'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_infraestr',
 'Consultar áreas productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'infraestructuras'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_infraestr',
 'Modificar datos de áreas productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'infraestructuras'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_iot',
 'Registrar nuevos dispositivos IoT', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_iot',
 'Consultar dispositivos IoT registrados', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_iot',
 'Modificar configuración de dispositivos IoT', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_sensor',
 'Asociar sensores a áreas productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_sensor',
 'Consultar asociaciones de sensores', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_sensor',
 'Reasignar sensores entre áreas productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_ejecutar_cierre',
 'Ejecutar proceso de cierre de ciclo productivo', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'cierre_ciclo'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_ejecutar_ajuste',
 'Ejecutar ajustes de inventario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'ajuste_inventario'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_ejecutar_reporte',
 'Generar reportes del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'generacion_reportes'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_ejecutar_exportacion',
 'Exportar datos del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'exportacion_datos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_crear_especie',
 'Crear nuevas especies en el catálogo productivo', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_leer_especie',
 'Consultar el catálogo de especies productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

('admin_actualizar_especie',
 'Editar especies existentes en el catálogo', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Administrador'),
 NOW(), NOW()),

-- ── Productor ─────────────────────────────────────────────────
('prod_leer_usuario',
 'Consultar su propio perfil de usuario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_actualizar_usuario',
 'Actualizar sus propios datos personales', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_leer_finca',
 'Consultar las fincas a las que está asignado', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'fincas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_leer_infraestr',
 'Consultar las áreas productivas de su finca', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'infraestructuras'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_leer_iot',
 'Consultar los dispositivos IoT de su finca', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_leer_sensor',
 'Consultar los sensores asociados a su finca', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_leer_especie',
 'Consultar el catálogo de especies productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

('prod_ejecutar_reporte',
 'Generar reportes propios de su unidad productiva', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'generacion_reportes'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Productor'),
 NOW(), NOW()),

-- ── Veterinario ───────────────────────────────────────────────
('vet_leer_usuario',
 'Consultar su propio perfil de usuario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_actualizar_usuario',
 'Actualizar sus propios datos personales', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_leer_especie',
 'Consultar el catálogo de especies productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_actualizar_especie',
 'Editar la descripción y nombre de especies existentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_leer_finca',
 'Consultar las fincas asignadas al veterinario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'fincas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_leer_infraestr',
 'Consultar la infraestructura de las fincas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'infraestructuras'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_leer_sensor',
 'Consultar los sensores y asociaciones vigentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

('vet_ejecutar_reporte',
 'Generar reportes sanitarios de los activos biológicos', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'generacion_reportes'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Veterinario'),
 NOW(), NOW()),

-- ── Ingeniero de Campo ────────────────────────────────────────
('ing_leer_usuario',
 'Consultar su propio perfil de usuario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_actualizar_usuario',
 'Actualizar sus propios datos personales', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_leer_especie',
 'Consultar el catálogo de especies productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_actualizar_especie',
 'Editar descripción de especies (sin crear ni desactivar)', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_leer_finca',
 'Consultar las fincas asignadas al ingeniero', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'fincas'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_leer_infraestr',
 'Consultar las áreas productivas de las fincas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'infraestructuras'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_crear_iot',
 'Registrar nuevos dispositivos IoT en el sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_leer_iot',
 'Consultar los dispositivos IoT registrados', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_actualizar_iot',
 'Modificar la configuración remota de dispositivos IoT', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'dispositivos_iot'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_crear_sensor',
 'Asociar sensores a áreas productivas', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'C'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_leer_sensor',
 'Consultar las asociaciones de sensores vigentes', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

('ing_actualizar_sensor',
 'Reasignar sensores a otra área productiva', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'sensores'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), NOW()),

-- ── Contador ──────────────────────────────────────────────────
('cont_leer_usuario',
 'Consultar su propio perfil de usuario', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Contador'),
 NOW(), NOW()),

('cont_actualizar_usuario',
 'Actualizar sus propios datos personales', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'usuarios'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'U'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Contador'),
 NOW(), NOW()),

('cont_leer_especie',
 'Consultar el catálogo de especies (valoración NIC 41)', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'especies'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'R'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Contador'),
 NOW(), NOW()),

('cont_ejecutar_reporte',
 'Generar reportes financieros de activos biológicos', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'generacion_reportes'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Contador'),
 NOW(), NOW()),

('cont_ejecutar_exportacion',
 'Exportar datos financieros del sistema', true,
 (SELECT id_recurso FROM modulo1.recursos WHERE nombre_recurso = 'exportacion_datos'),
 (SELECT id_accion  FROM modulo1.acciones WHERE codigo = 'E'),
 (SELECT id_rol     FROM modulo1.roles    WHERE nombre_rol = 'Contador'),
 NOW(), NOW());


-- ─────────────────────────────────────────────────────────────
-- 6. TIPOS DE EVENTOS  (RF-10)
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
-- 7. CANAL DE NOTIFICACIONES  (RF-14)
-- El campo 'canal' usa el enum modulo1.enum_estado_envio:
--   'en_cola' | 'enviado' | 'fallido'
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.notificaciones_canal (canal, fecha_envio, nombre) VALUES
('en_cola', CURRENT_DATE, 'EMAIL'),
('en_cola', CURRENT_DATE, 'INTERNO');


-- ─────────────────────────────────────────────────────────────
-- 8. USUARIOS  (RF-01)
-- Las contraseñas son placeholders bcrypt. En producción el hash
-- real lo genera la capa de aplicación antes de persistir.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.usuarios
    (tipo_identificacion, numero_identificacion, nombre, apellidos,
     fecha_nacimiento, genero, correo_electronico, contrasena_cifrada,
     telefono, direccion, id_rol, fecha_registro, version, fecha_actualizacion)
VALUES
('CC', '10750001',
 'Carlos',    'Rodríguez Pérez',    '1985-03-15', 'M',
 'admin@pecuaria.co',
 '$2b$12$hash_admin_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3001234567', 'Calle 10 # 5-20, Neiva, Huila',
 (SELECT id_rol FROM modulo1.roles WHERE nombre_rol = 'Administrador'),
 NOW(), 1, NOW()),

('CC', '10750002',
 'Laura',     'Gómez Torres',       '1990-07-22', 'F',
 'productor@pecuaria.co',
 '$2b$12$hash_prod_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3119876543', 'Vereda El Paraíso, Neiva, Huila',
 (SELECT id_rol FROM modulo1.roles WHERE nombre_rol = 'Productor'),
 NOW(), 1, NOW()),

('CE', '10750003',
 'Alejandro', 'Martínez Silva',     '1988-11-05', 'M',
 'veterinario@pecuaria.co',
 '$2b$12$hash_vet_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3205551234', 'Carrera 7 # 12-45, Neiva, Huila',
 (SELECT id_rol FROM modulo1.roles WHERE nombre_rol = 'Veterinario'),
 NOW(), 1, NOW()),

('CC', '10750004',
 'Valentina', 'López Herrera',      '1993-04-18', 'F',
 'ingeniero@pecuaria.co',
 '$2b$12$hash_ing_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3153337890', 'Calle 23 # 18-10, Neiva, Huila',
 (SELECT id_rol FROM modulo1.roles WHERE nombre_rol = 'Ingeniero de Campo'),
 NOW(), 1, NOW()),

('Pasaporte', '10750005',
 'Miguel',    'Vargas Ospina',      '1987-09-30', 'M',
 'contador@pecuaria.co',
 '$2b$12$hash_cont_placeholder_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
 '3002229876', 'Avenida Circunvalar # 40-15, Neiva, Huila',
 (SELECT id_rol FROM modulo1.roles WHERE nombre_rol = 'Contador'),
 NOW(), 1, NOW());


-- ─────────────────────────────────────────────────────────────
-- 9. CUENTAS DE USUARIO  (RF-01, RF-06)
-- id_estado_cuenta referenciado por nombre para robustez:
--   2 = ACTIVO (asumiendo secuencia desde 1)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.cuentas_usuarios
    (id_usuario, id_estado_cuenta, tiene_correo_verificado,
     fecha_verificacion, ultimo_acceso, intentos_fallidos,
     bloqueado_hasta, ultimo_intento_fallido,
     token_activacion_actual, fecha_cambio_estado, motivo_ultimo_cambio)
VALUES
((SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 (SELECT id_estado_cuenta FROM modulo1.estados_cuentas WHERE nombre = 'ACTIVO'),
 true, NOW() - INTERVAL '90 days', NOW() - INTERVAL '1 hour',
 0, NULL, NULL, NULL, NOW() - INTERVAL '90 days',
 'Cuenta de administrador configurada en instalación inicial del sistema'),

((SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co'),
 (SELECT id_estado_cuenta FROM modulo1.estados_cuentas WHERE nombre = 'ACTIVO'),
 true, NOW() - INTERVAL '60 days', NOW() - INTERVAL '2 hours',
 0, NULL, NULL, NULL, NOW() - INTERVAL '60 days',
 'Activación por token de verificación de correo electrónico'),

((SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'veterinario@pecuaria.co'),
 (SELECT id_estado_cuenta FROM modulo1.estados_cuentas WHERE nombre = 'ACTIVO'),
 true, NOW() - INTERVAL '45 days', NOW() - INTERVAL '3 hours',
 0, NULL, NULL, NULL, NOW() - INTERVAL '45 days',
 'Activación por token de verificación de correo electrónico'),

((SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'ingeniero@pecuaria.co'),
 (SELECT id_estado_cuenta FROM modulo1.estados_cuentas WHERE nombre = 'ACTIVO'),
 true, NOW() - INTERVAL '30 days', NOW() - INTERVAL '5 hours',
 0, NULL, NULL, NULL, NOW() - INTERVAL '30 days',
 'Activación por token de verificación de correo electrónico'),

((SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'contador@pecuaria.co'),
 (SELECT id_estado_cuenta FROM modulo1.estados_cuentas WHERE nombre = 'ACTIVO'),
 true, NOW() - INTERVAL '20 days', NOW() - INTERVAL '1 day',
 0, NULL, NULL, NULL, NOW() - INTERVAL '20 days',
 'Activación por token de verificación de correo electrónico');


-- ─────────────────────────────────────────────────────────────
-- 10. TOKENS  (RF-01, RF-07, RF-08, RF-09)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.tokens (token_tipo, fecha_expiracion, fecha_uso, fecha_creacion) VALUES
('verificacion_correo',
 NOW() - INTERVAL '89 days 23 hours', NOW() - INTERVAL '90 days', NOW() - INTERVAL '91 days'),

('verificacion_correo',
 NOW() - INTERVAL '59 days 23 hours', NOW() - INTERVAL '60 days', NOW() - INTERVAL '61 days'),

('verificacion_correo',
 NOW() - INTERVAL '44 days 23 hours', NOW() - INTERVAL '45 days', NOW() - INTERVAL '46 days'),

('verificacion_correo',
 NOW() - INTERVAL '29 days 23 hours', NOW() - INTERVAL '30 days', NOW() - INTERVAL '31 days'),

('verificacion_correo',
 NOW() - INTERVAL '19 days 23 hours', NOW() - INTERVAL '20 days', NOW() - INTERVAL '21 days'),

('acceso',
 NOW() + INTERVAL '7 hours', NULL, NOW());


-- ─────────────────────────────────────────────────────────────
-- 11. SESIONES  (RF-02)
--
-- [C2] CORRECCIÓN de fecha_finalizacion:
--
-- OPCIÓN A (DDL original sin modificar — fecha_finalizacion es timetz):
--   Usar CURRENT_TIME + INTERVAL '8 hours' para insertar solo
--   la parte de hora compatible con el tipo timetz.
--
-- OPCIÓN B (si se ejecutó constraints_modulo1_v2.sql primero,
--   que cambia fecha_finalizacion a timestamptz):
--   Usar NOW() + INTERVAL '8 hours' directamente.
--
-- El script usa OPCIÓN B porque la ejecución recomendada es:
--   1. constraints_modulo1_v2,0.sql  (hace el ALTER COLUMN)
--   2. script_insercion_m1_v2,0.sql  (este archivo)
--
-- Si se ejecuta este script sin haber corrido los constraints,
-- reemplazar la línea de fecha_finalizacion con:
--   CURRENT_TIME + INTERVAL '8 hours'
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.sesiones
    (id_token, direccion_ip, agente_usuario,
     fecha_inicio, fecha_finalizacion, es_activa, id_cuenta_usuario)
VALUES
((SELECT id_token FROM modulo1.tokens
  WHERE token_tipo = 'acceso' AND fecha_uso IS NULL
  ORDER BY fecha_creacion DESC LIMIT 1),
 '192.168.1.100',
 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0',
 NOW(),
 NOW() + INTERVAL '8 hours',    -- timestamptz (requiere ALTER COLUMN previo)
 true,
 (SELECT id_cuenta_usuario FROM modulo1.cuentas_usuarios cu
  JOIN modulo1.usuarios u ON u.id_usuario = cu.id_usuario
  WHERE u.correo_electronico = 'admin@pecuaria.co'));


-- ─────────────────────────────────────────────────────────────
-- 12. GESTIONES DE CUENTA  (RF-06)
--
-- [C1] CORRECCIÓN: el nombre real de la columna en el DDL es
--   "accion_cuenta " (con espacio al final). Se referencia con
--   comillas dobles para respetar el nombre exacto definido en
--   el esquema.
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.gestiones_cuenta
    ("accion_cuenta ", motivo_accion, fecha_accion,
     id_usuario_responsable, id_cuenta_usuario)
VALUES
('activar',
 'Configuración inicial del sistema. Cuenta de administrador activada manualmente.',
 NOW() - INTERVAL '90 days',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 (SELECT id_cuenta_usuario FROM modulo1.cuentas_usuarios cu
  JOIN modulo1.usuarios u ON u.id_usuario = cu.id_usuario
  WHERE u.correo_electronico = 'admin@pecuaria.co')),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro.',
 NOW() - INTERVAL '60 days',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 (SELECT id_cuenta_usuario FROM modulo1.cuentas_usuarios cu
  JOIN modulo1.usuarios u ON u.id_usuario = cu.id_usuario
  WHERE u.correo_electronico = 'productor@pecuaria.co')),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro.',
 NOW() - INTERVAL '45 days',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 (SELECT id_cuenta_usuario FROM modulo1.cuentas_usuarios cu
  JOIN modulo1.usuarios u ON u.id_usuario = cu.id_usuario
  WHERE u.correo_electronico = 'veterinario@pecuaria.co')),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro.',
 NOW() - INTERVAL '30 days',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 (SELECT id_cuenta_usuario FROM modulo1.cuentas_usuarios cu
  JOIN modulo1.usuarios u ON u.id_usuario = cu.id_usuario
  WHERE u.correo_electronico = 'ingeniero@pecuaria.co')),

('activar',
 'Usuario verificó su correo electrónico mediante token enviado durante el proceso de registro.',
 NOW() - INTERVAL '20 days',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 (SELECT id_cuenta_usuario FROM modulo1.cuentas_usuarios cu
  JOIN modulo1.usuarios u ON u.id_usuario = cu.id_usuario
  WHERE u.correo_electronico = 'contador@pecuaria.co'));


-- ─────────────────────────────────────────────────────────────
-- 13. EVENTOS  (RF-10)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.eventos
    (tipo_evento, descripcion, fecha_evento, modulo,
     resultado, detalle, id_usuario, categoria, estado)
VALUES
((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'REGISTRO_USUARIO'),
 'Creación de cuenta de administrador del sistema durante la instalación inicial.',
 NOW() - INTERVAL '91 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "id_usuario": 1, "correo": "admin@pecuaria.co"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'ACTIVACION_CUENTA'),
 'Cuenta de administrador activada. Correo electrónico verificado exitosamente.',
 NOW() - INTERVAL '90 days', 'modulo1', 'exitoso',
 '{"accion": "ACTIVACION_CUENTA", "id_cuenta": 1, "metodo": "manual"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'REGISTRO_USUARIO'),
 'Registro de nuevo usuario con rol Productor (rol asignado automáticamente por el sistema).',
 NOW() - INTERVAL '61 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "correo": "productor@pecuaria.co", "rol_asignado": "Productor"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'ACTIVACION_CUENTA'),
 'Cuenta de Productor activada. Correo electrónico verificado mediante token de 24 horas.',
 NOW() - INTERVAL '60 days', 'modulo1', 'exitoso',
 '{"accion": "ACTIVACION_CUENTA", "metodo": "token"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'REGISTRO_USUARIO'),
 'Registro de nuevo usuario con rol Veterinario.',
 NOW() - INTERVAL '46 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "correo": "veterinario@pecuaria.co", "rol_asignado": "Veterinario"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'REGISTRO_USUARIO'),
 'Registro de nuevo usuario con rol Ingeniero de Campo.',
 NOW() - INTERVAL '31 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "correo": "ingeniero@pecuaria.co", "rol_asignado": "Ingeniero de Campo"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'REGISTRO_USUARIO'),
 'Registro de nuevo usuario con rol Contador.',
 NOW() - INTERVAL '21 days', 'modulo1', 'exitoso',
 '{"accion": "REGISTRO_USUARIO", "correo": "contador@pecuaria.co", "rol_asignado": "Contador"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'LOGIN_EXITOSO'),
 'Inicio de sesión exitoso del Administrador. IP: 192.168.1.100.',
 NOW(), 'modulo1', 'exitoso',
 '{"accion": "LOGIN_EXITOSO", "ip": "192.168.1.100", "user_agent": "Chrome/124.0"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'ACCESO', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'LOGIN_FALLIDO'),
 'Intento fallido de inicio de sesión. Contraseña incorrecta. Intento 1 de 5.',
 NOW() - INTERVAL '5 days', 'modulo1', 'fallido',
 '{"accion": "LOGIN_FALLIDO", "correo": "productor@pecuaria.co", "intento_numero": 1, "ip": "10.0.0.55"}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co'),
 'SEGURIDAD', 'procesado'),

((SELECT id_tipo_evento FROM modulo1.tipos_eventos WHERE nombre = 'CONSULTA_AUDITORIA'),
 'El Administrador consultó el historial de eventos de auditoría del módulo 1.',
 NOW() - INTERVAL '2 days', 'modulo1', 'exitoso',
 '{"accion": "CONSULTA_AUDITORIA", "filtros": {"modulo": "modulo1"}, "pagina": 1, "registros_retornados": 9}',
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co'),
 'ADMINISTRACION', 'procesado');


-- ─────────────────────────────────────────────────────────────
-- 14. NOTIFICACIONES  (RF-14)
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo1.notificaciones
    (id_evento, mensaje, fecha_envio, es_leido,
     id_notificacion_canal, id_usuario)
VALUES
(1,
 'Bienvenido al sistema de gestión pecuaria. Su cuenta de administrador ha sido configurada exitosamente.',
 NOW() - INTERVAL '91 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co')),

(2,
 'Su cuenta ha sido activada correctamente. Ya puede iniciar sesión en la plataforma.',
 NOW() - INTERVAL '90 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'EMAIL'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co')),

(3,
 'Bienvenido a la plataforma. Verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '61 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co')),

(4,
 'Su cuenta ha sido activada exitosamente. Ya puede iniciar sesión.',
 NOW() - INTERVAL '60 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'EMAIL'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co')),

(5,
 'Bienvenido a la plataforma. Verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '46 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'veterinario@pecuaria.co')),

(6,
 'Bienvenido a la plataforma. Verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '31 days', false,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'ingeniero@pecuaria.co')),

(7,
 'Bienvenido a la plataforma. Verifique su correo electrónico para activar su acceso.',
 NOW() - INTERVAL '21 days', false,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'contador@pecuaria.co')),

(8,
 'Nuevo inicio de sesión detectado desde IP 192.168.1.100. Si no fue usted, contacte al soporte.',
 NOW(), false,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'admin@pecuaria.co')),

(9,
 'Intento fallido de inicio de sesión en su cuenta (intento 1 de 5). Si no fue usted, cambie su contraseña.',
 NOW() - INTERVAL '5 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'EMAIL'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co')),

(9,
 'Alerta: intento de acceso fallido detectado. Verifique si fue usted o contacte al administrador.',
 NOW() - INTERVAL '5 days', true,
 (SELECT id_notificacion_canal FROM modulo1.notificaciones_canal WHERE nombre = 'INTERNO'),
 (SELECT id_usuario FROM modulo1.usuarios WHERE correo_electronico = 'productor@pecuaria.co'));
