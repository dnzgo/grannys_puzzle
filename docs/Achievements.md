# Game Center achievements

Every achievement the game reports to Game Center. **Keep this file in step
with the code:** whenever an achievement is added, removed, or its target or
meaning changes, update it in the same commit.

Each one must also exist in App Store Connect (Apps → Granny's Puzzle →
Game Center → Achievements) with exactly the **ID** below. IDs and, once an
achievement is live, its points can never change, so a different rule means
a new ID.

## How progress is counted

- Progress comes from the saved player progress, not from single events:
  the game works out how far along every achievement is
  (`Achievements.progress` in ArrowwordCore) after every saved change and
  at sign-in, and sends Game Center whatever moved forward
  (`GameCenter.swift`).
  Game Center keeps the highest value, so reporting again is harmless and
  progress made while offline or signed out catches up later.
- **A solved word**: at Submit, every letter of the word is right and the
  player typed at least one of them. So a word grandma (or the cat) filled
  in alone doesn't count, one the cat helped with does, and one made only of
  starter letters doesn't. Counted on passed levels (a failed board is
  played again, so its words would count twice) and on every daily.
  (`LevelResult.solvedWords`.)
- **Levels** are counted per language and added up (the tutorial isn't a
  level). **No help** means no cat and no grandma on that level.
- **Streak** is the longest play streak ever reached (the flame on the home
  screen), so losing a streak later never takes an achievement away.
- **Dailies** are daily challenges submitted, on any days.
- The totals that can't be read off the rest of the progress are kept in
  `PlayerProgress.stats` (`PlayStats`). A test checks this table's IDs
  against `Achievements.all`, in order.
- Players sign in after the lesson (Apple shows its own screen, once).
  Settings → Achievements opens Apple's achievements screen, and only shows
  while signed in.

## The list

Points: 950 of the 1,000 Apple allows (50 left for later). None hidden,
none earnable more than once. Image: one per group, used for every tier in
it (see the image prompts in the chat / art folder).

