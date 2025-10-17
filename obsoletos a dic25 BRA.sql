WITH Stock_BRA AS (
  SELECT
    isa.itemid,
    SUM(isa.physicalinvent + isa.picked) AS OnHand,
    SUM((isa.physicalinvent + isa.picked) * isa.UNITCOST * isa.EXCHANGERATE_EUR) AS Amount
  FROM fersadv.InventSum_ALL isa
  WHERE isa.SUBSIDIARYID = 'FBRA'
    AND isa.INVENTLOCATIONID = 'FBRA'
  GROUP BY isa.itemid
),
Ventas_BRA AS (
  SELECT
    sia.itemid,
    SUM(sia.INVOICEQTY) AS qty,
    SUM(sia.AMOUNT * sia.EXCHANGERATE_EUR) AS amount
  FROM fersadv.SalesInvoices_ALL sia
  LEFT JOIN fersadv.Customer_ALL ca
    ON ca.SUBSIDIARYID = sia.SUBSIDIARYID
   AND ca.CUSTOMERID = sia.CUSTOMERID
  WHERE sia.SUBSIDIARYID = 'FBRA'
    AND sia.invoicedate >= '01/01/2024'
  GROUP BY sia.itemid
)
SELECT
  s.itemid,
  s.OnHand,
  s.Amount,
  COALESCE(v.qty, 0)    AS qty,
  COALESCE(v.amount, 0) AS amount,
  CASE WHEN s.OnHand - COALESCE(v.qty,0) > 0 THEN s.OnHand  ELSE 0 END AS OverstockQty,
  CASE WHEN s.OnHand - COALESCE(v.qty,0) > 0 THEN s.Amount  ELSE 0 END AS OverstockAmount,
  CASE WHEN s.OnHand - COALESCE(v.qty,0) > 0 THEN (s.OnHand - COALESCE(v.qty,0))/2.0 + 1 ELSE 0 END AS QtyToBeat,
  CASE
    WHEN NULLIF(s.OnHand,0) IS NOT NULL
     AND NULLIF(s.Amount,0) IS NOT NULL
     AND NULLIF(COALESCE(v.qty,0),0) IS NOT NULL
    THEN (COALESCE(v.amount,0) / NULLIF(COALESCE(v.qty,0),0))
         / (s.Amount / NULLIF(s.OnHand,0))
    ELSE NULL
  END AS AvgMargin
FROM Stock_BRA s
LEFT JOIN Ventas_BRA v
  ON s.itemid = v.itemid;
