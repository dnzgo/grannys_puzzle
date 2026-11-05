# Monetization

How the game earns, and the plan for earning more. Ads run through AdMob
(`Ads/AdsSetup.swift`, AdKit): rewarded, interstitial and banner.

## Ad mediation (planned for a 1.0.x update, not 1.0)

Mediation lets other ad networks bid against Google for each ad slot, so
prices and fill go up. AdMob stays the mediator.

**Who pays:** every network pays separately. Google pays only for ads
Google's buyers won; AppLovin, Unity and the rest each pay from their own
account, with their own payout minimum and statement. Each is income
from a foreign company: ask the Steuerberater how to book it before the
first payout.

**Needs an app update:** each network's SDK and Google's adapter for it
must be in the app. Once they are, switching networks on or off and their
settings happen in the AdMob console, with no further update.

**Why not in 1.0:** without AdMob-only numbers first there's nothing to
measure the gain against; at launch volume the gain is small in euros;
every network SDK adds size, crash risk and data partners to the first
build. Exception: if launch numbers show poor fill in Turkey (Google's
fill there is often weak), it moves up.

Steps:

1. [ ] Now: open accounts with 2–3 bidding networks (AppLovin, Unity Ads,
       Liftoff or Mintegral); approval takes days. Tax forms (W-8BEN for
       US companies) and bank details in each.
2. [ ] At launch: link the app to its App Store listing in AdMob; a
       baseline per format and country: eCPM, fill rate, ad revenue per
       daily user. Run it 2–4 weeks.
3. [ ] Each network on the consent message's ad partner list (UMP, GDPR),
       its lines in `app-ads.txt` on dengolabs.com, its SKAdNetwork IDs
       in `Config/grannys_puzzle-Info.plist`.
4. [ ] The adapters as Swift packages, bidding only (no waterfall: no
       price tiers to maintain). Check each brings a privacy manifest.
       Update the App Privacy answers and the privacy policy's partner
       list.
5. [ ] AdMob's mediation A/B test (AdMob-only against mediated) to prove
       the gain before rolling out to everyone.

## Other revenue levers

- [ ] Interstitial frequency through Remote Config, tested with Firebase
      A/B Testing against retention, not only revenue.
- [ ] More rewarded placements (players choose them; the best-paid
      format). A daily archive and streak repair (Backlog, v2) are both.
- [x] The shop (see below).
- [ ] Later, maybe: a "treat jar" with random helpers. Only with a
      guaranteed minimum worth its price, the odds shown on the tile
      before buying (Apple requires it), and Belgium left out of the App
      Store availability (paid random rewards count as gambling there).
      Not before the fixed packs show that helpers sell at all.

## The shop (built for 1.0)

Opened from the stall at the top left of grandma's room, between the
helpers card and the trophy.

| Item | Product ID (`com.dengolabs.grannyspuzzle.` …) | Type | Gives | Price |
| --- | --- | --- | --- | --- |
| Welcome bundle | `welcomebundle` | Non-consumable | Removes ads + 30 cat hints + 5 grandma helpers | €6.99 |
| Remove ads | `removeads` | Non-consumable | Removes ads | €4.99 |
| Small cat pack | `cathints.small` | Consumable | 15 cat hints | €0.99 |
| Big cat pack | `cathints.big` | Consumable | 50 cat hints | €2.99 |
| Small grandma pack | `grandmas.small` | Consumable | 5 grandma helpers | €1.99 |
| Big grandma pack | `grandmas.big` | Consumable | 15 grandma helpers | €4.99 |

- **Prices** are set in App Store Connect and can change any time, without
  an update or review (scheduled sales too).
- **Amounts** come from Remote Config (`shop_*` keys, docs/RemoteConfig.md),
  so they can change without an update too.
- **Product IDs are permanent**: never changed, never reused, even after
  deleting a product. They name the product, never an amount, and so do
  the App Store names ("Small Cat Hint Pack").
- **Why these prices:** free players get about 10 cat hints a day if they
  watch every video, and one grandma helper is worth about three cat
  hints, so packs have to save real time. The big packs are a little
  cheaper per helper (6.0 cents a cat hint against 6.6). The bundle costs
  €2 more than "Remove ads" and gives helpers worth more than that at pack
  prices: the obvious deal for anyone about to remove ads.
