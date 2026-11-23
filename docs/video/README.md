# The ad

A 47.5-second, 1280×720 ad for the cosmos: 19 bars at 96 BPM, one scene per bar, cut to a
lo-fi soundtrack synthesized in code. Run `./build.sh` to build
`lofi-eldritch-cosmos-ad.mp4` from scratch (about three minutes).

Needs: the project's toolchain (`mix deps.get` done), Node with Playwright and Chromium,
Python 3 with numpy, ffmpeg, curl.

| File | What it does |
| --- | --- |
| `ad.html` | The ad itself: a page where `window.render(t)` draws the frame at `t` seconds. Scenes, copy and timing live here. Assets load from `b/`. |
| `capture.js` | Steps through the page frame by frame (`node capture.js <dir> frames ad.html adframes`), or saves one still per bar (`node capture.js <dir> stills ad.html`). |
| `music.py` | Synthesizes the soundtrack (`python3 music.py music.wav`): kick, clap, hats, bass, arpeggios and a ducked pad over D–B♭–F–C, a breakdown in bar 11, the drop in bars 12–13, vinyl hiss. |
| `portraits.exs` | Draws the portraits with `Lofi.Portrait.Svg`: 16 beings, one being in five moods, and a name as it is typed. |
| `map.js` | Screenshots the replay page in `docs/` for the "strange beings roam" scene. |
| `app.js` | Registers the keeper in a running dev server, previews and summons `Gor Lop~Tome`, and screenshots the summon form and the Beings list. |
| `guide/` | Screenshots from the user guide (quiz, answering, adding cards, journal); they show no portraits. |
| `build.sh` | Runs all of the above in order. |

Everything generated (`b/`, frames, stills, `music.wav`, the video) is ignored by git.
When the portraits change, rerun `./build.sh`. When the app's layout changes, the
windows' `pan(...)` coordinates in `ad.html` may need adjusting: check the stills with
`node capture.js "$PWD" stills ad.html`.
