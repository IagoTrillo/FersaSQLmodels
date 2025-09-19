select
    date_trunc('month', invoices.INVOICEDATE) as mesventas,
    invoices.SUBSIDIARYID as  SubsidiaryFROM,
    cls.COUNTRY as CountryFROM,
    cvics.TODATAAREAID as SubsidiaryTO,
    cls2.COUNTRY as CountryTO,
    invoices.ITEMID,
    if2."CATALOG",
    sum(invoices.INVOICEQTY) as qty,
    sum(invoices.AMOUNT * invoices.EXCHANGERATE_EUR) as Amount_EUR
from fersadv.SalesInvoices_ALL invoices
join fersads.ds_MonthlyFinancialObsoletes_EDC obsoletes
  on invoices.itemid = obsoletes.itemid
 and invoices.subsidiaryid = obsoletes.SUBSIDIARYID
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
group by mesventas, SubsidiaryFROM, CountryFROM, SubsidiaryTO, CountryTO, invoices.ITEMID, if2."CATALOG"
order by mesventas