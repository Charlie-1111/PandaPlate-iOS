# Soft wall + Review at first success (#1 + #6)

## Files
- Sources/FirstSuccessMoments.swift (new)
- Sources/AppStore.swift (hook after successful addMeal)
- Sources/MainShellView.swift (soft sheet + RequestReviewAction + Pip sayHi)

## Keys
- pandaplate.hasCompletedFirstLog
- pandaplate.hasCompletedPipRitual
- pandaplate.didRequestReviewAtFirstSuccess
- pandaplate.didPresentSoftWall

## Order
success settle 1.2s → native review once → +2.2s soft wall (idle, not premium)
