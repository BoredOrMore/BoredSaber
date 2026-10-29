# Get songs list: why it stuttered and the new grid (plan and record)

Owner, 2026-10-28: dragging the Get songs list, loading more pages and changing a filter froze the view. After a
string of patches the owner asked for a different approach (option A, "A+"). This records what was measured on the
Pico 4 and what the list is now.

## 1. What the headset showed

All builds measured with the owner dragging the list on the headset; numbers from logcat (PxrMetric and the panel's
own slow-frame log).

| Build | What changed | Result |
|---|---|---|
| 8a0523b | covers decoded on worker threads, downloads unzipped off the main thread | a second at 20 of 72 frames while a page loaded |
| 1c474b4 | one placeholder card per level strip instead of one per song | page loads 25-62 ms; seconds at 19-38 of 72 after them |
| 9734010 | covers put on the list together every 0.25 s | seconds at 8-46 of 72, worse as the list grew |
| 58a722a / 67be33f / f2dfa02 | slow-frame log: this page's work, texture memory, render times, `_process` vs the rest | the page's own work was never in the slow frames; texture memory 169-192 MB (covers about 20 MB); render CPU under 1 ms; the app's frame work 7-13 ms while the headset logged 42-110 ms frames |
| 1073fc0 | font cache logged per page | 12 sheets, 328-340 glyphs: not the font |
| f9cfdf1 | stage quiet behind the page, page redrawn at most 36 times a second | dragging held 72/72 (GPU 8-10 ms, from 10-14); changing the filter froze a second (115 ms frame, then 0 of 72) as about 30 MB of covers were freed together |

So the GPU had too little headroom on this page (the stage behind it and a full-page redraw every frame), and the
ItemList kept one GPU texture per song: hundreds made and freed at once stalled the headset's driver.

## 2. The new list (`game/ui/BeatSaverPanel/CoverGrid.gd`)

- A fixed set of cards: the rows in view plus one spare row above and below (24 on the page), reused as the list
  scrolls. Song `i` always sits on card `i % 24`, so scrolling a row changes only that row's cards.
- Each card owns one 200 px `ImageTexture`, written over with `ImageTexture.update` when it shows another song. The
  songs' covers are kept as images in CPU memory. So scrolling, a new page or a filter change never makes or frees
  a GPU texture; clearing the list on the Mac takes 2.7 ms at 400 songs.
- It keeps the ItemList calls the page used (`add_item`, `set_item_image`, `set_item_text`, `get_item_icon`,
  `clear`, `item_count`, `item_selected`, the scroll bar), so the page's flow is unchanged.
- Kept from the patches: covers decoded on low-priority worker threads and put on together every 0.25 s; downloads
  saved, unzipped and read off the main thread; the quiet stage and the 36-a-second redraw cap.

## 3. Not done yet

- Covers' images stay in CPU memory for the whole list (about 160 KB each; 1,000 songs would be about 160 MB). If
  lists that long matter, drop the images of songs far from view and fetch them again when they come back.
- The song menu (songs on the headset, `SongList`) still makes a row per song; the same approach applies if large
  libraries stutter.
- Pass mark on the headset: dragging past 300 songs and changing a filter with no frame over 25 ms.

## 4. Layout A (owner, 2026-10-29)

The owner picked layout A of the redesign proposal (https://claude.ai/artifact/YS54ZdgvkYuxnp4dcpwQkS), lighter both
for the GPU and to look at: the page is laid out like the song menu (details left, list in the centre, the right
empty), and the grid became `BeatSaverList`, the song list's rows with the level strip at their end.

| | Grid (before) | Layout A |
|---|---|---|
| Canvas | 1536x1046 px at scale 2 (86° x 54°) | 1249x745 px at scale 2.4 (84° x 47°, two panels) |
| Pixels redrawn per update | 1.61 M | 0.93 M (-42%) |
| Covers on the GPU | 24 x 200 px = 3.84 MB | 11 x 72 px = 0.23 MB, a strip texture per kind of strip, one 152 px details cover |
| Cover per song in CPU memory | 160 KB | 20 KB |
| Smallest text | 22 px at scale 2 = 1.23° | 22 px at scale 2.4 = 1.43-1.48° (the song menu's) |

Numbers worked out from the layout, not measured on the headset; the GPU time still needs a bench there.

