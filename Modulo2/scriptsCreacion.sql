CREATE TABLE IF NOT EXISTS modulo2.activos_biologicos
(
    id_activo_biologico serial NOT NULL,
    id_especie integer NOT NULL,
    indentficador character varying(25),
    id_infraestructura integer NOT NULL,
    tipo modulo2.enum_activo_biologico_tipo NOT NULL,
    fecha_inicio_ciclo integer,
    id_estado integer NOT NULL,
    descripcion character varying(100),
    origen_financiero modulo2.enum_activo_biologico_origen_financiero NOT NULL,
    costo_adquisicion numeric(18, 4),
    atributos_dinamicos jsonb,
    id_usuario integer NOT NULL,
    fecha_creacion timestamp with time zone NOT NULL,
    PRIMARY KEY (id_activo_biologico),
    CONSTRAINT uq_activo_biologico_identificador UNIQUE (indentficador)
        INCLUDE(indentficador)
);


CREATE TABLE IF NOT EXISTS modulo2.movimientos
(
    id_movimiento serial NOT NULL,
    id_usuario integer NOT NULL,
    fecha_transferencia timestamp with time zone NOT NULL,
    fecha_fin time with time zone,
    tipo modulo2.enum_movimiento_tipo NOT NULL,
    id_activo_biologico integer NOT NULL,
    id_infraestructura_origen integer NOT NULL,
    id_infraestructura_destino integer NOT NULL,
    fecha_registro timestamp with time zone,
    PRIMARY KEY (id_movimiento)
);

CREATE TABLE IF NOT EXISTS modulo2.detalles_activos_individuales
(
    id_detalle_activo_individual serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    raza character varying(50) NOT NULL,
    sexo character varying(10) NOT NULL,
    fecha_nacimeinto timestamp with time zone NOT NULL,
    peso_inicial numeric(10, 3),
    fecha_creacion time with time zone NOT NULL,
    fecha_actualizacion timestamp with time zone,
    id_usuario integer,
    PRIMARY KEY (id_detalle_activo_individual),
    CONSTRAINT uq_detalle_activo_biologico UNIQUE (id_activo_biologico)
        INCLUDE(id_activo_biologico)
);

CREATE TABLE IF NOT EXISTS modulo2.auditoria_activos_biologicos_individuales
(
    id_auditoria_activo_biologico_individual serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    id_usuario integer NOT NULL,
    campo_modificado character varying NOT NULL,
    valor_anterior jsonb NOT NULL,
    valor_nuevo jsonb NOT NULL,
    fecha_cambio time with time zone NOT NULL,
    modulo_origen character varying(30),
    PRIMARY KEY (id_auditoria_activo_biologico_individual)
);

CREATE TABLE IF NOT EXISTS modulo2.detalles_activos_biologicos_poblacionales
(
    id_detalle_activo_biologico_poblacional serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    cantidad_inicial integer NOT NULL,
    cantidad_actual integer,
    peso_promedio numeric NOT NULL,
    biomasa_total numeric NOT NULL,
    densidad numeric NOT NULL,
    PRIMARY KEY (id_detalle_activo_biologico_poblacional)
);

CREATE TABLE IF NOT EXISTS modulo2.gestiones_fases
(
    id_gestion_fases serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    id_ciclo_productiva integer NOT NULL,
    fecha_inicio time with time zone NOT NULL,
    fecha_finalizacion timestamp with time zone,
    es_activa boolean NOT NULL DEFAULT true,
    id_usuario integer NOT NULL,
    PRIMARY KEY (id_gestion_fases)
);


CREATE TABLE IF NOT EXISTS modulo2.eventos_activos
(
    id_eventos serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    fecha timestamp with time zone NOT NULL,
    descripcion text,
    id_usuario integer,
    PRIMARY KEY (id_eventos)
);

CREATE TABLE IF NOT EXISTS modulo2.eventos_crecimeinto
(
    id_evento integer NOT NULL,
    tipo_medicion character varying(55) NOT NULL,
    valor_medicion numeric(10, 2) NOT NULL,
    unidad_medida character varying(5) NOT NULL,
    tipo_agregacion character varying(55) NOT NULL,
    frecuencia character varying(55) NOT NULL,
    PRIMARY KEY (id_evento)
);


CREATE TABLE IF NOT EXISTS modulo2.eventos_sanitarios
(
    id_evento integer NOT NULL,
    diagnostico text NOT NULL,
    medicamento character varying NOT NULL,
    dosis numeric(10, 2) NOT NULL,
    unidad_dosis character varying(5) NOT NULL,
    frecuencia integer,
    PRIMARY KEY (id_evento)
);

