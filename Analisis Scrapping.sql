WITH

sales_external AS (
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
),

nivel as (
SELECT ia.SUBSIDIARYID, ia.ITEMID, "CATALOG" ,
	CASE
		WHEN (ia.ITEMID LIKE '%PH%') THEN NULL
		WHEN
			(ia.ITEMID LIKE '135%' AND ia."CATALOG" LIKE 'AAS F 400%') OR (ia.ITEMID LIKE '135%' AND ia."CATALOG" LIKE 'AAH F 400%') OR (ia.ITEMID LIKE '250%' AND ia."CATALOG" LIKE 'AAS F 400%') 
			OR ia.ITEMID LIKE '251%'  OR ia."CATALOG" LIKE 'AAS U%'
		THEN 'KFP'
		WHEN
			(ia.ITEMID LIKE '1%' OR ia.ITEMID LIKE '2%' OR ia.ITEMID LIKE '3%' OR ia.ITEMID LIKE '5%' OR ia.ITEMID LIKE '9%' 
				OR (ia.ITEMID LIKE '6%' AND NOT (ia.ITEMID LIKE '67%' OR ia.ITEMID LIKE '68%' OR ia.ITEMID LIKE '69%')))
			AND (ia."CATALOG" LIKE '%AAS%' OR ia."CATALOG" LIKE 'AAH%' OR ia."CATALOG" LIKE 'CEM%' OR ia."CATALOG" LIKE 'CEH%' OR ia."CATALOG" LIKE 'AEH%' OR ia."CATALOG" LIKE 'AEM%' OR ia."CATALOG" LIKE 'KA %' OR ia."CATALOG" LIKE 'KB %'OR ia."CATALOG" LIKE 'KC %' OR ia."CATALOG" LIKE 'KF %' OR ia."CATALOG" LIKE 'KV %')
			AND NOT (ia."CATALOG" LIKE '%EXT%' OR ia."CATALOG" LIKE 'EXH%' OR ia."CATALOG" LIKE 'COM%' OR ia."CATALOG" LIKE 'ASP%' OR ia."CATALOG" LIKE 'CMH%' OR ia."CATALOG" LIKE 'ASH%' OR ia."CATALOG" LIKE 'AAM%' OR ia."CATALOG" LIKE 'ACM%' OR ia."CATALOG" LIKE 'ACH%' OR ia."CATALOG" LIKE 'KEXT%')
			OR (ia.ITEMID LIKE '%AS%' OR ia.ITEMID LIKE '%PF%')
		THEN 'FPR'
		WHEN
			(ia.ITEMID LIKE '1%' OR ia.ITEMID LIKE '2%' OR ia.ITEMID LIKE '3%' OR ia.ITEMID LIKE '5%' OR ia.ITEMID LIKE '9%'
				OR (ia.ITEMID LIKE '6%' AND NOT (ia.ITEMID LIKE '67%' OR ia.ITEMID LIKE '68%' OR ia.ITEMID LIKE '69%')))
			AND (ia."CATALOG" LIKE '%EXT%' OR ia."CATALOG" LIKE 'EXH%' OR ia."CATALOG" LIKE 'COM%' OR ia."CATALOG" LIKE 'ASP%' OR ia."CATALOG" LIKE 'CMH%' OR ia."CATALOG" LIKE 'ASH%' OR ia."CATALOG" LIKE 'AAM%' OR ia."CATALOG" LIKE 'ACM%' OR ia."CATALOG" LIKE 'ACH%' OR ia."CATALOG" LIKE 'KEXT%')
			AND NOT (ia."CATALOG" LIKE '%AAS%' OR ia."CATALOG" LIKE 'AAH%' OR ia."CATALOG" LIKE 'CEM%' OR ia."CATALOG" LIKE 'CEH%' OR ia."CATALOG" LIKE 'AEH%' OR ia."CATALOG" LIKE 'AEM%' OR ia."CATALOG" LIKE 'KA %' OR ia."CATALOG" LIKE 'KB %'OR ia."CATALOG" LIKE 'KC %' OR ia."CATALOG" LIKE 'KF %' OR ia."CATALOG" LIKE 'KV %')
			OR (ia.ITEMID LIKE '%AS%' OR ia.ITEMID LIKE '%PF%')
		THEN 'NFP'
		WHEN (ia."CATALOG" LIKE 'CSP%' OR ia."CATALOG" LIKE 'CSH%') THEN 'GRM'
		WHEN
			(ia.ITEMID LIKE '4%' OR ia.ITEMID LIKE '67%' OR ia.ITEMID LIKE '68%' OR ia.ITEMID LIKE '69%' OR ia.ITEMID LIKE '7%' OR ia.ITEMID LIKE '8%')
			AND ia."CATALOG" NOT LIKE 'AAS%' AND ia."CATALOG" NOT LIKE 'CSP%' AND ia."CATALOG" NOT LIKE 'CSH%'
		THEN 'RMA'
	END AS 'LEVEL'
FROM fersadv.Item_ALL ia
LEFT JOIN fersadv.MarkingInstruction_ALL mia ON mia.ITEMID = ia.ITEMID
WHERE SUBSIDIARYID ='FBEA'
),

resumen as(
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
)

select *
from resumen
where resumen.tipo in('PT','Commodity','Production','AUX','OTROS')