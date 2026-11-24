-- Purpose: Measure average and median order value, used to size the
--   checkout opportunity.
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: order count, total revenue, average order value and median
--   order value.
-- Note: revenue is counted once per transaction ID (MAX per ID), and
--   blank or "(not set)" IDs are excluded.

WITH
  orders AS (
    SELECT
      ecommerce.transaction_id AS transaction_id,
      MAX(ecommerce.purchase_revenue) AS revenue
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
      AND event_name = 'purchase'
      AND ecommerce.transaction_id NOT IN ('', '(not set)')
    GROUP BY transaction_id
  )
SELECT
  COUNT(*) AS orders,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(AVG(revenue), 2) AS avg_order_value,
  ROUND(APPROX_QUANTILES(revenue, 100)[OFFSET(50)], 2) AS median_order_value
FROM orders
