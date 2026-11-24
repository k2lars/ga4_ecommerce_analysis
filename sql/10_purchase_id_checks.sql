-- Purpose: Check how purchase events relate to sessions and transaction IDs,
--   to decide how to count a purchase in the funnel.
-- Data: GA4 sample ecommerce dataset, 2020-11-01 to 2021-01-31
-- Output: Query A splits purchase sessions by whether the transaction ID is
--   valid. Query B counts purchase events with no usable ID and the
--   revenue they carry.
-- Note: sessions with a NULL transaction ID match neither the IN nor the
--   NOT IN condition, so they appear in neither valid nor no-ID counts.
--   Run each query separately.

-- Query A
WITH
  purchase_events AS (
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
      ecommerce.transaction_id AS transaction_id
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
      AND event_name = 'purchase'
  )
SELECT
  COUNT(DISTINCT session_key) AS purchase_sessions,
  COUNT(DISTINCT IF(transaction_id NOT IN ('', '(not set)'), session_key, NULL))
    AS sessions_valid_id,
  COUNT(DISTINCT IF(transaction_id IN ('', '(not set)'), session_key, NULL))
    AS sessions_no_id,
  COUNT(
    DISTINCT IF(transaction_id NOT IN ('', '(not set)'), transaction_id, NULL))
    AS distinct_valid_ids
FROM purchase_events

-- Query B
WITH
  purchase_events AS (
    SELECT
      ecommerce.transaction_id AS transaction_id,
      ecommerce.purchase_revenue AS purchase_revenue,
      (
        SELECT value.int_value
        FROM UNNEST(event_params)
        WHERE key = 'ga_session_id'
      ) AS ga_session_id
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
      AND event_name = 'purchase'
  )
SELECT
  COUNT(*) AS purchase_events,
  COUNTIF(ga_session_id IS NULL) AS events_without_session_id,
  COUNTIF(transaction_id IN ('', '(not set)')) AS no_id_events,
  COUNTIF(transaction_id IN ('', '(not set)') AND purchase_revenue > 0)
    AS no_id_with_revenue,
  ROUND(SUM(IF(transaction_id IN ('', '(not set)'), purchase_revenue, 0)), 2)
    AS no_id_revenue
FROM purchase_events
