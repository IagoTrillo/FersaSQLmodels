WITH pesos_ia_limpios AS (
  SELECT
      ia.subsidiaryid,
      ia.itemid,
      COALESCE(NULLIF(ia.netweight, 0),
               NULLIF(ia.grossweight, 0)) AS peso
  FROM fersadv.item_all ia
),
analisis_pesos AS (
  SELECT
      pil.itemid,
      COUNT(*) AS n_filiales,
      COUNT(pil.peso) AS n_valores,
      MIN(pil.peso) AS peso_min,
      MAX(pil.peso) AS peso_max,
      MAX(pil.peso) - MIN(pil.peso) AS dif_peso_abs,
      (MAX(pil.peso) - MIN(pil.peso)) / NULLIF(AVG(pil.peso), 0) AS dif_peso_rel,
      CASE
        WHEN (MAX(pil.peso) - MIN(pil.peso)) / NULLIF(AVG(pil.peso), 0) < 0.10 THEN AVG(pil.peso)
        ELSE NULL
      END AS peso_normalizado,
      CASE
        WHEN COUNT(pil.peso) = 0 THEN 'Revisar - Sin info'
        WHEN (MAX(pil.peso) - MIN(pil.peso)) / NULLIF(AVG(pil.peso), 0) < 0.10 THEN 'OK'
        ELSE 'Revisar diferencias globales'
      END AS estado
  FROM pesos_ia_limpios pil
  GROUP BY pil.itemid
),
sin_info AS (
  SELECT itemid
  FROM analisis_pesos
  WHERE n_valores = 0
),

/* === FUENTES ALTERNATIVAS === */
alt_pesos AS (

  /* --- ITEMID --- */
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)) AS peso, 'NET' AS tipo,
         'fersads.ds_InventTable_FER.NETWEIGHT' AS origen
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."NETWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_InventTable_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'TARE',
         'fersads.ds_InventTable_FER.TARAWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."TARAWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_InventTable_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'NET',
         'fersads.ds_Item_DLX.NETWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."NETWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_DLX s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'GROSS',
         'fersads.ds_Item_DLX.GROSSWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."GROSSWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_DLX s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'NET',
         'fersads.ds_Item_PFI_HIST.NETWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."NETWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_PFI_HIST s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'GROSS',
         'fersads.ds_Item_PFI_HIST.GROSSWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."GROSSWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_PFI_HIST s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'NET',
         'fersads.ds_Item_SP_NKE.NETWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."NETWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_SP_NKE s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'GROSS',
         'fersads.ds_Item_SP_NKE.GROSSWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."GROSSWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_SP_NKE s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'TARE',
         'fersads.ds_Item_SP_NKE.TARAWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."TARAWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_Item_SP_NKE s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'OTHER',
         'fersads.ds_PurchaseInvoiceLine_CHN_HIST.WEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."WEIGHT" AS FLOAT) AS v
         FROM fersads.ds_PurchaseInvoiceLine_CHN_HIST s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'NET',
         'fersads.ds_WHSLoadLine_FER.ITEMNETWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."ITEMNETWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_WHSLoadLine_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'OTHER',
         'fersads.ds_WHSLoadLine_FER.PICKEDWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."PICKEDWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_WHSLoadLine_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'TARE',
         'fersads.ds_WHSLoadLine_FER.ITEMTAREWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."ITEMTAREWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_WHSLoadLine_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'OTHER',
         'fersads.ds_WHSWorkInventTrans_FER.TRANSACTIONWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."TRANSACTIONWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_WHSWorkInventTrans_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  UNION ALL
  SELECT t.itemid, CAST(t.v AS DECIMAL(38,10)), 'OTHER',
         'fersads.ds_WHSWorkInventTrans_FER.REMAININGTRANSACTIONWEIGHT'
  FROM ( SELECT s."ITEMID" AS itemid, CAST(s."REMAININGTRANSACTIONWEIGHT" AS FLOAT) AS v
         FROM fersads.ds_WHSWorkInventTrans_FER s ) t
  WHERE t.v > 0 AND t.v <= 1000000

  /* --- ITEMNO + cálculo de peso unitario desde caja --- */
  /* Variante A: WEIGHTPERBOX / QTYPCS (si existe QTYPCS en LABELING) */
  UNION ALL
  SELECT t.itemid,
         CAST(t.unit_v AS DECIMAL(38,10)) AS peso,
         'OTHER' AS tipo,
         'fersads.ds_FERPACKINGINSTRUCTIONLINE_FER.WEIGHTPERBOX / fersads.ds_FERLABELINGINSTRUCTIONLINE_FER.QTYPCS' AS origen
  FROM (
    SELECT p."ITEMNO" AS itemid,
           CAST(p."WEIGHTPERBOX" AS FLOAT) / NULLIF(CAST(l."QTYPCS" AS FLOAT), 0) AS unit_v
    FROM fersads.ds_FERPACKINGINSTRUCTIONLINE_FER p
    JOIN fersads.ds_FERLABELINGINSTRUCTIONLINE_FER l
      ON l."ITEMNO" = p."ITEMNO"
  ) t
  WHERE t.unit_v > 0 AND t.unit_v <= 1000000

  /* Variante B (fallback): si NO hay QTYPCS, usar ITEMPERBOX de PACKING */
  UNION ALL
  SELECT t.itemid,
         CAST(t.unit_v AS DECIMAL(38,10)),
         'OTHER',
         'fersads.ds_FERPACKINGINSTRUCTIONLINE_FER.WEIGHTPERBOX / ITEMPERBOX' AS origen
  FROM (
    SELECT p."ITEMNO" AS itemid,
           CAST(p."WEIGHTPERBOX" AS FLOAT) / NULLIF(CAST(p."ITEMPERBOX" AS FLOAT), 0) AS unit_v
    FROM fersads.ds_FERPACKINGINSTRUCTIONLINE_FER p
  ) t
  WHERE t.unit_v > 0 AND t.unit_v <= 1000000
),

alt_pesos_filtrados AS (
  SELECT a.*
  FROM alt_pesos a
  JOIN sin_info si ON si.itemid = a.itemid
),

ranked AS (
  SELECT
    a.itemid,
    a.peso,
    a.tipo,
    a.origen,
    CASE a.tipo WHEN 'NET' THEN 1 WHEN 'GROSS' THEN 2 WHEN 'TARE' THEN 3 ELSE 4 END AS prioridad,
    ROW_NUMBER() OVER (
      PARTITION BY a.itemid
      ORDER BY CASE a.tipo WHEN 'NET' THEN 1 WHEN 'GROSS' THEN 2 WHEN 'TARE' THEN 3 ELSE 4 END, a.peso DESC
    ) AS rn
  FROM alt_pesos_filtrados a
)

SELECT
  r.itemid,
  ROUND(r.peso, 6) AS peso_sugerido,
  r.tipo AS tipo_sugerido,
  r.origen AS origen_sugerido
FROM ranked r
WHERE r.rn = 1
ORDER BY r.itemid;
