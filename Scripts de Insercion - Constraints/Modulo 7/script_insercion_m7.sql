-- ==============================================================
-- SCRIPT DE INSERCIÓN DE DATOS — MÓDULO 7
-- ==============================================================
--
-- TABLAS DEL MÓDULO 7 (verificadas contra backup6_1_1.sql):
--   1.  tipos_documentos_aaef
--   2.  versiones_contrato_aaef
--   3.  clientes_externos
--   4.  permisos_api
--   5.  permisos_clientes
--   6.  identificadores_apis
--   7.  catalogo_errores_de_integracion
--   8.  mapeos_anexos_aaef
--   9.  reglas_mapeo_aaef
--  10.  integraciones_solicitudes
--  11.  documentos_generados_aaef
--  12.  metadatos_respuesta_aaef
--  13.  registros_ejecucion_mapeador
--  14.  notificaciones_weebhook
--  15.  auditoria_peticiones
--
-- TYPOS EN EL DDL (usar nombres exactos del DDL):
--   auditoria_peticiones.id_intgracion_solucitud    (doble typo)
--   notificaciones_weebhook (tabla: doble 'e')
--   notificaciones_weebhook.estado_notifiacion      (falta 'c')
--   permisos_clientes.id_clienete_externo           (letras invertidas)
--   integraciones_solicitudes.fecha_comienzoo       (doble 'o')
--   documentos_generados_aaef."tamaño_payload_bytes" (con tilde)
--
-- ESTADO DE CONSTRAINTS EN EL BACKUP:
--   FKs ACTIVAS (SIN NOT VALID):
--     fk_auditoria_integracion_solicitudes_id
--     fk_documentos_generados_aaef_integracion_solicitud
--     fk_documentos_generados_aaef_tipo_documento_aaef_id
--     fk_identificadores_apis_cliente_externo_id
--     fk_integraciones_solicitudes_catalogo_error_id
--     fk_integraciones_solicitudes_cliente_externo_id
--     fk_integraciones_solicitudes_version_contrato_id
--     fk_mapeos_anexos_aaef_version_contrato_aaef_id
--     fk_metadatos_respuesta_aaef_integracion_solicitud_id
--     fk_notificaciones_weebhook_integracion_solicitudes
--     fk_permisos_clientes_cliente_externo
--     fk_permisos_clientes_persmiso_api_id
--     fk_registros_ejecucion_mapeador_integracion_solicitud_id
--     fk_reglas_mapeo_aaef_mapeo_anexo_id
--     fk_reglas_mapeo_aaef_tipo_documento_id
--     fk_consultas_auditoria_externas_auditoria (M8→M7)
--
--   FKs ELIMINADAS EN MIGRACIÓN (referencias lógicas):
--     fk_auditoria_usuario_id             → modulo1.usuarios
--     fk_integraciones_solicitudes_usuario_id → modulo1.usuarios
--     fk_integraciones_solicitudes_periodo_contable_id → modulo6
--     fk_documentos_generados_aaef_calculo_valor_razonable_id → M6
--     fk_documentos_generados_aaef_cotizaciones_id → M6
--     fk_documentos_generados_aaef_reconocimiento_iniciales → M6
--     fk_documentos_generados_aaef_valoracion_por_costo_id → M6
--     fk_registros_ejecucion_mapeador_usuario_id → modulo1.usuarios
--
--   UQs ELIMINADAS (re-creadas en constraints):
--     uq_auditoria_evento
--     uq_cliente_externo_codigo
--     uq_mapeos_anexos_aaef_codigo_anexo
--     uq_metadatos_respuesta_aaef_identificador_cambio
--     uq_permisos_api_codigo
--     uq_tipos_documentos_aaef_codigo
--     uq_version_contrato
--
-- ENUMs DEL MÓDULO 7:
--   enum_catalogo_errores_de_integracion_codigo:
--     'METHOD_NOT_ALLOWED','UNAUTHORIZED','FORBIDDEN','INVALID_PERIOD',
--     'PERIOD_NOT_FOUND','INTERNAL_ERROR','SERVICE_UNAVAILABLE'
--
--   enum_cliente_externo_tipo:
--     'ACTIVO','SUSPENDIDO','REVOCADO'
--
--   enum_documentos_generados_aaef_estado:
--     'GENERATED','FAILED','PARTIAL'
--
--   enum_identificadores_apis_estado:
--     'ACTIVA','REVOCADA','EXPIRADA'
--
--   enum_integraciones_solicitudes_estado:
--     'SUCCESS','FAILED','TIMEOUT','UNAUTHORIZED','FORBIDDEN'
--
--   enum_mapeos_anexos_aaef_estado:
--     'BORRADOR','EN_REVISION','APROBADO','OBSOLETO'
--
--   enum_notificaciones_weebhook_estado_notificacion:
--     'PENDING','SENT','FAILED'
--
--   enum_notificaciones_weebhook_tipo:
--     'PERIODO_CERRADO'
--
--   enum_permisos_api_metodo_http:
--     'GET','POST','PUT','PATCH','DELETE'
--
--   enum_registros_ejecucion_mapeador_estado:
--     'SUCCESS','FAILED','SKIPPED'
--
--   enum_versiones_contrato_aaef_estado:
--     'BORRADOR','EN_REVISION','APROBADO','OBSOLETO'
-- ==============================================================


