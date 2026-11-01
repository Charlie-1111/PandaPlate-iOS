# PandaPlate onboarding — Nest owner brief
Updated: 2026-10-25 ~18:09 HKT
Owner: Nest · Implements: Lead · Verifies: Nest · Leads: Patrick

## Locked (Charlie via Patrick)
- **Age floor 13+** (picker `Array(13...100)`). Never regress to 10. Under-18 BMI/projection honesty still applies for ages 13–17. ASC age rating 13+ = Charlie store step.
- BitePal parity override (2026-10-25): attribution · sex/gender · goal pace · weight-date projection · pet hearts · account · mid-flow rate/paywall. Nest owns order/copy after LAND.
- Welcome first screen: BitePal floating-bubbles + condensed “Reach your weight goals” (Get started / I already have an account).
- Group-only: all Nest PandaPlate status/verify stays in the PandaPlate room — no 1:1 status spam.
- Mid-onboarding Open video = Charlie’s short BitePal/Pip intro clip (~5s: mint bg, coral Pip wave + floating hearts). **Not** the full questionnaire.
- Open → that full-screen video only; **no box-pop**. Question order = this brief + design board §01–02.
- Patrick coding reveal on Mac (Cursor credits empty); Nest verifies in-group when it lands.
- Follow **BitePal new-user video** (Patrick watching; beat notes TBD).
- **Open → full-screen intro video only. No box-pop.** Retire `PandaPlateMidflowRevealArtwork` from reveal path.
- Align question order + visuals to `design/DESIGN_BOARD.png` **§01 Make it yours** and **§02 Find your rhythm**.
- Honesty (Clear): plan/kcal on board = illustrative / not medical; scanner unavailable until secure proxy; session-only OK.

## Target order (board §01–02) — Nest verify checklist
### §01 Make it yours
1. Splash — “Small bites. Big little wins.” + companion line; CTA Let’s get started
2. Main focus — Feel more balanced / Maintain my weight / Change my weight (single)
3. Extra support — e.g. More energy / Mindful eating (multi)
4. Open teaser — **Pip hidden** until Open
5. Full-screen intro **video only** (no box-pop); Reduce Motion → static poster
6. Pip persona — Cheerleader / Gentle friend / Straight talker / Mindful guide
7. Optional names (Pip / user) if video keeps them — confirm vs watch notes

### §02 Find your rhythm
8. Meals per day — 2 / 3 / 4 (board); extend only if video requires
9. Eating location — Cook at home / Order in / Eat out (**multi-select**)
10. Optional toggles — Meal check-ins / Water breaks (board)
11. Starting point — Age (from 13), Height, Current weight; Activity; labels `Your age` / `Height` / `Current weight` (Target weight only if video/board keeps it)
12. Plan preview — illustrative only; Clear copy gate (“Nutrition guidance, not medical advice”) — no BMI/deficit theater

Measurements: BitePal **wheel** pickers (system `Picker` `.wheel`) — Charlie/BitePal parity supersedes earlier scroll-and-snap lock. Session-only draft. Age **13+** only.

## Current code gaps (verify after Lead)
| Item | Today | Target |
|------|-------|--------|
| Reveal | box-pop artwork | full-screen video only |
| Tone/persona | after names + reminders | in §01 with board personas |
| Extra mid-flow (logging familiarity, fasting*, meal window, diet/restrictions, water adequacy, habits, weekend, cravings) | present | **defer** unless BitePal video keeps them |
| Meals choices | 1–5-ish | board 2/3/4 until video says otherwise |
| Nav post-Home | Lead/Pip | board: Home / Pip / + / Progress / Profile |

\*Fasting curiosity may stay if video has it; no fasting plan/advice (prior honesty).

## Verify when Lead lands
- [ ] Open → video fullscreen; no box assets/animation on reveal
- [ ] Pip not visible before Open
- [ ] §01–02 order matches table above (or video delta doc)
- [ ] Snap pickers + labels + age≥13 + eating multi-select
- [ ] Skip/Continue/Back still work; session-only draft
- [ ] UITests reach Home after measurements

## Pointers
Flow: `Sources/PandaPlateCategorizedOnboardingFlow.swift`
Video: `Resources/red_panda_welcome_animation.mp4`
Board: `design/DESIGN_BOARD.png`
