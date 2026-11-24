-- Purpose: Check whether the high conversion of the "referral" medium is
--   driven by the store's own domain appearing as a referral source
--   (self-referral).
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: for each referral source, sessions that added to cart, began
--   checkout, added payment info and purchased, plus conversion rate.
-- Note: limited to traffic_source.medium = 'referral'. traffic_source
--   describes how the user was first acquired. A purchase is a purchase
--   event with revenue above zero.

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
      traffic_source.source AS source,
      event_name,
      ecommerce.purchase_revenue AS purchase_revenue
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
      AND traffic_source.medium = 'referral'
  ),
  by_source AS (
    SELECT
      source,
      COUNT(DISTINCT session_key) AS all_sessions,
      COUNT(DISTINCT IF(event_name = 'add_to_cart', session_key, NULL))
        AS added_to_cart,
      COUNT(DISTINCT IF(event_name = 'begin_checkout', session_key, NULL))
        AS began_checkout,
      COUNT(DISTINCT IF(event_name = 'add_payment_info', session_key, NULL))
        AS added_payment,
      COUNT(
        DISTINCT
          IF(
            event_name = 'purchase' AND purchase_revenue > 0,
            session_key,
            NULL)) AS purchased
    FROM session_events
    GROUP BY source
  )
SELECT
  *,
  ROUND(SAFE_DIVIDE(purchased, all_sessions) * 100, 2) AS conversion_rate
FROM by_source
ORDER BY all_sessions DESC
