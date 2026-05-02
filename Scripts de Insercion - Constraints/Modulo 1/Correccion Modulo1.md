
## Constraints para corregir (parciales o no aprobados)

| Constraint name | Issue | Proposed correction |
|----------------|-------|----------------------|
| chk_sesiones_fechas_coherentes | Incompatibilidad de tipos: `fecha_inicio` es `timestamptz`, `fecha_finalizacion` es `timetz`. La comparación `<=` no es semánticamente válida entre un timestamp con fecha y una hora sin fecha. | Cambiar el tipo de columna `fecha_finalizacion` en `modulo1.sesiones` de `timetz` a `timestamptz`. Luego el constraint funcionará correctamente. |
| chk_permisos_es_activo_not_null | Redundante: la columna `es_activo` ya tiene `NOT NULL` en el DDL de la tabla `permisos`. | Eliminar este constraint (opcional, no afecta ejecución pero duplica regla). |
| chk_usuarios_version_positiva | Redundante: la columna `version` tiene `DEFAULT 1 NOT NULL`, lo que ya garantiza valor >= 1. | Eliminar este constraint. |
| chk_notificaciones_es_leido_not_null | Redundante: la columna `es_leido` ya tiene `NOT NULL` en el DDL de la tabla `notificaciones`. | Eliminar este constraint. |

Los constraints redundantes no provocan error de ejecución, pero se listan como "no aprobados" si el criterio es evitar duplicación lógica. La única corrección obligatoria es la de `chk_sesiones_fechas_coherentes` mediante la modificación del tipo de `fecha_finalizacion`.



## Script de insercion


| Tabla/Seccion | Cumple | Observaciones | RF al que apunta |
|---------------|--------|---------------|------------------|
| `gestiones_cuenta` (INSERT) | No | El nombre real de la columna en el esquema es `"accion_cuenta "` (con espacio al final). El script usa `accion_cuenta` sin espacio, lo que provoca un error de sintaxis. | RF-06 (Gestión de Cuentas) |
| `notificaciones` (INSERT) | No | La tabla `notificaciones` tiene la columna `categoria varchar(30) NOT NULL` sin valor por defecto. El script no incluye esta columna en la lista de columnas ni proporciona valores, causando violación de `NOT NULL`. | RF-14 (Notificaciones a Usuarios) |
| `sesiones` (INSERT) | No | La columna `fecha_finalizacion` en el esquema es de tipo `timetz` (hora con zona horaria, sin fecha). El script asigna `NOW() + INTERVAL '8 hours'` que es `timestamptz` (timestamp con fecha). Incompatibilidad de tipos que genera error. | RF-02 (Autenticación de Usuarios) |
| `permisos` (INSERT) | Parcial | Los INSERTs asignan valores literales a `id_recurso`, `id_accion` e `id_rol` (1,2,3...). Si las secuencias de las tablas `recursos`, `acciones` o `roles` no comienzan en 1 o si se insertaron registros previos, las referencias serán incorrectas. Se recomienda usar subconsultas para obtener los IDs reales. | RF-03, RF-04 (Roles y Permisos) |
| `recursos` (INSERT) | Correcto | Incluye `fecha_creacion` con `NOW()`. Aunque la columna tiene `DEFAULT now()`, no es un error; funciona correctamente. | N/A |
| `notificaciones_canal` (INSERT) | Correcto | El valor `'en_cola'` para la columna `canal` (tipo `enum_estado_envio`) es válido. | RF-14 |
| `tokens` (INSERT) | Correcto | El valor `'acceso'` para `token_tipo` existe en el enum correspondiente. | RF-07, RF-08, RF-09 |
| `eventos` (INSERT) | Correcto | El campo `detalle` utiliza formato JSON válido con comillas dobles. No hay error de sintaxis. | RF-10 |
