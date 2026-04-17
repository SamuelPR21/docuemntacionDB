INSERT INTO roles (nombre_rol, descripcion, fecha_creacion, fecha_actualizacion, es_protegido)
VALUES
('Administrador', 'Acceso total al sistema', NOW(), NOW(), true),
('Productor', 'Gestiona producción agropecuaria', NOW(), NOW(), false),
('Veterinario', 'Control de salud animal', NOW(), NOW(), false),
('Contador', 'Gestión financiera', NOW(), NOW(), false),
('Ing. Campo', 'Supervisión técnica en campo', NOW(), NOW(), false);


INSERT INTO permisos (nombre, descripcion, fecha_creacion, fecha_actualizacion, es_activo, accion, modulo)
VALUES
('Leer', 'Permite leer información', NOW(), NOW(), true, 'READ', 'sistema'),
('Escribir', 'Permite crear y editar', NOW(), NOW(), true, 'WRITE', 'sistema'),
('Eliminar', 'Permite eliminar registros', NOW(), NOW(), true, 'DELETE', 'sistema'),
('Exportar', 'Permite exportar datos', NOW(), NOW(), true, 'EXPORT', 'sistema');

select * from  roles_permisos


-- Administrador (id_rol = 1) → todos los permisos
INSERT INTO roles_permisos (id_rol, id_permiso, fecha_asignacion)
SELECT 1, id_permiso, NOW() FROM permisos;

-- Productor (id_rol = 2)
INSERT INTO roles_permisos (id_rol, id_permiso, fecha_asignacion)
VALUES
(2, 1, NOW()), -- Leer
(2, 2, NOW()); -- Escribir

-- Veterinario (id_rol = 3)
INSERT INTO roles_permisos (id_rol, id_permiso, fecha_asignacion)
VALUES
(3, 1, NOW()),
(3, 2, NOW());

-- Contador (id_rol = 4)
INSERT INTO roles_permisos (id_rol, id_permiso, fecha_asignacion)
VALUES
(4, 1, NOW()),
(4, 4, NOW()); -- Exportar

-- Ing. Campo (id_rol = 5)
INSERT INTO roles_permisos (id_rol, id_permiso, fecha_asignacion)
VALUES
(5, 1, NOW());





INSERT INTO usuarios (
    tipo_identificacion,
    numero_identificacion,
    nombre,
    apellidos,
    fecha_nacimiento,
    usuario_genero,
    correo_electronico,
    contrasena_hash,
    telefono,
    direccion,
    id_rol
)
VALUES
('CC', '100000001', 'Juan', 'Pérez', '1990-05-10', 'M', 'juan@example.com', 'hash123', '3001234567', 'Calle 1', 1),
('CC', '100000002', 'Ana', 'Gómez', '1995-08-20', 'F', 'ana@example.com', 'hash123', '3007654321', 'Calle 2', 2),
('CC', '100000003', 'Luis', 'Martínez', '1988-03-15', 'X', 'luis@example.com', 'hash123', '3011111111', 'Calle 3', 3),
('CC', '100000004', 'Carla', 'Ruiz', '1992-11-30', 'F', 'carla@example.com', 'hash123', '3022222222', 'Calle 4', 4),
('CC', '100000005', 'Pedro', 'Ramírez', '1985-07-25', 'T', 'pedro@example.com', 'hash123', '3033333333', 'Calle 5', 5),
('CC', '123456789', 'Juan', 'Pérez', '1990-05-10', 'M', 'mario@example.com', 'hash123', '3001234567', 'Calle 1', 1);


INSERT INTO usuarios (
    tipo_identificacion,
    numero_identificacion,
    nombre,
    apellidos,
    fecha_nacimiento,
    usuario_genero,
    correo_electronico,
    contrasena_hash,
    telefono,
    direccion,
    id_rol
)
VALUES
('CC', '123456789', 'Juan', 'Pérez', '1990-05-10', 'M', 'mario@example.com', 'hash123', '3001234567', 'Calle 1', 1);



INSERT INTO estados_cuenta (nombre, descripcion)
VALUES
('Activo', 'Cuenta activa y funcional'),
('Pendiente', 'Cuenta en espera de verificación'),
('Bloqueado', 'Cuenta bloqueada por seguridad o inactividad');


select * from usuarios



INSERT INTO cuentas_usuarios (
    id_usuario,
    id_estado_cuenta,
    tiene_correo_verificado,
    fecha_verificacion,
    ultimo_acceso
)
VALUES
-- Usuario activo y verificado
(1, 1, true, NOW(), NOW()),

-- Usuario pendiente (no verificado)
(2, 2, false, NOW(), NOW()),

-- Usuario activo y verificado
(3, 1, true, NOW(), NOW()),

-- Usuario bloqueado
(4, 3, false, NOW(), NOW()),

