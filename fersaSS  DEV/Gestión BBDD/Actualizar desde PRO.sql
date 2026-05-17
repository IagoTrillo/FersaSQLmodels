DISCONNECT fersadw;
-- =========================================================
-- 1. Conectar desde DEV hacia PRO
-- Ejecutar conectado a:
--   verticadev.fersa.local
--   database: fersadwpre
-- =========================================================

CONNECT TO VERTICA fersadw
USER usr_iago_trillo
PASSWORD 'ZnZEvg2BJPsilblVTdc0'
ON 'verticapro.fersa.local', 5433;



-- =========================================================
-- 3. Vaciar tabla destino
-- =========================================================

TRUNCATE TABLE fersaSSTest.InventSum_FACT_HIST;


-- =========================================================
-- 4. Copiar datos directamente PRO -> DEV
-- =========================================================

COPY fersaSSTest.InventSum_FACT_HIST
(
    COMPANYID,
    SUBSIDIARYID,
    ITEMID,
    PHYSICALINVENT,
    RESERVPHYSICAL,
    PICKED,
    INVENTBATCHID,
    INVENTLOCATIONID,
    INVENTSERIALID,
    INVENTSITEID,
    INVENTSIZEID,
    INVENTSTATUSID,
    INVENTSTYLEID,
    LICENSEPLATEID,
    WMSLOCATIONID,
    UNITCOST,
    CURRENCYCODE,
    EXCHANGERATE_EUR,
    EXCHANGERATE_USD,
    ORIGIN,
    UPDATEDATE
)
FROM VERTICA fersadw.fersadw.InventSum_FACT_HIST
(
    COMPANYID,
    SUBSIDIARYID,
    ITEMID,
    PHYSICALINVENT,
    RESERVPHYSICAL,
    PICKED,
    INVENTBATCHID,
    INVENTLOCATIONID,
    INVENTSERIALID,
    INVENTSITEID,
    INVENTSIZEID,
    INVENTSTATUSID,
    INVENTSTYLEID,
    LICENSEPLATEID,
    WMSLOCATIONID,
    UNITCOST,
    CURRENCYCODE,
    EXCHANGERATE_EUR,
    EXCHANGERATE_USD,
    ORIGIN,
    UPDATEDATE
)
DIRECT;


-- =========================================================
-- 6. Cerrar conexión remota
-- =========================================================

DISCONNECT fersadw;