-- ==============================================================
-- PRECONDICIÓN 0 — VERIFICAR DEPENDENCIAS EXTERNAS
-- ==============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM modulo1.usuarios
        WHERE id_usuario IN (1, 2) HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo1.usuarios '
            'debe tener ids 1 y 2. Ejecute primero M1.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM modulo6.periodos_contables
        WHERE id_periodo_contable IN (1, 4)
        HAVING COUNT(*) = 2
    ) THEN
        RAISE EXCEPTION 'PRECONDICIÓN FALLIDA: modulo6.periodos_contables '
            'debe tener al menos 4 registros. Ejecute primero M6.';
    END IF;
END $$;


-- ==============================================================
-- ORDEN DE INSERCIÓN (respeta dependencias FK internas):
--   1.  tipos_documentos_aaef          ← tabla catálogo, sin FK
--   2.  versiones_contrato_aaef        ← sin FK interna
--   3.  clientes_externos              ← sin FK interna
--   4.  permisos_api                   ← sin FK interna
--   5.  permisos_clientes              ← depende de 3 y 4
--   6.  identificadores_apis           ← depende de 3
--   7.  catalogo_errores_de_integracion ← sin FK interna
--   8.  mapeos_anexos_aaef             ← depende de 2
--   9.  reglas_mapeo_aaef              ← depende de 8 y 1
--  10.  integraciones_solicitudes      ← depende de 3, 7 y 2
--  11.  documentos_generados_aaef      ← depende de 10 y 1
--  12.  metadatos_respuesta_aaef       ← depende de 10
--  13.  registros_ejecucion_mapeador   ← depende de 10
--  14.  notificaciones_weebhook        ← depende de 10
--  15.  auditoria_peticiones           ← depende de 10
-- ==============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. TIPOS DE DOCUMENTOS AAEF
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.tipos_documentos_aaef
    (id_tipo_documento_aaef, codigo, nombre, descripcion)
VALUES
(1, '01',
 'Reconocimiento / Factura / Estado de Resultados / Revelaciones',
 'Documentos de reconocimiento inicial (RF-82), estado de resultados '
 '(RF-93) y revelaciones NIC 41 (RF-92). Origen: RF-82, RF-93, RF-92.'),

(2, '02',
 'Compra / Costo / Inversión',
 'Documentos de costos de mantenimiento e inversión (RF-90). '
 'Formalizado en el contrato AAEF v2.0. Origen: RF-90.'),

