-- =============================================================================
-- MÓDULO 9: Esquema de base de datos para gestión de especies, infraestructura
-- IoT, producción y configuración visual de la plataforma agrícola.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TABLA: especies
-- Catálogo maestro de las especies acuícolas o agrícolas gestionadas.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.especies
(
    id_especie          INTEGER                     NOT NULL,
    nombre              CHARACTER VARYING(50)       NOT NULL,
    descripcion         CHARACTER VARYING(255)      NOT NULL,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE,
    fecha_creacion      TIMESTAMP WITH TIME ZONE    NOT NULL,
    es_activo           BOOLEAN                     NOT NULL,
    PRIMARY KEY (id_especie),
    CONSTRAINT uq_especie_nombre UNIQUE (nombre) INCLUDE(nombre)
);

COMMENT ON TABLE  modulo9.especies                        IS 'Catálogo maestro de especies gestionadas en la plataforma (peces, crustáceos, cultivos, etc.).';
COMMENT ON COLUMN modulo9.especies.id_especie             IS 'Identificador único de la especie.';
COMMENT ON COLUMN modulo9.especies.nombre                 IS 'Nombre común o científico de la especie. Debe ser único.';
COMMENT ON COLUMN modulo9.especies.descripcion            IS 'Descripción general de la especie y sus características relevantes.';
COMMENT ON COLUMN modulo9.especies.fecha_actualizacion    IS 'Fecha y hora de la última modificación del registro.';
COMMENT ON COLUMN modulo9.especies.fecha_creacion         IS 'Fecha y hora en que se registró la especie en el sistema.';
COMMENT ON COLUMN modulo9.especies.es_activo              IS 'Indica si la especie está activa y disponible para su uso en el sistema.';


-- -----------------------------------------------------------------------------
-- TABLA: gestion_especies
-- Auditoría de las acciones realizadas sobre las especies (ediciones, umbrales
-- asignados, usuario responsable).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.gestion_especies
(
    id_ediciones_especies   SERIAL                      NOT NULL,
    id_usuario              INTEGER                     NOT NULL,
    id_especie              INTEGER                     NOT NULL,
    fecha_gestion           TIMESTAMP WITH TIME ZONE    NOT NULL,
    id_umbral_ambiental     INTEGER                     NOT NULL,
    PRIMARY KEY (id_ediciones_especies)
);

COMMENT ON TABLE  modulo9.gestion_especies                        IS 'Registro de auditoría de las gestiones (creación, edición) realizadas sobre las especies, incluyendo el umbral ambiental asociado en cada momento.';
COMMENT ON COLUMN modulo9.gestion_especies.id_ediciones_especies  IS 'Identificador único de la gestión registrada.';
COMMENT ON COLUMN modulo9.gestion_especies.id_usuario             IS 'Usuario que realizó la gestión sobre la especie.';
COMMENT ON COLUMN modulo9.gestion_especies.id_especie             IS 'Especie sobre la cual se realizó la gestión.';
COMMENT ON COLUMN modulo9.gestion_especies.fecha_gestion          IS 'Fecha y hora en que se realizó la gestión.';
COMMENT ON COLUMN modulo9.gestion_especies.id_umbral_ambiental    IS 'Umbral ambiental que estaba vigente o fue asignado durante la gestión.';


-- -----------------------------------------------------------------------------
-- TABLA: ciclos_biologicos
-- Define las etapas del ciclo de vida de una especie (larvario, juvenil,
-- adulto, etc.) con su duración estimada.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.ciclos_biologicos
(
    id_ciclo_biologico  SERIAL                      NOT NULL,
    nombre              CHARACTER VARYING(60)       NOT NULL,
    descripcion         CHARACTER VARYING(255)      NOT NULL,
    duracion_dias       INTEGER                     NOT NULL,
    id_especie          INTEGER                     NOT NULL,
    PRIMARY KEY (id_ciclo_biologico)
);

COMMENT ON TABLE  modulo9.ciclos_biologicos                   IS 'Etapas del ciclo de vida de una especie (ej: larvario, juvenil, adulto). Cada ciclo pertenece a una especie específica.';
COMMENT ON COLUMN modulo9.ciclos_biologicos.id_ciclo_biologico IS 'Identificador único del ciclo biológico.';
COMMENT ON COLUMN modulo9.ciclos_biologicos.nombre             IS 'Nombre descriptivo de la etapa biológica (ej: "Fase larval").';
COMMENT ON COLUMN modulo9.ciclos_biologicos.descripcion        IS 'Descripción detallada de las características de esta etapa del ciclo de vida.';
COMMENT ON COLUMN modulo9.ciclos_biologicos.duracion_dias      IS 'Duración estimada de la etapa biológica expresada en días.';
COMMENT ON COLUMN modulo9.ciclos_biologicos.id_especie         IS 'Especie a la que pertenece este ciclo biológico.';


-- -----------------------------------------------------------------------------
-- TABLA: ciclos_productivos
-- Ciclos operativos de producción que pueden estar vinculados a una o más
-- etapas biológicas de la especie.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.ciclos_productivos
(
    id_ciclo_productivo SERIAL                      NOT NULL,
    nombre              CHARACTER VARYING(60)       NOT NULL,
    duracion_dias       INTEGER                     NOT NULL,
    id_ciclo_biologico  INTEGER,
    PRIMARY KEY (id_ciclo_productivo)
);

COMMENT ON TABLE  modulo9.ciclos_productivos                    IS 'Ciclos operativos de producción definidos por el sistema. Pueden estar asociados opcionalmente a una etapa biológica específica.';
COMMENT ON COLUMN modulo9.ciclos_productivos.id_ciclo_productivo IS 'Identificador único del ciclo productivo.';
COMMENT ON COLUMN modulo9.ciclos_productivos.nombre              IS 'Nombre del ciclo productivo (ej: "Ciclo de engorde 2024-A").';
COMMENT ON COLUMN modulo9.ciclos_productivos.duracion_dias       IS 'Duración planificada del ciclo productivo en días.';
COMMENT ON COLUMN modulo9.ciclos_productivos.id_ciclo_biologico  IS 'Ciclo biológico de referencia asociado a este ciclo productivo (opcional).';


