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

/* FIX AQUÍ: itemid totalmente calificado en SELECT y GROUP BY */
sales_external_item AS (
  SELECT
    sia.SUBSIDIARYID                                   AS filial,
    ia.catalog                                         AS catalog,
    sia.ITEMID                                         AS itemid,
    date_trunc('month', sia.invoicedate)::date         AS mesventa,
    SUM(sia.INVOICEQTY)                                AS qty_item
  FROM fersadv.SalesInvoices_ALL sia
  LEFT JOIN fersadv.Customer_ALL ca
         ON ca.SUBSIDIARYID = sia.SUBSIDIARYID
        AND ca.CUSTOMERID   = sia.CUSTOMERID
  LEFT JOIN fersadv.Item_ALL ia
         ON sia.SUBSIDIARYID = ia.SUBSIDIARYID
        AND sia.ITEMID       = ia.ITEMID
  WHERE ca.customertype = 'EXTERNAL'
  GROUP BY
    sia.SUBSIDIARYID,
    ia.catalog,
    sia.ITEMID,
    date_trunc('month', sia.invoicedate)::date
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
)

/* Agregado de ventas EXTERNAS por ítem (10y) */
  SELECT
    filial,
    catalog,
    itemid,
    SUM(CASE WHEN mesventa >= current_date - INTERVAL '4 years' THEN COALESCE(qty_item,0) ELSE 0 END) AS qty_4y_item,
    SUM(CASE WHEN mesventa >= current_date - INTERVAL '10 years' THEN COALESCE(qty_item,0) ELSE 0 END) AS qty_10y_item
  FROM sales_external_item
  GROUP BY filial, catalog, itemid