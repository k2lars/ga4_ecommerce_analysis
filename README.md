# ga4_ecommerce_analysis
Analysis of GA4 sample ecommerce data (11/2020 - 01/2021)

*Work in progress: the data-quality check is done. The segmentation analysis and dashboard are next.*

## About this project

I'm using Google's public GA4 sample ecommerce dataset in BigQuery (obfuscated Google Merchandise Store data from November 1, 2020 to January 31, 2021) to look at where ecommerce performance breaks down. Before analyzing performance, I wanted to confirm the data could be trusted, so I started with a check for duplicate purchase events.

## Duplicate purchase check

In the raw export, some transaction IDs appear in more than one purchase event. I compared totals with and without the repeats (`sql/01_duplicate_check.sql`):

| Measure | Value |
| --- | --- |
| Purchase events | 4,786 |
| Distinct transaction IDs | 4,451 |
| Recorded revenue | $330,348 |
| Revenue counting each ID once | $308,200 |

Recorded revenue is about 7.2% higher than revenue counting each ID once.

Next I looked at the 326 repeated IDs (`sql/02_duplicate_breakdown.sql`). Of those, 311 are "clean repeats," meaning the same user and the same revenue amount each time. They account for 317 extra purchase events and $21,306 of the $22,148 gap. Most of them (269) fired less than a second apart, which suggests a purchase tag firing twice on one page load. Another 42 were between 4 seconds and about 27 minutes apart, which could be someone reloading the confirmation page.

The other 15 are different. The same transaction ID was used by different users with different revenue amounts, with gaps from about 5 days to about 56 days. These look like separate orders that share an ID, not duplicates, so I reported them separately and did not treat them as removable. The export alone can't confirm any of these causes, so they are my best explanations.

## Recommendation

Deduplicate on transaction ID before reporting revenue, and look into why 15 IDs are shared across different orders.

## Limitations

- "Counted once" uses the highest revenue value for each ID, which is only valid when the repeats carry the same amount. That holds for the clean repeats by definition.
- Purchases with a blank or "(not set)" transaction ID are excluded.
- These findings describe the raw BigQuery export. GA4's own reports may handle repeated IDs differently.

## A note on the queries

The second query includes a few columns (`unique_device_types`, `unique_browsers` and `time_lapse`) that aren't used in the final output. I added them while investigating the repeats. The device and browser columns showed at most two of each per ID and no clear pattern, so they didn't change the finding.

## Next

- Break down orders and conversion rate by device, country and traffic source
- Build a one-page Looker Studio dashboard
- Write a short executive summary