-- -----------------------------------------------------------------------------
-- TABLA: ciclos_productivos_biologicos
-- Tabla de relación N:M entre ciclos productivos y ciclos biológicos,
-- permitiendo asociar múltiples etapas biológicas a un ciclo de producción.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.ciclos_productivos_biologicos
(
    id_ciclos_productivo_biologico  SERIAL  NOT NULL,
    id_ciclo_biologico              INTEGER NOT NULL,
    id_ciclo_productivo             INTEGER NOT NULL,
    PRIMARY KEY (id_ciclos_productivo_biologico)
);

COMMENT ON TABLE  modulo9.ciclos_productivos_biologicos                          IS 'Relación N:M entre ciclos productivos y ciclos biológicos. Permite que un ciclo productivo cubra múltiples etapas biológicas.';
COMMENT ON COLUMN modulo9.ciclos_productivos_biologicos.id_ciclos_productivo_biologico IS 'Identificador único de la asociación.';
COMMENT ON COLUMN modulo9.ciclos_productivos_biologicos.id_ciclo_biologico       IS 'Referencia al ciclo biológico asociado.';
COMMENT ON COLUMN modulo9.ciclos_productivos_biologicos.id_ciclo_productivo      IS 'Referencia al ciclo productivo asociado.';


-- -----------------------------------------------------------------------------
-- TABLA: patologias
-- Catálogo de enfermedades o condiciones patológicas conocidas que pueden
-- afectar a las especies registradas.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.patologias
(
    id_patologias   SERIAL                      NOT NULL,
    nombre          CHARACTER VARYING(60)       NOT NULL,
    descripcion     CHARACTER VARYING(255),
    PRIMARY KEY (id_patologias)
);

COMMENT ON TABLE  modulo9.patologias              IS 'Catálogo de patologías (enfermedades, parásitos, condiciones) que pueden afectar a las especies del sistema.';
COMMENT ON COLUMN modulo9.patologias.id_patologias IS 'Identificador único de la patología.';
COMMENT ON COLUMN modulo9.patologias.nombre        IS 'Nombre de la patología o enfermedad (ej: "Ich", "Vibriosis").';
COMMENT ON COLUMN modulo9.patologias.descripcion   IS 'Descripción de los síntomas, causas y características de la patología (opcional).';


-- -----------------------------------------------------------------------------
-- TABLA: especies_patologias
-- Tabla de relación N:M entre especies y patologías que las pueden afectar.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.especies_patologias
(
    id_especies_patologias  SERIAL  NOT NULL,
    id_patologia            INTEGER,
    id_especie              INTEGER NOT NULL,
    PRIMARY KEY (id_especies_patologias)
);

COMMENT ON TABLE  modulo9.especies_patologias                   IS 'Relación N:M entre especies y las patologías conocidas que las pueden afectar.';
COMMENT ON COLUMN modulo9.especies_patologias.id_especies_patologias IS 'Identificador único de la asociación especie-patología.';
COMMENT ON COLUMN modulo9.especies_patologias.id_patologia      IS 'Referencia a la patología que puede afectar a la especie (opcional si está en proceso de clasificación).';
COMMENT ON COLUMN modulo9.especies_patologias.id_especie        IS 'Referencia a la especie afectada por la patología.';


-- -----------------------------------------------------------------------------
-- TABLA: metricas_produccion
-- Catálogo de indicadores medibles durante la producción (peso, talla,
-- biomasa, mortalidad, etc.).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.metricas_produccion
(
    id_metricas_produccion  SERIAL                      NOT NULL,
    nombre                  CHARACTER VARYING(60)       NOT NULL,
    unidad_medida           CHARACTER VARYING(20)       NOT NULL,
    tipo_medicion           CHARACTER VARYING(55)       NOT NULL,
    tiene_estado            BOOLEAN                     NOT NULL,
    PRIMARY KEY (id_metricas_produccion)
);

COMMENT ON TABLE  modulo9.metricas_produccion                     IS 'Catálogo de métricas de producción medibles durante los ciclos productivos (ej: peso promedio, tasa de mortalidad, FCR).';
COMMENT ON COLUMN modulo9.metricas_produccion.id_metricas_produccion IS 'Identificador único de la métrica.';
COMMENT ON COLUMN modulo9.metricas_produccion.nombre              IS 'Nombre de la métrica de producción (ej: "Peso promedio", "Biomasa total").';
COMMENT ON COLUMN modulo9.metricas_produccion.unidad_medida       IS 'Unidad de medida de la métrica (ej: "kg", "g", "%", "ind").';
COMMENT ON COLUMN modulo9.metricas_produccion.tipo_medicion       IS 'Clasifica el método o naturaleza de la medición (ej: "manual", "automatica", "calculada").';
COMMENT ON COLUMN modulo9.metricas_produccion.tiene_estado        IS 'Indica si la métrica tiene un estado de alerta asociado (activa/inactiva u ok/alerta).';


-- -----------------------------------------------------------------------------
-- TABLA: metricas_ciclo_productivo
-- Asocia las métricas de producción aplicables a cada ciclo productivo.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.metricas_ciclo_productivo
(
    id_metricas_ciclo_productivo    SERIAL  NOT NULL,
    id_ciclo_productivo             INTEGER NOT NULL,   -- corregido: antes "id_ciclo_producitvo"
    id_metrica_produccion           INTEGER NOT NULL,
    PRIMARY KEY (id_metricas_ciclo_productivo)
);

COMMENT ON TABLE  modulo9.metricas_ciclo_productivo                         IS 'Asocia las métricas de producción que aplican a cada ciclo productivo específico.';
COMMENT ON COLUMN modulo9.metricas_ciclo_productivo.id_metricas_ciclo_productivo IS 'Identificador único de la asociación métrica-ciclo.';
COMMENT ON COLUMN modulo9.metricas_ciclo_productivo.id_ciclo_productivo     IS 'Referencia al ciclo productivo al que se asigna la métrica.';
COMMENT ON COLUMN modulo9.metricas_ciclo_productivo.id_metrica_produccion   IS 'Referencia a la métrica de producción asignada al ciclo.';


