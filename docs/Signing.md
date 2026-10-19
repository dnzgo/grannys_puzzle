# Signing

The team's Apple Developer membership is an Individual one, so only its
account holder (Barış) can sign with the team. That decides who does what:

| Who | Does |
| --- | --- |
| Barış (account holder) | Capabilities (Game Center, …), TestFlight and App Store builds, App Store Connect setup |
| Everyone else | Code, simulator, own phone with their own team, real Game Center through TestFlight |

## Where the settings live

The app target's team, bundle ID and entitlements come from
`Config/Signing.xcconfig` (its base configuration), not from
`project.pbxproj`. That file holds the team's real values.

To sign with your own team, create **`Config/Local.xcconfig`** (git ignores
it) and override what you need:

```
DEVELOPMENT_TEAM = <your team ID>
PRODUCT_BUNDLE_IDENTIFIER = com.<you>.grannyspuzzle
// Leave Game Center out: it needs the team's app ID.
CODE_SIGN_ENTITLEMENTS =
```

Your team ID is in Xcode → Settings → Accounts, or developer.apple.com →
Membership. A different bundle ID is needed because the real one belongs
to the team's account.

**Don't pick a team in Xcode's Signing & Capabilities.** That writes the
team back into `project.pbxproj`, which brings back the conflicts this
setup removes. If it happens, discard the `project.pbxproj` change.

Adding a capability in Xcode is still done there (it creates the
entitlements file); afterwards check that `project.pbxproj` got no
`DEVELOPMENT_TEAM` or `PRODUCT_BUNDLE_IDENTIFIER` lines back.
