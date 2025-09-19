select date_trunc('month',invoices.INVOICEDATE) mesventas, 
sum(invoices.INVOICEQTY) qty,
sum(invoices.AMOUNT * invoices.EXCHANGERATE_EUR) as Amount_EUR
from fersadv.SalesInvoices_ALL invoices
--join con customer
join fersadv.Customer_ALL clientes
on invoices.CUSTOMERID = clientes.CUSTOMERID
AND invoices.SUBSIDIARYID =clientes.SUBSIDIARYID 
--filtros
WHERE invoices.INVOICEDATE > '2025-04-30'
and clientes.CUSTOMERTYPE ='INTERNAL'
--agrupaciones
group by mesventas 
order by mesventas