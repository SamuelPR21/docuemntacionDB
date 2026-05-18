CREATE OR REPLACE VIEW modulo6.VW_06_01precios_mercado_vigentes AS
	SELECT 
		pm.id_especie ,
		pm.categoria,
		pm.fuente,
		pm.id_usuario, 
		pm.estado,
		pm.fecha_vigencia, 
		pm.hash_evidencia, 
		act.id_activo_biologico

	FROM modulo6.precios_mercado pm
	JOIN modulo9.especies e
	ON pm.id_especie = e.id_especie
	JOIN modulo2.activos_biologicos act
	ON  act.id_especie =  e.id_especie;


CREATE OR REPLACE VIEW modulo6.VW_06_01precio_mercado_activo_por_activo AS
	SELECT 
		act.id_activo_biologico,
		pm.id_especie,
		pm.estado, 
		pm.fecha_vigencia, 
		pm.fuente 

	FROM modulo2.activos_biologicos act
	INNER JOIN modulo9.especies e
	ON act.id_especie = e.id_especie
	INNER JOIN modulo6.precios_mercado pm 
	ON   e.id_especie =  pm.id_especie
	WHERE pm.estado = 'ACTIVO' AND pm.fecha_vigencia <= CURRENT_DATE; 


CREATE OR REPLACE VIEW modulo6.VW_06_03parametros_costos_venta_activos AS
	SELECT 
		pcv.id_parametro_costo_venta,
		pcv.id_especie,
		pcv.es_activo 

	FROM modulo6.parametros_costos_venta pcv
	INNER JOIN modulo9.especies e
	ON pcv.id_especie = e.id_especie
	WHERE pcv.es_activo = true; 

CREATE OR REPLACE VIEW modulo6.VW_06_04reconocimientos_iniciales_detalle AS
	SELECT 
		ri.id_reconocimiento_inicial,
		ri.estado,
		ri.cuenta_debito,
		ri.cuenta_credito,
		ri.valor_razonable_neto_inicial,
		ri.id_activo_biologico,
		ri.id_periodo_contable,
		ri.id_usuario,	
		act.id_especie,
		act.id_infraestructura,
		inf.id_finca
		
	FROM modulo6.reconocimientos_iniciales ri
	INNER JOIN modulo2.activos_biologicos act
	ON ri.id_activo_biologico = act.id_activo_biologico
	INNER JOIN modulo9.infraestructuras inf
	ON act.id_infraestructura  = inf.id_infraestructura

CREATE OR REPLACE VIEW modulo6.VW_06_05_activos_sin_reconocimiento AS
	SELECT 
		act.id_activo_biologico,	
		act.id_especie,
		act.id_infraestructura,
		ri.id_reconocimiento_inicial,
		ri.estado
		
	FROM modulo2.activos_biologicos act
	LEFT JOIN modulo6.reconocimientos_iniciales ri
	ON ri.id_activo_biologico = act.id_activo_biologico
	WHERE ri.id_activo_biologico IS NULL;

CREATE OR REPLACE VIEW modulo6.VW_06_06_calculos_valor_razonable_detalle AS
	SELECT 
		cvr.id_calculo_valor_razonable,	
		act.id_especie,
		act.id_infraestructura,
		ri.id_reconocimiento_inicial,
		ri.estado
		
	FROM modulo2.activos_biologicos act
	LEFT JOIN modulo6.reconocimientos_iniciales ri
	ON ri.id_activo_biologico = act.id_activo_biologico
	WHERE ri.id_activo_biologico IS NULL;


 