-- -----------------------------------------------------------------------------
-- TABLA: variables_ambientales
-- Define las variables físico-químicas del entorno que se monitorean
-- (temperatura, oxígeno disuelto, pH, salinidad, etc.).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.variables_ambientales
(
    id_variable_ambiental   SERIAL                  NOT NULL,
    nombre                  CHARACTER VARYING(50)   NOT NULL,
    unidad                  CHARACTER VARYING(10)   NOT NULL,
    valor_fisico_min        NUMERIC(8)              NOT NULL,   -- corregido: eliminado duplicado "valor_fisco_min"
    valor_fisico_max        NUMERIC(8)              NOT NULL,   -- corregido: renombrado campo con typo
    es_activo               BOOLEAN                 NOT NULL,
    PRIMARY KEY (id_variable_ambiental),
    CONSTRAINT uq_variable_ambiental_nombre UNIQUE (nombre) INCLUDE(nombre)
);

COMMENT ON TABLE  modulo9.variables_ambientales                       IS 'Catálogo de variables ambientales monitoreadas por los sensores IoT (ej: temperatura del agua, pH, oxígeno disuelto).';
COMMENT ON COLUMN modulo9.variables_ambientales.id_variable_ambiental IS 'Identificador único de la variable ambiental.';
COMMENT ON COLUMN modulo9.variables_ambientales.nombre                IS 'Nombre de la variable ambiental (ej: "Temperatura", "Oxígeno disuelto").';
COMMENT ON COLUMN modulo9.variables_ambientales.unidad                IS 'Unidad de medida física de la variable (ej: "°C", "mg/L", "ppm").';
COMMENT ON COLUMN modulo9.variables_ambientales.valor_fisico_min      IS 'Valor mínimo físicamente posible o aceptable para la variable según su naturaleza.';
COMMENT ON COLUMN modulo9.variables_ambientales.valor_fisico_max      IS 'Valor máximo físicamente posible o aceptable para la variable según su naturaleza.';
COMMENT ON COLUMN modulo9.variables_ambientales.es_activo             IS 'Indica si la variable está activa y siendo monitoreada actualmente.';


-- -----------------------------------------------------------------------------
-- TABLA: umbrales_ambientales
-- Configuración de rangos óptimos y límites de alerta para cada variable
-- ambiental, segmentados por especie.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.umbrales_ambientales
(
    id_umbral_ambiental     SERIAL                      NOT NULL,
    nombre                  CHARACTER VARYING(60)       NOT NULL,
    unidad_medida           CHARACTER VARYING(20)       NOT NULL,
    descripcion             CHARACTER VARYING(255)      NOT NULL,
    es_activo               BOOLEAN                     NOT NULL,
    id_especie              INTEGER                     NOT NULL,
    id_variable_ambiental   INTEGER                     NOT NULL,
    id_usuario              INTEGER,
    PRIMARY KEY (id_umbral_ambiental),
    CONSTRAINT uq_umbral_ambiental_nombre UNIQUE (nombre) INCLUDE(nombre)
);

COMMENT ON TABLE  modulo9.umbrales_ambientales                      IS 'Define los rangos de operación y niveles de alerta para una variable ambiental en el contexto de una especie específica.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.id_umbral_ambiental  IS 'Identificador único del umbral ambiental.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.nombre               IS 'Nombre descriptivo del umbral (ej: "Temperatura óptima tilapia"). Debe ser único.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.unidad_medida        IS 'Unidad de medida asociada a los límites definidos en este umbral.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.descripcion          IS 'Descripción del propósito y criterios de configuración del umbral.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.es_activo            IS 'Indica si el umbral está activo y siendo evaluado por el sistema de alertas.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.id_especie           IS 'Especie para la cual aplica este umbral ambiental.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.id_variable_ambiental IS 'Variable ambiental sobre la que se definen los límites del umbral.';
COMMENT ON COLUMN modulo9.umbrales_ambientales.id_usuario           IS 'Usuario que configuró o actualizó el umbral (opcional).';


-- -----------------------------------------------------------------------------
-- TABLA: niveles_alerta_ambientales
-- Niveles de severidad de alerta (ej: NORMAL, ADVERTENCIA, CRITICO) con sus
-- rangos límite para cada umbral ambiental.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.niveles_alerta_ambientales
(
    id_nivel_alerta_ambiental   SERIAL                  NOT NULL,
    id_umbral_ambiental         INTEGER                 NOT NULL,
    nivel                       enum_nivel_alerta       NOT NULL,
    limite_inferior             NUMERIC(8)              NOT NULL,
    limite_superior             NUMERIC(8)              NOT NULL,
    PRIMARY KEY (id_nivel_alerta_ambiental)
);

COMMENT ON TABLE  modulo9.niveles_alerta_ambientales                        IS 'Define los rangos numéricos de cada nivel de alerta (ej: NORMAL, PRECAUCIÓN, CRÍTICO) para un umbral ambiental dado.';
COMMENT ON COLUMN modulo9.niveles_alerta_ambientales.id_nivel_alerta_ambiental IS 'Identificador único del nivel de alerta.';
COMMENT ON COLUMN modulo9.niveles_alerta_ambientales.id_umbral_ambiental    IS 'Umbral ambiental al que pertenece este nivel de alerta.';
COMMENT ON COLUMN modulo9.niveles_alerta_ambientales.nivel                  IS 'Tipo o severidad del nivel de alerta (valor del enum enum_nivel_alerta).';
COMMENT ON COLUMN modulo9.niveles_alerta_ambientales.limite_inferior        IS 'Valor mínimo del rango que activa este nivel de alerta.';
COMMENT ON COLUMN modulo9.niveles_alerta_ambientales.limite_superior        IS 'Valor máximo del rango que activa este nivel de alerta.';


-- -----------------------------------------------------------------------------
-- TABLA: configuraciones_globales
-- Parámetros globales del sistema IoT (frecuencia de muestreo, heartbeat)
-- con historial de cambios por usuario.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.configuraciones_globales
(
    id_configuracion_global SERIAL                      NOT NULL,
    frecuencia_muestreo     INTEGER                     NOT NULL,
    heartbeat               INTEGER                     NOT NULL,   -- corregido typo: "hearbeat"
    fecha_actualizacion     TIMESTAMP WITH TIME ZONE    NOT NULL,   -- corregido typo: "fecha_actulizacion"
    id_usuario              INTEGER                     NOT NULL,
    es_activo               BOOLEAN                     NOT NULL,
    PRIMARY KEY (id_configuracion_global)
);

