--Proceso en 2 pasos.
--Primero obtenemos la DDL de la tabla origen y le damos el nombre de la tabla destino
    --A ejecutar en PRO
SELECT REPLACE(
    EXPORT_TABLES('', 'schemaorigen.NombreTablaOrigen'),
    'CREATE TABLE schemaorigen.NombreTablaOrigen',
    'CREATE TABLE schemadestino.NombreTabladestino'
) AS ddl_destino;


--Copias el resultado y lo ejecutas en DEV.
-- =========================================================
-- 0. Ejecutar conectado al DESTINO
-- Ejemplo:
--   DEV: verticadev.fersa.local
--   DB:  fersadwpre
-- =========================================================


-- =========================================================
-- 1. Crear conexión desde DESTINO hacia ORIGEN
-- =========================================================
DISCONNECT fersadw;
CONNECT TO VERTICA fersadw
USER usr_iago_trillo
PASSWORD 'ZnZEvg2BJPsilblVTdc0'
ON 'verticapro.fersa.local', 5433;


-- =========================================================
-- 2. Borrar tabla destino si existe
-- =========================================================

DROP TABLE IF EXISTS schemadestino.NombreTabladestino;


-- =========================================================
-- 3. Crear tabla destino
-- =========================================================
--Básicamente, el DDL, a ser copiado desde la consulta de PRO
CREATE TABLE schemadestino.NombreTabladestino
(
    CAMPO1 varchar(80),
    CAMPO2 varchar(160),
    CAMPO3 numeric(32,6),
    CAMPO4 date,
    CAMPO5 timestamptz
);


-- =========================================================
-- 4. Cargar datos directamente desde origen
-- Si origen y destino tienen mismas columnas y mismo orden
-- =========================================================

COPY schemadestino.NombreTabladestino
FROM VERTICA fersadw.schemaorigen.NombreTablaOrigen
DIRECT;


-- =========================================================
-- 5. Cerrar conexión
-- =========================================================

DISCONNECT fersadw;

