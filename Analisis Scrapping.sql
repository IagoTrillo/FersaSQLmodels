/*ANÁLISIS DE VENTAS  DE OBSOLETOS POR CATALOG*/


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

sales_from_date as (
select filial,
min(mesventa) as fromdate
from sales_external se
group by se.filial
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
  WHERE dmfoe.UPLOADMONTH = '2025-09-30'
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
	END AS lvl
FROM fersadv.Item_ALL ia
LEFT JOIN fersadv.MarkingInstruction_ALL mia ON mia.ITEMID = ia.ITEMID
WHERE SUBSIDIARYID ='FBEA'
),


-- 1) Normalizamos lvl y calculamos prioridad
nivel_prioridad AS (
  SELECT
    catalog,
    COALESCE(NULLIF(lvl,''), '') AS lvl_norm,        -- '' para "en blanco"
    CASE
      WHEN lvl = 'KFP' THEN 1
      WHEN lvl = 'FPR' THEN 2
      WHEN lvl = 'NFP' THEN 3
      WHEN lvl = 'RMA' THEN 4
      ELSE 5                                         -- cualquier otro valor o blanco al final
    END AS prio
  FROM nivel
),

-- 2) Elegimos el mejor lvl por catalog
nivel_catalog AS (
  SELECT
    catalog,
    lvl_norm AS lvl_top,
    ROW_NUMBER() OVER (
      PARTITION BY catalog
      ORDER BY prio, lvl_norm
    ) AS rn
  FROM nivel_prioridad
),

leveltop_catalog as (
SELECT
	catalog,
	lvl_top
FROM nivel_catalog
WHERE rn = 1
ORDER BY catalog
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

SELECT
  o.filial                                        AS "SubsidiaryID",
  o.catalog                                       AS "Catalog",
  ltc.lvl_top 									AS lvl_catalog,
  o.tipo											AS cost_group,
  SUM(o.stockQ)                                   AS "StockQ obsoleto (catálogo)",
  SUM(o.stock_eur)								AS "Stock€ obsoleto (catálogo)",
  sfd.fromdate 									as "SalesFromDate",
  COALESCE(se.qty_hist, 0)                        AS "Ventas toda la historia (externas)",
  COALESCE(se.qty_10y, 0)                         AS "Ventas 10 años (externas)",
  GREATEST(SUM(o.stockQ) - COALESCE(se.qty_10y, 0), 0)
                                                  AS "Stock total a repartir",
  (GREATEST(SUM(o.stockQ) - COALESCE(se.qty_10y, 0), 0))*SUM(o.stock_eur)/SUM(o.stockQ)
                                                  AS "Stock€ total a repartir",                                        
  COALESCE(se.qty_4y,  0)                         AS "Ventas 4 años (externas)"
FROM obsoletos o
LEFT JOIN sales_exe_agg se
       ON se.catalog = o.catalog
left join sales_from_date sfd
on sfd.filial=o.filial
left join leveltop_catalog ltc
  on o.catalog=ltc.catalog
WHERE 
  (
    -- Caso 1: n.lvl tiene valor no vacío ⇒ debe estar en ('KFP','FPR')
    (ltc.lvl_top IS NOT NULL AND ltc.lvl_top <> '' AND ltc.lvl_top IN ('KFP','FPR'))
    OR
    -- Caso 2: n.lvl es NULL o vacío ⇒ aplicamos reglas sobre o.tipo
    ((ltc.lvl_top IS NULL OR ltc.lvl_top = '')
      AND (
           o.tipo IS NULL
           OR TRIM(o.tipo) = ''
           OR o.tipo IN ('PT','Commodity','Production','AUX','OTROS')
      )
    )
  )
GROUP BY o.filial, o.catalog, ltc.lvl_top,o.tipo, se.qty_10y, se.qty_4y,se.qty_hist,sfd.fromdate
ORDER BY o.filial, o.catalog;




/*--------------------------------------------------
 REPARTIR CANTIDADES A LIQUIDAR POR ITEM
 ----------------------------------------------*/

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

sales_from_date as (
select filial,
min(mesventa) as fromdate
from sales_external se
group by se.filial
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
  WHERE dmfoe.UPLOADMONTH = '2025-09-30'
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
	END AS lvl
FROM fersadv.Item_ALL ia
LEFT JOIN fersadv.MarkingInstruction_ALL mia ON mia.ITEMID = ia.ITEMID
WHERE SUBSIDIARYID ='FBEA'
),

-- 1) Normalizamos lvl y calculamos prioridad
nivel_prioridad AS (
  SELECT
    catalog,
    COALESCE(NULLIF(lvl,''), '') AS lvl_norm,        -- '' para "en blanco"
    CASE
      WHEN lvl = 'KFP' THEN 1
      WHEN lvl = 'FPR' THEN 2
      WHEN lvl = 'NFP' THEN 3
      WHEN lvl = 'RMA' THEN 4
      ELSE 5                                         -- cualquier otro valor o blanco al final
    END AS prio
  FROM nivel
),

