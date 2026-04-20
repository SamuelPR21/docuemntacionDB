SELECT 
    n.nspname AS esquema,
    c.relname AS tabla,
    a.attname AS nombre_columna,

    pg_catalog.format_type(a.atttypid, a.atttypmod) AS tipo_dato,

    CASE 
        WHEN a.atttypmod > 0 THEN (a.atttypmod - 4)::text
        ELSE 'NO REFIERE'
    END AS longitud,

    CASE 
        WHEN t.typname IN ('numeric', 'decimal') 
        THEN (a.atttypmod - 4) >> 16 
        ELSE NULL 
    END AS precision_numerica,

    CASE 
        WHEN t.typname IN ('numeric', 'decimal') 
        THEN (a.atttypmod - 4) & 65535 
        ELSE NULL 
    END AS escala_numerica,

    CASE 
        WHEN a.attnotnull THEN 'NO' 
        ELSE 'YES' 
    END AS permite_nulos,



    -- 🔑 PK
    pk.nombre_pk,
    CASE 
        WHEN pk.nombre_pk IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS es_llave_primaria,

    -- 🔗 FK
    fk.nombre_fk,
    CASE 
        WHEN fk.nombre_fk IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS es_llave_foranea,
    fk.tabla_referenciada,

    -- 🧾 comentario
    col_description(a.attrelid, a.attnum) AS comentario,

    -- 📊 índices
    idx.tiene_indice

FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_type t ON a.atttypid = t.oid

LEFT JOIN pg_attrdef ad 
    ON a.attrelid = ad.adrelid 
    AND a.attnum = ad.adnum

LEFT JOIN LATERAL (
    SELECT string_agg(con.conname, ', ') AS nombre_pk
    FROM pg_constraint con
    WHERE con.conrelid = c.oid
      AND con.contype = 'p'
      AND a.attnum = ANY(con.conkey)
) pk ON true

LEFT JOIN LATERAL (
    SELECT 
        string_agg(tc.constraint_name, ', ') AS nombre_fk,
        string_agg(ccu.table_name, ', ') AS tabla_referenciada
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND kcu.table_schema = n.nspname
      AND kcu.table_name = c.relname
      AND kcu.column_name = a.attname
) fk ON true

LEFT JOIN LATERAL (
    SELECT 
        CASE 
            WHEN COUNT(*) > 0 THEN 'YES'
            ELSE 'NO'
        END AS tiene_indice
    FROM pg_index i
    WHERE i.indrelid = c.oid
      AND a.attnum = ANY(i.indkey)
) idx ON true

WHERE a.attnum > 0
AND NOT a.attisdropped
AND c.relkind = 'r'
AND n.nspname NOT IN ('pg_catalog', 'information_schema')

ORDER BY n.nspname, c.relname, a.attnum;