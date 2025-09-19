WITH mov_interco as ( --movimientos interco de obsoletos de abril (con fecha ETD)
select
    date_trunc('month', invoices.INVOICEDATE+60) as mesventas,
    invoices.SUBSIDIARYID as  SubsidiaryFROM,
    cls.COUNTRY as CountryFROM,
    cvics.TODATAAREAID as SubsidiaryTO,
    cls2.COUNTRY as CountryTO,
    invoices.ITEMID,
    if2."CATALOG",
    sum(invoices.INVOICEQTY) as qty,
    sum(invoices.AMOUNT * invoices.EXCHANGERATE_EUR) as Amount_EUR
from fersadv.SalesInvoices_ALL invoices
left join fersads.ds_MonthlyFinancialObsoletes_EDC obsoletes
	on invoices.itemid = obsoletes.itemid	
	and invoices.subsidiaryid = obsoletes.SUBSIDIARYID
join fersadv.Customer_ALL client
	on client.CUSTOMERID =invoices.CUSTOMERID 
	and client.SUBSIDIARYID =invoices.SUBSIDIARYID 
Join fersaparams.CompanyLocation_standalone cls
	on invoices.subsidiaryid=cls.LOCATIONID 
join fersaParamsPublic.CustomerVendorInterCo_standalone cvics 
	on cvics.CUSTVENDACCOUNT =invoices.CUSTOMERID
	and cvics.FROMDATAAREAID=invoices.SUBSIDIARYID 
	and cvics."TYPE"=2
join fersaParams.CompanyLocation_standalone cls2
	on cls2.LOCATIONID =cvics.TODATAAREAID
join fersadw.Item_FACT if2
	on if2.ITEMID = invoices.ITEMID
	and if2.SUBSIDIARYID =invoices.SUBSIDIARYID
where obsoletes.uploadmonth = '2025-04-30'
	and invoices.INVOICEDATE > '2025-04-30'
	and client.CUSTOMERTYPE = 'INTERNAL'
group by mesventas, SubsidiaryFROM, CountryFROM, SubsidiaryTO, CountryTO, invoices.ITEMID, if2."CATALOG"
order by mesventas),

clas_ventas as (
select
	date_trunc('month', inv2.INVOICEDATE),
	inv2.itemid,
	cust.CUSTOMERTYPE
from fersadv.SalesInvoices_ALL inv2
join fersadv.Customer_ALL cust
	on cust.CUSTOMERID =inv2.CUSTOMERID 
	and cust.SUBSIDIARYID =inv2.SUBSIDIARYID
)

select
	salesinv.SUBSIDIARYID as Subsidiary,
	salesinv.invoicedate as Date,
	sum(salesinv.AMOUNT * salesinv.EXCHANGERATE_EUR) as Amount_EUR
from fersadv.SalesInvoices_ALL salesinv
join fersadv.Customer_ALL client2
	on client2.CUSTOMERID =salesinv.CUSTOMERID 
	and client2.SUBSIDIARYID =salesinv.SUBSIDIARYID 
join mov_interco
on mov_interco.SubsidiaryTO=salesinv.SUBSIDIARYID
and mov_interco.itemid=salesinv.ITEMID 
where client2.CUSTOMERTYPE = 'EXTERNAL'
and salesinv.INVOICEDATE > '2025-04-30'
group by Subsidiary, Date