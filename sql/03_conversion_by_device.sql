-- Purpose: Compare conversion rate (orders / sessions) by device category.
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: sessions, orders and conversion rate for each device category.
-- Note: orders are distinct transaction IDs on purchase events,
--   excluding blank or "(not set)" IDs. A session is a unique
--   user_pseudo_id + ga_session_id combination.

WITH session_events AS (
  SELECT
    user_pseudo_id,
    device.category AS device_category,
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id') AS ga_session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions_by_device AS (
  SELECT
    device_category,
    COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING))) AS sessions
  FROM session_events
  GROUP BY device_category
),

orders_by_device AS (
  SELECT
    device.category AS device_category,
    COUNT(DISTINCT ecommerce.transaction_id) AS orders
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id NOT IN ('', '(not set)')
  GROUP BY device.category
)

SELECT
  s.device_category,
  s.sessions,
  o.orders,
  ROUND(SAFE_DIVIDE(o.orders, s.sessions) * 100, 2) AS conversion_rate
FROM sessions_by_device AS s
LEFT JOIN orders_by_device AS o
  ON s.device_category = o.device_category
ORDER BY s.sessions DESC
