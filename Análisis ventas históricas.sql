	select
		sia.SUBSIDIARYID as filial,
		ca.customertype as sales_type,
		sum(sia.INVOICEQTY) as qty,
		sum(sia.AMOUNT*sia.EXCHANGERATE_EUR) as amount
	from fersadv.SalesInvoices_ALL sia
	left join fersadv.Customer_ALL ca
		on ca.SUBSIDIARYID = sia.SUBSIDIARYID
		and ca.CUSTOMERID = sia.CUSTOMERID
	where sia.itemid='10022018001001'
	group by filial, sales_type