-- 2) Elegimos el mejor lvl por catalog
nivel_catalog AS (
  SELECT
    catalog,
    lvl_norm AS lvl_top,
    ROW_NUMBER() OVER (
      PARTITION BY catalog
      ORDER BY prio, lvl_norm
    ) AS rn
  FROM nivel_prioridad
),

leveltop_catalog as (
SELECT
	catalog,
	lvl_top
FROM nivel_catalog
WHERE rn = 1
ORDER BY catalog
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
),

--- Obsoletos por ItemID con importes y brand --- 
obso_items AS (
  SELECT
    dmfoe.SUBSIDIARYID AS filial,
    ia.CATALOG         AS catalog,
    ia.COSTGROUP       AS tipo,
    dmfoe.ITEMID       AS itemid,
    /* stock por ítem en obsoletos */
    SUM(dmfoe.STOCKQTY) AS stockQ_item,
    /* importe a coste del ítem (EUR) */
    SUM(dmfoe.STOCKAMOUNT * dmfoe.CALCULATEDSDAMOUNT_EUR
        / NULLIF(dmfoe.CALCULATEDSDAMOUNT_LOCAL, 0)) AS stock_eur_item,
    /* importe depreciado (EUR) */
    SUM(dmfoe.FINANCIALSDAMOUNT_EUR) AS deprec_eur_item,
    /* coste unitario */
    CASE
      WHEN SUM(dmfoe.STOCKQTY) <> 0 THEN
        SUM(dmfoe.STOCKAMOUNT * dmfoe.CALCULATEDSDAMOUNT_EUR
            / NULLIF(dmfoe.CALCULATEDSDAMOUNT_LOCAL, 0))
        / NULLIF(SUM(dmfoe.STOCKQTY), 0)
      ELSE NULL
    END AS unit_cost_item,
    /* ajusta si tu columna de marca se llama distinto */
    ia.BRAND AS brand
  FROM fersads.ds_MonthlyFinancialObsoletes_EDC dmfoe
  LEFT JOIN fersadv.item_all ia
         ON ia.SUBSIDIARYID = dmfoe.SUBSIDIARYID
        AND ia.ITEMID       = dmfoe.ITEMID
  WHERE dmfoe.UPLOADMONTH = '2025-09-30'
    AND dmfoe.STOCKQTY > 0
  GROUP BY dmfoe.SUBSIDIARYID, ia.COSTGROUP, ia.CATALOG, dmfoe.ITEMID, ia.BRAND
),

 --- Stock total a repartir por catálogo (de tu `resumen`) --- 
to_allocate AS (
  SELECT
    r.filial,
    r.catalog,
    r.stock_tras_consumo_10y AS stock_to_allocate
  FROM resumen r
left join leveltop_catalog ltc
  on r.catalog=ltc.catalog
WHERE 
  (
	    -- Caso 1: n.lvl tiene valor no vacío ⇒ debe estar en ('KFP','FPR')
	    (ltc.lvl_top IS NOT NULL AND ltc.lvl_top <> '' AND ltc.lvl_top IN ('KFP','FPR'))
	    OR
	    -- Caso 2: n.lvl es NULL o vacío ⇒ aplicamos reglas sobre o.tipo
	    (
	    (ltc.lvl_top IS NULL OR ltc.lvl_top = '')
	      AND (
	           r.tipo IS NULL
	           OR TRIM(r.tipo) = ''
	           OR r.tipo IN ('PT','Commodity','Production','AUX','OTROS')
	      )
	    )
    )
    AND r.stock_tras_consumo_10y > 0
),

