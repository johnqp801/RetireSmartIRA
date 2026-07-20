# Alan Levy — local/city tax field cursor (SENT 2026-07-19, ACCEPTED)

**Status:** sent as-is by John 2026-07-19. Alan replied "Looks good, so lets proceed with that plan."
**Thread:** Re: App (Alan's 3:42 PM report: "There is no decimal point on the number pad. I cannot enter 3.88 percent for my taxes.")

## Sent text

Subject: Re: App

Alan,

Good catch, and thanks for staying on this one.

I went into the local tax field on the Profile tab, just below where you pick New York. The number pad that comes up does have a decimal point, bottom left, next to the zero. It's small and easy to miss on an iPhone screen. There's also a Done button at the top right above the pad to close it out.

What I did find is a real problem, just a different one. The cursor starts at the far left of the field instead of the right. So the field already has a number in it, and anything you type goes in *front* of that number rather than replacing it. You end up with a whole number you never meant to enter, which I think is what you were running into.

The workaround for now: tap at the far right end of the field to move the cursor there, delete what's in it, then type 3.88. Works for any whole or decimal number.

Does that match what you were seeing on your end?

I'm going to put a fix in the next release so the cursor starts at the right side of the field. My read is that clears up the whole thing, but you're the one who hit it, so tell me if you think something else is still off.

Thanks as always,
John

## Investigation behind it

Alan's literal report did NOT reproduce. Verified on iPhone 17 simulator (iOS 26.2) against the app's stored preferences plist, not screenshots:
- `.decimalPad` IS present on the field (`SettingsView.swift:388`); decimal key works.
- Clean entry of 3.88 stores `0.0388` correctly.
- Done accessory EXISTS (`KeyboardDismiss.swift`, applied at `SettingsView.swift:296` and `ContentView.swift:290`). An earlier claim that it was missing was a simulator artifact from force-toggling the software keyboard (Cmd+K) with a hardware keyboard attached.

REAL defect found instead: caret lands at position 0 in trailing-aligned pre-filled numeric fields, so the first keystroke inserts in FRONT of the existing value. Measured: typing 8 into a field showing 3 committed `0.83` (83%). Commits live per keystroke with no validation, and feeds the state tax calculation.

Alan's complaint is PLAUSIBLY this, but unconfirmed — he described a missing decimal point, not a wrong number appearing. Left the bridge sentence in the email deliberately; his "looks good" reply does not definitively confirm the mechanism.

## Outcome

Fix built and verified: `df39ae2` on branch `fix/numeric-caret-at-end` (`.caretAtEndOnFocus()` modifier, applied to SettingsView). Verified via stored value: tap into field showing 3.88, type 9 → `0.03889` (appended, was prepending).

Related but NOT from Alan: `3e85410` on `fix/year1-override-wipe` (Multi-Year silently zeroing a Scenarios Roth conversion).

Still open: clearing the local tax field leaves the stale value in the model (verified across relaunch, unfixed).