(3, '03',
 'Nota Crédito (variación negativa de valor razonable)',
 'Nota crédito generada por variación negativa de VR (RF-86). '
 'Representa pérdida por transformación biológica o precio. '
 'Origen: RF-86 componente negativo.'),

(4, '04A',
 'Nota Débito — Variación Positiva de Valor Razonable',
 'Nota débito por variación positiva de VR. DocumentId prefijo VB-. '
 'Origen: RF-86 componente positivo (ganancia).'),

(5, '04B',
 'Cotización de Venta de Activo Biológico',
 'Documento de cotización de venta de activo biológico (RF-COT). '
 'Registro en cuentas de orden. No modifica el VR.');


-- ─────────────────────────────────────────────────────────────
-- 2. VERSIONES DEL CONTRATO AAEF
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.versiones_contrato_aaef
    (id_version_contrato_aaef, contrato_version, estado,
     descripcion, fecha_comienzo, fecha_creacion)
VALUES
-- Versión obsoleta (primera versión del contrato)
(1, '1.0', 'OBSOLETO',
 'Primera versión del contrato AAEF con Agrofusión. '
 'Cubre type_code 01 (reconocimiento) y 04 (cotizaciones). '
 'Deprecada al aprobarse v2.0 con soporte para type_code 02 y 03.',
 '2024-01-01', NOW() - INTERVAL '400 days'),

-- Versión vigente y aprobada
(2, '2.0', 'APROBADO',
 'Versión 2.0 del contrato AAEF. Formaliza type_code 02 (Costo/Inversión) '
 'y 03 (Nota Crédito variación negativa). Incorpora Anexo de Mapeo '
 'AAEF v2.0 aprobado por Agrofusión. Cumple estándar RF-INT-13 v4.0.',
 '2024-07-01', NOW() - INTERVAL '200 days');


-- ─────────────────────────────────────────────────────────────
-- 3. CLIENTES EXTERNOS
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.clientes_externos
    (id_cliente_externo, codigo, nombre, tipo, estado,
     ip_permitida, fecha_creacion)
VALUES
-- Agrofusión: sistema externo principal (SISTEMA_INTERMEDIARIO)
(1, 'AGROFUSION-PROD-001',
 'Agrofusión S.A.S. — Sistema de Integración Financiera',
 'SISTEMA_INTERMEDIARIO', 'ACTIVO',
 '190.144.32.10',
 NOW() - INTERVAL '400 days'),

-- Cliente de pruebas en ambiente de staging
(2, 'AGROFUSION-STAGING-001',
 'Agrofusión S.A.S. — Ambiente de Staging / QA',
 'SISTEMA_INTERMEDIARIO', 'ACTIVO',
 '190.144.32.50',
 NOW() - INTERVAL '300 days'),

-- Cliente suspendido (integración temporal revocada)
(3, 'BANCO-AGRARIO-TEST-001',
 'Banco Agrario de Colombia — Integración Piloto (suspendida)',
 'SISTEMA_EXTERNO', 'SUSPENDIDO',
 NULL,
 NOW() - INTERVAL '200 days');


-- ─────────────────────────────────────────────────────────────
-- 4. PERMISOS DE API
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.permisos_api
    (id_permiso_api, codigo, nombre, endpoint_patron,
     metodo_http, fecha_creacion)
VALUES
-- Consulta del endpoint AAEF principal (RF-102)
(1, 'AAEF_CONSULT_GET',
 'Consulta de datos financieros AAEF por período',
 '/api/v2/aaef/periodos/{id_periodo}/exportar',
 'GET', NOW() - INTERVAL '400 days'),

-- Exportación / generación del paquete AAEF (RF-96)
(2, 'AAEF_EXPORT_POST',
 'Generación y exportación del paquete AAEF',
 '/api/v2/aaef/exportar',
 'POST', NOW() - INTERVAL '400 days'),

-- Consulta del estado de una solicitud de integración
(3, 'AAEF_STATUS_GET',
 'Consulta del estado de una solicitud de integración',
 '/api/v2/integraciones/{id}/estado',
 'GET', NOW() - INTERVAL '400 days'),