/* --- Preparamos ranking; ahora LEFT JOIN para incluir catálogos sin reparto --- */
items_ranked AS (
  SELECT
    oi.filial,
    oi.catalog,
    oi.itemid,
    oi.brand,
    oi.stockQ_item,
    COALESCE(oi.unit_cost_item, 0) AS unit_cost_item,
    CASE WHEN CAST(oi.itemid AS VARCHAR) LIKE '%1001' THEN 1 ELSE 0 END AS ends_1001,
    COALESCE(ta.stock_to_allocate, 0) AS stock_to_allocate
  FROM obso_items oi
  LEFT JOIN to_allocate ta
         ON ta.filial  = oi.filial
        AND ta.catalog = oi.catalog
),

/* --- Suma acumulada previa en el orden de reparto (para todos los obsoletos) --- */
calc AS (
  SELECT
    ir.*,
    COALESCE(
      SUM(ir.stockQ_item) OVER (
        PARTITION BY ir.filial, ir.catalog
        ORDER BY ir.ends_1001 ASC, ir.unit_cost_item DESC, ir.itemid
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
      ), 0
    ) AS cum_before
  FROM items_ranked ir
),

/* --- Reparto por ítem (puede ser 0) --- */
reparto_final AS (
  SELECT
    c.filial,
    c.catalog,
    c.itemid,
    c.brand,
    c.unit_cost_item                             AS unit_cost,
    c.stockQ_item                                AS stockQ_obsoleto,
    /* Si no hay to_allocate para ese catálogo → 0 */
    c.stock_to_allocate                          AS stock_total_a_repartir,
    LEAST(c.stockQ_item, GREATEST(0, c.stock_to_allocate - c.cum_before)) AS stock_repartido
  FROM calc c
  /* no hace falta join adicional, ya traemos todo en items_ranked */
)

/* --- TABLA FINAL: TODOS LOS ÍTEMS DE OBSOLETOS (repartan o no) --- */
SELECT
  rf.filial                                     AS "SubsidiaryID",
  sfd.fromdate as 'SalesFromDate',
  rf.itemid                                     AS "ItemID",
  rf.filial || ' - ' || rf.itemid               AS "Subsidiary - ItemID",
  rf.catalog                                    AS "Catalog",
  rf.brand                                      AS "Brand",
  rf.stockQ_obsoleto                            AS "StockQ obsoleto",
  /* Importes del obsoleto y depreciación desde obso_items */
  oi.stock_eur_item                             AS "StockAmount obsoleto",
  oi.deprec_eur_item                            AS "StockAmount depreciada en obsoletos",
  rf.stock_total_a_repartir                     AS "Stock total a repartir",
  (rf.stockQ_obsoleto - rf.stock_repartido)     AS "Stock no repartido",
  (rf.stockQ_obsoleto - rf.stock_repartido) * COALESCE(rf.unit_cost, 0)
                                                AS "Amount no repartido",
  rf.stock_repartido                            AS "Stock repartido",
  rf.stock_repartido * COALESCE(rf.unit_cost, 0)
                                                AS "Amount repartido"
FROM reparto_final rf
JOIN obso_items oi
  ON oi.filial  = rf.filial
 AND oi.catalog = rf.catalog
 AND oi.itemid  = rf.itemid
 join sales_from_date sfd
 on sfd.filial=oi.filial
ORDER BY
  rf.filial,
  rf.catalog,
  CASE WHEN CAST(rf.itemid AS VARCHAR) LIKE '%1001' THEN 1 ELSE 0 END ASC,
  rf.unit_cost DESC,
  rf.itemid;