CREATE TABLE IF NOT EXISTS modulo2.eventos_reproductivos
(
    id_evento_reproductivo integer NOT NULL,
    categoria modulo2.enum_evento_sanitario_categoria NOT NULL,
    id_padre integer NOT NULL,
    resultado character varying(55) NOT NULL,
    numero_cria integer NOT NULL DEFAULT 0,
    id_madre integer,
    PRIMARY KEY (id_evento_reproductivo)
);

CREATE TABLE IF NOT EXISTS modulo2.eventos_productivos
(
    id_evento integer NOT NULL,
    cantidad numeric(12, 3) NOT NULL,
    condiciones text,
    id_metrica_produccion integer NOT NULL,
    id_ciclo_productivo integer NOT NULL,
    PRIMARY KEY (id_evento)
);


CREATE TABLE IF NOT EXISTS modulo2.estados_activos_biologicos
(
    id_estado_activo_biologico serial NOT NULL,
    nombre character varying(25) NOT NULL,
    PRIMARY KEY (id_estado_activo_biologico)
);

CREATE TABLE IF NOT EXISTS modulo2.historicos_estados_activos
(
    id_historico_estado_activo serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    id_estado_nuevo integer NOT NULL,
    id_estado_anterior integer NOT NULL,
    fecha_cambio timestamp with time zone NOT NULL,
    motivo_cambio text,
    modulo_origen character varying(20) NOT NULL,
    id_usuario integer NOT NULL,
    PRIMARY KEY (id_historico_estado_activo)
);

CREATE TABLE IF NOT EXISTS modulo2.eventos_bajas
(
    id_evento integer NOT NULL,
    cantidad_afectada integer NOT NULL,
    detalles text,
    tipo modulo2.enum_evento_bajas_tipo NOT NULL,
    PRIMARY KEY (id_evento)
);

CREATE TABLE IF NOT EXISTS modulo2.asociaciones_activos_sensores
(
    id_asociacion_activo_sensor serial NOT NULL,
    id_sensor integer NOT NULL,
    id_usuario integer NOT NULL,
    fecha_inicio timestamp with time zone NOT NULL,
    fecha_fin timestamp with time zone NOT NULL,
    motivo text,
    PRIMARY KEY (id_asociacion_activo_sensor)
);

CREATE TABLE IF NOT EXISTS modulo2.indicadores_zootecnicos
(
    id_indicador_zootecnico serial NOT NULL,
    id_activo_biologico integer NOT NULL,
    rango_fecha daterange NOT NULL,
    tipo modulo2.enum_indicador_zootecnico_tipo NOT NULL,
    paramtros_calculo jsonb NOT NULL,
    PRIMARY KEY (id_indicador_zootecnico)
);