-- Registro de webhook (RF-98)
(4, 'WEBHOOK_REGISTER_POST',
 'Registro de endpoint de webhook para notificaciones',
 '/api/v2/webhooks/registro',
 'POST', NOW() - INTERVAL '200 days'),

-- Consulta de auditoría (RF-101)
(5, 'AUDIT_CONSULT_GET',
 'Consulta del log de auditoría de peticiones',
 '/api/v2/auditoria/peticiones',
 'GET', NOW() - INTERVAL '200 days');


-- ─────────────────────────────────────────────────────────────
-- 5. PERMISOS DE CLIENTES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.permisos_clientes
    (id_permiso_cliente, id_clienete_externo, id_permiso_api,
     fecha_asignacion)
VALUES
-- Agrofusión PROD: acceso a consulta AAEF, exportación y webhooks
(1, 1, 1, NOW() - INTERVAL '400 days'),
(2, 1, 2, NOW() - INTERVAL '400 days'),
(3, 1, 3, NOW() - INTERVAL '400 days'),
(4, 1, 4, NOW() - INTERVAL '200 days'),
(5, 1, 5, NOW() - INTERVAL '200 days'),

-- Agrofusión STAGING: solo consulta y estado (sin exportación real)
(6, 2, 1, NOW() - INTERVAL '300 days'),
(7, 2, 3, NOW() - INTERVAL '300 days');


-- ─────────────────────────────────────────────────────────────
-- 6. IDENTIFICADORES DE API
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.identificadores_apis
    (id_identificador_api, id_cliente_externo,
     api_llave_encriptada, certificado_serial,
     fecha_emision, fecha_expiracion, fecha_revocacion,
     estado, fecha_creacion)
VALUES
-- API Key activa de Agrofusión PROD
(1, 1,
 '$argon2id$v=19$m=65536,t=3,p=4$'
 'c2FsdF9hZ3JvZnVzaW9uX3YxX3Byb2Q$'
 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
 'CERT-AGROFUSION-2024-001',
 NOW() - INTERVAL '365 days',
 NOW() + INTERVAL '365 days',
 NULL,
 'ACTIVA', NOW() - INTERVAL '365 days'),

-- API Key revocada de Agrofusión PROD (renovación semestral)
(2, 1,
 '$argon2id$v=19$m=65536,t=3,p=4$'
 'c2FsdF9hZ3JvZnVzaW9uX3YwX3Byb2Q$'
 'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3',
 'CERT-AGROFUSION-2023-001',
 NOW() - INTERVAL '730 days',
 NOW() - INTERVAL '365 days',
 NOW() - INTERVAL '366 days',
 'REVOCADA', NOW() - INTERVAL '730 days'),

-- API Key activa de Agrofusión STAGING
(3, 2,
 '$argon2id$v=19$m=65536,t=3,p=4$'
 'c2FsdF9hZ3JvZnVzaW9uX3N0YWdpbmc$'
 'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4',
 NULL,
 NOW() - INTERVAL '300 days',
 NOW() + INTERVAL '65 days',
 NULL,
 'ACTIVA', NOW() - INTERVAL '300 days');


-- ─────────────────────────────────────────────────────────────
-- 7. CATÁLOGO DE ERRORES DE INTEGRACIÓN
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.catalogo_errores_de_integracion
    (id_catalogo_error, codigo, estado_http, mensaje,
     descripcion_interna, es_activo)
VALUES
(1, 'UNAUTHORIZED', 401,
 'Credencial de acceso no válida o ausente.',
 'La API Key no fue enviada en el encabezado Authorization, '
 'no existe en el sistema o está en estado REVOCADA/EXPIRADA.',
 true),

(2, 'FORBIDDEN', 403,
 'El cliente no tiene permisos para este recurso.',
 'El cliente existe y está autenticado, pero no tiene el permiso '
 'de API necesario para el endpoint solicitado.',
 true),

