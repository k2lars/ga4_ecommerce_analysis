-- Purpose: Check whether conversion and checkout drop-off differ by
--   acquisition medium (traffic_source.medium).
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: for each medium, sessions that added to cart, began checkout,
--   added payment info and purchased.
-- Note: traffic_source describes how the user was first acquired, not the
--   channel of each session. "<Other>" and "(data deleted)" values are
--   not usable. A purchase is a purchase event with revenue above zero.

WITH
  session_events AS (
    SELECT
      CONCAT(
        user_pseudo_id,
        '-',
        CAST(
          (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
          )
          AS STRING)) AS session_key,
      traffic_source.medium AS medium,
      event_name,
      ecommerce.purchase_revenue AS purchase_revenue
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  )
SELECT
  medium,
  COUNT(DISTINCT session_key) AS all_sessions,
  COUNT(DISTINCT IF(event_name = 'add_to_cart', session_key, NULL))
    AS added_to_cart,
  COUNT(DISTINCT IF(event_name = 'begin_checkout', session_key, NULL))
    AS began_checkout,
  COUNT(DISTINCT IF(event_name = 'add_payment_info', session_key, NULL))
    AS added_payment,
  COUNT(
    DISTINCT
      IF(event_name = 'purchase' AND purchase_revenue > 0, session_key, NULL))
    AS purchased
FROM session_events
GROUP BY medium
ORDER BY all_sessions DESC