ALTER TABLE IF EXISTS modulo2.activos_biologicos
    ADD FOREIGN KEY (id_infraestructura)
    REFERENCES modulo9.infraestructuras (id_infraestructura) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.activos_biologicos
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.activos_biologicos
    ADD FOREIGN KEY (id_estado)
    REFERENCES modulo2.estados_activos_biologicos (id_estado_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.movimientos
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.movimientos
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.movimientos
    ADD FOREIGN KEY (id_infraestructura_origen)
    REFERENCES modulo9.infraestructuras (id_infraestructura) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.movimientos
    ADD FOREIGN KEY (id_infraestructura_destino)
    REFERENCES modulo9.infraestructuras (id_infraestructura) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.detalles_activos_individuales
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.detalles_activos_individuales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.auditoria_activos_biologicos_individuales
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.auditoria_activos_biologicos_individuales
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.detalles_activos_biologicos_poblacionales
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.gestiones_fases
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.gestiones_fases
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.gestiones_fases
    ADD FOREIGN KEY (id_ciclo_productiva)
    REFERENCES modulo9.ciclos_productivos (id_ciclo_productivo) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_activos
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_activos
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_crecimeinto
    ADD FOREIGN KEY (id_evento)
    REFERENCES modulo2.eventos_activos (id_eventos) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_sanitarios
    ADD FOREIGN KEY (id_evento)
    REFERENCES modulo2.eventos_activos (id_eventos) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_reproductivos
    ADD FOREIGN KEY (id_evento_reproductivo)
    REFERENCES modulo2.eventos_activos (id_eventos) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_reproductivos
    ADD FOREIGN KEY (id_padre)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_reproductivos
    ADD FOREIGN KEY (id_madre)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_productivos
    ADD FOREIGN KEY (id_evento)
    REFERENCES modulo2.eventos_activos (id_eventos) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_productivos
	ADD CONSTRAINT fk_evento_metrica
	FOREIGN KEY (id_metrica_produccion)
	REFERENCES modulo9.metricas_produccion (id_metrica_produccion)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;


ALTER TABLE IF EXISTS modulo2.eventos_productivos
    ADD FOREIGN KEY (id_ciclo_productivo)
    REFERENCES modulo9.ciclos_productivos (id_ciclo_productivo) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.historicos_estados_activos
    ADD FOREIGN KEY (id_estado_nuevo)
    REFERENCES modulo2.estados_activos_biologicos (id_estado_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.historicos_estados_activos
    ADD FOREIGN KEY (id_estado_anterior)
    REFERENCES modulo2.estados_activos_biologicos (id_estado_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.historicos_estados_activos
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.historicos_estados_activos
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.eventos_bajas
    ADD FOREIGN KEY (id_evento)
    REFERENCES modulo2.eventos_activos (id_eventos) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.asociaciones_activos_sensores
    ADD FOREIGN KEY (id_usuario)
    REFERENCES modulo1.usuarios (id_usuario) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.asociaciones_activos_sensores
    ADD FOREIGN KEY (id_sensor)
    REFERENCES modulo9.sensores (id_sensores) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS modulo2.indicadores_zootecnicos
    ADD FOREIGN KEY (id_activo_biologico)
    REFERENCES modulo2.activos_biologicos (id_activo_biologico) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


COMMENT ON COLUMN modulo2.activos_biologicos.id_activo_biologico IS 'Identificador único del activo biológico';
COMMENT ON COLUMN modulo2.activos_biologicos.id_especie IS 'Referencia a la especie del activo biológico';
COMMENT ON COLUMN modulo2.activos_biologicos.indentficador IS 'Código único de identificación del activo (arete, lote, etc.)';
COMMENT ON COLUMN modulo2.activos_biologicos.id_infraestructura IS 'Infraestructura donde se encuentra el activo';
COMMENT ON COLUMN modulo2.activos_biologicos.tipo IS 'Tipo de activo biológico (individual o poblacional)';
COMMENT ON COLUMN modulo2.activos_biologicos.fecha_inicio_ciclo IS 'Fecha de inicio del ciclo productivo del activo';
COMMENT ON COLUMN modulo2.activos_biologicos.id_estado IS 'Estado actual del activo biológico';
COMMENT ON COLUMN modulo2.activos_biologicos.descripcion IS 'Descripción general del activo';
COMMENT ON COLUMN modulo2.activos_biologicos.origen_financiero IS 'Origen financiero del activo (propio, arrendado, etc.)';
COMMENT ON COLUMN modulo2.activos_biologicos.costo_adquisicion IS 'Costo de adquisición del activo biológico';
COMMENT ON COLUMN modulo2.activos_biologicos.atributos_dinamicos IS 'Atributos variables del activo en formato JSON';
COMMENT ON COLUMN modulo2.activos_biologicos.id_usuario IS 'Usuario que registró el activo';
COMMENT ON COLUMN modulo2.activos_biologicos.fecha_creacion IS 'Fecha de creación del registro';

COMMENT ON COLUMN modulo2.movimientos.id_movimiento IS 'Identificador único del movimiento';
COMMENT ON COLUMN modulo2.movimientos.id_usuario IS 'Usuario que registra el movimiento';
COMMENT ON COLUMN modulo2.movimientos.fecha_transferencia IS 'Fecha en que se realiza el traslado del activo';
COMMENT ON COLUMN modulo2.movimientos.fecha_fin IS 'Hora de finalización del movimiento';
COMMENT ON COLUMN modulo2.movimientos.tipo IS 'Tipo de movimiento realizado';
COMMENT ON COLUMN modulo2.movimientos.id_activo_biologico IS 'Activo biológico involucrado en el movimiento';
COMMENT ON COLUMN modulo2.movimientos.id_infraestructura_origen IS 'Infraestructura de origen';
COMMENT ON COLUMN modulo2.movimientos.id_infraestructura_destino IS 'Infraestructura de destino';
COMMENT ON COLUMN modulo2.movimientos.fecha_registro IS 'Fecha de registro del movimiento en el sistema';

COMMENT ON COLUMN modulo2.detalles_activos_individuales.id_detalle_activo_individual IS 'Identificador del detalle individual';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.id_activo_biologico IS 'Activo biológico asociado';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.raza IS 'Raza del activo';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.sexo IS 'Sexo del activo';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.fecha_nacimeinto IS 'Fecha de nacimiento';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.peso_inicial IS 'Peso inicial registrado';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.fecha_creacion IS 'Hora de creación del registro';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.fecha_actualizacion IS 'Fecha de última actualización';
COMMENT ON COLUMN modulo2.detalles_activos_individuales.id_usuario IS 'Usuario que registra o actualiza';

COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.id_auditoria_activo_biologico_individual IS 'Identificador del registro de auditoría';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.id_activo_biologico IS 'Activo auditado';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.id_usuario IS 'Usuario que realizó el cambio';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.campo_modificado IS 'Campo que fue modificado';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.valor_anterior IS 'Valor previo en formato JSON';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.valor_nuevo IS 'Nuevo valor en formato JSON';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.fecha_cambio IS 'Fecha del cambio realizado';
COMMENT ON COLUMN modulo2.auditoria_activos_biologicos_individuales.modulo_origen IS 'Módulo desde donde se realizó el cambio';

COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.id_detalle_activo_biologico_poblacional IS 'Identificador del detalle poblacional';
COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.id_activo_biologico IS 'Activo biológico asociado';
COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.cantidad_inicial IS 'Cantidad inicial de individuos';
COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.cantidad_actual IS 'Cantidad actual de individuos';
COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.peso_promedio IS 'Peso promedio del grupo';
COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.biomasa_total IS 'Biomasa total del grupo';
COMMENT ON COLUMN modulo2.detalles_activos_biologicos_poblacionales.densidad IS 'Densidad poblacional';


COMMENT ON COLUMN modulo2.eventos_productivos.id_evento IS 'Identificador del evento productivo';
COMMENT ON COLUMN modulo2.eventos_productivos.cantidad IS 'Cantidad producida o registrada';
COMMENT ON COLUMN modulo2.eventos_productivos.condiciones IS 'Condiciones del evento productivo';
COMMENT ON COLUMN modulo2.eventos_productivos.id_metrica_produccion IS 'Métrica de producción asociada';
COMMENT ON COLUMN modulo2.eventos_productivos.id_ciclo_productivo IS 'Ciclo productivo asociado';

COMMENT ON COLUMN modulo2.asociaciones_activos_sensores.id_asociacion_activo_sensor IS 'Identificador de la asociación activo-sensor';
COMMENT ON COLUMN modulo2.asociaciones_activos_sensores.id_sensor IS 'Sensor IoT asociado';
COMMENT ON COLUMN modulo2.asociaciones_activos_sensores.id_usuario IS 'Usuario que realiza la asociación';
COMMENT ON COLUMN modulo2.asociaciones_activos_sensores.fecha_inicio IS 'Fecha de inicio de la asociación';
COMMENT ON COLUMN modulo2.asociaciones_activos_sensores.fecha_fin IS 'Fecha de finalización de la asociación';
COMMENT ON COLUMN modulo2.asociaciones_activos_sensores.motivo IS 'Motivo de la asociación o desvinculación';

COMMENT ON COLUMN modulo2.indicadores_zootecnicos.id_indicador_zootecnico IS 'Identificador del indicador';
COMMENT ON COLUMN modulo2.indicadores_zootecnicos.id_activo_biologico IS 'Activo biológico evaluado';
COMMENT ON COLUMN modulo2.indicadores_zootecnicos.rango_fecha IS 'Periodo de cálculo del indicador';
COMMENT ON COLUMN modulo2.indicadores_zootecnicos.tipo IS 'Tipo de indicador zootécnico';
COMMENT ON COLUMN modulo2.indicadores_zootecnicos.paramtros_calculo IS 'Parámetros utilizados en el cálculo';

COMMENT ON COLUMN modulo2.gestiones_fases.id_gestion_fases IS 'Identificador de la gestión de fase productiva';
COMMENT ON COLUMN modulo2.gestiones_fases.id_activo_biologico IS 'Activo biológico asociado';
COMMENT ON COLUMN modulo2.gestiones_fases.id_ciclo_productiva IS 'Ciclo productivo al que pertenece';
COMMENT ON COLUMN modulo2.gestiones_fases.fecha_inicio IS 'Fecha de inicio de la fase';
COMMENT ON COLUMN modulo2.gestiones_fases.fecha_finalizacion IS 'Fecha de finalización de la fase';
COMMENT ON COLUMN modulo2.gestiones_fases.es_activa IS 'Indica si la fase se encuentra activa';
COMMENT ON COLUMN modulo2.gestiones_fases.id_usuario IS 'Usuario responsable del registro';

COMMENT ON COLUMN modulo2.eventos_activos.id_eventos IS 'Identificador del evento';
COMMENT ON COLUMN modulo2.eventos_activos.id_activo_biologico IS 'Activo biológico asociado al evento';
COMMENT ON COLUMN modulo2.eventos_activos.fecha IS 'Fecha en que ocurre el evento';
COMMENT ON COLUMN modulo2.eventos_activos.descripcion IS 'Descripción del evento registrado';
COMMENT ON COLUMN modulo2.eventos_activos.id_usuario IS 'Usuario que registra el evento';

COMMENT ON COLUMN modulo2.eventos_crecimeinto.id_evento IS 'Identificador del evento de crecimiento';
COMMENT ON COLUMN modulo2.eventos_crecimeinto.tipo_medicion IS 'Tipo de medición realizada (peso, talla, etc.)';
COMMENT ON COLUMN modulo2.eventos_crecimeinto.valor_medicion IS 'Valor registrado de la medición';
COMMENT ON COLUMN modulo2.eventos_crecimeinto.unidad_medida IS 'Unidad de medida utilizada';
COMMENT ON COLUMN modulo2.eventos_crecimeinto.tipo_agregacion IS 'Tipo de agregación de la medición';
COMMENT ON COLUMN modulo2.eventos_crecimeinto.frecuencia IS 'Frecuencia de medición';

COMMENT ON COLUMN modulo2.eventos_sanitarios.id_evento IS 'Identificador del evento sanitario';
COMMENT ON COLUMN modulo2.eventos_sanitarios.diagnostico IS 'Diagnóstico registrado';
COMMENT ON COLUMN modulo2.eventos_sanitarios.medicamento IS 'Medicamento aplicado';
COMMENT ON COLUMN modulo2.eventos_sanitarios.dosis IS 'Cantidad administrada del medicamento';
COMMENT ON COLUMN modulo2.eventos_sanitarios.unidad_dosis IS 'Unidad de la dosis aplicada';
COMMENT ON COLUMN modulo2.eventos_sanitarios.frecuencia IS 'Frecuencia de aplicación del tratamiento';

COMMENT ON COLUMN modulo2.eventos_reproductivos.id_evento_reproductivo IS 'Identificador del evento reproductivo';
COMMENT ON COLUMN modulo2.eventos_reproductivos.categoria IS 'Categoría del evento reproductivo';
COMMENT ON COLUMN modulo2.eventos_reproductivos.id_padre IS 'Identificador del padre';
COMMENT ON COLUMN modulo2.eventos_reproductivos.resultado IS 'Resultado del evento reproductivo';
COMMENT ON COLUMN modulo2.eventos_reproductivos.numero_cria IS 'Número de crías generadas';
COMMENT ON COLUMN modulo2.eventos_reproductivos.id_madre IS 'Identificador de la madre';

COMMENT ON COLUMN modulo2.eventos_bajas.id_evento IS 'Identificador del evento de baja';
COMMENT ON COLUMN modulo2.eventos_bajas.cantidad_afectada IS 'Cantidad de activos afectados';
COMMENT ON COLUMN modulo2.eventos_bajas.detalles IS 'Detalles del evento de baja';
COMMENT ON COLUMN modulo2.eventos_bajas.tipo IS 'Tipo de baja (muerte, venta, descarte, etc.)';

COMMENT ON COLUMN modulo2.estados_activos_biologicos.id_estado_activo_biologico IS 'Identificador del estado';
COMMENT ON COLUMN modulo2.estados_activos_biologicos.nombre IS 'Nombre del estado del activo biológico';

COMMENT ON COLUMN modulo2.historicos_estados_activos.id_historico_estado_activo IS 'Identificador del cambio de estado';
COMMENT ON COLUMN modulo2.historicos_estados_activos.id_activo_biologico IS 'Activo biológico asociado';
COMMENT ON COLUMN modulo2.historicos_estados_activos.id_estado_nuevo IS 'Nuevo estado asignado';
COMMENT ON COLUMN modulo2.historicos_estados_activos.id_estado_anterior IS 'Estado previo del activo';
COMMENT ON COLUMN modulo2.historicos_estados_activos.fecha_cambio IS 'Fecha del cambio de estado';
COMMENT ON COLUMN modulo2.historicos_estados_activos.motivo_cambio IS 'Motivo del cambio de estado';
COMMENT ON COLUMN modulo2.historicos_estados_activos.modulo_origen IS 'Módulo que generó el cambio';
COMMENT ON COLUMN modulo2.historicos_estados_activos.id_usuario IS 'Usuario que realizó el cambio';