COMMENT ON TABLE  modulo9.configuraciones_globales                        IS 'Configuración global del sistema IoT. Controla parámetros generales como la frecuencia de muestreo y el intervalo de heartbeat de los dispositivos.';
COMMENT ON COLUMN modulo9.configuraciones_globales.id_configuracion_global IS 'Identificador único de la configuración global.';
COMMENT ON COLUMN modulo9.configuraciones_globales.frecuencia_muestreo    IS 'Frecuencia de muestreo global de los sensores, expresada en segundos.';
COMMENT ON COLUMN modulo9.configuraciones_globales.heartbeat              IS 'Intervalo de señal de vida (heartbeat) de los dispositivos IoT, expresado en segundos.';
COMMENT ON COLUMN modulo9.configuraciones_globales.fecha_actualizacion    IS 'Fecha y hora en que se registró o modificó esta configuración.';
COMMENT ON COLUMN modulo9.configuraciones_globales.id_usuario             IS 'Usuario administrador que aplicó la configuración.';
COMMENT ON COLUMN modulo9.configuraciones_globales.es_activo              IS 'Indica si esta es la configuración global vigente actualmente.';


-- -----------------------------------------------------------------------------
-- TABLA: finca
-- Unidad productiva principal. Contiene la información geográfica y
-- administrativa de cada finca o instalación.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.finca
(
    id_finca            SERIAL                      NOT NULL,
    nombre              CHARACTER VARYING(55)       NOT NULL,
    ubicacion           JSONB                       NOT NULL,
    tamano_h            NUMERIC(8,2)                NOT NULL,   -- ampliado precision para hectáreas
    fecha_actualizacion TIMESTAMP WITH TIME ZONE    NOT NULL,
    fecha_creacion      TIMESTAMP(0) WITH TIME ZONE NOT NULL,
    id_usuario          INTEGER,
    es_activo           BOOLEAN,
    PRIMARY KEY (id_finca)
);

COMMENT ON TABLE  modulo9.finca                   IS 'Unidad productiva principal del sistema. Representa una finca, granja o instalación acuícola/agrícola con su información georreferenciada.';
COMMENT ON COLUMN modulo9.finca.id_finca          IS 'Identificador único de la finca.';
COMMENT ON COLUMN modulo9.finca.nombre            IS 'Nombre comercial o identificador de la finca.';
COMMENT ON COLUMN modulo9.finca.ubicacion         IS 'Información geográfica de la finca en formato JSON (coordenadas, polígono, dirección, etc.).';
COMMENT ON COLUMN modulo9.finca.tamano_h          IS 'Tamaño total de la finca expresado en hectáreas.';
COMMENT ON COLUMN modulo9.finca.fecha_actualizacion IS 'Fecha y hora de la última modificación del registro de la finca.';
COMMENT ON COLUMN modulo9.finca.fecha_creacion    IS 'Fecha y hora en que se registró la finca en el sistema.';
COMMENT ON COLUMN modulo9.finca.id_usuario        IS 'Usuario propietario o responsable de la finca (opcional).';
COMMENT ON COLUMN modulo9.finca.es_activo         IS 'Indica si la finca está operativa en el sistema.';


-- -----------------------------------------------------------------------------
-- TABLA: infraestructuras
-- Estructuras físicas dentro de una finca (estanques, jaulas, invernaderos,
-- galpones) donde se desarrolla la producción.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.infraestructuras
(
    id_infraestructura  SERIAL                          NOT NULL,
    descripcion         CHARACTER VARYING(100)          NOT NULL,
    nombre              CHARACTER VARYING(50)           NOT NULL,
    id_finca            INTEGER                         NOT NULL,
    superficie          NUMERIC(10,2)                   NOT NULL,   -- corregido typo: "superfice"
    es_activo           BOOLEAN                         NOT NULL,
    tipo                enum_tipo_infraestructura       NOT NULL,
    PRIMARY KEY (id_infraestructura),
    CONSTRAINT uq_infraestructura_nombre UNIQUE (nombre) INCLUDE(nombre)
);

COMMENT ON TABLE  modulo9.infraestructuras                    IS 'Estructura física de producción dentro de una finca (ej: estanque, jaula flotante, invernadero, galpón). Es la unidad de monitoreo principal.';
COMMENT ON COLUMN modulo9.infraestructuras.id_infraestructura IS 'Identificador único de la infraestructura.';
COMMENT ON COLUMN modulo9.infraestructuras.descripcion        IS 'Descripción adicional de la infraestructura y su uso.';
COMMENT ON COLUMN modulo9.infraestructuras.nombre             IS 'Nombre o código identificador de la infraestructura dentro de la finca. Debe ser único.';
COMMENT ON COLUMN modulo9.infraestructuras.id_finca           IS 'Finca a la que pertenece esta infraestructura.';
COMMENT ON COLUMN modulo9.infraestructuras.superficie         IS 'Área o superficie de la infraestructura expresada en metros cuadrados.';
COMMENT ON COLUMN modulo9.infraestructuras.es_activo          IS 'Indica si la infraestructura está activa y en operación.';
COMMENT ON COLUMN modulo9.infraestructuras.tipo               IS 'Tipo de infraestructura según el catálogo del enum (ej: ESTANQUE, JAULA, INVERNADERO).';


-- -----------------------------------------------------------------------------
-- TABLA: dispositivos_iot
-- Dispositivos físicos IoT (gateways, controladores) instalados en las
-- infraestructuras para recolectar datos de sensores.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.dispositivos_iot
(
    id_dispositivo_iot  SERIAL                      NOT NULL,
    serial              CHARACTER VARYING(50)       NOT NULL,
    descripcion         CHARACTER VARYING(100)      NOT NULL,
    id_infraestructura  INTEGER                     NOT NULL,
    es_activo           BOOLEAN                     NOT NULL,
    fecha_creacion      TIMESTAMP WITH TIME ZONE    NOT NULL,
    PRIMARY KEY (id_dispositivo_iot)
);

COMMENT ON TABLE  modulo9.dispositivos_iot                      IS 'Dispositivo IoT físico (gateway, controlador, nodo) instalado en una infraestructura para gestionar la captura y transmisión de datos de sensores.';
COMMENT ON COLUMN modulo9.dispositivos_iot.id_dispositivo_iot  IS 'Identificador único del dispositivo IoT en el sistema.';
COMMENT ON COLUMN modulo9.dispositivos_iot.serial              IS 'Número de serie o código MAC del dispositivo IoT físico.';
COMMENT ON COLUMN modulo9.dispositivos_iot.descripcion         IS 'Descripción del dispositivo, modelo o notas de instalación.';
COMMENT ON COLUMN modulo9.dispositivos_iot.id_infraestructura  IS 'Infraestructura donde está instalado el dispositivo.';
COMMENT ON COLUMN modulo9.dispositivos_iot.es_activo           IS 'Indica si el dispositivo está activo y comunicándose con la plataforma.';
COMMENT ON COLUMN modulo9.dispositivos_iot.fecha_creacion      IS 'Fecha y hora en que el dispositivo fue registrado en el sistema.';