(3, 'METHOD_NOT_ALLOWED', 405,
 'Método HTTP no permitido para este endpoint.',
 'El cliente usó un método HTTP (GET, POST, etc.) no definido '
 'en el permiso de API correspondiente al endpoint.',
 true),

(4, 'INVALID_PERIOD', 422,
 'El período contable no está en estado CERRADO.',
 'El endpoint AAEF solo permite consultar períodos CERRADO. '
 'El período solicitado está ABIERTO o EN_CIERRE.',
 true),

(5, 'PERIOD_NOT_FOUND', 404,
 'El período contable solicitado no existe.',
 'No existe un período contable con el identificador proporcionado '
 'en el parámetro de la solicitud.',
 true),

(6, 'INTERNAL_ERROR', 500,
 'Error interno del sistema. Intente nuevamente.',
 'Error no controlado en el procesamiento interno del Gateway '
 'o en la generación del paquete AAEF. Se registra en auditoría.',
 true),

(7, 'SERVICE_UNAVAILABLE', 503,
 'El servicio no está disponible temporalmente.',
 'El módulo fuente de datos (M06 u otro) no responde dentro '
 'del tiempo límite configurado para el Gateway.',
 true);


-- ─────────────────────────────────────────────────────────────
-- 8. MAPEOS ANEXOS AAEF
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.mapeos_anexos_aaef
    (id_mapeo_anexo_aaef, id_version_contrato_aaef,
     codigo_anexo, version_anexo, estado,
     direccion_pdf, canonical_sha256,
     fecha_aprobacion_interna, fecha_aprobacion_agrofusion,
     fecha_creacion)
VALUES
-- Anexo v1.0 (obsoleto — correspondía al contrato v1.0)
(1, 1,
 'ANEXO-AAEF-V1.0', '1.0', 'OBSOLETO',
 's3://pecuaria-docs/contratos/anexo-aaef-v1.0.pdf',
 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
 NOW() - INTERVAL '400 days', NOW() - INTERVAL '395 days',
 NOW() - INTERVAL '400 days'),

-- Anexo v2.0 APROBADO (contrato vigente)
(2, 2,
 'ANEXO-AAEF-V2.0', '2.0', 'APROBADO',
 's3://pecuaria-docs/contratos/anexo-aaef-v2.0.pdf',
 'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3',
 NOW() - INTERVAL '210 days', NOW() - INTERVAL '200 days',
 NOW() - INTERVAL '210 days');


-- ─────────────────────────────────────────────────────────────
-- 9. REGLAS DE MAPEO AAEF
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.reglas_mapeo_aaef
    (id_regla_mapeo_aaef, id_mapeo_anexo, id_tipo_documento,
     entidad_origen, campo_origen, campo_destino,
     regla_transformacion, es_requerida, fecha_creacion)
VALUES
-- Mapeos del Anexo v2.0 — type_code 01 (Reconocimiento/Factura)
(1, 2, 1,
 'modulo6.reconocimientos_iniciales', 'valor_razonable_neto_inicial',
 'invoice.amount.totalAmount',
 'ROUND(valor_razonable_neto_inicial, 2)',
 true, NOW() - INTERVAL '200 days'),

(2, 2, 1,
 'modulo6.reconocimientos_iniciales', 'cuenta_debito',
 'invoice.accounting.accountingAccount[0]',
 'CAST(cuenta_debito AS VARCHAR)',
 true, NOW() - INTERVAL '200 days'),

-- Mapeos del Anexo v2.0 — type_code 02 (Costos)
(3, 2, 2,
 'modulo6.registros_costos', 'monto_costo',
 'invoice.amount.totalAmount',
 'ROUND(monto_costo, 2)',
 true, NOW() - INTERVAL '200 days'),