(6, 1, false, NOW(), NOW()),

-- Usuario pendiente
(5, 2, false, NOW(), NOW());


SELECT 
    u.id_usuarios,
    u.nombre,
    u.correo_electronico,
    cu.tiene_correo_verificado,
    ec.nombre AS estado_cuenta
FROM usuarios u
JOIN cuentas_usuarios cu ON u.id_usuarios = cu.id_usuario
JOIN estados_cuenta ec ON cu.id_estado_cuenta = ec.id_estado_cuentas
WHERE u.id_usuarios = 6;


INSERT INTO tipos_evento (nombre, accion)
VALUES
('Login', 'AUTH'),
('Logout', 'AUTH'),
('Actualización de perfil', 'UPDATE'),
('Eliminación de cuenta', 'DELETE'),
('Creación de recurso', 'CREATE');


select * from notificaciones_canal


INSERT INTO notificaciones_canal (
    canal,
    fecha_envio,
    nombre
)
VALUES
('enviado', CURRENT_DATE, 'Email'),
('en_cola', CURRENT_DATE, 'SMS'),
('fallido', CURRENT_DATE, 'Push');


INSERT INTO eventos (
    tipo_evento,
    descripcion,
    fecha_evento,
    modulo,
    evento_resultado,
    detalle,
    id_usuario,
    categoria,
    estado
)
VALUES
(1, 'Inicio de sesión exitoso', NOW(), 'auth', 'exitoso', '{"ip":"127.0.0.1"}', 1, 'seguridad', 'activo'),

(2, 'Cierre de sesión', NOW(), 'auth', 'exitoso', '{"motivo":"manual"}', 1, 'seguridad', 'cerrado'),

(3, 'Actualización de datos personales', NOW(), 'perfil', 'exitoso', '{"campo":"correo"}', 2, 'usuario', 'activo'),

(4, 'Intento de eliminación fallido', NOW(), 'cuenta', 'fallido', '{"error":"permiso denegado"}', 3, 'seguridad', 'fallido'),

(5, 'Creación de registro', NOW(), 'produccion', 'exitoso', '{"tipo":"animal"}', 4, 'operacion', 'activo'),
(2, 'Actualización permiso', NOW(), 'perfil', 'exitoso', '{"motivo":"Actualizacion de"}', 6, 'usuario', 'activo'),
(3, 'Actualización de datos personales', NOW(), 'perfil', 'fallido', '{"campo":"correo"}', 6, 'usuario', 'activo');

SELECT 
    u.nombre,
    u.apellidos,
    te.nombre AS nombre_evento,
    e.modulo,
    e.fecha_evento
FROM eventos e
JOIN usuarios u 
    ON e.id_usuario = u.id_usuarios
JOIN tipos_evento te 
    ON e.tipo_evento = te.id_tipo_evento
WHERE u.id_usuarios = 6
ORDER BY e.fecha_evento DESC;


INSERT INTO notificaciones (
    id_evento,
    mensaje,
    fecha_envio,
    es_leido,
    id_notificacion_canal,
    id_usuario
)
VALUES
(1, 'Inicio de sesión detectado', NOW(), true, 1, 1),
(2, 'Sesión finalizada correctamente', NOW(), true, 1, 1),
(3, 'Perfil actualizado', NOW(), false, 2, 2),
(4, 'Error al eliminar cuenta', NOW(), false, 3, 3),
(5, 'Nuevo registro creado', NOW(), false, 1, 4);


INSERT INTO notificaciones (
    id_evento,
    mensaje,
    fecha_envio,
    es_leido,
    id_notificacion_canal,
    id_usuario
)
VALUES
-- Evento 1 → usuario 1
(1, 'Inicio de sesión detectado', NOW(), true, 1, 1),

-- Evento 2 → usuario 1
(2, 'Sesión cerrada correctamente', NOW(), true, 1, 1),

-- Evento 3 → usuario 2
(3, 'Perfil actualizado', NOW(), false, 2, 2),

-- Evento 4 → usuario 3
(4, 'Error al intentar eliminar cuenta', NOW(), false, 3, 3),

-- Evento 5 → usuario 4
(5, 'Nuevo registro creado', NOW(), false, 1, 4),

-- Evento 6 → usuario 6
(6, 'Permisos actualizados', NOW(), false, 2, 6),

-- Evento 7 → usuario 6
(7, 'Error en actualización de datos', NOW(), false, 3, 6);


SELECT 
    n.id_notificaciones,
    n.mensaje,
    n.fecha_envio,
    n.es_leido,
    u.nombre,
    u.apellidos,
    e.descripcion AS evento,
    e.modulo,
    e.fecha_evento
FROM notificaciones n
JOIN eventos e 
    ON n.id_evento = e.id_evento
JOIN usuarios u 
    ON n.id_usuario = u.id_usuarios
WHERE n.id_evento = 1;