-- -----------------------------------------------------------------------------
-- TABLA: sensores
-- Sensores individuales conectados a un dispositivo IoT, que miden variables
-- ambientales específicas.
-- Nota: nombre corregido de "sesnsores" a "sensores".
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.sensores
(
    id_sensores         SERIAL                  NOT NULL,
    id_dispositivo_iot  INTEGER                 NOT NULL,
    es_activo           BOOLEAN                 NOT NULL,
    nombre              CHARACTER VARYING(60)   NOT NULL,
    PRIMARY KEY (id_sensores)
);

COMMENT ON TABLE  modulo9.sensores                    IS 'Sensor físico conectado a un dispositivo IoT, encargado de medir una variable ambiental específica (ej: sonda de temperatura, electrodo de pH).';
COMMENT ON COLUMN modulo9.sensores.id_sensores        IS 'Identificador único del sensor.';
COMMENT ON COLUMN modulo9.sensores.id_dispositivo_iot IS 'Dispositivo IoT al que está conectado este sensor.';
COMMENT ON COLUMN modulo9.sensores.es_activo          IS 'Indica si el sensor está operativo y enviando lecturas.';
COMMENT ON COLUMN modulo9.sensores.nombre             IS 'Nombre descriptivo del sensor (ej: "Sensor pH estanque 1", "Termómetro zona norte").';


-- -----------------------------------------------------------------------------
-- TABLA: sensores_areas_asociadas
-- Historial de instalación de sensores en infraestructuras específicas,
-- con fechas de inicio y fin de la asociación.
-- Nota: nombre corregido de "sensores_areas_asocidas" a "sensores_areas_asociadas".
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.sensores_areas_asociadas
(
    id_sensores_area_asociada   SERIAL                      NOT NULL,
    id_sensor                   INTEGER                     NOT NULL,
    id_dispositivo_iot          INTEGER                     NOT NULL,
    id_infraestructura          INTEGER                     NOT NULL,
    punto_instalacion           CHARACTER VARYING(100)      NOT NULL,
    tiene_estado                BOOLEAN                     NOT NULL,
    fecha_asociacion            TIMESTAMP WITH TIME ZONE    NOT NULL,
    fecha_finalizacion          TIMESTAMP WITH TIME ZONE,
    id_usuario                  INTEGER                     NOT NULL,
    PRIMARY KEY (id_sensores_area_asociada)
    -- Nota: se eliminó el UNIQUE sobre "tiene_estado" (booleano) ya que no tiene
    -- sentido semántico restringir a un solo registro verdadero/falso en toda la tabla.
);

COMMENT ON TABLE  modulo9.sensores_areas_asociadas                        IS 'Historial de asociaciones de sensores a infraestructuras (áreas de monitoreo). Permite conocer dónde estuvo o está instalado cada sensor a lo largo del tiempo.';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.id_sensores_area_asociada IS 'Identificador único de la asociación sensor-área.';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.id_sensor              IS 'Sensor asociado al área de monitoreo.';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.id_dispositivo_iot     IS 'Dispositivo IoT al que pertenece el sensor en esta asociación.';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.id_infraestructura     IS 'Infraestructura (área) donde está o estuvo instalado el sensor.';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.punto_instalacion      IS 'Descripción del punto exacto de instalación dentro de la infraestructura (ej: "Entrada de agua", "Centro estanque").';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.tiene_estado           IS 'Indica si la asociación está actualmente vigente (TRUE) o fue finalizada (FALSE).';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.fecha_asociacion       IS 'Fecha y hora en que el sensor fue instalado en esta área.';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.fecha_finalizacion     IS 'Fecha y hora en que el sensor fue retirado o desasociado del área (NULL si sigue activo).';
COMMENT ON COLUMN modulo9.sensores_areas_asociadas.id_usuario             IS 'Usuario que registró o gestionó la asociación del sensor.';


-- -----------------------------------------------------------------------------
-- TABLA: configuraciones_remotas
-- Parámetros de captura y transmisión configurados remotamente en cada
-- dispositivo IoT.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.configuraciones_remotas
(
    id_configuracion_remota SERIAL  NOT NULL,
    frecuencia_captura      INTEGER NOT NULL,
    intervalo_transmision   INTEGER NOT NULL,
    id_dispositivo_iot      INTEGER NOT NULL,
    PRIMARY KEY (id_configuracion_remota)
);

COMMENT ON TABLE  modulo9.configuraciones_remotas                       IS 'Configuración enviada remotamente a cada dispositivo IoT para controlar la frecuencia de captura de datos y el intervalo de transmisión hacia la plataforma.';
COMMENT ON COLUMN modulo9.configuraciones_remotas.id_configuracion_remota IS 'Identificador único de la configuración remota.';
COMMENT ON COLUMN modulo9.configuraciones_remotas.frecuencia_captura    IS 'Frecuencia con la que el dispositivo captura lecturas de sus sensores, en segundos.';
COMMENT ON COLUMN modulo9.configuraciones_remotas.intervalo_transmision IS 'Intervalo de tiempo entre transmisiones de datos hacia la plataforma, en segundos.';
COMMENT ON COLUMN modulo9.configuraciones_remotas.id_dispositivo_iot    IS 'Dispositivo IoT al que aplica esta configuración remota.';


-- -----------------------------------------------------------------------------
-- TABLA: calibraciones
-- Registro de calibraciones realizadas sobre los sensores, con el valor de
-- referencia y observaciones del técnico.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.calibraciones
(
    id_calibracion      SERIAL                      NOT NULL,
    id_dispositivo_iot  INTEGER                     NOT NULL,
    fecha_calibracion   TIMESTAMP WITH TIME ZONE    NOT NULL,
    id_sensor           INTEGER                     NOT NULL,
    valor_referencia    NUMERIC(10),
    observaciones       TEXT,
    id_usuario          INTEGER,
    PRIMARY KEY (id_calibracion)
);

