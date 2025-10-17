with sales_external as
(
    select
        sia.SUBSIDIARYID           as filial,
        ca.customertype            as sales_type,
        date_trunc('month', sia.invoicedate)::date as mesventa,
        sia.itemid                 as item,
        sum(sia.INVOICEQTY)        as qty,
        sum(sia.AMOUNT*sia.EXCHANGERATE_EUR) as amount_eur
    from fersadv.SalesInvoices_ALL sia
    left join fersadv.Customer_ALL ca
        on ca.SUBSIDIARYID = sia.SUBSIDIARYID
       and ca.CUSTOMERID   = sia.CUSTOMERID
    where ca.customertype = 'EXTERNAL'
    group by filial, sales_type, mesventa, item
),
sales_own_subs as
(
    select
        sia.SUBSIDIARYID           as filial,
        ca.customertype            as sales_type,
        date_trunc('month', sia.invoicedate)::date as mesventa,
        sia.itemid                 as item,
        sum(sia.INVOICEQTY)        as qty,
        sum(sia.AMOUNT*sia.EXCHANGERATE_EUR) as amount_eur
    from fersadv.SalesInvoices_ALL sia
    left join fersadv.Customer_ALL ca
        on ca.SUBSIDIARYID = sia.SUBSIDIARYID
       and ca.CUSTOMERID   = sia.CUSTOMERID
    group by filial, sales_type, mesventa, item
),
/* Agregamos por clave de unión para evitar duplicados al unir dos tablas de ventas */
sales_exe_agg as
(
    select
        item,
        sum(qty)                                                        as qty_hist,
        sum(case when mesventa >= current_date - interval '4 years'
                 then coalesce(qty,0) else 0 end)                       as qty_4y,
        sum(case when mesventa >= current_date - interval '10 years'
                 then coalesce(qty,0) else 0 end)                       as qty_10y
    from sales_external
    group by item
),
sales_own_agg as
(
    select
        filial,
        item,
        sum(qty) as qty_hist,
        sum(case when mesventa >= current_date - interval '4 years'
                 then coalesce(qty,0) else 0 end)                       as qty_4y,
        sum(case when mesventa >= current_date - interval '10 years'
                 then coalesce(qty,0) else 0 end)                       as qty_10y
    from sales_own_subs
    group by filial, item
),
obsoletos as
(
    select
        dmfoe.SUBSIDIARYID as filial,
        dmfoe.ITEMID       as item,
        dmfoe."CATALOG"    as catalog,
        sum(dmfoe.STOCKQTY) as stockQ,
        sum(dmfoe.STOCKAMOUNT * dmfoe.CALCULATEDSDAMOUNT_EUR
            / nullif(dmfoe.CALCULATEDSDAMOUNT_LOCAL,0))                as stock_eur,
        sum(dmfoe.FINANCIALSDAMOUNT_EUR)                               as deprec_eur
    from fersads.ds_MonthlyFinancialObsoletes_EDC dmfoe
    where dmfoe.UPLOADMONTH  = '2025-08-31'
      and dmfoe.STOCKQTY > 0
    group by dmfoe.SUBSIDIARYID, dmfoe.ITEMID, dmfoe."CATALOG"
)

select
    o.filial,
    o.item,
    o.catalog,
    min(o.stockQ)                                     as stockQ,
    coalesce(min(o.stock_eur),  0)                    as stock_eur,
    coalesce(min(o.deprec_eur), 0)                    as deprec_eur,
	coalesce(min(o.stock_eur),  0)/nullif(min(o.stockQ), 0)  as unit_cost,
    
    coalesce(sales_own.qty_hist, 0)                      as hist_sales_own_subs_ext_int,
    coalesce(sales_ext.qty_hist,     0)                      as hist_sales,
    coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_hist,0)      as stock_tras_consumo_hist,
    (coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_hist,0))*coalesce(min(o.stock_eur),  0)/nullif(min(o.stockQ), 0) as amount_hist,
    case when coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_hist,0) > 0
         then 'NO' else 'SI' end                      as consumo_hist_suf,

    coalesce(sales_own.qty_10y, 0)                      as sales_10y_own_subs_ext_int,
    coalesce(sales_ext.qty_10y, 0)                           as sales_10y,
    coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_10y,0) as stock_tras_consumo_10y,
    (coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_10y,0))*coalesce(min(o.stock_eur),  0)/nullif(min(o.stockQ), 0) as amount_10y,
    case when coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_10y,0) > 0
         then 'NO' else 'SI' end                      as consumo_10y_suf,
         
    coalesce(sales_own.qty_4y, 0)                      as sales_4y_own_subs_ext_int,
    coalesce(sales_ext.qty_4y,  0)                           as sales_4y,
    coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_4y,0) as stock_tras_consumo_4y,
    (coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_4y,0))*coalesce(min(o.stock_eur),  0)/nullif(min(o.stockQ), 0) as amount_4y,    
    case when coalesce(min(o.stockQ),0) - coalesce(sales_ext.qty_4y,0) > 0
         then 'NO' else 'SI' end                      as consumo_4y_suf

from obsoletos o
left join sales_exe_agg sales_ext
    on sales_ext.item   = o.item
left join sales_own_agg sales_own
    on sales_own.filial = o.filial
   and sales_own.item   = o.item
group by o.filial, o.item, o.catalog, sales_ext.qty_hist, sales_ext.qty_4y, sales_ext.qty_10y, sales_own.qty_hist, sales_own.qty_4y, sales_own.qty_10y
