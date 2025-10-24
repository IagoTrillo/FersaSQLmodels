WITH pesos_ia_limpios AS (
  SELECT
      ia.subsidiaryid,
      ia.itemid,
      /* NETWEIGHT si > 0; si no, GROSSWEIGHT si > 0 */
      COALESCE(NULLIF(ia.netweight, 0),
               NULLIF(ia.grossweight, 0)) AS peso
  FROM fersadv.item_all ia
),

analisis_pesos AS (
  SELECT
      pil.itemid,
      COUNT(*)                    AS n_filiales,          -- total filas (incluye NULL)
      COUNT(pil.peso)             AS n_valores,           -- pesos no nulos
      MIN(pil.peso)               AS peso_min,
      MAX(pil.peso)               AS peso_max,
      MAX(pil.peso) - MIN(pil.peso)                        AS dif_peso_abs,
      (MAX(pil.peso) - MIN(pil.peso)) / NULLIF(AVG(pil.peso), 0) AS dif_peso_rel,
      CASE
        WHEN (MAX(pil.peso) - MIN(pil.peso)) / NULLIF(AVG(pil.peso), 0) < 0.10
          THEN AVG(pil.peso)
        ELSE NULL
      END                          AS peso_normalizado,
      /* Estado en función de la disponibilidad y coherencia */
      CASE
        WHEN COUNT(pil.peso) = 0 THEN 'Revisar - Sin info'
        WHEN (MAX(pil.peso) - MIN(pil.peso)) / NULLIF(AVG(pil.peso), 0) < 0.10
          THEN 'OK'
        ELSE 'Revisar diferencias globales'
      END                          AS estado
  FROM pesos_ia_limpios pil
  GROUP BY pil.itemid
)

SELECT *
FROM analisis_pesos;