- **Family Sharing** is on for the bundle and "Remove ads" (it can't be
  turned off again once on in App Store Connect). Packs can't be shared.

### How it works

Files: `Store/ShopItem.swift` (the list), `Services/Purchases.swift`
(StoreKit), `Store/StoreCard.swift` (the card), `ShopPacks` in
ArrowwordCore (the amounts), `PlayerProgress.grantPurchase`.

- Every item is a `ShopItem` in `ShopItem.all`: product ID, kind,
  placement, picture (`shop-<name>`, same illustrated style), and for a
  featured item its name and ribbon. What it gives is read from tuning.
- Placement: `featured` items are large panels on top (picture, name, what
  it gives, Buy with Apple's price); `tile` items fill a grid under them,
  two to a row, a lone tile taking the whole width (picture, what it
  gives, the price as the button). An owned one-time item shows "Bought".
- Listing: once ads are removed (by either item), the other ad-removing
  item is hidden rather than offered again (`Purchases.isListed`): Apple
  can't refund the overlap. The stall stays, since packs are always for
  sale.
- **Delivery is idempotent.** The App Store can hand a purchase over more
  than once (after a crash before it was finished, at every restore), so
  each one has a key and `PlayerProgress.grantPurchase` adds a key's
  helpers only once. The keys are saved with the helpers.
  - A pack: key `pack-<transaction id>`. Helpers are saved first, the
    transaction finished after; if the app dies in between, Apple offers
    it again at the next launch and the key stops it counting twice.
  - The bundle: key `bundle-<original transaction id>`, the same at every
    restore. On a new phone or after a reinstall progress starts empty, so
    its helpers come again, which is fair (so did everything else). A
    refund doesn't take given helpers back.
- "Remove ads": ownership comes from Apple (`Transaction.currentEntitlements`),
  cached in UserDefaults only so a buyer never sees an ad flash in at
  launch. A refund revokes it and the ads come back. Owned: no banner slot
  in levels (`LevelScreen`), no ad breaks and none loaded
  (`Game.showsAdBreaks`). AdKit knows nothing of it.
- "Restore purchases" is on the shop card (App Review requires one).
- A new item: its `ShopItem`, its product in App Store Connect and in
  `Store.storekit`, its picture, its amounts in `ShopPacks` and Remote
  Config if it gives helpers, its Turkish texts, and this page.

Testing without App Store Connect: `Store/Store.storekit`, selected in the
shared scheme (Edit Scheme → Run → Options → StoreKit Configuration). Runs
started from Xcode then use Xcode's own App Store; Debug → StoreKit →
Manage Transactions refunds or deletes a purchase to test again.

Before release:

- [x] Paid Apps agreement accepted (with the account's wrong name, see
      below; the agreement follows the account, so no re-signing needed)
- [x] Plan B while the tax form waits: 1.0 ships with the shop switched
      off (`shop_enabled` = 0, the default; docs/RemoteConfig.md) and
      without its in-app purchases. Once the agreement is active: submit
      the six products with an update, and after they're approved set
      `shop_enabled` to 1 in the console (no build needed for that step)
- [ ] Tax form (W-8BEN) and bank details. Blocked: Apple's account data
      has the legal name as "Deniz Gözc" (the "ü" cut off) and the
      citizenship as Germany, both locked in every pre-filled form.
      Support asked to correct them to "Deniz Gözcü" (Gozcu in ASCII, as
      in the passport's machine-readable line) and Türkiye. Sign the
      W-8BEN only after the fix (residence Germany, treaty Germany); then
      check the bank account holder name matches the bank
- [ ] Small Business Program (15% commission instead of 30%): applied
      4 November 2026, waiting for Apple. Associated account listed:
      Deniz's own membership, team `737WW78VY2` (no apps, no proceeds)
- [ ] The six products in App Store Connect with the same IDs, types and
      prices, English and Turkish names and descriptions (as in
      `Store.storekit`), Family Sharing on the two non-consumables, a
      review screenshot of the shop card each; submitted with version 1.0
- [ ] Test real purchases on TestFlight (sandbox account): a pack, the
      bundle, a restore on a second phone
