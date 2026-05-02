## Tabla de Constraints a corregir (parciales o no aprobados)

| Nombre del constraint | Tipo | Tabla | Problema identificado | Acción para corregir |
|-----------------------|------|-------|----------------------|----------------------|
| fk_finca_usuario | FOREIGN KEY | fincas → modulo1.usuarios | Ya existe en el DDL como `finca_id_usuario_fkey` (aunque con NOT VALID). Crear otra FK duplicada generará error. | Omitir del script o convertir en `ALTER TABLE ... VALIDATE CONSTRAINT finca_id_usuario_fkey` para activar la existente. |
| fk_config_global_usuario | FOREIGN KEY | configuraciones_globales → modulo1.usuarios | Ya existe como `configuraciones_globales_id_usuario_fkey` (NOT VALID). | Omitir o validar la existente. |
| fk_sensor_area_usuario | FOREIGN KEY | sensores_areas_asociadas → modulo1.usuarios | Ya existe como `sensores_areas_asociadas_id_usuario_fkey` (NOT VALID). | Omitir o validar. |
| fk_identidad_visual_usuario | FOREIGN KEY | identidad_visuales → modulo1.usuarios | Ya existe como `identidad_visuales_id_usuario_fkey` (NOT VALID). | Omitir o validar. |
| fk_calibracion_usuario | FOREIGN KEY | calibraciones → modulo1.usuarios | Ya existe como `calibraciones_id_usuario_fkey` (NOT VALID). | Omitir o validar. |
| fk_plantilla_usuario | FOREIGN KEY | plantillas → modulo1.usuarios | Ya existe como `plantillas_id_usuario_fkey` (NOT VALID). | Omitir o validar. |
| fk_aplicacion_plantilla_usuario | FOREIGN KEY | aplicaciones_plantillas → modulo1.usuarios | Ya existe como `aplicaciones_plantillas_id_usuario_fkey` (NOT VALID). | Omitir o validar. |
| fk_gestion_especie_usuario | FOREIGN KEY | gestion_especies → modulo1.usuarios | Ya existe como `gestion_especies_id_usuario_fkey` (NOT VALID). | Omitir o validar. |
| chk_nivel_alerta_dominio | CHECK | niveles_alerta_ambientales | La columna `nivel` es de tipo `modulo9.enum_nivel_alerta`. Si el enum no define exactamente `'normal'`, `'precaucion'`, `'critico'` (en minúsculas) el CHECK fallará. | Verificar el dominio del enum. Si coincide, el CHECK es redundante; si no, ajustar literales o eliminar el CHECK. |
| chk_conf_global_heartbeat_ge_frecuencia | CHECK | configuraciones_globales | Puede fallar si existen registros con `heartbeat < frecuencia_muestreo`. | Agregar con `NOT VALID` y luego validar, o limpiar datos previos. |
| chk_conf_remota_intervalo_ge_frecuencia | CHECK | configuraciones_remotas | Puede fallar si existen registros con `intervalo_transmision < frecuencia_captura`. | Agregar con `NOT VALID` y luego validar. |
| chk_especie_nombre_longitud | CHECK | especies | Puede fallar si existen nombres con longitud menor a 3 caracteres. | Agregar con `NOT VALID` o corregir datos existentes. |
| chk_ciclo_biologico_duracion_positiva | CHECK | ciclos_biologicos | Puede fallar si hay duracion_dias <= 0. | Verificar datos o usar `NOT VALID`. |
| chk_variable_min_no_negativo | CHECK | variables_ambientales | Puede fallar si hay valor_fisico_min negativo. | Verificar datos. |
| uix_conf_global_unica_activa | Índice único parcial | configuraciones_globales | Falla si ya existe más de una fila con es_activo = true. | Asegurar una sola activa antes de crear el índice. |
| uix_sensor_asociacion_activa | Índice único parcial | sensores_areas_asociadas | Falla si un sensor tiene dos asociaciones con tiene_estado = true. | Corregir duplicados antes de crear. |
| uix_umbral_activo_especie_variable | Índice único parcial | umbrales_ambientales | Falla si existe más de un umbral activo para la misma (especie, variable). | Desactivar umbrales redundantes antes de crear. |

