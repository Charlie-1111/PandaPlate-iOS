# PandaPlate UI/motion screen map · DESIGN_BOARD lock
Owner: Pip · Implements: Lead (Cursor) · Product: Patrick  
Source: `docs/DESIGN_BOARD.png` (same art as References board) · Updated: 2026-10-24 HKT  

BitePal / Charlie mid-intro clip (~5s, mint bg, coral Pip wave + floating hearts): **Open → that full-screen video only** (not the questionnaire). Broader BitePal new-user questionnaire beats: still TBD if more watch notes land.

## Nest locked question order (board §01–02, before nav pivot)
splash → main focus → extra support → **Open (Pip hidden)** → **video reveal only** → Pip persona → optional names → meals 2/3/4 → eating multi-select → meal/water toggles → starting point snaps.  
Defer logging-familiarity / fasting / diet / weekend / cravings unless a later video keeps them. Checklist: `docs/onboarding-owner-brief.md`.

## Visual system (ship everywhere)
- Palette: `PPColor` cream / card / coral / coralInk / ink / muted / line / mint / peach / lavender — keep; no BitePal brand colors.
- Type: Avenir Next via `DesignSystem` helpers; bold rounded titles, generous leading.
- Cards: 18–22pt continuous corner radius, cream card fill, soft line stroke; full-width choice rows; no mid-word wraps (`lineLimit` + truncate or grow height).
- Pip: original PandaPlate assets only; full-body where hero; Reduce Motion → static; VoiceOver labels on every interactive + Pip art.
- Section rhythm on board: **Make it yours → Find your rhythm → Snap·Check·Log → Little wins** — use as onboarding category / Home content order cues, not as extra root tabs.

## Root navigation (Charlie override — match board)
| Slot | Board | Shipped today | Target |
|---|---|---|---|
| 1 | Home (house) | Home (`TodayDashboard`) | **Home** — daily rings / water / meals dashboard (board §03 left + §04 cues). Forest **not** full-bleed under all cards. |
| 2 | Pip (paw) | Challenges (empty) | **Pip** — Pip’s Little World forest hero only here (full-body Pip; forest **only** in this tab’s hero — no second forest under cards). Missions list OK; **leaves/hearts meter only if Clear greenlights opt-in + explainable** — otherwise omit or disabled empty. |
| 3 | + (coral) | Floating + → Quick Log | Keep **center +** → Quick Log sheet (Food / Water / Movement / Weight unavailable / Eating window per Harvest+Clear honesty). |
| 4 | Progress (chart) | Stats | **Progress** — rename; weekly consistency + illustrative trends; History session-only. |
| 5 | Profile / You (person) | Home gear → Profile sheet | **Profile** tab (Patrick lock; Lead label “You” OK) — settings / clear session; not buried only on Home. |

Implement: replace `RootTab` `home/challenges/stats` with `home/pip/progress/profile` + center +. Drop Challenges tab until real challenges exist (Clear: empty theater bad — better absent than fake).

## Board §01 Make it yours · Onboarding (Nest owns questions; Pip owns motion)
| Board beat | Motion / UI note |
|---|---|
| Welcome — Pip + “Let’s get started” | Keep welcome motion (`PandaPlateWelcomeMotion`); Reduce Motion static. |
| Focus / goals cards | Full-width choice rows; selected = coral stroke + peach icon chip. |
| Encouragement style (4 personas) | Same selection language; Pip tone art already in assets. |

**Midflow Pip (Nest lock — overrides storyboard box-pop)**  
1. **Teaser (pre-Open):** Pip **hidden**. No `PandaPlateHomeCheer`, no autoplay video. Backdrop = non-Pip (mint / forest abstract / `PP_RevealBackground` alone). Copy can tease (“Someone’s here…”) without showing Pip.  
2. **Open:** unlocks **full-screen muted one-shot intro video only**.  
3. **No box-pop** — retire `PandaPlateMidflowRevealArtwork` / `PipRevealAnimationView` as the reveal path.  
4. Reduce Motion: static **non-Pip** until Open; after Open → static Pip poster (not cheer-as-teaser leak).  
5. Skip continues without forcing Pip art on the gate.

## Board §02 Find your rhythm
Routine / starting point / plan summary — Nest+Clear. UI: snap pickers, illustrative plan labeled “not medical advice”; no BMI/deficit theater. Pip: spacing + card hierarchy only.

## Board §03 Snap · Check · Log
| Board | Honesty + UI |
|---|---|
| Dashboard rings | Illustrative or session totals — Clear labels. |
| Snap camera | **Unavailable** until secure proxy (Clear). Show honest empty / disabled, never fake AI result. |
| Result “Looks delicious” | Do not ship fake estimate UI. |

Quick Log sheet: match board icon grid rhythm (Food / Water / Movement / …); Weight unavailable visible.

## Board §04 Little wins
| Board screen | Map to |
|---|---|
| Quick check-in sheet | Existing Quick Log — align icons/spacing to board. |
| Pip’s Little World | **Pip tab** hero (see nav). |
| Progress trends | **Progress tab** — sample charts labeled illustrative; session History real. |

## Motion checklist (Pip sign-off)
- [ ] Teaser: zero Pip pixels / video before Open  
- [ ] Post-Open: video-only reveal; box-pop removed from path  
- [ ] Reduce Motion + pause off-screen/background on any looping/finite Pip motion  
- [ ] Nav: Home / Pip / + / Progress / Profile  
- [ ] Forest only on Pip tab hero  
- [ ] Full-width choices; no mid-word wraps; 44pt targets  
- [ ] BitePal video beat timings — **pending watch notes**

## Out of scope for this map
Scanner enablement, proxy, notifications opt-in copy (Harvest/Clear), XCTest eng red (Lead), Figma (none in tree).
