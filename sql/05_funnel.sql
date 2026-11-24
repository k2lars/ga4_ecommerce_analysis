-- Purpose: Count sessions reaching each stage of the shopping funnel to
--   find where shoppers drop off.
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: one row with the number of sessions that viewed an item, added
--   to cart, began checkout, added shipping info, added payment info and
--   purchased.
-- Note: each column counts distinct sessions that fired the event at least
--   once. purchased_any counts any purchase event; purchased_with_revenue
--   counts purchase events with revenue above zero and is the number used
--   in the analysis.

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
      event_name,
      ecommerce.purchase_revenue AS purchase_revenue
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  )
SELECT
  COUNT(DISTINCT session_key) AS all_sessions,
  COUNT(DISTINCT IF(event_name = 'view_item', session_key, NULL))
    AS viewed_item,
  COUNT(DISTINCT IF(event_name = 'add_to_cart', session_key, NULL))
    AS added_to_cart,
  COUNT(DISTINCT IF(event_name = 'begin_checkout', session_key, NULL))
    AS began_checkout,
  COUNT(DISTINCT IF(event_name = 'add_shipping_info', session_key, NULL))
    AS added_shipping,
  COUNT(DISTINCT IF(event_name = 'add_payment_info', session_key, NULL))
    AS added_payment,
  COUNT(DISTINCT IF(event_name = 'purchase', session_key, NULL))
    AS purchased_any,
  COUNT(
    DISTINCT
      IF(event_name = 'purchase' AND purchase_revenue > 0, session_key, NULL))
    AS purchased_with_revenue
FROM session_events