COMMENT ON TABLE  modulo9.calibraciones                     IS 'Historial de calibraciones realizadas a los sensores. Garantiza la trazabilidad y precisión de las mediciones en el tiempo.';
COMMENT ON COLUMN modulo9.calibraciones.id_calibracion      IS 'Identificador único del evento de calibración.';
COMMENT ON COLUMN modulo9.calibraciones.id_dispositivo_iot  IS 'Dispositivo IoT al que pertenece el sensor calibrado.';
COMMENT ON COLUMN modulo9.calibraciones.fecha_calibracion   IS 'Fecha y hora en que se realizó la calibración del sensor.';
COMMENT ON COLUMN modulo9.calibraciones.id_sensor           IS 'Sensor que fue calibrado en este evento.';
COMMENT ON COLUMN modulo9.calibraciones.valor_referencia    IS 'Valor patrón o de referencia utilizado durante la calibración.';
COMMENT ON COLUMN modulo9.calibraciones.observaciones       IS 'Notas o comentarios del técnico sobre el proceso de calibración o el estado del sensor.';
COMMENT ON COLUMN modulo9.calibraciones.id_usuario          IS 'Usuario o técnico que realizó la calibración (opcional).';


-- -----------------------------------------------------------------------------
-- TABLA: identidad_visuales
-- Configuración de identidad visual (logo, color primario, nombre) por finca,
-- para personalizar la interfaz de cada organización.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.identidad_visuales
(
    id_identidad_visual SERIAL                      NOT NULL,   -- corregido typo: "id_indentidad_visual"
    id_finca            INTEGER                     NOT NULL,
    id_usuario          INTEGER                     NOT NULL,
    logo_path           CHARACTER VARYING(255),
    primary_color       CHARACTER VARYING(7),
    org_display_name    CHARACTER VARYING(50),
    version             INTEGER,
    fecha_creacion      TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (id_identidad_visual)
);

COMMENT ON TABLE  modulo9.identidad_visuales                    IS 'Configuración de identidad visual de la organización asociada a una finca (logotipo, color corporativo, nombre visible). Permite personalizar la interfaz por cliente.';
COMMENT ON COLUMN modulo9.identidad_visuales.id_identidad_visual IS 'Identificador único del registro de identidad visual.';
COMMENT ON COLUMN modulo9.identidad_visuales.id_finca           IS 'Finca u organización a la que pertenece esta identidad visual.';
COMMENT ON COLUMN modulo9.identidad_visuales.id_usuario         IS 'Usuario que configuró o actualizó la identidad visual.';
COMMENT ON COLUMN modulo9.identidad_visuales.logo_path          IS 'Ruta o URL del archivo de logotipo de la organización.';
COMMENT ON COLUMN modulo9.identidad_visuales.primary_color      IS 'Color primario corporativo en formato hexadecimal (ej: "#2A7AE4").';
COMMENT ON COLUMN modulo9.identidad_visuales.org_display_name   IS 'Nombre visible de la organización en la interfaz de usuario.';
COMMENT ON COLUMN modulo9.identidad_visuales.version            IS 'Versión del registro de identidad visual (para control de cambios).';
COMMENT ON COLUMN modulo9.identidad_visuales.fecha_creacion     IS 'Fecha y hora en que se creó o actualizó la configuración visual.';


-- -----------------------------------------------------------------------------
-- TABLA: temas_visuales
-- Preferencia de tema de interfaz (oscuro/claro/sistema) por usuario.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.temas_visuales
(
    id_tema_visual      SERIAL                      NOT NULL,
    id_usuario          INTEGER                     NOT NULL,   -- corregido: "id_user" -> "id_usuario"
    theme_mode          INTEGER                     NOT NULL,
    es_global           BOOLEAN                     NOT NULL,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE    NOT NULL,
    PRIMARY KEY (id_tema_visual)
);

COMMENT ON TABLE  modulo9.temas_visuales                    IS 'Preferencia de tema visual de la interfaz por usuario (ej: claro, oscuro, según sistema operativo).';
COMMENT ON COLUMN modulo9.temas_visuales.id_tema_visual     IS 'Identificador único de la preferencia de tema.';
COMMENT ON COLUMN modulo9.temas_visuales.id_usuario         IS 'Usuario al que pertenece esta preferencia de tema.';
COMMENT ON COLUMN modulo9.temas_visuales.theme_mode         IS 'Modo de tema seleccionado (ej: 0=Sistema, 1=Claro, 2=Oscuro).';
COMMENT ON COLUMN modulo9.temas_visuales.es_global          IS 'Indica si la preferencia aplica globalmente para todos los módulos o solo para una sección específica.';
COMMENT ON COLUMN modulo9.temas_visuales.fecha_actualizacion IS 'Fecha y hora de la última actualización de la preferencia.';


-- -----------------------------------------------------------------------------
-- TABLA: dashboard_layouts
-- Configuración del layout y widgets activos del dashboard por usuario.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.dashboard_layouts
(
    id_dashboard_layout SERIAL                      NOT NULL,
    id_usuario          INTEGER                     NOT NULL,   -- corregido: "id_user" -> "id_usuario"
    config              JSONB                       NOT NULL,
    active_widget       TEXT[]                      NOT NULL,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (id_dashboard_layout)
);

COMMENT ON TABLE  modulo9.dashboard_layouts                     IS 'Almacena la configuración personalizada del dashboard de cada usuario: disposición de paneles, widgets activos y parámetros de visualización.';
COMMENT ON COLUMN modulo9.dashboard_layouts.id_dashboard_layout IS 'Identificador único de la configuración de dashboard.';
COMMENT ON COLUMN modulo9.dashboard_layouts.id_usuario          IS 'Usuario al que pertenece esta configuración de dashboard.';
COMMENT ON COLUMN modulo9.dashboard_layouts.config              IS 'Objeto JSON con la disposición y parámetros de los paneles del dashboard.';
COMMENT ON COLUMN modulo9.dashboard_layouts.active_widget       IS 'Lista de identificadores de widgets activos y visibles en el dashboard del usuario.';
COMMENT ON COLUMN modulo9.dashboard_layouts.fecha_actualizacion IS 'Fecha y hora de la última actualización de la configuración del dashboard.';


