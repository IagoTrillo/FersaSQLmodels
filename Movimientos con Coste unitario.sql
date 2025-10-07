with movements as
(select
omf.SUBSIDIARYIDFROM as SubsFROM,
omf.ITEMIDFROM as ItemFROM, 
omf.SUBSIDIARYIDTO as SubsTO,
omf.ITEMIDTO as ItemTO,
omf.QTY,
case
	WHEN mfo.SUBSIDIARYID = 'NAUT' THEN
		CASE 
	        WHEN mfo.CALCULATEDSDAMOUNT_LOCAL = 0 THEN NULL
	        ELSE mfo.STOCKAMOUNT * 1.275 * mfo.CALCULATEDSDAMOUNT_EUR / mfo.CALCULATEDSDAMOUNT_LOCAL / mfo.STOCKQTY
     	END
     ELSE
     	CASE 
	        WHEN mfo.CALCULATEDSDAMOUNT_LOCAL = 0 THEN NULL
	        ELSE mfo.STOCKAMOUNT * mfo.CALCULATEDSDAMOUNT_EUR / mfo.CALCULATEDSDAMOUNT_LOCAL / mfo.STOCKQTY
     	END
     END as unitCost€,
omf.QTY * (case
	WHEN mfo.SUBSIDIARYID = 'NAUT' THEN
		CASE 
	        WHEN mfo.CALCULATEDSDAMOUNT_LOCAL = 0 THEN NULL
	        ELSE mfo.STOCKAMOUNT * 1.275 * mfo.CALCULATEDSDAMOUNT_EUR / mfo.CALCULATEDSDAMOUNT_LOCAL / mfo.STOCKQTY
     	END
     ELSE
     	CASE 
	        WHEN mfo.CALCULATEDSDAMOUNT_LOCAL = 0 THEN NULL
	        ELSE mfo.STOCKAMOUNT * mfo.CALCULATEDSDAMOUNT_EUR / mfo.CALCULATEDSDAMOUNT_LOCAL / mfo.STOCKQTY
     	END
     END) as MovementAmount€ 
from fersadw.ObsoleteMovement_FACT omf
LEFT JOIN fersads.ds_monthlyfinancialobsoletes_edc mfo
	ON mfo.ITEMID =omf.ITEMIDFROM
	and mfo.SUBSIDIARYID=omf.SUBSIDIARYIDFROM 
where
	omf.FLAG = 'FINANCE'
	AND omf.CALCTYPE = 'MAXStock'
	and mfo.UPLOADMONTH = '2025-07-31')
	
select movements.SubsFROM, sum(movements.MovementAmount€)
from movements
group by SubsFROM

