WITH ProductionQty AS (
    SELECT
        ito.ReferenceId  AS ProdId,
        SUM(CASE WHEN it.QTY > 0 THEN it.QTY ELSE 0 END) AS ProducedQty
    FROM fersads.ds_InventTrans_FER it
    INNER JOIN fersads.ds_InventTransOrigin_FER ito
        ON it.INVENTTRANSORIGIN = ito.RECID
    WHERE it.StatusReceipt <> 0
    GROUP BY ito.ReferenceId
),
Consumption AS (
    SELECT
        ito.ReferenceId AS ProdId,
        it.ITEMID       AS ComponentItemID,
        SUM(-it.QTY)    AS ActualConsumption
    FROM fersads.ds_InventTrans_FER it
    INNER JOIN fersads.ds_InventTransOrigin_FER ito
        ON it.INVENTTRANSORIGIN = ito.RECID
    WHERE it.StatusIssue <> 0
    GROUP BY ito.ReferenceId, it.ITEMID
),
BOM AS (
    SELECT
        pb.PRODID         AS ProdId,
        pb.ITEMID         AS ComponentItemID,
        pb.BOMQTY,
        pb.BOMQTYSERIE,
        pb.QTYINVENTSTUP,
        pb.QTYBOMSTUP
    FROM fersads.ds_ProdBOM_FER pb
)
SELECT
    b.ProdId,
    b.ComponentItemID,
    ISNULL(c.ActualConsumption, 0) AS ConsumoReal,
    p.ProducedQty                  AS UnidadesProducidas,
    (p.ProducedQty / NULLIF(b.BOMQTYSERIE, 0)) * b.BOMQTY AS ConsumoEsperado,
    ISNULL(c.ActualConsumption, 0) - ((p.ProducedQty / NULLIF(b.BOMQTYSERIE, 0)) * b.BOMQTY) AS Desviacion
FROM BOM b
LEFT JOIN ProductionQty p
    ON b.ProdId = p.ProdId
LEFT JOIN Consumption c
    ON b.ProdId = c.ProdId
   AND b.ComponentItemID = c.ComponentItemID
ORDER BY b.ProdId, b.ComponentItemID;