| ID | Target | Points | English title | English (before / after) | Turkish title | Turkish (before / after) |
| --- | --- | --- | --- | --- | --- | --- |
| `grannyspuzzle.words.10` | 10 words | 5 | First Words | Solve 10 words. / You solved 10 words! | İlk Kelimeler | 10 kelime çöz. / 10 kelime çözdün! |
| `grannyspuzzle.words.100` | 100 words | 10 | Word Collector | Solve 100 words. / You solved 100 words! | Kelime Toplayıcı | 100 kelime çöz. / 100 kelime çözdün! |
| `grannyspuzzle.words.500` | 500 words | 25 | Bookworm | Solve 500 words. / You solved 500 words! | Kitap Kurdu | 500 kelime çöz. / 500 kelime çözdün! |
| `grannyspuzzle.words.1000` | 1,000 words | 40 | Word Wizard | Solve 1,000 words. / You solved 1,000 words! | Kelime Sihirbazı | 1.000 kelime çöz. / 1.000 kelime çözdün! |
| `grannyspuzzle.words.5000` | 5,000 words | 80 | Walking Dictionary | Solve 5,000 words. / You solved 5,000 words! | Ayaklı Sözlük | 5.000 kelime çöz. / 5.000 kelime çözdün! |
| `grannyspuzzle.levels.1` | 1 level | 5 | First Puzzle | Pass your first level. / You passed your first level! | İlk Bulmaca | İlk bölümünü geç. / İlk bölümünü geçtin! |
| `grannyspuzzle.levels.10` | 10 levels | 10 | Getting Cozy | Pass 10 levels. / You passed 10 levels! | Isınıyoruz | 10 bölüm geç. / 10 bölüm geçtin! |
| `grannyspuzzle.levels.50` | 50 levels | 25 | Puzzle Pal | Pass 50 levels. / You passed 50 levels! | Bulmaca Dostu | 50 bölüm geç. / 50 bölüm geçtin! |
| `grannyspuzzle.levels.100` | 100 levels | 40 | A Hundred Puzzles | Pass 100 levels. / You passed 100 levels! | Yüz Bulmaca | 100 bölüm geç. / 100 bölüm geçtin! |
| `grannyspuzzle.levels.250` | 250 levels | 60 | Puzzle Master | Pass 250 levels. / You passed 250 levels! | Bulmaca Ustası | 250 bölüm geç. / 250 bölüm geçtin! |
| `grannyspuzzle.levels.500` | 500 levels | 90 | Grandma's Favourite | Pass 500 levels. / You passed 500 levels! | Ninenin Gözdesi | 500 bölüm geç. / 500 bölüm geçtin! |
| `grannyspuzzle.perfect.1` | 1 perfect board | 10 | Not a Letter Wrong | Finish a level with every letter right. / Every letter right! | Tek Harf Hatasız | Bir bölümü tüm harfleri doğru bitir. / Tüm harfler doğru! |
| `grannyspuzzle.perfect.10` | 10 perfect boards | 25 | Sharp Eye | Finish 10 levels with every letter right. / 10 perfect boards! | Keskin Göz | 10 bölümü tüm harfleri doğru bitir. / 10 kusursuz bulmaca! |
| `grannyspuzzle.perfect.50` | 50 perfect boards | 50 | Flawless | Finish 50 levels with every letter right. / 50 perfect boards! | Kusursuz | 50 bölümü tüm harfleri doğru bitir. / 50 kusursuz bulmaca! |
| `grannyspuzzle.nohelp.1` | 1 level, no help | 10 | All by Myself | Pass a level without the cat or grandma. / You did it all by yourself! | Kendi Başıma | Kedi ve nine olmadan bir bölüm geç. / Hepsini kendin yaptın! |
| `grannyspuzzle.nohelp.25` | 25 levels, no help | 40 | Needs No Help | Pass 25 levels without the cat or grandma. / 25 levels, all on your own! | Yardıma Gerek Yok | Kedi ve nine olmadan 25 bölüm geç. / 25 bölüm, hepsi kendi başına! |
| `grannyspuzzle.streak.3` | 3-day streak | 10 | Three in a Row | Play 3 days in a row. / 3 days in a row! | Üç Gün Üst Üste | 3 gün üst üste oyna. / 3 gün üst üste! |
| `grannyspuzzle.streak.7` | 7-day streak | 25 | A Whole Week | Play 7 days in a row. / A whole week in a row! | Koca Bir Hafta | 7 gün üst üste oyna. / Koca bir hafta üst üste! |
| `grannyspuzzle.streak.30` | 30-day streak | 60 | A Month of Puzzles | Play 30 days in a row. / 30 days in a row! | Bulmaca Dolu Bir Ay | 30 gün üst üste oyna. / 30 gün üst üste! |
| `grannyspuzzle.streak.100` | 100-day streak | 100 | A Hundred Days | Play 100 days in a row. / 100 days in a row! | Yüz Gün | 100 gün üst üste oyna. / 100 gün üst üste! |
| `grannyspuzzle.daily.1` | 1 daily | 10 | Daily Visitor | Finish a daily challenge. / Your first daily challenge! | Günlük Ziyaretçi | Bir günlük görevi bitir. / İlk günlük görevin! |
| `grannyspuzzle.daily.7` | 7 dailies | 30 | Regular Guest | Finish 7 daily challenges. / 7 daily challenges done! | Müdavim | 7 günlük görev bitir. / 7 günlük görev tamam! |
| `grannyspuzzle.daily.perfect` | a 100% daily | 40 | Perfect Day | Finish a daily challenge with every letter right. / A perfect daily challenge! | Kusursuz Gün | Bir günlük görevi tüm harfleri doğru bitir. / Kusursuz bir günlük görev! |
| `grannyspuzzle.knit.1` | 1 item knitted | 10 | First Stitch | Knit your first item. / You knitted your first item! | İlk İlmek | İlk parçanı ör. / İlk parçanı ördün! |
| `grannyspuzzle.knit.set` | 1 garment, all colours | 30 | Matching Set | Knit one garment in every colour. / A full set! | Takım Tamam | Bir giysiyi her renkte ör. / Takım tamam! |
| `grannyspuzzle.knit.all` | all 20 items | 80 | Full Wardrobe | Knit everything in the wardrobe. / The wardrobe is full! | Dolap Dolu | Dolaptaki her şeyi ör. / Dolap dopdolu! |
| `grannyspuzzle.languages.2` | levels in 2 languages | 30 | Bilingual | Pass a level in English and in Turkish. / Puzzles in two languages! | İki Dilli | İngilizce ve Türkçe birer bölüm geç. / İki dilde bulmaca! |

## Images (1024 × 1024, RGB, no transparency)

| Group | Image file |
| --- | --- |
| words | `achievement-words.png` |
| levels | `achievement-levels.png` |
| perfect | `achievement-perfect.png` |
| nohelp | `achievement-nohelp.png` |
| streak | `achievement-streak.png` |
| daily | `achievement-daily.png` |
| knit | `achievement-knit.png` |
| languages | `achievement-languages.png` |
