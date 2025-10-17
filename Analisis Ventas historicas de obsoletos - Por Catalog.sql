WITH sales_external AS (
  SELECT
    sia.SUBSIDIARYID AS filial,
    ca.customertype  AS sales_type,
    date_trunc('month', sia.invoicedate)::date AS mesventa,
    ia.catalog AS catalog,
    SUM(sia.INVOICEQTY) AS qty,
    SUM(sia.AMOUNT * sia.EXCHANGERATE_EUR) AS amount_eur
  FROM fersadv.SalesInvoices_ALL sia
  LEFT JOIN fersadv.Customer_ALL ca
         ON ca.SUBSIDIARYID = sia.SUBSIDIARYID
        AND ca.CUSTOMERID   = sia.CUSTOMERID
  LEFT JOIN fersadv.Item_ALL ia
         ON sia.SUBSIDIARYID = ia.SUBSIDIARYID
        AND sia.ITEMID       = ia.ITEMID
  WHERE ca.customertype = 'EXTERNAL'
  GROUP BY filial, sales_type, mesventa, catalog
),
sales_own_subs AS (
  SELECT
    sia.SUBSIDIARYID AS filial,
    ca.customertype  AS sales_type,
    date_trunc('month', sia.invoicedate)::date AS mesventa,
    ia.catalog AS catalog,
    SUM(sia.INVOICEQTY) AS qty,
    SUM(sia.AMOUNT * sia.EXCHANGERATE_EUR) AS amount_eur
  FROM fersadv.SalesInvoices_ALL sia
  LEFT JOIN fersadv.Customer_ALL ca
         ON ca.SUBSIDIARYID = sia.SUBSIDIARYID
        AND ca.CUSTOMERID   = sia.CUSTOMERID
  LEFT JOIN fersadv.Item_ALL ia
         ON sia.SUBSIDIARYID = ia.SUBSIDIARYID
        AND sia.ITEMID       = ia.ITEMID
  GROUP BY filial, sales_type, mesventa, catalog
),
sales_exe_agg AS (
  SELECT
    catalog,
    SUM(qty) AS qty_hist,
    SUM(CASE WHEN mesventa >= current_date - INTERVAL '4 years'  THEN COALESCE(qty,0) ELSE 0 END)  AS qty_4y,
    SUM(CASE WHEN mesventa >= current_date - INTERVAL '10 years' THEN COALESCE(qty,0) ELSE 0 END)  AS qty_10y
  FROM sales_external
  GROUP BY catalog
),
sales_own_agg AS (
  SELECT
    filial,
    catalog,
    SUM(qty) AS qty_hist,
    SUM(CASE WHEN mesventa >= current_date - INTERVAL '4 years'  THEN COALESCE(qty,0) ELSE 0 END)  AS qty_4y,
    SUM(CASE WHEN mesventa >= current_date - INTERVAL '10 years' THEN COALESCE(qty,0) ELSE 0 END)  AS qty_10y
  FROM sales_own_subs
  GROUP BY filial, catalog
),
-- 🔧 Agrega obsoletos al MISMO grano que vas a unir (filial + catálogo + tipo)
obsoletos AS (
  SELECT
    dmfoe.SUBSIDIARYID AS filial,
    ia.CATALOG         AS catalog,
    ia.COSTGROUP       AS tipo,
    SUM(dmfoe.STOCKQTY) AS stockQ,
    SUM(dmfoe.STOCKAMOUNT * dmfoe.CALCULATEDSDAMOUNT_EUR
        / NULLIF(dmfoe.CALCULATEDSDAMOUNT_LOCAL, 0))      AS stock_eur,
    SUM(dmfoe.FINANCIALSDAMOUNT_EUR)                      AS deprec_eur
  FROM fersads.ds_MonthlyFinancialObsoletes_EDC dmfoe
  LEFT JOIN fersadv.item_all ia
         ON ia.SUBSIDIARYID = dmfoe.SUBSIDIARYID
        AND ia.ITEMID       = dmfoe.ITEMID
  WHERE dmfoe.UPLOADMONTH = '2025-08-31'
    AND dmfoe.STOCKQTY > 0
  GROUP BY dmfoe.SUBSIDIARYID, ia.COSTGROUP, ia.CATALOG
)

SELECT
  o.filial,
  o.catalog,
  o.tipo,
  o.stockQ,
  COALESCE(o.stock_eur,  0) AS stock_eur,
  COALESCE(o.deprec_eur, 0) AS deprec_eur,
  COALESCE(o.stock_eur,0) / NULLIF(o.stockQ,0) AS unit_cost,

  COALESCE(so.qty_hist, 0) AS hist_sales_own_subs_ext_int,
  COALESCE(se.qty_hist,  0) AS hist_sales,
  (COALESCE(o.stockQ,0) - COALESCE(se.qty_hist,0)) AS stock_tras_consumo_hist,
  (COALESCE(o.stockQ,0) - COALESCE(se.qty_hist,0))
    * COALESCE(o.stock_eur,0) / NULLIF(o.stockQ,0) AS amount_hist,
  CASE WHEN COALESCE(o.stockQ,0) - COALESCE(se.qty_hist,0) > 0 THEN 'NO' ELSE 'SI' END AS consumo_hist_suf,

  COALESCE(so.qty_10y, 0) AS sales_10y_own_subs_ext_int,
  COALESCE(se.qty_10y, 0) AS sales_10y,
  (COALESCE(o.stockQ,0) - COALESCE(se.qty_10y,0)) AS stock_tras_consumo_10y,
  (COALESCE(o.stockQ,0) - COALESCE(se.qty_10y,0))
    * COALESCE(o.stock_eur,0) / NULLIF(o.stockQ,0) AS amount_10y,
  CASE WHEN COALESCE(o.stockQ,0) - COALESCE(se.qty_10y,0) > 0 THEN 'NO' ELSE 'SI' END AS consumo_10y_suf,

  COALESCE(so.qty_4y, 0) AS sales_4y_own_subs_ext_int,
  COALESCE(se.qty_4y,  0) AS sales_4y,
  (COALESCE(o.stockQ,0) - COALESCE(se.qty_4y,0)) AS stock_tras_consumo_4y,
  (COALESCE(o.stockQ,0) - COALESCE(se.qty_4y,0))
    * COALESCE(o.stock_eur,0) / NULLIF(o.stockQ,0) AS amount_4y,
  CASE WHEN COALESCE(o.stockQ,0) - COALESCE(se.qty_4y,0) > 0 THEN 'NO' ELSE 'SI' END AS consumo_4y_suf

FROM obsoletos o
LEFT JOIN sales_exe_agg se
       ON se.catalog = o.catalog
LEFT JOIN sales_own_agg so
       ON so.filial  = o.filial
      AND so.catalog = o.catalog