---

## Tabla de problemas en el script de inserción (versión 2.0)

| Sección / Tabla | Problema identificado | Riesgo | Corrección necesaria |
|-----------------|----------------------|--------|----------------------|
| Renombrado (`ALTER TABLE modulo9.finca RENAME TO fincas`) | En el DDL proporcionado la tabla ya se llama `fincas`. Ejecutar esta línea fallará. | ALTER falla, detiene el script. | Envolver en bloque condicional que verifique existencia de `finca` antes de renombrar, o eliminar la línea si el esquema ya está corregido. |
| `patologias` – columna `categoria` | El valor insertado (`'parasitaria'`, `'bacteriana'`, `'micotica'`, `'viral'`) debe coincidir con el tipo `modulo9.enum_patologia_categoria`. Si el enum usa otros literales (ej. `'PARASITARIA'` o `'bacteriana'` con acento), fallará. | Error de tipo enum. | Verificar la definición del enum y ajustar los literales del INSERT. |
| `niveles_alerta_ambientales` – columna `nivel` | Se usan `'normal'`, `'precaucion'`, `'critico'`. La columna es de tipo `modulo9.enum_nivel_alerta`. Si el enum no contiene exactamente esos valores en minúsculas, la inserción falla. | Error de tipo enum. | Verificar el enum; si es necesario, modificar los literales a mayúsculas o a los valores definidos. |
| `sensores` – columna `categoria` | Se usan `'temperatura'`, `'ph'`, `'oxigeno_disuelto'`, `'salinidad'`, `'amoniaco'`. La columna es de tipo `modulo3.enum_reglas_alertas_tipo_sensor`. El módulo 3 no está definido en los scripts entregados, y el enum puede no contener esos valores. | Inserción falla por tipo enum desconocido o valores no permitidos. | Asegurar que el enum exista en `modulo3` y contenga esos literales, o ajustar los datos. |
| `configuraciones_remotas` – `fecha_aplicacion` | Se insertan fechas con `NOW() - INTERVAL 'n days'`. Si el script se ejecuta en una base de datos vacía, es válido. Pero si ya existen datos, puede generar duplicados o conflictos con FKs. | Bajo riesgo (depende del estado de la BD). | Verificar que no haya configuraciones previas para los mismos dispositivos. |
| `configuraciones_globales` – única activa | Solo se inserta una fila con `es_activo = true`. Es correcto. Sin embargo, si el índice parcial `uix_conf_global_unica_activa` se crea después, no habrá conflicto. | Ninguno, siempre que no existan otras activas previas. | Asegurar que no haya otras configuraciones activas antes de insertar. |
| `identidad_visuales` – `secondary_color` | El DDL incluye esta columna, el INSERT la usa. Válido. | - | - |
| `aplicaciones_plantillas` – `target_config`, `before_snapshot`, `after_snapshot` | Los JSON son válidos. Las FK a `plantillas` y `usuarios` deben existir previamente. | Dependencia de datos semilla previos (plantillas y usuarios). | Insertar primero `plantillas` y asegurar usuarios con id=1,2 en `modulo1.` |
| Dependencia de usuarios (`id_usuario = 1` y `2`) | El script asume que existen en `modulo1.usuarios`. Si no, todas las FKs hacia usuarios fallarán. | Error de integridad referencial. | Ejecutar primero el módulo 1 con al menos un administrador (id=1) y un productor (id=2). |

 Ambos scripts (constraints e inserción) requieren ajustes antes de ser aplicados en un entorno con el DDL existente. Los problemas principales son constraints duplicados (ya presentes en el DDL) y discrepancias entre los literales insertados y los tipos enum reales de los módulos 3 y 9. Se recomienda corregir las FK redundantes (omitirlas o validar las existentes) y verificar la definición de los enums antes de ejecutar la inserción.
