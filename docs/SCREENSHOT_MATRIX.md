# PandaPlate — ASC screenshot matrix

**Owner:** Plate Ship  
**Updated:** 2026-10-31 Asia/Hong_Kong  
**Source assets:** `outputs/AppStoreScreenshots/`

## Required device sizes (confirm current ASC for this year)

| Slot | Target | On disk | Gap |
|------|--------|---------|-----|
| iPhone 6.7" | e.g. 1290×2796 or ASC current | **none** | CAPTURE |
| iPhone 6.5" | e.g. 1284×2778 or ASC current | **none** | CAPTURE |
| Current set | 1206×2622 (≈6.1″ Pro @3x) | Launch, Home/Pip, Workout, Fasting | usable as drafts only — **not** checklist 6.7/6.5 |

## Shot list (per required size)

| # | Shot | Status | Notes |
|---|------|--------|-------|
| 1 | Welcome / Get started | MISSING | Crop clean; avoid battery clutter |
| 2 | Home / Pip Little World | DRAFT 1206×2622 | `2026-10-25/01-Home-Pips-Little-World.png` — re-capture at required sizes |
| 3 | Food Scan (consent / camera flow) | MISSING | Checklist §7; do not imply live production AI if proxy still localhost |
| 4 | Progress / nutrition day | MISSING | |
| 5 | Workout / Activity | DRAFT 1206×2622 | `02-Workout-Activity-Log.png` |
| 6 | Fasting | DRAFT 1206×2622 | `03-Fasting-Log.png` |
| 7 | Launch / splash | DRAFT 1206×2622 | `01-PandaPlate-Launch.png` |

## Capture plan (Mac-local)

1. After Code Release sim/device build is green with honest Release config.
2. Use required simulators (6.7″ / 6.5″ class) — not only 6.1″.
3. Prefer real UI; no invented calories/medical claims on screen.
4. Drop finals under `outputs/AppStoreScreenshots/ASC/<size>/`.

**Blocked on:** Code Release readiness + (for Food Scan shot) decision whether production scan is live or still “unavailable.”
