WITH pk_columns AS (
    SELECT 
        c.table_id,
        c.table_name,
        cc.column_name
    FROM 
        v_catalog.constraint_columns cc
    JOIN 
        v_catalog.table_constraints tc ON cc.constraint_id = tc.constraint_id
    JOIN 
        v_catalog.columns c ON cc.table_name = c.table_name AND cc.column_name = c.column_name
    WHERE 
        tc.constraint_type = 'p'
)
SELECT 
    c.table_schema,
    c.table_name,
    c.column_name,
    c.ordinal_position,
    c.data_type,
    c.column_default,
    c.is_nullable,
    com.comment AS column_comment,
    CASE 
        WHEN pk.column_name IS NOT NULL THEN 'YES' 
        ELSE 'NO' 
    END AS is_primary_key
FROM 
    v_catalog.columns c
JOIN 
    v_catalog.tables t ON c.table_id = t.table_id
LEFT JOIN 
    v_catalog.comments com 
    ON com.object_type = 'COLUMN'
    AND com.object_schema = c.table_schema
    AND com.object_name = c.table_name
    AND com.child_object = c.column_name
LEFT JOIN 
    pk_columns pk 
    ON c.table_id = pk.table_id
    AND c.table_name = pk.table_name
    AND c.column_name = pk.column_name
WHERE 
    t.is_system_table = false
ORDER BY 
    c.table_name, c.ordinal_position;