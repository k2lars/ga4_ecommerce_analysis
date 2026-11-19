-- Purpose: Break repeated purchase transaction IDs into "clean repeat"
--   (one user, one revenue amount) vs. "mixed" (multiple users or amounts),
--   to separate true duplicate events from IDs that may be separate orders.
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: repeated IDs, total events, recorded revenue, and revenue counted
--   once, for each repeat type.
-- Note: unique_device_types, unique_browsers and time_lapse were added while
--   investigating the repeats; they are not used in the final output.

WITH per_id AS (
  SELECT
    ecommerce.transaction_id,
    COUNT(*) AS transID_count,
    COUNT(DISTINCT user_pseudo_id) AS unique_users,
    COUNT(DISTINCT ecommerce.purchase_revenue) AS unique_amounts,
    COUNT(DISTINCT device.category) AS unique_device_types,
    COUNT(DISTINCT device.web_info.browser) AS unique_browsers,
    SUM(ecommerce.purchase_revenue) AS total_revenue,
    MAX(ecommerce.purchase_revenue) AS one_revenue,
    TIMESTAMP_DIFF(
      MAX(TIMESTAMP_MICROS(event_timestamp)),
      MIN(TIMESTAMP_MICROS(event_timestamp)),
      SECOND) AS time_lapse
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id NOT IN ('', '(not set)')
  GROUP BY ecommerce.transaction_id
  HAVING transID_count > 1
)
SELECT
  CASE
    WHEN unique_users = 1 AND unique_amounts = 1 THEN 'clean repeat'
    ELSE 'mixed'
  END AS repeat_type,
  COUNT(*) AS repeated_ids,
  SUM(transID_count) AS total_events,
  SUM(total_revenue) AS recorded_revenue,
  SUM(one_revenue) AS revenue_1count
FROM per_id
GROUP BY repeat_type