SELECT 
nombre AS nombre_usuario,
apellidos AS apellido_usuario,
correo_electronico,
telefono,
fecha_registro AS fecha_creacion_cuenta
FROM usuarios u
WHERE u.id_usuario = 6;



INSERT INTO tokens (
    token_tipo,
    fecha_expiracion,
    fecha_uso,
    fecha_creacion
)
VALUES
('recuperacion', NOW() + INTERVAL '1 hour', NOW(), NOW()),
('acceso', NOW() + INTERVAL '30 minutes', NOW(), NOW()),
('acceso', NOW() + INTERVAL '1 day', NOW(), NOW()),
('verificacion_correo', NOW() + INTERVAL '1 hour', NOW(), NOW()),
('recuperacion', NOW() + INTERVAL '30 minutes', NOW(), NOW());

select * from notificaciones

INSERT INTO sesiones (
    id_token,
    direccion_ip,
    user_agent,
    fecha_inicio,
    fecha_finalizacion,
    es_activa,
    id_cuenta_usuario
)
VALUES
(1, '192.168.1.10', 'Chrome/Windows', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', true, 1),

(2, '192.168.1.11', 'Firefox/Linux', NOW() - INTERVAL '2 hours', NOW() + INTERVAL '30 minutes', true, 3),

(3, '192.168.1.12', 'Edge/Windows', NOW() - INTERVAL '1 day', NOW() + INTERVAL '1 hour', false, 1),

(4, '192.168.1.13', 'Mobile/Android', NOW() - INTERVAL '3 hours', NOW() + INTERVAL '2 hours', true, 2),

(5, '192.168.1.14', 'Safari/iOS', NOW() - INTERVAL '5 hours', NOW() + INTERVAL '1 hour', true, 5);


SELECT 
    u.nombre,
    u.apellidos,
    r.nombre_rol,
    cu.ultimo_acceso,
    ec.nombre AS estado_cuenta,
    s.id_sesion,
    s.es_activa,
    s.direccion_ip,
    s.fecha_inicio
FROM sesiones s
JOIN cuentas_usuarios cu 
    ON s.id_cuenta_usuario = cu.id_cuenta_usuario
JOIN usuarios u 
    ON cu.id_usuario = u.id_usuario
JOIN roles r 
    ON u.id_rol = r.id_rol
JOIN estados_cuenta ec 
    ON cu.id_estado_cuenta = ec.id_estado_cuenta
WHERE s.es_activa = true AND u.id_usuario = 6;


SELECT 
    r.nombre_rol,
    p.nombre AS permiso,
    p.accion,
    p.modulo,
    rp.fecha_asignacion
FROM roles r
JOIN roles_permisos rp 
    ON r.id_rol = rp.id_rol
JOIN permisos p 
    ON rp.id_permiso = p.id_permiso
WHERE r.nombre_rol = 'Administrador';


UPDATE usuarios
SET contrasena_hash = 'nuevo_hash_seguro'
WHERE id_usuario = 1;

select * from usuarios


SELECT 
    u.nombre,
    u.apellidos,
    te.nombre AS nombre_evento,
    e.estado,
    e.modulo,
    s.direccion_ip,
    e.fecha_evento
FROM eventos e
JOIN usuarios u 
    ON e.id_usuario = u.id_usuario
JOIN tipos_evento te 
    ON e.tipo_evento = te.id_tipo_evento
JOIN cuentas_usuarios cu 
    ON cu.id_usuario = u.id_usuario
JOIN sesiones s 
    ON s.id_cuenta_usuario = cu.id_cuenta_usuario
WHERE e.fecha_evento BETWEEN '2026-01-01' AND '2026-12-31'
  AND s.es_activa = true
ORDER BY e.fecha_evento DESC;


SELECT 
    u.nombre,
    u.apellidos,
    u.correo_electronico,
    r.nombre_rol AS rol,
    ec.nombre AS estado_cuenta,
    cu.ultimo_acceso
FROM usuarios u
JOIN roles r 
    ON u.id_rol = r.id_rol
JOIN cuentas_usuarios cu 
    ON cu.id_usuario = u.id_usuario
JOIN estados_cuenta ec 
    ON cu.id_estado_cuenta = ec.id_estado_cuenta
WHERE u.id_usuario = 6;

SELECT 
    u.nombre,
    u.apellidos,
    r.nombre_rol AS rol,
    ec.nombre AS estado_cuenta,
    cu.ultimo_acceso
FROM usuarios u
JOIN roles r 
    ON u.id_rol = r.id_rol
JOIN cuentas_usuarios cu 
    ON cu.id_usuario = u.id_usuario
JOIN estados_cuenta ec 
    ON cu.id_estado_cuenta = ec.id_estado_cuenta
WHERE u.id_usuario = 6;



ALTER TABLE usuarios
RE