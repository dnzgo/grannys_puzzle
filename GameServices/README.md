# GameServices

Analytics, remotely tuned numbers and crash reports for our iOS games,
written once and reused. Same two layers as AdKit:

- **GameServices**: `AnalyticsEvent` (checked against Google Analytics'
  naming rules), `EventLogger`, and `RemoteValueSource`. No SDK inside, so
  `swift test` runs it on a Mac.
- **GameServicesFirebase**: Firebase Analytics, Remote Config and
  Crashlytics behind those types.

## Setting up an app

### In the Firebase console

1. Create a project (Google Analytics on), add an iOS app with the app's
   bundle ID, and download `GoogleService-Info.plist`.
2. Remote Config: add a parameter per tunable number, using the game's key
   names. Only set the ones you want to change; the app has defaults.

### In the AdMob console (if the app uses AdKit)

3. Settings → Linked services: link the Firebase project.
4. Privacy & messaging: turn on Google consent mode. Google's consent tool
   then passes each EU player's choice to Analytics.

### In Xcode (app target)

5. File → Add Package Dependencies → Add Local… → this folder. Link
   `GameServices` and `GameServicesFirebase` to the app target. Firebase
   comes along as a dependency.
6. Drag `GoogleService-Info.plist` into the app folder, with the app target
   ticked. It identifies the Firebase project; it isn't a password, but
   keep it out of public repositories.
7. Build Settings → Other Linker Flags: add `-ObjC`. Firebase needs it when
   Analytics arrives through another package, as it does here.
8. Build Settings → Debug Information Format: `DWARF with dSYM File` for
   Debug and Release, so Crashlytics can turn crash addresses into code
   lines.
9. Build Phases → + → New Run Script Phase, dragged to the very end:

   ```
   "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
   ```

   Input Files:

   ```
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist
   $(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist
   $(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}.debug.dylib
   ```

   (The last line is for script sandboxing with debug dylibs, both on by
   default in new projects.)

### In code

```swift
// First thing at launch, before AdKit's start():
guard FirebaseServices.start(collectsAnalytics: true) else { /* run without */ }
let events = EventLogger(backend: FirebaseAnalyticsBackend())
let remote = FirebaseRemoteValues()

events.log(AnalyticsEvent("level_end", ["level": .int(12), "success": .bool(true)]))

await remote.activateFetched()        // last launch's values
let passThreshold = remote.number(forKey: "pass_threshold") ?? 0.8
await remote.fetchForNextLaunch()     // next launch's values
```

Without `GoogleService-Info.plist`, `start` returns false and the app runs
without these services, so a fresh checkout still builds and plays.

## Seeing the data

- Events appear in Analytics reports after about a day. Custom parameters
  (`score_percent`, `mistakes`…) only show in reports after registering
  them under Admin → Custom definitions.
- For live testing: turn analytics collection on in the debug build, run
  with the launch argument `-FIRDebugEnabled`, and open DebugView.
