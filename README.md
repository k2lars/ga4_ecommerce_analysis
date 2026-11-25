# ga4_ecommerce_analysis
Analysis of GA4 sample ecommerce data (11/2020 - 01/2021)

*Status: the analysis is complete. The Looker Studio dashboard and executive summary are next.*

## About this project

I'm using Google's public GA4 sample ecommerce dataset in BigQuery (obfuscated Google Merchandise Store data from November 1, 2020 to January 31, 2021) to answer one question: where does ecommerce performance break down? Before analyzing performance I checked that the data could be trusted. Then I looked for gaps by device, country, shopping-funnel step and acquisition channel, and sized the biggest one.

**Short version:** conversion is about 1.2% (4,451 orders from 360,129 sessions) and doesn't differ meaningfully by device or country. The biggest controllable loss is in checkout: about 60% of sessions that begin checkout don't buy, and most of that loss happens before payment details are entered. That drop is store-wide, so I propose a test of the checkout step and estimate what it could be worth.

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

**Recommendation:** deduplicate on transaction ID before reporting revenue, and look into why 15 IDs are shared across different orders.

## Orders, sessions and revenue

A session is a unique `user_pseudo_id` and `ga_session_id` combination (360,129 sessions). Orders are distinct transaction IDs on purchase events, excluding blank or "(not set)" IDs (4,451 orders). Conversion rate is orders divided by sessions. The average order is $69.24 but the median is $48, so a smaller number of large orders pulls the average up (`sql/09_order_value.sql`).

Some purchase events have no usable ID. Of 883 events with a blank or "(not set)" ID, 433 carry revenue (about $30,500 in total, an upper bound because repeats can't be removed without an ID) and the rest carry none. At least 12 more purchase sessions have a NULL ID. For the funnel below I count a purchase as a session with a purchase event that has revenue above zero. That gives 4,446 sessions, very close to the 4,451 orders. One question is still open: there are 4,044 sessions with a valid ID but 4,451 distinct valid IDs, which suggests some sessions contain more than one order, but I haven't verified that (`sql/10_purchase_id_checks.sql`).

## Conversion by device and country

Conversion was similar across devices: desktop 1.22%, mobile 1.27% and tablet 1.04% (`sql/03_conversion_by_device.sql`). The differences are small and not statistically significant. Device counts add up to 4,459 orders instead of 4,451, likely because a few transaction IDs appear under more than one device category.

Among the ten countries with the most sessions, conversion ranged from 1.0% to 1.59% (`sql/04_conversion_by_country.sql`), and the overall difference is not statistically significant (chi-square p of about 0.14). Spain was highest at 1.59% against 1.23% for all other sessions (p of about 0.008). With ten countries compared, that doesn't hold up after a multiple-comparison correction, and Spain is only about 1.9% of sessions, so I treat it as a lead, not a finding. Ruling out device and country is still a useful result because it points to where to look next.

## Where the funnel breaks down

| Step | Sessions | % of previous step |
| --- | --- | --- |
| All sessions | 360,129 | |
| Viewed an item | 77,020 | 21.4% |
| Added to cart | 15,188 | 19.7% |
| Began checkout | 11,106 | 73.1% |
| Added payment info | 6,815 | 61.4% |
| Purchased | 4,446 | 65.2% |

Each step counts distinct sessions that fired the event at least once (`sql/05_funnel.sql`), not necessarily in strict order. I left `add_shipping_info` out of the table. It fires in 11,105 sessions against 11,106 for `begin_checkout`, which suggests it fires along with the start of checkout and isn't a real step. That is a hypothesis I can't confirm from the export.

Earlier steps lose more sessions in absolute terms, but I focused on checkout because those shoppers have already shown intent to buy. Of 11,106 sessions that began checkout, 6,660 (about 60%) did not purchase. Of those, 4,291 (39% of checkout starts) never entered payment details. After payment details are entered, about 65% purchase.

The checkout-to-payment rate was similar on every device: 60.8% on desktop, 62.1% on mobile and 63.3% on tablet (tablet has only 240 checkout sessions). The 1.3-point gap between desktop and mobile is not statistically significant (p of about 0.17), so the drop looks store-wide and not tied to one device (`sql/06_funnel_by_device.sql`).

## Acquisition channel

The `traffic_source` fields in the GA4 export describe how a user was first acquired, not the channel of each session, and about a fifth of users have an unusable medium (`<Other>` or deleted data). With that limit, conversion by first-touch medium was: referral 1.53%, direct 1.16%, organic 1.02%, paid search (ppc) 0.92%, `<Other>` 0.91%, and 2.84% for sessions with deleted data (`sql/07_funnel_by_medium.sql`). I don't draw conclusions from the deleted-data group because I can't tell who is in it. Payment-to-purchase was flat at 64% to 66% in every group, so the differences between channels sit at the checkout-to-payment step, which ranged from 52% to 81%.

Paid search converts below all other sessions combined (0.92% against 1.25%, p of about 0.0002) but isn't distinguishable from organic. The dataset has no ad cost, so I can't say anything about return on ad spend.

The referral result needs a caution. About 44% of referral users (roughly 26,000) show what looks like the store's own domain as their source, and they convert at about 1.9% against about 1.3% for other referrals (`sql/08_referral_source.sql`). That pattern is typical of self-referral, where shoppers already mid-journey are counted as referrals, and it inflates the headline referral rate. Common causes are cross-domain tracking that isn't configured or an unwanted-referrals list that doesn't include the store's own domain. The export can't confirm the cause, so I would check those settings. Other referrals at 1.3% still sit above organic and direct, which I treat as a lead, not a finding.

## Opportunity and proposed test

The data shows where shoppers leave, not why, so the next step is an experiment on the checkout step between starting checkout and entering payment details. For example, a simpler form or a guest-checkout variant against the current flow, randomized by user, with checkout-start to payment-entry rate as the main metric.

To size it, I assumed a lift in that rate and that recovered shoppers then buy at today's 65% rate. These are illustrative assumptions, not a forecast:

- A 3-point lift (61.4% to 64.4%) would mean about 217 extra orders over the 92 days, worth roughly $10,000 to $15,000 at the $48 median to $69 average order value. That is 3% to 5% of the $308,200 in revenue.
- A 5-point lift would mean about 362 extra orders, worth roughly $17,000 to $25,000, or 6% to 8%.

At about 120 checkout starts a day, detecting a 3-point lift (95% confidence, 80% power) would need about 8,100 checkout starts in total, or roughly 10 weeks. A 5-point lift would need about 2,900, or about 3.5 weeks. A modest improvement is slow to confirm at this volume, so I would test a bolder change first. Because baseline checkout rates differ by channel, I would also check results by channel.

## Limitations

- This is a sample dataset covering 92 days, and the findings describe the raw BigQuery export. GA4's own reports may handle repeated IDs differently.
- "Counted once" uses the highest revenue value for each ID, which is only valid when repeats carry the same amount. That holds for the clean repeats by definition.
- Funnel and order counts use slightly different definitions (sessions with revenue-bearing purchases versus distinct valid IDs), described above.
- Channel results are first-touch, about a fifth of users can't be classified, and there is no cost data.
- Significance tests are two-proportion tests. I only corrected for multiple comparisons where noted.

## A note on the queries

The second query includes a few columns (`unique_device_types`, `unique_browsers` and `time_lapse`) that aren't used in the final output. I added them while investigating the repeats. The device and browser columns showed at most two of each per ID and no clear pattern, so they didn't change the finding.

## Next

- Build a one-page Looker Studio dashboard
- Write a short executive summary