(4, 2, 2,
 'modulo6.registros_costos', 'naturaleza_costo',
 'invoice.lineItems[0].lineType',
 'CASE naturaleza_costo WHEN ''MANTENIMIENTO'' THEN ''Gastos de mantenimiento'' '
 'WHEN ''INVERSION'' THEN ''Inversión capitalizable'' END',
 true, NOW() - INTERVAL '200 days'),

-- Mapeos del Anexo v2.0 — type_code 04B (Cotizaciones)
(5, 2, 5,
 'modulo6.cotizaciones', '"valor_cotizacion_propuesto "',
 'invoice.amount.totalAmount',
 'ROUND("valor_cotizacion_propuesto ", 2)',
 true, NOW() - INTERVAL '200 days');


-- ─────────────────────────────────────────────────────────────
-- 10. INTEGRACIONES SOLICITUDES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.integraciones_solicitudes
    (id_integracion_solicitud, id_cliente_externo, id_usuario,
     id_periodo_contable, id_version_contrato,
     estado, fecha_comienzoo, fecha_finalizacion,
     duracion_ms, correlacion_id, id_error)
VALUES
-- Solicitud exitosa Q3-2024 (período cerrado, Agrofusión PROD)
(1, 1, 1, 3, 2,
 'SUCCESS',
 NOW() - INTERVAL '100 days',
 NOW() - INTERVAL '100 days' + INTERVAL '2345 milliseconds',
 2345,
 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
 NULL),

-- Solicitud fallida por período no cerrado (Q4-2024 estaba ABIERTO)
(2, 1, 1, 4, 2,
 'FAILED',
 NOW() - INTERVAL '60 days',
 NOW() - INTERVAL '60 days' + INTERVAL '120 milliseconds',
 120,
 'b1ffcd00-ad1c-5fg9-cc7e-7cc0ce491b22',
 4),

-- Solicitud exitosa Q3-2024 desde Agrofusión STAGING
(3, 2, 1, 3, 2,
 'SUCCESS',
 NOW() - INTERVAL '90 days',
 NOW() - INTERVAL '90 days' + INTERVAL '1876 milliseconds',
 1876,
 'c2a0de11-be2d-6gh0-dd8f-8dd1df502c33',
 NULL),

-- Solicitud rechazada por credencial inválida
(4, 3, NULL, NULL, NULL,
 'UNAUTHORIZED',
 NOW() - INTERVAL '50 days',
 NOW() - INTERVAL '50 days' + INTERVAL '45 milliseconds',
 45,
 'd3b1ef22-cf3e-7hi1-ee90-9ee2e0613d44',
 1);


-- ─────────────────────────────────────────────────────────────
-- 11. DOCUMENTOS GENERADOS AAEF
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.documentos_generados_aaef
    (id_documentos_generados_aaef, id_integracion_solicitud,
     id_reconocimiento_iniciales, id_valoracion_por_costo,
     id_calculo_valor_razonable, id_cotizaciones,
     id_tipo_documento_aaef, fecha_generacion,
     estado, "tamaño_payload_bytes")
VALUES
-- Documento type_code 01 (Reconocimiento) — solicitud exitosa Q3-2024
(1, 1, 1, 1, 3, 1,
 1,
 NOW() - INTERVAL '100 days',
 'GENERATED', 18432),

-- Documento type_code 02 (Costos) — solicitud exitosa Q3-2024
(2, 1, 1, 1, 3, 1,
 2,
 NOW() - INTERVAL '100 days',
 'GENERATED', 12288),

-- Documento type_code 04B (Cotización) — solicitud exitosa Q3-2024
(3, 1, 1, 1, 3, 2,
 5,
 NOW() - INTERVAL '100 days',
 'GENERATED', 8192);


-- ─────────────────────────────────────────────────────────────
-- 12. METADATOS RESPUESTA AAEF
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.metadatos_respuesta_aaef
    (id_metadato_respuesta_aaef, id_integracion_solicitud,
     identificador_de_cambio, sha256_sobre,
     metadatos, facturas, resumen,
     fecha_creacion)
