DROP TABLE fersaSS.WarehouseLocationEquivalences_ALL;

CREATE TABLE fersaSS.WarehouseLocationEquivalences_ALL AS


WITH

/* ============================================================
   1. SRC
   ------------------------------------------------------------
   Obtenemos el universo base de almacenes/localizaciones.

   Usamos DISTINCT porque queremos una tabla de equivalencias única
   por combinación de:
   - SUBSIDIARYID
   - INVENTLOCATIONID
   - INVENTLOCATIONIDTRANSIT
   - NAME

   Estos campos representan el origen, es decir, los valores FROM.
   ============================================================ */
SRC AS
(
    SELECT DISTINCT
        SUBSIDIARYID,
        INVENTLOCATIONID,
        INVENTLOCATIONIDTRANSIT,
        NAME
    FROM fersadv.WarehouseLocation_ALL
),


/* ============================================================
   2. MATCHES
   ------------------------------------------------------------
   Cruzamos cada registro origen contra todas las reglas activas
   de la tabla de configuración.

   Una regla aplica si:
   - SUBSIDIARYID_FROM está vacío, o coincide exactamente
     con el SUBSIDIARYID origen.
   - INVENTLOCATIONID_FROM está vacío, o coincide según el tipo
     de match configurado:
       EXACT   -> igualdad exacta
       PREFIX  -> el INVENTLOCATIONID origen empieza por el valor
       GENERIC -> regla genérica / fallback

   Aquí todavía pueden salir varias reglas candidatas para un mismo
   registro origen. Más adelante elegiremos solo la mejor.
   ============================================================ */
MATCHES AS
(
    SELECT
        S.SUBSIDIARYID,
        S.INVENTLOCATIONID,
        S.INVENTLOCATIONIDTRANSIT,
        S.NAME,

        R.MODEL,
        R.RULE_ID,
        R.PRIORITY,
        R.INVENTLOCATIONID_MATCHTYPE,
        R.DESCRIPTION,

        R.SUBSIDIARYID_FROM,
        R.INVENTLOCATIONID_FROM,

        R.SUBSIDIARYID_TO,
        R.INVENTLOCATIONID_TO,

        /* =====================================================
           Si el destino está informado, usamos el destino.

           Si el destino está en NULL o en blanco, conservamos
           el valor original del origen.

           Esto permite tener reglas parciales:
           - cambiar solo subsidiary
           - cambiar solo location
           - o no cambiar nada en una regla fallback
           ===================================================== */
        COALESCE(NULLIF(R.SUBSIDIARYID_TO, ''), S.SUBSIDIARYID)       AS CALCULATED_SUBSIDIARYID,
        COALESCE(NULLIF(R.INVENTLOCATIONID_TO, ''), S.INVENTLOCATIONID) AS CALCULATED_INVENTLOCATIONID,

        /* =====================================================
           AUTO_PRIORITY
           -----------------------------------------------------
           Prioridad técnica calculada automáticamente.

           Esta prioridad NO sustituye a PRIORITY manual.
           Sirve como segundo criterio cuando:
           - no hay prioridad manual, o
           - hay empate entre reglas.

           Cuanto menor el número, más específica la regla.

           1  = subsidiary + location exactos
           2  = subsidiary + location prefix
           3  = subsidiary + location genérico
           4  = solo subsidiary exacto
           5  = solo subsidiary prefix
           6  = solo subsidiary genérico
           7  = solo location exacto
           8  = solo location prefix
           9  = solo location genérico
           10 = fallback totalmente genérico
           ===================================================== */
        CASE
            WHEN R.SUBSIDIARYID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'EXACT'
            THEN 1

            WHEN R.SUBSIDIARYID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'PREFIX'
            THEN 2

            WHEN R.SUBSIDIARYID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'GENERIC'
            THEN 3

            WHEN R.SUBSIDIARYID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_FROM IS NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'EXACT'
            THEN 4

            WHEN R.SUBSIDIARYID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_FROM IS NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'PREFIX'
            THEN 5

            WHEN R.SUBSIDIARYID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_FROM IS NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'GENERIC'
            THEN 6

            WHEN R.SUBSIDIARYID_FROM IS NULL
             AND R.INVENTLOCATIONID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'EXACT'
            THEN 7

            WHEN R.SUBSIDIARYID_FROM IS NULL
             AND R.INVENTLOCATIONID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'PREFIX'
            THEN 8

            WHEN R.SUBSIDIARYID_FROM IS NULL
             AND R.INVENTLOCATIONID_FROM IS NOT NULL
             AND R.INVENTLOCATIONID_MATCHTYPE = 'GENERIC'
            THEN 9

            ELSE 10
        END AS AUTO_PRIORITY,

        /* =====================================================
           SPECIFICITY_SCORE
           -----------------------------------------------------
           Desempate técnico adicional.

           Cuanto más largo sea el patrón FROM, más específico es.

           Ejemplo:
           - P      menos específico
           - T_P    más específico
           - T_PUSA todavía más específico

           En el ORDER BY se usará DESC para que gane el valor
           más largo.
           ===================================================== */
        LENGTH(COALESCE(R.SUBSIDIARYID_FROM, ''))
        +
        LENGTH(COALESCE(R.INVENTLOCATIONID_FROM, '')) AS SPECIFICITY_SCORE

    FROM SRC S

    JOIN fersaSS.Config_SubsidiaryEquivalences R
      ON R.ACTIVE = TRUE

     /* Match de subsidiary:
        - si la regla no informa SUBSIDIARYID_FROM, aplica a cualquiera
        - si lo informa, debe coincidir exactamente */
     AND (
            R.SUBSIDIARYID_FROM IS NULL
         OR R.SUBSIDIARYID_FROM = S.SUBSIDIARYID
     )

     /* Match de invent location:
        - si la regla no informa INVENTLOCATIONID_FROM, aplica a cualquiera
        - EXACT: igualdad exacta
        - PREFIX: empieza por el valor informado
        - GENERIC: fallback genérico */
     AND (
            R.INVENTLOCATIONID_FROM IS NULL

         OR (
                R.INVENTLOCATIONID_MATCHTYPE = 'EXACT'
            AND R.INVENTLOCATIONID_FROM = S.INVENTLOCATIONID
         )

         OR (
                R.INVENTLOCATIONID_MATCHTYPE = 'PREFIX'
            AND S.INVENTLOCATIONID LIKE R.INVENTLOCATIONID_FROM || '%'
         )

         OR (
                R.INVENTLOCATIONID_MATCHTYPE = 'GENERIC'
         )
     )
),


