# Level delivery

How levels and daily puzzles reach players. Levels come in packs of 100;
pack 1 ships inside the app, the rest are downloaded as players need them.

## Packs

| Kind | File names | Numbers |
| --- | --- | --- |
| Levels | `en-001`, `en-002`, … | `en-002` is levels 101–200 |
| Daily puzzles | `daily-en-001`, `daily-en-002`, … | `daily-en-002` is dailies 101–200 |

The same name is used in the app bundle, on the server and on the phone,
and it's also the pack's `packId` (a test checks this). Three digits,
padded.

**Packs are append-only.** A player's place is a level *number*, and a
level's number comes from its pack's number and its place inside it
(`LevelLibrary`). So once a pack is published:

- never change how many levels it has, or reorder them;
- never renumber packs;
- fixing a clue or a typo inside a level is safe (a player halfway through
  that level starts it fresh, see `Game.startingPuzzle`), but for now it
  only reaches phones that haven't downloaded the pack yet (see "Not done
  yet").

Every pack except the newest must have exactly 100 levels.

## In the app

- **Pack 1** of each kind is bundled (`grannys_puzzle/Levels`), so the first
  session works offline and App Review sees content without our server.
- **Later packs** are stored in `Application Support/LevelPacks`, excluded
  from iCloud backup (they can be downloaded again). At launch they're
  loaded after pack 1, in order, until one is missing. A stored pack that no
  longer loads is deleted and downloaded again.
- **When to fetch:** when the app opens or comes back to the front, once
  the player has played 90 levels of the newest pack on the phone (90
  levels of puzzles to spare in case the download fails). Also when the
  player runs out of levels.
- **Out of levels** (home screen, in the Play button's place):
  - downloading: "Loading new levels…";
  - no connection, or the download failed: "Connect to the internet to load
    new levels" (tapping it tries again);
  - the server has no next pack: "More puzzles soon!".
- **Checks before a download is used:** it decodes as a `LevelPack` (every
  level valid), its id is the name asked for, its language is right, and it
  fits after the packs already there.
- **Dailies** are numbered from `DailyDay.firstDay` (1 November 2026): that
  day plays daily 1. While a day's pack isn't on the phone, the dailies that
  are go round in order, so there's always a puzzle. The leaderboard must
  not count such a go, since it isn't the day's real puzzle.

Code: `LevelLibrary` (ArrowwordCore), `PackDownloader`, `DownloadedPacks`,
`LevelLoader`, and `Game.fetchUpcomingPacks()`.

## The content server

Static JSON files on Firebase Hosting, at `<base URL>/packs/<name>.json`.
Static files rather than Remote Config, which is made for small settings
(every player downloads all of it), or Firebase Storage, which would add an
SDK and access rules we don't need for public files. Hosting is a CDN and
the app only needs `URLSession`.

The folder `ContentServer/` is the Hosting project: `public/packs` holds the
packs, `firebase.json` the settings (packs may be cached for an hour, so a
fix reaches everyone within that).

### Setting it up (once, on Deniz's Firebase project)

1. Install the Firebase CLI and log in: `npm install -g firebase-tools`,
   then `firebase login`.
2. In `ContentServer/`: `firebase use --add` and pick the project.
3. Deploy: `firebase deploy --only hosting`.
4. Put the site's address (e.g. `https://<project>.web.app`) in
   `PackDownloader.contentBaseURL`. Until it's set the app never downloads,
   and a player out of levels sees "More puzzles soon!".

### Publishing a pack

1. Generate it with the content pipeline, named as above (e.g. `en-002`).
2. Copy it to `ContentServer/public/packs/`.
3. Run the ArrowwordCore tests: they check every pack there loads, is named
   after its file and follows on from the app's pack 1 with no gaps.
4. `firebase deploy --only hosting`.
5. Watch the `pack_download` event in Analytics.

Publish packs well before players need them: a player downloads the next
pack 10 levels before the end of the current one.

## Costs

A pack is about 200 KB (about 20 KB compressed in transit). 100,000
players each downloading 10 packs is about 20 GB of transfer in total. The
pricing of Hosting's free tier and the Blaze plan changes from time to time,
so check the current numbers before launch, and set a budget alert in the
Google Cloud console either way.

## Not done yet

- A manifest listing published packs with versions, so fixed packs are
  downloaded again (today a phone keeps the version it first got).
- Removing old stored packs when a player switches language for good.
