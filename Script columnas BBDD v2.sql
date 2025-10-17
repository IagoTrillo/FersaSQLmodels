WITH pk_columns AS (
    SELECT 
        tc.constraint_id,
        cc.table_id,
        cc.table_name,
        cc.column_name
    FROM 
        v_catalog.table_constraints tc
    JOIN 
        v_catalog.constraint_columns cc ON tc.constraint_id = cc.constraint_id
    WHERE 
        tc.constraint_type = 'p'
),
unique_columns AS (
    SELECT 
        tc.constraint_id,
        cc.table_id,
        cc.table_name,
        cc.column_name
    FROM 
        v_catalog.table_constraints tc
    JOIN 
        v_catalog.constraint_columns cc ON tc.constraint_id = cc.constraint_id
    WHERE 
        tc.constraint_type = 'u'
),
fk_columns AS (
    SELECT 
        tc.constraint_id,
        cc.table_id,
        cc.table_name,
        cc.column_name,
        tc.constraint_name
    FROM 
        v_catalog.table_constraints tc
    JOIN 
        v_catalog.constraint_columns cc ON tc.constraint_id = cc.constraint_id
    WHERE 
        tc.constraint_type = 'f'
)
SELECT 
    c.table_schema,
    c.table_name,
    c.column_name,
    c.ordinal_position,
    c.data_type,
    c.column_default,
    c.is_nullable,
    tab_comments.comment AS table_comment,
    col_comments.comment AS column_comment,
    CASE WHEN pk.column_name IS NOT NULL THEN 'YES' ELSE 'NO' END AS is_primary_key,
    CASE WHEN uk.column_name IS NOT NULL THEN 'YES' ELSE 'NO' END AS is_unique,
    CASE WHEN fk.column_name IS NOT NULL THEN 'YES' ELSE 'NO' END AS is_foreign_key,
    fk.constraint_name AS foreign_key_constraint_name
FROM 
    v_catalog.columns c
JOIN 
    v_catalog.tables t ON c.table_id = t.table_id
LEFT JOIN 
    v_catalog.comments tab_comments 
        ON tab_comments.object_type = 'TABLE'
        AND tab_comments.object_schema = c.table_schema
        AND tab_comments.object_name = c.table_name
LEFT JOIN 
    v_catalog.comments col_comments 
        ON col_comments.object_type = 'COLUMN'
        AND col_comments.object_schema = c.table_schema
        AND col_comments.object_name = c.table_name
        AND col_comments.child_object = c.column_name
LEFT JOIN 
    pk_columns pk 
        ON c.table_id = pk.table_id
        AND c.table_name = pk.table_name
        AND c.column_name = pk.column_name
LEFT JOIN 
    unique_columns uk 
        ON c.table_id = uk.table_id
        AND c.table_name = uk.table_name
        AND c.column_name = uk.column_name
LEFT JOIN 
    fk_columns fk 
        ON c.table_id = fk.table_id
        AND c.table_name = fk.table_name
        AND c.column_name = fk.column_name
WHERE 
    t.is_system_table = false
ORDER BY 
    c.table_schema, c.table_name, c.ordinal_position;