/* ============================================================
   3. RANKED
   ------------------------------------------------------------
   Como una misma combinación FROM puede matchear varias reglas,
   ordenamos las reglas candidatas y nos quedamos con una sola.

   Orden de decisión:
   1. PRIORITY manual, si existe.
   2. AUTO_PRIORITY calculada.
   3. SPECIFICITY_SCORE descendente: gana el patrón más largo.
   4. RULE_ID como desempate final estable.

   Importante:
   - PRIORITY manual manda sobre la automática.
   - Si PRIORITY es NULL, entonces entra la automática.
   ============================================================ */
RANKED AS
(
    SELECT
        MATCHES.*,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                MODEL,
                SUBSIDIARYID,
                INVENTLOCATIONID,
                INVENTLOCATIONIDTRANSIT,
                NAME

            ORDER BY
                COALESCE(PRIORITY, AUTO_PRIORITY) ASC,
                AUTO_PRIORITY ASC,
                SPECIFICITY_SCORE DESC,
                RULE_ID ASC
        ) AS RN

    FROM MATCHES
)


/* ============================================================
   4. SELECT FINAL
   ------------------------------------------------------------
   Nos quedamos únicamente con la mejor regla por cada combinación
   de origen y modelo.

   Además dejamos trazabilidad de qué regla ganó:
   - MATCHED_RULE_ID
   - MATCHED_PRIORITY
   - AUTO_PRIORITY
   - INVENTLOCATIONID_MATCHTYPE
   - SPECIFICITY_SCORE
   - MATCHED_RULE_DESCRIPTION
   ============================================================ */
SELECT
    MODEL,

    SUBSIDIARYID             AS SUBSIDIARYID_FROM,
    INVENTLOCATIONID         AS INVENTLOCATIONID_FROM,
    INVENTLOCATIONIDTRANSIT,
    NAME,

    CALCULATED_SUBSIDIARYID      AS SUBSIDIARYID_TO,
    CALCULATED_INVENTLOCATIONID  AS INVENTLOCATIONID_TO,

    RULE_ID                      AS MATCHED_RULE_ID,
    PRIORITY                     AS MATCHED_PRIORITY,
    AUTO_PRIORITY,
    INVENTLOCATIONID_MATCHTYPE,
    SPECIFICITY_SCORE,
    DESCRIPTION                  AS MATCHED_RULE_DESCRIPTION

FROM RANKED
WHERE RN = 1;

GRANT SELECT
ON fersaSS.WarehouseLocationEquivalences_ALL
TO usr_paula_carmona,
   usr_juan_lanero;
 
GRANT SELECT, INSERT, UPDATE, DELETE, ALTER
ON fersaSS.WarehouseLocationEquivalences_ALL
TO usr_iago_trillo,
   usr_alejandro_villen;
