-- Purpose: Compare conversion rate (orders / sessions) by geographic location (country).
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: sessions, orders and conversion rate for each location.
-- Note: orders are distinct transaction IDs on purchase events,
--   excluding blank or "(not set)" IDs. A session is a unique
--   user_pseudo_id + ga_session_id combination.

WITH
  session_events AS (
    SELECT
      user_pseudo_id,
      geo.country AS country,
      (
        SELECT value.int_value
        FROM UNNEST(event_params)
        WHERE key = 'ga_session_id'
      ) AS ga_session_id
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  ),
  sessions_by_country AS (
    SELECT
      country,
      COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)))
        AS sessions
    FROM session_events
    GROUP BY country
  ),
  orders_by_country AS (
    SELECT
      geo.country AS country,
      COUNT(DISTINCT ecommerce.transaction_id) AS orders
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
      AND event_name = 'purchase'
      AND ecommerce.transaction_id NOT IN ('', '(not set)')
    GROUP BY geo.country
  )
SELECT
  s.country,
  s.sessions,
  o.orders,
  ROUND(SAFE_DIVIDE(o.orders, s.sessions) * 100, 2) AS conversion_rate
FROM sessions_by_country AS s
LEFT JOIN orders_by_country AS o
  ON s.country = o.country
ORDER BY s.sessions DESC
LIMIT 10
