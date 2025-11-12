WITH agg AS (
  /* Importe y stock por mes × item */
  SELECT
    TRUNC(UPLOADMONTH, 'month')      AS mes,
    ITEMID,
    SUM(FINANCIALSDAMOUNT_EUR)       AS fin_eur,
    SUM(STOCKQTY)                    AS stockqty
  FROM fersads.ds_MonthlyFinancialObsoletes_EDC
  WHERE fersads.ds_MonthlyFinancialObsoletes_EDC.SUBSIDIARYID ='FBEA'
  GROUP BY 1, 2
),

/* Cobertura de (mes, item) incluyendo los que desaparecen (desplazo +1 mes) */
mes_item AS (
  SELECT a.mes, a.ITEMID FROM agg a
  UNION
  SELECT ADD_MONTHS(a.mes, 1) AS mes, a.ITEMID FROM agg a
),

/* Pareo valor actual vs. valor del mes anterior */
pairs AS (
  SELECT
    mi.mes,
    mi.ITEMID,
    cur.fin_eur   AS fin_cur,
    cur.stockqty  AS qty_cur,
    prev.fin_eur  AS fin_prev,
    prev.stockqty AS qty_prev
  FROM mes_item mi
  LEFT JOIN agg cur
    ON cur.mes = mi.mes AND cur.ITEMID = mi.ITEMID
  LEFT JOIN agg prev
    ON prev.mes = ADD_MONTHS(mi.mes, -1) AND prev.ITEMID = mi.ITEMID
),

/* Delta financiero por item y mes */
clasif AS (
  SELECT
    mes,
    ITEMID,
    COALESCE(fin_cur, 0) - COALESCE(fin_prev, 0) AS delta_fin,
    fin_cur,
    fin_prev,
    qty_cur,
    qty_prev
  FROM pairs
),

/* Entradas = parte positiva del delta (o todo si es nuevo)
   Salidas  = parte negativa en valor absoluto (o todo si desaparece) */
by_item AS (
  SELECT
    mes,
    ITEMID,
    CASE
      WHEN fin_cur IS NOT NULL AND fin_prev IS NOT NULL THEN GREATEST(delta_fin, 0)
      WHEN fin_cur IS NOT NULL AND fin_prev IS NULL THEN fin_cur
      ELSE 0
    END AS entrada_eur,
    CASE
      WHEN fin_cur IS NOT NULL AND fin_prev IS NOT NULL THEN GREATEST(-delta_fin, 0)
      WHEN fin_cur IS NULL AND fin_prev IS NOT NULL THEN fin_prev
      ELSE 0
    END AS salida_eur
  FROM clasif
),

/* Totales por mes y total del mes anterior con LAG */
month_totals AS (
  SELECT
    mes,
    SUM(fin_eur) AS total_eur
  FROM agg
  GROUP BY 1
),
mt_with_prev AS (
  SELECT
    mes,
    total_eur,
    LAG(total_eur) OVER (ORDER BY mes) AS prev_total_eur
  FROM month_totals
)

/* Resultado final (sin subqueries en SELECT) */
SELECT
  t.mes,
  SUM(t.entrada_eur) AS Entradas_EUR,
  SUM(t.salida_eur)  AS Salidas_EUR,
  SUM(t.entrada_eur) - SUM(t.salida_eur) AS Balance_EUR,              -- Entradas - Salidas
  (mt.total_eur - COALESCE(mt.prev_total_eur, 0)) AS Variacion_Total_EUR,
  (SUM(t.entrada_eur) - SUM(t.salida_eur)) - (mt.total_eur - COALESCE(mt.prev_total_eur, 0))
    AS Diferencia_Comprobacion
FROM by_item AS t
JOIN mt_with_prev AS mt
  ON mt.mes = t.mes
GROUP BY t.mes, mt.total_eur, mt.prev_total_eur
ORDER BY t.mes;
