# PandaPlate iOS prototype

PandaPlate is an original SwiftUI prototype featuring Pip the red panda. It uses PandaPlate’s own artwork, colors and copy while following the broad interaction rhythm of the supplied references.

## Build and run

Requires Xcode and an iOS 17+ simulator or device. Generate the project with `xcodegen generate --spec project.yml --project .`, then build with `xcodebuild -project PandaPlate.xcodeproj -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build`. Open `PandaPlate.xcodeproj` to run it in Xcode.

The canonical project is `/Users/charlie/Projects/PandaPlate-iOS`.

## What works in this slice

The 13-step setup stores routine and optional names in session memory. Step 5/13 uses the bundled, muted 5.04-second H.264 Pip teaser as a full-screen one-shot backdrop, with Open and Skip controls; it pauses on navigation/background and shows a static Pip pose under Reduce Motion. No trim was needed. Pip’s separate full-screen reveal follows at 6/13: a closed box with a peek, an open-box pose, a jump, then a settled happy greeting. The main navigation has Home, Log and Progress; the center plus opens Quick Log, while Settings opens from Home.

Home keeps the forest behind scrollable content and makes Pip’s Little World its main scene. Manual meal logging, local photo attachment, water increments, four walk types (15/30/60 minutes), and start/end/cancel fasting logs are functional. These local entries can be deleted or cleared and disappear when the app closes. Workout and fasting records do not estimate calories, set goals or send reminders. Unknown calories stay unknown.

Progress/History contains clearly illustrative charts and actual current-session entries. Supplied artwork is used for Pip’s Home entrance, the Progress note, the fasting background and Home’s water cup. Camera capture is disabled in the simulator; the photo picker and physical-camera behavior still need device testing.

## Explicitly unavailable

Food recognition, barcode lookup, DeepSeek/USDA requests, scan progress/results, meal-detail feedback, reminders, Health integration, persistent history, sync and accounts are unavailable. A chosen photo is only attached to a manual meal and is not uploaded or analyzed. The app returns no mock food results and does not imply that a scan happened.

The experimental local proxy in `Server/` is not called by the app and is not a hosted service. Keep its live provider mode off. Do not add provider keys to the app or repository, and do not use the previously consumed one-shot route for new photos.

## Verification

The app compiled and launched on iPhone 18 Pro Simulator with Xcode 27. iPhone 17 Pro / iOS 26.5 Simulator passed all 10 hosted UI and safety tests on 2026-10-24, including teaser-to-reveal navigation, the reveal’s settled-pose accessibility state, setup, three destinations plus Quick Log, Settings, 44pt water hit target, unavailable-recognition copy, manual meal save, workout/fasting logs and History, bounded photo handling, cancellation and unknown-versus-zero calories. The local proxy/provider suite passed 11 tests with fake provider responses; no external provider call was made by the app or that suite.

A single earlier public-pear API test was performed outside the app. It does not establish nutrition accuracy or enable scanning here.

## Boundaries and next gate

All meals, attached photos, water, workout/fasting logs and preferences are held in memory only and clear when the app closes. There is no persistent storage, account, sync, analytics or notifications. Sample nutrition values and charts are illustrative; this prototype is not medical advice or validated nutrition guidance. The opt-in heart/leaf meter is not implemented.

Before remote scanning returns, build and review an owner-controlled HTTPS proxy with authentication, rate limits, server-side image decoding/dimension limits, secret management, retention and cross-border privacy review, a production FoodData Central key, and a small labeled-data accuracy evaluation. Ask before every new photo upload. Never place provider keys in the iOS app or repository.