-- -----------------------------------------------------------------------------
-- TABLA: preferencias_idiomas
-- Preferencias de idioma y localización por usuario.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.preferencias_idiomas
(
    id_preferencia_idioma   SERIAL                      NOT NULL,
    id_usuario              INTEGER                     NOT NULL,   -- corregido typo: "id_ususario"
    local_code              CHARACTER VARYING(5)        NOT NULL,
    es_por_defecto          BOOLEAN                     NOT NULL,
    fecha_actualizacion     TIMESTAMP WITH TIME ZONE,               -- corregido typo: "fecha_actulizacion"
    PRIMARY KEY (id_preferencia_idioma)
);

COMMENT ON TABLE  modulo9.preferencias_idiomas                        IS 'Preferencias de idioma e internacionalización (i18n) de cada usuario en la plataforma.';
COMMENT ON COLUMN modulo9.preferencias_idiomas.id_preferencia_idioma  IS 'Identificador único de la preferencia de idioma.';
COMMENT ON COLUMN modulo9.preferencias_idiomas.id_usuario             IS 'Usuario al que pertenece esta preferencia de idioma.';
COMMENT ON COLUMN modulo9.preferencias_idiomas.local_code             IS 'Código de idioma y región según estándar IETF BCP 47 (ej: "es-CO", "en-US", "pt-BR").';
COMMENT ON COLUMN modulo9.preferencias_idiomas.es_por_defecto         IS 'Indica si este es el idioma predeterminado del usuario.';
COMMENT ON COLUMN modulo9.preferencias_idiomas.fecha_actualizacion    IS 'Fecha y hora de la última actualización de la preferencia de idioma.';


-- -----------------------------------------------------------------------------
-- TABLA: auditorias_visuales
-- Registro de cambios en configuraciones visuales para trazabilidad y rollback.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.auditorias_visuales
(
    id_auditoria_visual SERIAL                      NOT NULL,
    id_usuario          INTEGER                     NOT NULL,
    fecha_creacion      TIMESTAMP WITH TIME ZONE    NOT NULL,
    valor_anterior      JSONB                       NOT NULL,
    valor_nuevo         JSONB                       NOT NULL,
    PRIMARY KEY (id_auditoria_visual)
);

COMMENT ON TABLE  modulo9.auditorias_visuales                     IS 'Registro de auditoría de cambios en configuraciones visuales (temas, layouts, identidad). Permite trazabilidad y posibilidad de revertir cambios.';
COMMENT ON COLUMN modulo9.auditorias_visuales.id_auditoria_visual IS 'Identificador único del registro de auditoría.';
COMMENT ON COLUMN modulo9.auditorias_visuales.id_usuario          IS 'Usuario que realizó el cambio en la configuración visual.';
COMMENT ON COLUMN modulo9.auditorias_visuales.fecha_creacion      IS 'Fecha y hora en que se registró el cambio auditado.';
COMMENT ON COLUMN modulo9.auditorias_visuales.valor_anterior      IS 'Snapshot JSON del estado de la configuración visual antes del cambio.';
COMMENT ON COLUMN modulo9.auditorias_visuales.valor_nuevo         IS 'Snapshot JSON del estado de la configuración visual después del cambio.';


-- -----------------------------------------------------------------------------
-- TABLA: plantillas
-- Plantillas reutilizables de configuración de especie, que capturan un
-- snapshot de parámetros para ser aplicadas a nuevos ciclos o fincas.
-- Nota: nombre corregido de "platillas" a "plantillas".
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.plantillas
(
    id_plantilla    SERIAL                      NOT NULL,
    id_especie      INTEGER                     NOT NULL,
    id_usuario      INTEGER                     NOT NULL,
    template_name   CHARACTER VARYING(50)       NOT NULL,
    params_snapshot JSONB                       NOT NULL,
    version         INTEGER                     NOT NULL,
    fecha_creacion  TIMESTAMP WITH TIME ZONE    NOT NULL,
    PRIMARY KEY (id_plantilla)
);

COMMENT ON TABLE  modulo9.plantillas                  IS 'Plantillas de configuración reutilizables por especie. Almacenan un snapshot de parámetros (umbrales, métricas, ciclos) para ser replicados en nuevas infraestructuras o ciclos productivos.';
COMMENT ON COLUMN modulo9.plantillas.id_plantilla     IS 'Identificador único de la plantilla.';
COMMENT ON COLUMN modulo9.plantillas.id_especie       IS 'Especie para la cual fue creada la plantilla de configuración.';
COMMENT ON COLUMN modulo9.plantillas.id_usuario       IS 'Usuario que creó o es propietario de la plantilla.';
COMMENT ON COLUMN modulo9.plantillas.template_name    IS 'Nombre descriptivo de la plantilla.';
COMMENT ON COLUMN modulo9.plantillas.params_snapshot  IS 'Snapshot JSON de los parámetros de configuración capturados en el momento de creación de la plantilla.';
COMMENT ON COLUMN modulo9.plantillas.version          IS 'Número de versión de la plantilla para control de cambios.';
COMMENT ON COLUMN modulo9.plantillas.fecha_creacion   IS 'Fecha y hora en que se creó la plantilla.';


-- -----------------------------------------------------------------------------
-- TABLA: aplicaciones_plantillas
-- Registro de cada vez que una plantilla fue aplicada a una configuración
-- concreta, con snapshots del antes y después.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modulo9.aplicaciones_plantillas
(
    id_aplicacion_plantilla SERIAL                      NOT NULL,   -- corregido typo: "id_aplicacion_platilla"
    id_usuario              INTEGER                     NOT NULL,
    id_plantilla            INTEGER                     NOT NULL,
    target_config           JSONB                       NOT NULL,
    before_snapshot         JSONB,
    after_snapshot          JSONB,
    fecha_aplicacion        TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (id_aplicacion_plantilla)
);

COMMENT ON TABLE  modulo9.aplicaciones_plantillas                       IS 'Historial de aplicaciones de plantillas de configuración sobre infraestructuras o ciclos productivos. Permite auditar qué configuración existía antes y después de aplicar cada plantilla.';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.id_aplicacion_plantilla IS 'Identificador único del evento de aplicación de plantilla.';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.id_usuario            IS 'Usuario que ejecutó la aplicación de la plantilla.';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.id_plantilla          IS 'Plantilla que fue aplicada.';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.target_config         IS 'JSON con la identificación del objetivo sobre el que se aplicó la plantilla (finca, infraestructura, ciclo, etc.).';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.before_snapshot       IS 'Snapshot JSON de la configuración del objetivo antes de aplicar la plantilla.';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.after_snapshot        IS 'Snapshot JSON de la configuración del objetivo después de aplicar la plantilla.';
COMMENT ON COLUMN modulo9.aplicaciones_plantillas.fecha_aplicacion      IS 'Fecha y hora en que se aplicó la plantilla.';


