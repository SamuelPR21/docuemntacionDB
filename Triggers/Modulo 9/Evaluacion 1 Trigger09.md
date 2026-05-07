Aquí tienes la tabla solicitada, sin emojis, en formato texto plano:

| ID Trigger | Nombre | Requerimiento(s) | Cumple | Observaciones / Deficiencias |
|------------|--------|------------------|--------|-------------------------------|
| TRG-M9-01 | Unicidad de nombre de especie (case-insensitive) | RF-15 | Si | Corrige la limitación del UNIQUE case-sensitive. Además normaliza con INITCAP. Aceptable. |
| TRG-M9-02 | Longitud y formato mínimo del nombre de especie | RF-15 | Si | Valida largo entre 3 y 50. Mensaje claro. |
| TRG-M9-03 | Auditoría automática de operaciones sobre especies | RF-15 | No | Error grave: asigna COALESCE(NEW.id_especie, OLD.id_especie) a id_usuario, rompiendo la FK. No guarda valores anteriores/nuevos como exige RF-15. |
| TRG-M9-04 | Protección de eliminación física de especies | RF-15 | Si | Bloquea DELETE correctamente. |
| TRG-M9-05 | Unicidad de nombre de ciclo biológico (etapa) por especie, case-insensitive | RF-16 | Si | Cubre unicidad por especie. |
| TRG-M9-06 | Validación de duración de ciclo biológico (etapa) | RF-16 | Si | Asegura duración > 0. |
| TRG-M9-07 | Bloqueo de desactivación de etapa con activos biológicos vinculados | RF-16 | Parcial | Solo revisa ciclos_productivos_biologicos. No verifica animales/lotes reales en esa etapa. |
| TRG-M9-08 | Unicidad de nombre de patología (case-insensitive, global) | RF-16 | Si | Unicidad global case-insensitive para patologías. |
| TRG-M9-09 | Protección de eliminación física de patologías | RF-16 | Si | Bloquea DELETE. |
| TRG-M9-10 | Unicidad de nombre de métrica productiva (case-insensitive) | RF-16 | Si | Unicidad global para métricas. |
| TRG-M9-11 | Unicidad activa de umbral ambiental por especie + variable | RF-17 | Si | Impide dos umbrales activos para misma especie y variable. |
| TRG-M9-12 | Validación de rango y especie activa en umbral ambiental | RF-17 | Si | Valida valor_min < valor_max y especie activa. |
| TRG-M9-13 | Validación de no solapamiento de niveles de alerta | RF-17 | Parcial | Lógica de solapamiento correcta pero código truncado en PDF. No valida cobertura completa del rango [valor_min, valor_max]. |
| TRG-M9-14 | Unicidad de configuración global activa | RF-18 | No | Solo actúa en BEFORE INSERT. No impide que un UPDATE active otra fila. |
| TRG-M9-15 | Validación de heartbeat y frecuencia de muestreo | RF-18 | Si | Valida positivos y heartbeat >= frecuencia. |
| TRG-M9-16 | Unicidad y validación de formato del nombre de finca | RF-19 | Parcial | Unicidad correcta. Validación de formato falla: usa `!=` con regex, no funciona en PostgreSQL. |
| TRG-M9-17 | Validación de coordenadas y tamaño de finca | RF-19 | Si | Valida tamaño >0 y coordenadas en rangos. Correcto. |
| TRG-M9-18 | Protección de eliminación física de fincas | RF-19 | Parcial | Solo revisa infraestructuras. No verifica dispositivos IoT ni activos biológicos dependientes directamente. |
| TRG-M9-19 | Unicidad de nombre de infraestructura por finca (case-insensitive) | RF-20 | Si | Correcto. |
| TRG-M9-20 | Validación de superficie de infraestructura | RF-20 | Si | Superficie > 0. |
| TRG-M9-21 | Bloqueo de desactivación de infraestructura con dependencias operativas | RF-20 | Si | Verifica dispositivos activos y sensores asociados. |
| TRG-M9-22 | Unicidad del serial de dispositivo IoT | RF-21 | Si | Serial único. |
| TRG-M9-23 | Bloqueo de eliminación física de dispositivos IoT con datos históricos | RF-21 | Si | Verifica calibraciones, configuraciones remotas y sensores. |
| TRG-M9-24 | Unicidad de asociación activa sensor-área | RF-22 | Si | Un sensor solo puede estar activo en un área. |
| TRG-M9-25 | Validación de dispositivo activo para calibración | RF-24 | Parcial | Verifica dispositivo activo, pero no verifica que el sensor esté activo (sensores.es_activo = true). |
| TRG-M9-26 | Unicidad de nombre de plantilla e inmutabilidad de versiones | RF-30, RF-31 | Si | Versionado incremental, evita duplicados en nombre. |
| TRG-M9-27 | Inmutabilidad de plantillas (bloqueo de UPDATE y DELETE) | RF-30, RF-31 | Si | Bloquea modificaciones directas. |
| TRG-M9-28 | Auditoría de cambios en identidad visual | RF-26 | Parcial | Solo se dispara en UPDATE. No audita INSERT (creación inicial). |
| TRG-M9-29 | Validación de colores hexadecimales en identidad visual | RF-26 | No | Mismo error de regex: usa `!=` con patrón, no funciona. |
| TRG-M9-30 | Validación de theme_mode en temas visuales | RF-27 | Si | Acepta solo 1,2,3. |
| TRG-M9-31 | Validación de configuración remota: lógica de tiempos | RF-23 | Si | Valida positivos e intervalo >= frecuencia. |
| TRG-M9-32 | Unicidad de configuración remota PENDIENTE por dispositivo | RF-23 | Si | Impide dos comandos pendientes simultáneos. |
