# Signing

The app is signed by Dengo Labs' Apple Developer membership (team
`GF38VK467T`, bundle ID `com.dengolabs.grannyspuzzle`). It is an
Individual membership, so Deniz, the account holder, makes the TestFlight
and App Store builds and sets up App Store Connect.

## Where the settings live

The app target's team, bundle ID and entitlements come from
`Config/Signing.xcconfig` (its base configuration), not from
`project.pbxproj`. Keeping them in one file means nothing at target level
can silently override them.

The entitlements file (`grannys_puzzle/grannys_puzzle.entitlements`)
turns on Game Center. If it is missing or emptied, the build still signs
and uploads, but Game Center (achievements, leaderboards) silently stops
working. A quick check after archiving: the archive's provisioning profile
must be the app's own, not "iOS Team Provisioning Profile: *". A wildcard
profile means the app has no entitlements.

### Another developer signing with their own team

Create **`Config/Local.xcconfig`** (git ignores it; `Signing.xcconfig`
includes it last, so it wins) and override what you need:

```
DEVELOPMENT_TEAM = <your team ID>
PRODUCT_BUNDLE_IDENTIFIER = com.<you>.grannyspuzzle
// Leave Game Center out: it needs the team's app ID.
CODE_SIGN_ENTITLEMENTS =
```

Never keep this file on the Mac that makes release builds: it would take
Game Center out of the build.

**Don't pick a team in Xcode's Signing & Capabilities.** That writes the
team back into `project.pbxproj`, where it overrides `Signing.xcconfig`.
If it happens, remove the `DEVELOPMENT_TEAM` and
`PRODUCT_BUNDLE_IDENTIFIER` lines from the app target in
`project.pbxproj`. Adding a capability in Xcode is still done there (it
updates the entitlements file); check the same lines afterwards.

## Uploading

Archive with the Release configuration (Product → Archive), then
Organizer → Distribute App → App Store Connect. The archive is signed with
the Apple Development certificate; Xcode re-signs it with the Apple
Distribution certificate during the upload, so that certificate (with its
private key) must be in the keychain.

"Upload Symbols Failed" warnings for Google's frameworks (FirebaseAnalytics,
GoogleMobileAds, UserMessagingPlatform, …) are expected: Google ships them
without dSYMs. They don't block the upload, and Crashlytics only needs the
app's own dSYM.

`Store/Store.storekit` is for the simulator and Xcode testing only; it is
excluded from the app target (a membership exception in `project.pbxproj`)
so it doesn't ship.
