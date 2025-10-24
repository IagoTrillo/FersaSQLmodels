/*---------------------------------------------------------------------------*
  Parámetro de año: utiliza 0 para todos los años o un número de año específico
  al ejecutar la consulta. Ejemplo: year_filter = 2024
*---------------------------------------------------------------------------*/
WITH
Trans AS (
    SELECT
        pt.PRODID             AS ProdId,
        pt.SUBSIDIARYID       AS SubsidiaryID,
        pt.LINEID             AS LineID,
        pt.ITEMID             AS ItemID,
        pt.QTY,
        pt.COSTAMOUNTPOSTED   AS CostAmountPosted,
        pt.STATUSISSUE,
        pt.STATUSRECEIPT,
        pt.DATEPHYSICAL
    FROM fersadw.ProdTableTrans_FER pt
    WHERE (:year_filter = 0 OR EXTRACT(YEAR FROM pt.DATEPHYSICAL) = :year_filter)
),
Production AS (
    SELECT
        ProdId,
        SubsidiaryID,
        LineID,
        SUM(CASE WHEN StatusReceipt <> 0 THEN QTY ELSE 0 END) AS ProducedQty
    FROM Trans
    GROUP BY ProdId, SubsidiaryID, LineID
),
Consumption AS (
    SELECT
        ProdId,
        SubsidiaryID,
        LineID,
        ItemID        AS ComponentItemID,
        SUM(CASE WHEN StatusIssue <> 0 THEN -QTY ELSE 0 END) AS ActualConsumption,
        SUM(CASE WHEN StatusIssue <> 0 THEN -CostAmountPosted ELSE 0 END) AS ActualAmount
    FROM Trans
    GROUP BY ProdId, SubsidiaryID, LineID, ItemID
),
BOM AS (
    SELECT
        pb.PRODID           AS ProdId,
        pb.ITEMID           AS ComponentItemID,
        SUM(pb.BOMQTY)      AS BOMQTY,
        SUM(pb.BOMQTYSERIE) AS BOMQTYSERIE
    FROM fersads.ds_ProdBOM_FER pb
    GROUP BY pb.PRODID, pb.ITEMID
)
SELECT
    c.ProdId,
    c.SubsidiaryID,
    c.LineID,
    c.ComponentItemID,
    CASE 
        WHEN c.ComponentItemID LIKE '67%' 
          OR c.ComponentItemID LIKE '68%' 
          OR c.ComponentItemID LIKE '69%' 
          OR c.ComponentItemID LIKE '7%' 
        THEN 'Embalajes'
        ELSE 'Otros'
    END AS TipoComponente,
    c.ActualConsumption                  AS ConsumoReal,
    b.BOMQTY, 
    b.BOMQTYSERIE,
    p.ProducedQty                        AS UnidadesProducidas,
    (p.ProducedQty / NULLIF(b.BOMQTYSERIE, 0)) * b.BOMQTY AS ConsumoEsperado,
    CASE 
        WHEN c.ActualConsumption <> 0 
        THEN c.ActualAmount / c.ActualConsumption 
        ELSE 0 
    END AS CosteUnitarioReal,
    c.ActualAmount                       AS ImporteReal,
    ( (p.ProducedQty / NULLIF(b.BOMQTYSERIE, 0)) * b.BOMQTY ) *
      ( CASE WHEN c.ActualConsumption <> 0 
             THEN c.ActualAmount / c.ActualConsumption 
             ELSE 0 
        END )                            AS ImporteEsperado,
    c.ActualAmount -
      ( (p.ProducedQty / NULLIF(b.BOMQTYSERIE, 0)) * b.BOMQTY ) *
        ( CASE WHEN c.ActualConsumption <> 0 
               THEN c.ActualAmount / c.ActualConsumption 
               ELSE 0 
          END )                          AS DesviacionImporte,
    MIN(t.DATEPHYSICAL)                  AS PrimeraFecha,
    MAX(t.DATEPHYSICAL)                  AS UltimaFecha
FROM Consumption c
LEFT JOIN Production p
    ON c.ProdId = p.ProdId 
   AND c.SubsidiaryID = p.SubsidiaryID
   AND c.LineID = p.LineID
LEFT JOIN BOM b
    ON c.ProdId = b.ProdId 
   AND c.ComponentItemID = b.ComponentItemID
LEFT JOIN Trans t 
    ON c.ProdId = t.ProdId 
    AND c.ComponentItemID = t.ItemID 
    AND t.StatusIssue <> 0
left join fersadv.ProdTable_ALL pta
    on pta.PRODID=c.ProdId
    where pta.PRODSTATUS = 7
GROUP BY
    c.ProdId,
    c.SubsidiaryID,
    c.LineID,
    c.ComponentItemID,
    b.BOMQTY,
    b.BOMQTYSERIE,
    p.ProducedQty,
    c.ActualConsumption,
    c.ActualAmount
ORDER BY
    c.ProdId,
    c.SubsidiaryID,
    c.LineID,
    c.ComponentItemID;