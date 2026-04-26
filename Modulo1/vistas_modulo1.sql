--Vistas Modulo 1

CREATE OR REPLACE VIEW modulo1.vw_cuentas_correo_estado AS
SELECT
    u.id_usuario,
    u.nombre,
    u.apellidos,
    u.correo_electronico,
    cu.id_cuenta_usuario,
    cu.tiene_correo_verificado,
    cu.fecha_verificacion,
    ec.id_estado_cuenta,
    ec.nombre AS estado_cuenta
FROM modulo1.usuarios AS u
JOIN modulo1.cuentas_usuarios AS cu
    ON cu.id_usuario = u.id_usuario
JOIN modulo1.estados_cuentas AS ec
    ON ec.id_estado_cuenta = cu.id_estado_cuenta;


CREATE OR REPLACE VIEW modulo1.vw_eventos_usuario_detalle AS
SELECT
    e.id_evento,
    u.id_usuario,
    u.nombre,
    u.apellidos,
    te.id_tipo_evento,
    te.nombre AS nombre_evento,
    te.accion AS accion_evento,
    e.modulo,
    e.resultado,
    e.estado,
    e.fecha_evento
FROM modulo1.eventos AS e
JOIN modulo1.usuarios AS u
    ON u.id_usuario = e.id_usuario
JOIN modulo1.tipos_eventos AS te
    ON te.id_tipo_evento = e.tipo_evento;

CREATE OR REPLACE VIEW modulo1.vw_notificaciones_eventos AS
SELECT
    n.id_notificacion,
    n.id_evento,
    n.mensaje,
    n.fecha_envio,
    n.es_leido,
    u.id_usuario,
    u.nombre,
    u.apellidos,
    e.descripcion AS evento,
    e.modulo,
    e.fecha_evento
FROM modulo1.notificaciones AS n
JOIN modulo1.eventos AS e
    ON e.id_evento = n.id_evento
JOIN modulo1.usuarios AS u
    ON u.id_usuario = n.id_usuario;


CREATE OR REPLACE VIEW modulo1.vw_usuarios_contacto AS
SELECT
    u.id_usuario,
    u.nombre AS nombre_usuario,
    u.apellidos AS apellido_usuario,
    u.correo_electronico,
    u.telefono,
    u.fecha_registro AS fecha_creacion_cuenta
FROM modulo1.usuarios AS u;


CREATE OR REPLACE VIEW modulo1.vw_sesiones_activas_usuario AS
SELECT
    u.id_usuario,
    u.nombre,
    u.apellidos,
    r.id_rol,
    r.nombre_rol,
    cu.id_cuenta_usuario,
    cu.ultimo_acceso,
    ec.nombre AS estado_cuenta,
    s.id_sesion,
    s.es_activa,
    s.direccion_ip,
    s.fecha_inicio
FROM modulo1.sesiones AS s
JOIN modulo1.cuentas_usuarios AS cu
    ON cu.id_cuenta_usuario = s.id_cuenta_usuario
JOIN modulo1.usuarios AS u
    ON u.id_usuario = cu.id_usuario
JOIN modulo1.roles AS r
    ON r.id_rol = u.id_rol
JOIN modulo1.estados_cuentas AS ec
    ON ec.id_estado_cuenta = cu.id_estado_cuenta
WHERE s.es_activa IS TRUE;


CREATE OR REPLACE VIEW modulo1.vw_permisos_roles AS
SELECT
    r.id_rol,
    r.nombre_rol,
    p.id_permiso,
    p.nombre AS permiso,
    p.descripcion AS descripcion_permiso,
    a.id_accion,
    a.codigo AS codigo_accion,
    a.descripcion AS accion,
    rec.id_recurso,
    rec.nombre_recurso AS recurso,
    rec.descripcion AS descripcion_recurso,
    p.fecha_creacion AS fecha_asignacion,
    p.fecha_actualizacion,
    p.es_activo
FROM modulo1.roles AS r
JOIN modulo1.permisos AS p
    ON p.id_rol = r.id_rol
JOIN modulo1.acciones AS a
    ON a.id_accion = p.id_accion
JOIN modulo1.recursos AS rec
    ON rec.id_recurso = p.id_recurso;


CREATE OR REPLACE VIEW modulo1.vw_eventos_usuario_sesion_activa AS
SELECT
    e.id_evento,
    u.id_usuario,
    u.nombre,
    u.apellidos,
    te.nombre AS nombre_evento,
    e.estado,
    e.modulo,
    s.id_sesion,
    s.direccion_ip,
    e.fecha_evento
FROM modulo1.eventos AS e
JOIN modulo1.usuarios AS u
    ON u.id_usuario = e.id_usuario
JOIN modulo1.tipos_eventos AS te
    ON te.id_tipo_evento = e.tipo_evento
JOIN modulo1.cuentas_usuarios AS cu
    ON cu.id_usuario = u.id_usuario
JOIN LATERAL (
    SELECT
        ses.id_sesion,
        ses.direccion_ip,
        ses.fecha_inicio
    FROM modulo1.sesiones AS ses
    WHERE ses.id_cuenta_usuario = cu.id_cuenta_usuario
      AND ses.es_activa IS TRUE
    ORDER BY
        ses.fecha_inicio DESC,
        ses.id_sesion DESC
    LIMIT 1
) AS s
    ON TRUE;


CREATE OR REPLACE VIEW modulo1.vw_resumen_cuentas_usuarios AS
SELECT
    u.id_usuario,
    u.nombre,
    u.apellidos,
    u.correo_electronico,
    u.telefono,
    r.id_rol,
    r.nombre_rol AS rol,
    cu.id_cuenta_usuario,
    ec.id_estado_cuenta,
    ec.nombre AS estado_cuenta,
    cu.ultimo_acceso
FROM modulo1.usuarios AS u
JOIN modulo1.roles AS r
    ON r.id_rol = u.id_rol
JOIN modulo1.cuentas_usuarios AS cu
    ON cu.id_usuario = u.id_usuario
JOIN modulo1.estados_cuentas AS ec
    ON ec.id_estado_cuenta = cu.id_estado_cuenta;