-- =============================================================================
-- FOREIGN KEYS
-- =============================================================================

-- gestion_especies
ALTER TABLE IF EXISTS modulo9.gestion_especies
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.gestion_especies
    ADD FOREIGN KEY (id_especie)
    REFERENCES modulo9.especies (id_especie) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.gestion_especies
    ADD FOREIGN KEY (id_umbral_ambiental)
    REFERENCES modulo9.umbrales_ambientales (id_umbral_ambiental) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- ciclos_biologicos
ALTER TABLE IF EXISTS modulo9.ciclos_biologicos
    ADD FOREIGN KEY (id_especie)
    REFERENCES modulo9.especies (id_especie) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- especies_patologias
ALTER TABLE IF EXISTS modulo9.especies_patologias
    ADD FOREIGN KEY (id_patologia)
    REFERENCES modulo9.patologias (id_patologias) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.especies_patologias
    ADD FOREIGN KEY (id_especie)
    REFERENCES modulo9.especies (id_especie) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- ciclos_productivos_biologicos
ALTER TABLE IF EXISTS modulo9.ciclos_productivos_biologicos
    ADD FOREIGN KEY (id_ciclo_biologico)
    REFERENCES modulo9.ciclos_biologicos (id_ciclo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.ciclos_productivos_biologicos
    ADD FOREIGN KEY (id_ciclo_productivo)
    REFERENCES modulo9.ciclos_productivos (id_ciclo_productivo) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- metricas_ciclo_productivo (corregida la FK que apuntaba a la PK propia)
ALTER TABLE IF EXISTS modulo9.metricas_ciclo_productivo
    ADD FOREIGN KEY (id_ciclo_productivo)
    REFERENCES modulo9.ciclos_productivos (id_ciclo_productivo) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.metricas_ciclo_productivo
    ADD FOREIGN KEY (id_metrica_produccion)
    REFERENCES modulo9.metricas_produccion (id_metricas_produccion) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- umbrales_ambientales
ALTER TABLE IF EXISTS modulo9.umbrales_ambientales
    ADD FOREIGN KEY (id_especie)
    REFERENCES modulo9.especies (id_especie) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.umbrales_ambientales
    ADD FOREIGN KEY (id_variable_ambiental)
    REFERENCES modulo9.variables_ambientales (id_variable_ambiental) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.umbrales_ambientales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuarios) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- niveles_alerta_ambientales
ALTER TABLE IF EXISTS modulo9.niveles_alerta_ambientales
    ADD FOREIGN KEY (id_umbral_ambiental)
    REFERENCES modulo9.umbrales_ambientales (id_umbral_ambiental) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- configuraciones_globales
ALTER TABLE IF EXISTS modulo9.configuraciones_globales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- finca
ALTER TABLE IF EXISTS modulo9.finca
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- infraestructuras
ALTER TABLE IF EXISTS modulo9.infraestructuras
    ADD FOREIGN KEY (id_finca)
    REFERENCES modulo9.finca (id_finca) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- dispositivos_iot
ALTER TABLE IF EXISTS modulo9.dispositivos_iot
    ADD FOREIGN KEY (id_infraestructura)
    REFERENCES modulo9.infraestructuras (id_infraestructura) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- sensores
ALTER TABLE IF EXISTS modulo9.sensores
    ADD FOREIGN KEY (id_dispositivo_iot)
    REFERENCES modulo9.dispositivos_iot (id_dispositivo_iot) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- sensores_areas_asociadas
ALTER TABLE IF EXISTS modulo9.sensores_areas_asociadas
    ADD FOREIGN KEY (id_sensor)
    REFERENCES modulo9.sensores (id_sensores) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.sensores_areas_asociadas
    ADD FOREIGN KEY (id_dispositivo_iot)
    REFERENCES modulo9.dispositivos_iot (id_dispositivo_iot) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.sensores_areas_asociadas
    ADD FOREIGN KEY (id_infraestructura)
    REFERENCES modulo9.infraestructuras (id_infraestructura) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.sensores_areas_asociadas
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- configuraciones_remotas
ALTER TABLE IF EXISTS modulo9.configuraciones_remotas
    ADD FOREIGN KEY (id_dispositivo_iot)
    REFERENCES modulo9.dispositivos_iot (id_dispositivo_iot) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- calibraciones
ALTER TABLE IF EXISTS modulo9.calibraciones
    ADD FOREIGN KEY (id_dispositivo_iot)
    REFERENCES modulo9.dispositivos_iot (id_dispositivo_iot) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.calibraciones
    ADD FOREIGN KEY (id_sensor)
    REFERENCES modulo9.sensores (id_sensores) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.calibraciones
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- identidad_visuales
ALTER TABLE IF EXISTS modulo9.identidad_visuales
    ADD FOREIGN KEY (id_finca)
    REFERENCES modulo9.finca (id_finca) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.identidad_visuales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- temas_visuales
ALTER TABLE IF EXISTS modulo9.temas_visuales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- dashboard_layouts
ALTER TABLE IF EXISTS modulo9.dashboard_layouts
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- preferencias_idiomas
ALTER TABLE IF EXISTS modulo9.preferencias_idiomas
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- auditorias_visuales
ALTER TABLE IF EXISTS modulo9.auditorias_visuales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- plantillas
ALTER TABLE IF EXISTS modulo9.plantillas
    ADD FOREIGN KEY (id_especie)
    REFERENCES modulo9.especies (id_especie) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.plantillas
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

-- aplicaciones_plantillas
ALTER TABLE IF EXISTS modulo9.aplicaciones_plantillas
    ADD FOREIGN KEY (id_usuario)
    REFERENCES public.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;

ALTER TABLE IF EXISTS modulo9.aplicaciones_plantillas
    ADD FOREIGN KEY (id_plantilla)
    REFERENCES modulo9.plantillas (id_plantilla) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT VALID;