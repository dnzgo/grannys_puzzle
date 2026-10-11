# AdKit

Ads for our iOS games: consent, the tracking question, rewarded ads and
banners, written once and reused.

- **AdKit**: the rules (start order, preloading, retries, expiry) behind a
  small `AdNetwork` protocol. No ad SDK inside, so `swift test` runs it on
  a Mac.
- **AdKitGoogle**: AdMob + Google's consent tool (UMP) as an `AdNetwork`.

## Using it in an app

1. Add the package (Xcode: File → Add Package Dependencies → Add Local, or
   its git URL once it has its own repo) and link both libraries.
2. Info.plist needs:
   - `GADApplicationIdentifier`: the AdMob app ID (Google's test ID while
     developing: `ca-app-pub-3940256099942544~1458002511`).
   - `NSUserTrackingUsageDescription`: the text of iOS's tracking prompt.
   - `SKAdNetworkItems`: Google's list from the AdMob iOS quick start.
3. Create one controller at launch and put it in the environment:

   ```swift
   let ads = AdsController(network: GoogleAdNetwork(configuration: .googleTestUnits))
   ContentView().environment(ads)
   ```

4. Call `await ads.start()` when a form may appear (e.g. the main screen's
   `.task`). It gathers consent, asks the tracking question, starts the SDK
   and preloads a rewarded ad. Repeat calls do nothing.
5. Rewarded: show the offer only when `ads.isRewardedReady`, then
   `if await ads.showRewarded() { grant the reward }`.
6. Banner: `ads.bannerView(size: .standard)` (nil until ads may show).
   Reserve its size either way so the layout doesn't jump.
7. Settings: when `ads.isPrivacyOptionsRequired`, show a "Privacy choices"
   row that calls `await ads.presentPrivacyOptions()`.

## Before release

- Real ad unit IDs in the app's `GoogleAdsConfiguration`, real app ID in
  Info.plist. Never tap your own real ads.
- Set up the consent message (and optionally the IDFA explainer) in the
  AdMob console under Privacy & messaging; UMP shows what's configured there.
