# PandaPlate flow map · three-tab build

Scope: follow the reference journeys’ order and interaction rhythm using PandaPlate’s own colors, Pip artwork, wording and motion. The video and storyboard are design references, not evidence that every feature exists. Do not copy BitePal branding, art, exact copy, price claims or unsupported wellness claims.

## Navigation and current behavior

| Surface | Behavior | Boundary |
|---|---|---|
| Home | Today summaries, full-bleed forest behind the scroll, dominant Pip playground scene, water and meal cards, settings gear | Pip has no food/streak-linked reward meter. The heart/leaf meter remains unimplemented. Sample nutrition values are illustrative. |
| Center plus | Opens Quick Log | Working choices: food photo attachment, manual meal, water, workout, fasting. Weight is visibly unavailable. This is an action, not a fourth tab. |
| Log | Manual meal/photo attachment plus session-only meals, workouts and fasting entries | Food recognition and barcode scanning are unavailable. Photo attachment does not analyze or upload the image. |
| Progress | Illustrative sample charts plus a History section | History lists actual entries from this session only. Sample trends are not user data. |
| Settings | Home gear opens the settings sheet | Clear-session action is available; reminders, accounts, sync and persistent history are not. |

## Onboarding · second supplied flow video

Welcome is the opening screen. Thirteen counted steps follow; the full-screen Pip reveal is step 6/13, after the fasting-familiarity answer and Pip teaser, before the optional names. A reference-only reminder-choice card appears later but does not ask for OS permission or schedule reminders.

1. Main focus — single-select; wellbeing/routine choices, not weight-loss promises.
2. Extra goals — optional multi-select; no selection is fine.
3. Logging familiarity — single-select; stored only for this session.
4. Fasting familiarity — Yes/No preference only; it gives no fasting recommendation.
5. Full-screen Pip teaser — the bundled 5.04-second muted H.264 clip plays once as the whole-screen backdrop; Open and Skip continue to the reveal. Playback pauses off-screen/background and a static Pip pose is shown under Reduce Motion. The full clip needed no trimming.
6. Full-screen Pip reveal — original box/opening sequence; Meet Pip continues, Skip goes to the static pose. Finite animation pauses off-screen/background and falls back under Reduce Motion.
7. Optional Pip name — text; Skip/default uses “Pip”.
8. Optional user name — text; Skip/default uses “friend”.
9. Encouragement style — single-select; local tone preference only.
10. Meals per day — custom single value from 1–5; a reference preference, not a target.
11. Optional first/last meal times — direct 24-hour text entry; Skip clears both.
12. Usual eating places — independent multi-select: Cook at home, Order in, Eat out. House, delivery-bag and restaurant pictograms distinguish choices.
13. Illustrative guide — sample values only, then Open Home. Values are not calculated from onboarding answers.

## Home and logging

- Home embeds Pip’s Little World as the main scene over the forest background. Pip’s gentle entry pose is local artwork. The heart/leaf meter is not shipped; no food choices, missed logs or calories change Pip’s state.
- Water increments are 250 ml and bounded to 4,000 ml per session. The sample water target is labeled illustrative.
- Manual meal entries distinguish unknown calories from zero, apply bounds and offer deletion. Attached photos are locally downsampled, held in memory, removable and not uploaded.
- Workout logging currently offers Casual walk, Brisk walk, Power walk or Walking uphill, in 15/30/60-minute choices. It calculates no calories.
- Fasting is an optional start/end/cancel session log. There is no target, recommendation, countdown, reminder or health claim.
- All meals, photos, water, workout/fasting entries and preferences clear when the app closes. Session reset/delete controls are available.

## Deliberately unavailable

Food recognition, barcode lookup, scan progress/results, food-matching, meal-detail feedback/rating, remote provider calls from the app, Health integration, body metrics, persistent history, sync, accounts and notifications are not available. The app does not return mock results or imply that a scan happened. The loopback server package is not called by the app and is not a hosted service; its live route remains off and its one-shot test was already consumed.

Progress charts and all sample macro/nutrition values are illustrative, not personalized, medically meaningful or validated nutrition guidance. The opt-in heart/leaf meter is not implemented; it must remain disabled until its food-goal confirmation, uncertainty, undo/delete and opt-out behavior can be tested.

## Verification snapshot

The current Mac project compiled for iPhone 18 Pro Simulator. iPhone 17 Pro / iOS 26.5 passed 10 hosted UI and safety tests, including teaser-to-reveal navigation, onboarding, center Quick Log, three tabs, Home water, manual meal save, local Workout/Fasting actions, session History, photo bounds/cancellation and unknown-versus-zero calories. The loopback proxy/provider suite passed 11 tests using fake provider responses only. Camera hardware behavior remains unverified; simulator camera capture is unavailable.
