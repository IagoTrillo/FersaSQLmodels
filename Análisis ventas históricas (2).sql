	select
		sia.SUBSIDIARYID as filial,
		sia.itemid as itemid,
		sum(sia.INVOICEQTY) as qty,
		sum(sia.AMOUNT*sia.EXCHANGERATE_EUR) as amount
	from fersadv.SalesInvoices_ALL sia
	left join fersadv.Customer_ALL ca
		on ca.SUBSIDIARYID = sia.SUBSIDIARYID
		and ca.CUSTOMERID = sia.CUSTOMERID
	where sia.subsidiaryid='FBRA'
		AND sia.invoicedate>='01/01/2024'
	group by filial, sia.ITEMID;
	