VALUES
-- Metadatos de la solicitud exitosa 1 (Q3-2024, Agrofusión PROD)
(1, 1,
 'e4c2f033-d04f-4a12-b890-aeb3f1724e55',
 'd4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5',
 '{"aaef_version": "2.0", "periodo": "2024-Q3", "fecha_generacion": "2024-10-10",
   "cliente": "AGROFUSION-PROD-001", "tipo_contrato": "APROBADO",
   "total_documentos": 3, "latencia_ms": 2345}',
 '[{"type_code": "01", "id": "REC-001", "monto": 4286400.00},
   {"type_code": "02", "id": "CST-001", "monto": 47025.00},
   {"type_code": "04B", "id": "COT-001", "monto": 4600000.00}]',
 '{"total_monto": 8933425.00, "documentos_generados": 3,
   "documentos_fallidos": 0, "estado": "SUCCESS"}',
 NOW() - INTERVAL '100 days'),

-- Metadatos de la solicitud exitosa 3 (Q3-2024, Agrofusión STAGING)
(2, 3,
 'f5d3a044-e15a-5b23-c901-bfc4a2835f66',
 'e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6',
 '{"aaef_version": "2.0", "periodo": "2024-Q3", "fecha_generacion": "2024-10-12",
   "cliente": "AGROFUSION-STAGING-001", "tipo_contrato": "APROBADO",
   "total_documentos": 3, "latencia_ms": 1876}',
 '[{"type_code": "01", "id": "REC-001-STG", "monto": 4286400.00},
   {"type_code": "02", "id": "CST-001-STG", "monto": 47025.00},
   {"type_code": "04B", "id": "COT-001-STG", "monto": 4600000.00}]',
 '{"total_monto": 8933425.00, "documentos_generados": 3,
   "documentos_fallidos": 0, "estado": "SUCCESS"}',
 NOW() - INTERVAL '90 days');


-- ─────────────────────────────────────────────────────────────
-- 13. REGISTROS DE EJECUCIÓN DEL MAPEADOR
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.registros_ejecucion_mapeador
    (id_registro_ejecucion_mapeador, id_integracion_solicitud,
     id_usuario, nombre, estado, orden_ejecucion,
     fecha_comienzo, duration_ms, mensaje_error)
VALUES
-- Ejecución exitosa solicitud 1: Mapper Reconocimiento (type_code 01)
(1, 1, 1,
 'MapperReconocimientoNIC41',
 'SUCCESS', 1,
 NOW() - INTERVAL '100 days', 780, NULL),

-- Ejecución exitosa solicitud 1: Mapper Costos (type_code 02)
(2, 1, 1,
 'MapperCostosMantenimientoInversion',
 'SUCCESS', 2,
 NOW() - INTERVAL '100 days' + INTERVAL '780 milliseconds', 520, NULL),

-- Ejecución exitosa solicitud 1: Mapper Cotizaciones (type_code 04B)
(3, 1, 1,
 'MapperCotizacionesVenta',
 'SUCCESS', 3,
 NOW() - INTERVAL '100 days' + INTERVAL '1300 milliseconds', 390, NULL),

-- Ejecución fallida solicitud 2 (período no cerrado — skipped todos)
(4, 2, 1,
 'MapperReconocimientoNIC41',
 'SKIPPED', 1,
 NOW() - INTERVAL '60 days', NULL,
 'Período contable id=4 en estado ABIERTO. '
 'Los Mappers requieren período en estado CERRADO (RF-96 PC-1).'),

-- Ejecución exitosa solicitud 3: Mapper Reconocimiento
(5, 3, 1,
 'MapperReconocimientoNIC41',
 'SUCCESS', 1,
 NOW() - INTERVAL '90 days', 650, NULL),

-- Ejecución exitosa solicitud 3: Mapper Costos
(6, 3, 1,
 'MapperCostosMantenimientoInversion',
 'SUCCESS', 2,
 NOW() - INTERVAL '90 days' + INTERVAL '650 milliseconds', 480, NULL);


