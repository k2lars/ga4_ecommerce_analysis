-- Purpose: Check whether duplicate purchase events overstate revenue.
--   Compares total purchase events and recorded revenue against distinct
--   transaction IDs and revenue counted once per ID.
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: total purchase events, distinct orders, recorded revenue, and
--   revenue counted once (MAX per transaction ID).
-- Note: Excludes purchases with a blank or "(not set)" transaction ID.

WITH per_order AS (
  SELECT
    ecommerce.transaction_id,
    COUNT(*) AS events,
    SUM(ecommerce.purchase_revenue) AS total_revenue,
    MAX(ecommerce.purchase_revenue) AS unique_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id NOT IN ('', '(not set)')
  GROUP BY ecommerce.transaction_id
)
SELECT
  SUM(per_order.events) AS total_purchases,
  COUNT(*) AS distinct_orders,
  SUM(per_order.total_revenue) AS recorded_revenue,
  SUM(per_order.unique_revenue) AS revenue_1count
FROM per_order