-- ─────────────────────────────────────────────────────────────
-- 14. NOTIFICACIONES WEBHOOK
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.notificaciones_weebhook
    (id_notificacion_weebhook, tipo_evento, url_destino,
     payload_sha256, codigo_respuesta, estado_notifiacion,
     fecha_envio, fecha_recepcion, id_integracion_solicitudes)
VALUES
-- Webhook exitoso: cierre período Q3-2024 a Agrofusión PROD
(1, 'PERIODO_CERRADO',
 'https://api.agrofusion.com/v2/webhooks/pecuaria/periodo-cerrado',
 'f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7',
 200, 'SENT',
 NOW() - INTERVAL '100 days',
 NOW() - INTERVAL '100 days' + INTERVAL '1200 milliseconds',
 1),

-- Webhook fallido y reintentado (primer intento falló — timeout)
(2, 'PERIODO_CERRADO',
 'https://api.agrofusion.com/v2/webhooks/pecuaria/periodo-cerrado',
 'f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7',
 NULL, 'FAILED',
 NOW() - INTERVAL '100 days' - INTERVAL '5 minutes',
 NULL,
 1),

-- Webhook exitoso: mismo cierre Q3-2024 a Agrofusión STAGING
(3, 'PERIODO_CERRADO',
 'https://staging.agrofusion.com/v2/webhooks/pecuaria/periodo-cerrado',
 'f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7',
 200, 'SENT',
 NOW() - INTERVAL '90 days',
 NOW() - INTERVAL '90 days' + INTERVAL '980 milliseconds',
 3);


-- ─────────────────────────────────────────────────────────────
-- 15. AUDITORÍA DE PETICIONES
-- ─────────────────────────────────────────────────────────────
INSERT INTO modulo7.auditoria_peticiones
    (id_auditoria, evento, id_intgracion_solucitud,
     id_usuario, id_auditorias_financieras,
     tipo, fecha, datos, evento_sha256, es_inmuntable)
VALUES
-- Auditoría solicitud 1 exitosa (consulta AAEF Q3-2024)
(1, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
 1, 1, 3,
 'AAEF_EXPORT_REQUEST',
 NOW() - INTERVAL '100 days',
 '{"cliente": "AGROFUSION-PROD-001", "periodo": "Q3-2024",
   "endpoint": "/api/v2/aaef/exportar", "metodo": "POST",
   "ip_origen": "190.144.32.10", "estado_resultado": "SUCCESS",
   "documentos_generados": 3, "duracion_ms": 2345}',
 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
 true),

-- Auditoría solicitud 2 fallida (período no cerrado)
(2, 'b1ffcd00-ad1c-5fg9-cc7e-7cc0ce491b22',
 2, 1, 1,
 'AAEF_EXPORT_REQUEST_FAILED',
 NOW() - INTERVAL '60 days',
 '{"cliente": "AGROFUSION-PROD-001", "periodo": "Q4-2024",
   "endpoint": "/api/v2/aaef/exportar", "metodo": "POST",
   "ip_origen": "190.144.32.10", "estado_resultado": "FAILED",
   "error": "INVALID_PERIOD", "estado_periodo": "ABIERTO"}',
 'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3',
 true),

-- Auditoría solicitud 4 rechazada (credencial inválida)
(3, 'd3b1ef22-cf3e-7hi1-ee90-9ee2e0613d44',
 4, 1, 1,
 'AAEF_AUTH_FAILED',
 NOW() - INTERVAL '50 days',
 '{"cliente": "BANCO-AGRARIO-TEST-001", "periodo": null,
   "endpoint": "/api/v2/aaef/exportar", "metodo": "POST",
   "ip_origen": "201.244.15.32", "estado_resultado": "UNAUTHORIZED",
   "error": "UNAUTHORIZED", "motivo": "Cliente en estado SUSPENDIDO"}',
 'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4',
 true);
