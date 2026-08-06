# Task 1 Report: Freeze the behavior baseline

Worktree: `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`
Branch: `feature/state-tax-phase3a`
Commit: `855b7c3` "test(state-tax): freeze the pre-Phase-3a behavior baseline for 51 jurisdictions"

Every `xcodebuild` invocation below was run with `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && ...` in the same Bash call. Each transcript's build log was grepped for the `.xcodeproj` path and confirmed to read:

```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

for every run, including the final full-suite run. No run used the wrong tree.

## Process note: order deviated slightly from the brief's file layout, not its content

The brief's Step 1 code block contains only `BaselineScenario` + `StateTaxBehaviorBaselineTests` + the `BehaviorBaselineMarker` declaration; Step 3 says "append" the generator suite to the same file. To get a genuine RED (Step 2) before any generator code existed in the file, I wrote the file in that exact split: Step 1 content only, ran RED, then appended the Step 3 generator content verbatim. Final file content matches the brief's two code blocks concatenated exactly, with the marker at the very bottom as specified.

## Step 2: RED transcript (verbatim)

Command:
```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests
```

Pure test-run portion of the transcript (build-log noise above this point omitted; the xcodeproj path was verified separately, see above):

```
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
◇ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
◇ Test case passing 1 argument state → .alabama to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .alabama at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .alaska to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .alaska at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .arizona to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .arizona at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .arkansas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .arkansas at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .california to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .california at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .colorado to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .colorado at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .connecticut to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .connecticut at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .delaware to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .delaware at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .districtOfColumbia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .districtOfColumbia at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .florida to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .florida at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .georgia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .georgia at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .hawaii to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .hawaii at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .idaho to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .idaho at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .illinois to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .illinois at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .indiana to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .indiana at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .iowa to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .iowa at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .kansas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .kansas at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .kentucky to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .kentucky at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .louisiana to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .louisiana at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .maine to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .maine at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .maryland to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .maryland at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .massachusetts to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .massachusetts at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .michigan to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .michigan at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .minnesota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .minnesota at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .mississippi to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .mississippi at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .missouri to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .missouri at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .montana to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .montana at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .nebraska to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .nebraska at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .nevada to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .nevada at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .newHampshire to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .newHampshire at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .newJersey to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .newJersey at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .newMexico to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .newMexico at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .newYork to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .newYork at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .northCarolina to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .northCarolina at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .northDakota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .northDakota at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .ohio to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .ohio at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .oklahoma to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .oklahoma at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .oregon to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .oregon at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .pennsylvania to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .pennsylvania at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .rhodeIsland to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .rhodeIsland at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .southCarolina to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .southCarolina at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .southDakota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .southDakota at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .tennessee to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .tennessee at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .texas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .texas at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .utah to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .utah at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .vermont to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .vermont at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .virginia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .virginia at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .washington to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .washington at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .westVirginia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .westVirginia at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .wisconsin to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .wisconsin at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​◇ Test case passing 1 argument state → .wyoming to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .wyoming at StateTaxBehaviorBaselineTests.swift:171:23: Expectation failed: (Bundle(for: BehaviorBaselineMarker.self) → NSBundle </Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug/RetireSmartIRA.app/Contents/PlugIns/RetireSmartIRATests.xctest> (loaded)).url(forResource: "statetax-behavior-baseline-2026", withExtension: "json") → nil
↳ baseline fixture is not bundled
​✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases failed after 0.005 seconds with 51 issues.
✘ Suite "PHASE 3a GATE: state tax behavior baseline" failed after 0.005 seconds with 51 issues.
✘ Test run with 1 test in 1 suite failed after 0.005 seconds with 51 issues.
2026-08-03 00:17:06.064 xcodebuild[72556:8346816] [MT] IDETestOperationsObserverDebug: 12.330 elapsed -- Testing started completed.
2026-08-03 00:17:06.064 xcodebuild[72556:8346816] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-08-03 00:17:06.064 xcodebuild[72556:8346816] [MT] IDETestOperationsObserverDebug: 12.330 sec, +12.330 sec -- end

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_00-16-26--0700.xcresult

Failing tests:
	-[StateTaxBehaviorBaselineTests matchesFrozenBaseline(state:)]

** TEST FAILED **

Testing started
```

Fails for the correct reason: all 51 states fail at `#require(...url(forResource:...))` with "baseline fixture is not bundled", exactly as the brief predicted, because the fixture file does not exist yet at this point.

## Step 4: fixture generation

Generator run (`TEST_RUNNER_STATE_TAX_BASELINE=1`, `ENABLE_APP_SANDBOX=NO`) passed:

```
◇ Suite "State tax behavior baseline generator (manual)" started.
◇ Test "Generate the frozen behavior baseline" started.
✔ Test "Generate the frozen behavior baseline" passed after 0.008 seconds.
✔ Suite "State tax behavior baseline generator (manual)" passed after 0.008 seconds.
✔ Test run with 1 test in 1 suite passed after 0.008 seconds.
```

Entry-count command output (actual, not reconstructed):

```
$ python3 -c "import json;d=json.load(open('RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json'));print(len(d))"
867
```

Matches the expected 51 x 17 = 867 exactly.

## Step 5: GREEN transcript (verbatim)

Command:
```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests
```

Pure test-run portion:

```
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
◇ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
◇ Test case passing 1 argument state → .alabama to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .alaska to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .arizona to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .arkansas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .california to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .colorado to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .connecticut to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .delaware to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .districtOfColumbia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .florida to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .georgia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .hawaii to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .idaho to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .illinois to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .indiana to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .iowa to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .kansas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .kentucky to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .louisiana to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .maine to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .maryland to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .massachusetts to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .michigan to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .minnesota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .mississippi to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .missouri to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .montana to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .nebraska to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .nevada to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .newHampshire to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .newJersey to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .newMexico to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .newYork to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .northCarolina to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .northDakota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .ohio to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .oklahoma to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .oregon to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .pennsylvania to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .rhodeIsland to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .southCarolina to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .southDakota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .tennessee to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .texas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .utah to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .vermont to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .virginia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .washington to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .westVirginia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .wisconsin to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .wyoming to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.042 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.043 seconds.
✔ Test run with 1 test in 1 suite passed after 0.043 seconds.

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_00-20-05--0700.xcresult

** TEST SUCCEEDED **

Testing started
```

## Step 6, Mutation 1: distribution age gate 59 to 60

File: `RetireSmartIRA/TaxCalculationEngine.swift`, line 583.

Before (and after revert):
```swift
let retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)
```

Mutated to:
```swift
let retirementAge = primaryAge >= 60 || (enableSpouse && spouseAge >= 60)
```

Re-ran the assertion test. Result: FAILED, exactly as the brief predicted, with 15 issues, all on the "single 59, distributions only" scenario. Failure output (verbatim, all 15 states):

```
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .arkansas at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 1852.8000000000002) == (expected → 1630.8)
↳ AR|single 59, distributions only: computed 1852.8000000000002, baseline 1630.8.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .colorado at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2640.0) == (expected → 1760.0)
↳ CO|single 59, distributions only: computed 2640.0, baseline 1760.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .connecticut at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2550.0) == (expected → 650.0)
↳ CT|single 59, distributions only: computed 2550.0, baseline 650.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .delaware at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2943.5) == (expected → 2249.75)
↳ DE|single 59, distributions only: computed 2943.5, baseline 2249.75.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .illinois at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2970.0) == (expected → 990.0)
↳ IL|single 59, distributions only: computed 2970.0, baseline 990.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .kentucky at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2100.0) == (expected → 1011.1500000000001)
↳ KY|single 59, distributions only: computed 2100.0, baseline 1011.1500000000001.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .louisiana at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 1800.0) == (expected → 1440.0)
↳ LA|single 59, distributions only: computed 1800.0, baseline 1440.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .michigan at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2550.0) == (expected → 850.0000000000001)
↳ MI|single 59, distributions only: computed 2550.0, baseline 850.0000000000001.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .mississippi at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2400.0) == (expected → 800.0)
↳ MS|single 59, distributions only: computed 2400.0, baseline 800.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .missouri at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2639.368) == (expected → 759.3679999999999)
↳ MO|single 59, distributions only: computed 2639.368, baseline 759.3679999999999.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .newYork at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 3075.0) == (expected → 1995.0)
↳ NY|single 59, distributions only: computed 3075.0, baseline 1995.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .oklahoma at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2485.25) == (expected → 2035.25)
↳ OK|single 59, distributions only: computed 2485.25, baseline 2035.25.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .pennsylvania at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 1842.0) == (expected → 614.0)
↳ PA|single 59, distributions only: computed 1842.0, baseline 614.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .southCarolina at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2160.0) == (expected → 1639.0)
↳ SC|single 59, distributions only: computed 2160.0, baseline 1639.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .virginia at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 3192.5) == (expected → 2502.5)
↳ VA|single 59, distributions only: computed 3192.5, baseline 2502.5.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
​✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases failed after 0.038 seconds with 15 issues.
✘ Suite "PHASE 3a GATE: state tax behavior baseline" failed after 0.038 seconds with 15 issues.
✘ Test run with 1 test in 1 suite failed after 0.039 seconds with 15 issues.
```

**Which states/scenarios failed:** AR, CO, CT, DE, IL, KY, LA, MI, MS, MO, NY, OK, PA, SC, VA (15 states), all and only on the `"single 59, distributions only"` scenario. These are exactly the 15 states in the baseline grid whose IRA/pension exemption is not `.none`, matching the brief's prediction precisely.

**Reverted:** confirmed by `git diff RetireSmartIRA/TaxCalculationEngine.swift` returning no output after reverting.

## Step 6, Mutation 2: NJ regularExemptionMinAge 62 to 65

File: `RetireSmartIRA/StateTaxData.swift`, line 1673.

Before (and after revert):
```swift
regularExemptionMinAge: 62,
```

Mutated to:
```swift
regularExemptionMinAge: 65,
```

Re-ran the assertion test. This mutation was actually run (not reconstructed), and the result was **not** a failure. Full transcript:

```
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
◇ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
[... all 51 states "started", no failures interleaved ...]
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.046 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.047 seconds.
✔ Test run with 1 test in 1 suite passed after 0.047 seconds.

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_00-21-12--0700.xcresult

** TEST SUCCEEDED **

Testing started
```

(The bracketed line above elides 51 repetitive "Test case passing 1 argument state -> .X ... started" lines with no interleaved failures, to keep this section readable; the full untruncated transcript is identical in shape to the Step 5 GREEN transcript above, just with NJ's config value changed. No line was omitted that contained a `recorded an issue`, `✘`, or non-zero issue count; there were none.)

**Reverted:** confirmed by `git diff RetireSmartIRA/StateTaxData.swift` returning no output after reverting.

### Why this mutation did not discriminate, and why that is not a defect in the test file

Investigated the discrepancy against the brief's stated expectation ("expect NJ failures on the pension scenarios") rather than accepting the unexpected PASS silently. Root cause, confirmed by reading the source:

1. `TaxCalculationEngine.calculateStateTax` resolves its config via `StateTaxData.config(for: state)` (`TaxCalculationEngine.swift:361`), never via `configOverride` for Task 1's calls (as instructed).
2. `StateTaxData.config(for:)` (`StateTaxData.swift:2097-2105`) checks `configs2026[state]` FIRST and returns it if present; `configs2026Legacy[state]` (the Swift literal dictionary I edited) is only consulted as a fallback.
3. `configs2026` (`StateTaxData.swift:2077`) is `StateTaxDataLoader.configs2026`, which loads the bundled JSON resource for each state (`StateTaxDataLoader.swift:186-194`) and only falls back to `configs2026Legacy` **per state** if that state's JSON fails to load or decode (`StateTaxDataLoader.swift:134-147`).
4. NJ's bundled JSON (`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json`) loads successfully, so `configs2026[.newJersey]` is returned, and my edit to `configs2026Legacy`'s NJ entry in `StateTaxData.swift` is never consulted by production code. This is the exact architecture the test file's own doc comment describes: "The Phase 1 gate compares the JSON-loaded config against the legacy Swift config. Phase 3a edits BOTH, so they move together..." The gate's premise is that both must be edited together; a Swift-literal-only edit is, by that same premise, invisible to production.

Separately, even setting the shadowing issue aside: none of the 17 baseline scenarios has an NJ-relevant pension income at an age in the [62, 64] window (the only ages that would move under a 62-to-65 threshold change). The pension scenarios in the grid use ages 65, 66, and 68, all already >= 65. The two scenarios closest to that window are "single 62 conversion 100k no withholding" and "single 62 conversion 100k with 22k withheld" (age 62, `retirementDistributions: 20_000`), which touch NJ's `iraWithdrawalExemption` age gate, not the pension exemption the brief called out. I did not pursue mutating the bundled JSON to confirm this second-order prediction, because doing so would go beyond the two mutations the brief and the hard constraints authorized ("stop and report" if editing anything under `RetireSmartIRA/` beyond the Step 6 mutations as described) - flagging as a concern below rather than acting further.

**This is reported as a concern, not glossed over.** The suite itself is sound (Mutation 1 proves it discriminates on the axis that matters most for the age-gate, per-state IRA/pension exemption computation), but Mutation 2 as literally specified in the brief does not exercise the production code path and therefore provides no evidence either way about the baseline's sensitivity to NJ's `regularExemptionMinAge`. A meaningful version of this check would need to mutate the bundled JSON resource (`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json`), not the legacy Swift table, and per current scenario coverage would only be exercised by the two age-62 Roth-conversion-with-distribution scenarios, not the pension scenarios the brief named.

## Full suite (both frameworks)

Command:
```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'
```

Confirmed this ran against the worktree's project (grepped the log):
```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

Swift Testing summary line (verbatim):
```
✔ Test run with 1622 tests in 277 suites passed after 293.051 seconds.
```

XCTest summary lines (verbatim):
```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-03 00:25:07.150.
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.682 (21.024) seconds
Test Suite 'All tests' passed at 2026-08-03 00:25:07.150.
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.682 (21.024) seconds
```

Overall result: `** TEST SUCCEEDED **`. No failures anywhere in the full suite. The manual generator suite (`StateTaxBehaviorBaselineGeneratorTests`) ran as part of this pass too, confirmed disabled/no-op (its `.enabled(if:)` guard was false since `STATE_TAX_BASELINE` was not set for this run):
```
◇ Suite "State tax behavior baseline generator (manual)" started.
​✔ Suite "State tax behavior baseline generator (manual)" passed after 0.001 seconds.
```
It recorded zero writes and did not touch the checked-in fixture.

## Commit diff stat (actual command output, not hand-counted)

```
$ git diff --cached --stat   (captured before the commit)
 .../Baselines/statetax-behavior-baseline-2026.json | 869 +++++++++++++++++++++
 .../StateTaxBehaviorBaselineTests.swift            | 236 ++++++
 2 files changed, 1105 insertions(+)
```

```
$ git commit output
[feature/state-tax-phase3a 855b7c3] test(state-tax): freeze the pre-Phase-3a behavior baseline for 51 jurisdictions
 2 files changed, 1105 insertions(+)
 create mode 100644 RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json
 create mode 100644 RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift
```

## Post-commit tree state

```
$ git status --short
(clean)
```

`git diff RetireSmartIRA/TaxCalculationEngine.swift` and `git diff RetireSmartIRA/StateTaxData.swift` both returned no output before the commit, confirming both Step 6 mutations were fully reverted and no production source file was left modified. Only the two new test-target files were staged and committed.

## Summary

- Steps 1 through 5 executed exactly as specified: RED confirmed for the right reason (fixture absent), fixture generated with exactly 867 entries, GREEN confirmed.
- Step 6 Mutation 1 (distribution age gate) discriminates exactly as predicted: 15 states, all on the "single 59, distributions only" scenario, cleanly reverted.
- Step 6 Mutation 2 (NJ `regularExemptionMinAge` in the legacy Swift table) does NOT discriminate, because production reads the bundled JSON config first and only falls back to the legacy Swift table on a per-state load failure; NJ's JSON loads successfully so the Swift-literal edit is invisible to `calculateStateTax`. This is a genuine finding, not a test defect, and is flagged as a concern for whoever owns the Step 6 brief text and for later Phase 3a tasks that will edit NJ's config (they need to know which source of truth actually governs runtime behavior).
- No production source file is modified in the final committed state.
- Full suite green: 1622 Swift Testing tests / 277 suites, 503 XCTest tests, zero failures.

## Corrected second mutation (data path)

Follow-up evidence-gathering pass, run separately from the Task 1 work above, to correctly target the second discriminating mutation against the DATA path instead of the legacy Swift table the original Step 6 Mutation 2 hit. No production code or fixture change is kept; this section only records the transcript.

Worktree and branch confirmed unchanged: `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`, branch `feature/state-tax-phase3a`.

### Step 1: pre-mutation tree state

`git status` showed one pre-existing unrelated modification, not touched by this pass and not part of the mutation:

```
On branch feature/state-tax-phase3a
Changes not staged for commit:
	modified:   docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md
```

The two files relevant to this mutation (`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json` and the baseline test/fixture pair) were confirmed clean before editing via `git status <paths>`, returning "nothing to commit, working tree clean".

### Step 2: the mutation

Changed `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json`, `"regularExemptionMinAge"` from `62` to `65`. Nothing else. Confirmed via `git diff`:

```
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
index de8f076..da4b0c0 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
@@ -69,7 +69,7 @@
         }
       ]
     },
-    "regularExemptionMinAge" : 62,
+    "regularExemptionMinAge" : 65,
     "socialSecurityExempt" : true
   },
   "safeHarborRule" : {
```

### Step 3-4: test run and result -- FAILED, as expected

Command:
```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests
```

Confirmed against the correct worktree by grepping the log for `.xcodeproj`:
```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

Relevant portion of the test transcript (all 51 jurisdictions run; only NJ failed):

```
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
◇ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
◇ Test case passing 1 argument state → .alabama to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
...
◇ Test case passing 1 argument state → .newJersey to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" recorded an issue with 1 argument state → .newJersey at StateTaxBehaviorBaselineTests.swift:186:13: Expectation failed: (actual → 2485.5) == (expected → 0.0)
↳ NJ|single 63 in the early age tier: computed 2485.5, baseline 0.0.
  Phase 3a is behavior-inert. A moved value is a defect in the change that moved it, NOT a reason to regenerate this fixture.
...
✘ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases failed after 0.046 seconds with 1 issue.
✘ Suite "PHASE 3a GATE: state tax behavior baseline" failed after 0.046 seconds with 1 issue.
✘ Test run with 1 test in 1 suite failed after 0.047 seconds with 1 issue.

** TEST FAILED **

Failing tests:
	-[StateTaxBehaviorBaselineTests matchesFrozenBaseline(state:)]
```

(All 50 other jurisdictions' test cases ran and passed with no issue recorded; only the `.newJersey` case failed. The `...` above elide the routine "Test case passing 1 argument ... started" lines for the other 50 states, none of which had an interleaved failure.)

**Discriminated: yes.** Exactly one state failed (New Jersey), on exactly one scenario ("single 63 in the early age tier"), with computed value 2485.5 against a recorded baseline of 0.0. This confirms the JSON-backed `regularExemptionMinAge` field is live on the production read path, unlike the legacy-Swift-table field mutated in the original Step 6 Mutation 2, which produced no failure. This is consistent with, and confirms, the root-cause explanation already recorded above in this report: `StateTaxData.config(for:)` reads `configs2026` (JSON-backed) first and only falls back to `configs2026Legacy` per-state on a load failure; NJ's JSON loads successfully, so the JSON value -- not the Swift literal -- governs runtime behavior.

Note on scenario identity: the earlier root-cause analysis in this report predicted (without testing it) that a JSON-path mutation would only be reachable via the two age-62 Roth-conversion-with-distribution scenarios, through NJ's `iraWithdrawalExemption` age gate, not the pension-exemption scenarios. The scenario that actually failed here is named "single 63 in the early age tier," a different scenario than either of those two predicted candidates, and at age 63 (inside the moved [62,65) window) rather than age 62. This does not change the "yes, it discriminates" verdict, since it is a genuine failure on the JSON-backed field under mutation. It only means the earlier prediction of which scenario would catch it was not precise; the actual catching scenario was not individually verified against the JSON field it exercises as part of this pass, since the brief for this pass only asked for evidence that the DATA-path mutation discriminates.

### Step 5: revert and clean-tree confirmation

```
$ git checkout -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
$ git status
On branch feature/state-tax-phase3a
Changes not staged for commit:
	modified:   docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md

no changes added to commit (use "git add" and/or "git commit -a")
$ git diff -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
(no output)
```

Confirmed clean: the only modified file remaining is the pre-existing unrelated docs plan file present before this pass began; the target JSON file's diff is empty.

### Step 6: re-run after revert -- PASSED

Same command, same worktree confirmed again via `.xcodeproj` grep (`cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`):

```
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
◇ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
...
​◇ Test case passing 1 argument state → .newJersey to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
...
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.045 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.045 seconds.
✔ Test run with 1 test in 1 suite passed after 0.045 seconds.

** TEST SUCCEEDED **
```

### Corrected finding

The corrected, data-path-targeted mutation DOES discriminate. This supersedes nothing in the original Step 6 Mutation 2 write-up above (that mutation, against `configs2026Legacy` in `StateTaxData.swift`, correctly and separately showed the legacy table is dead code on the read path) but completes the picture: the baseline gate is sensitive to changes in the actual bundled JSON data files that govern production behavior, which is the mutation axis that matters for Phase 3a (a phase whose schema extensions will edit these same JSON files). No commit was made; no fixture or test file was touched; only the one JSON field was mutated and reverted.

## Review fixes

### Pre-check: no production drift from e540e9f

```
$ git diff --name-only e540e9f..HEAD
.claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md
RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json
RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift
docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md
```

No file under `RetireSmartIRA/` (production source) differs from `e540e9f`. Not BLOCKED; regeneration proceeded.

### Fixes applied

1. **Size assertion.** Added the `#expect(baseline.count == USState.allCases.count * Self.scenarios.count, ...)` check at the top of `matchesFrozenBaseline`, exactly as specified.
2. **MFJ both-below-gate scenario.** Added `"MFJ 56 with spouse 55, both below the gate"` immediately after `"MFJ 61 with spouse 56"`.
3. **NJ single-filer tier 2/3 scenarios.** Added `"single 68 pension, total 120k"` (tier 2, singlePercent 0.375) and `"single 68 pension, total 140k"` (tier 3, singlePercent 0.1875) immediately after `"single 65 pension, total 95k"`.
4. **Comment correction.** Replaced the misleading `njPersonalExemptions` comment on the "MFJ status but spouse disabled, 66" scenario with the corrected text naming `NJOtherExclusionAndExemptionsTests` as the actual guard for that logic.
5. **`fileprivate` on `BaselineScenario`: REVERTED, not applied.** Marking `struct BaselineScenario` as `fileprivate` produced a genuine Swift access-level cascade error, not a false alarm:

   ```
   RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift:40:16: error: property must be declared fileprivate because its type uses a fileprivate type
       static let scenarios: [BaselineScenario] = [
                  ^           ~~~~~~~~~~~~~~~~
   RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift:164:17: error: method must be declared fileprivate because its parameter uses a fileprivate type
       static func key(_ state: USState, _ scenario: BaselineScenario) -> String {
   RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift:168:17: error: method must be declared fileprivate because its parameter uses a fileprivate type
       static func computedTax(state: USState, scenario: BaselineScenario) -> Double {
   ```

   Cause: `StateTaxBehaviorBaselineGeneratorTests.generate()`, a *different* struct later in the same file, calls `StateTaxBehaviorBaselineTests.scenarios`, `.key(...)`, and `.computedTax(...)`. Making `BaselineScenario` fileprivate forces those three `internal` members to also become `fileprivate` to type-check, which per the finding's own fallback instruction counts as restructuring rather than a one-line access-level tightening. Reverted to plain `struct BaselineScenario` (unchanged from before this fix pass). No fileprivate keyword is present in the committed diff.

### Fixture regeneration

Command:
```
TEST_RUNNER_STATE_TAX_BASELINE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineGeneratorTests ENABLE_APP_SANDBOX=NO
```

Confirmed run against the worktree's own project:
```
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

Output:
```
◇ Suite "State tax behavior baseline generator (manual)" started.
◇ Test "Generate the frozen behavior baseline" started.
✔ Test "Generate the frozen behavior baseline" passed after 0.008 seconds.
✔ Suite "State tax behavior baseline generator (manual)" passed after 0.008 seconds.
✔ Test run with 1 test in 1 suite passed after 0.008 seconds.
** TEST SUCCEEDED **
```

Entry count, counted directly from the regenerated JSON (not hand-counted):
```
$ python3 -c "
import json
d = json.load(open('RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json'))
print('entry count:', len(d))
"
entry count: 1020
```
1020 = 51 jurisdictions x 20 scenarios (17 original + 3 added by fixes 2 and 3), matching the task's expected value.

### Gate re-run: GREEN

Command: `-only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests ENABLE_APP_SANDBOX=NO`

```
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.043 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.043 seconds.
✔ Test run with 1 test in 1 suite passed after 0.043 seconds.
** TEST SUCCEEDED **
```

### Step 5: proving fix 2 discriminates

Mutated `RetireSmartIRA/TaxCalculationEngine.swift` line 583 from:
```swift
let retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)
```
to the exact degradation the finding predicts:
```swift
let retirementAge = primaryAge >= 59 || enableSpouse
```

Re-ran `-only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests ENABLE_APP_SANDBOX=NO` against this mutation, confirmed still running from the worktree's own `.xcodeproj` (`cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`).

Result: 14 of 51 per-state test cases failed, and in every failing case the ONLY scenario that failed was the new "MFJ 56 with spouse 55, both below the gate" scenario. No pre-existing scenario failed under this mutation. Exact failure lines:

```
↳ AR|MFJ 56 with spouse 55, both below the gate: computed 3850.7999999999997, baseline 4072.7999999999997.
↳ CO|MFJ 56 with spouse 55, both below the gate: computed 4400.0, baseline 5280.0.
↳ CT|MFJ 56 with spouse 55, both below the gate: computed 2650.0, baseline 5100.0.
↳ DE|MFJ 56 with spouse 55, both below the gate: computed 6078.5, baseline 6903.5.
↳ IL|MFJ 56 with spouse 55, both below the gate: computed 3465.0, baseline 5940.0.
↳ KY|MFJ 56 with spouse 55, both below the gate: computed 3111.15, baseline 4200.0.
↳ LA|MFJ 56 with spouse 55, both below the gate: computed 3240.0, baseline 3600.0.
↳ MI|MFJ 56 with spouse 55, both below the gate: computed 2975.0, baseline 5100.0.
↳ MS|MFJ 56 with spouse 55, both below the gate: computed 2800.0, baseline 4800.0.
↳ MO|MFJ 56 with spouse 55, both below the gate: computed 3109.368, baseline 5459.3679999999995.
↳ OK|MFJ 56 with spouse 55, both below the gate: computed 4520.5, baseline 4970.5.
↳ PA|MFJ 56 with spouse 55, both below the gate: computed 2149.0, baseline 3684.0.
↳ SC|MFJ 56 with spouse 55, both below the gate: computed 4765.0, baseline 5286.0.
↳ VA|MFJ 56 with spouse 55, both below the gate: computed 5952.5, baseline 6642.5.
```

Failing states: AR, CO, CT, DE, IL, KY, LA, MI, MS, MO, OK, PA, SC, VA (14 states, all carry nonzero `pensionAndIRAShareSingleCap`/retirement-income exemptions that are age-gated). The 37 non-failing states either have no such exemption or exempt unconditionally, so the mutated gate value never surfaces there. Confirms the new scenario is the sole detector for this exact degradation; the finding's prediction holds.

### Revert confirmed

Reverted `TaxCalculationEngine.swift` line 583 back to `primaryAge >= 59 || (enableSpouse && spouseAge >= 59)`.

```
$ git diff --stat RetireSmartIRA/TaxCalculationEngine.swift
(no output)
$ git diff RetireSmartIRA/TaxCalculationEngine.swift | wc -l
       0
```

Re-ran the gate suite after revert, confirmed GREEN again:
```
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.047 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.047 seconds.
✔ Test run with 1 test in 1 suite passed after 0.047 seconds.
** TEST SUCCEEDED **
```

### Full suite: GREEN

Command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' ENABLE_APP_SANDBOX=NO` (no `-only-testing`, full target), confirmed against the worktree's own `.xcodeproj`.

Swift Testing summary line:
```
✔ Test run with 1622 tests in 277 suites passed after 276.043 seconds.
```

XCTest summary line:
```
Test Suite 'All tests' passed at 2026-08-03 00:53:49.240.
	 Executed 503 tests, with 0 failures (0 unexpected) in 18.929 (19.231) seconds
```

Both green, 0 failures.

### Commit

```
601a622dd3bf85978949f08b5924cb4357cb7789
test(state-tax): close three coverage holes in the behavior baseline
```

Files changed: `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`, `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` (2 files changed, 188 insertions, 2 deletions per `git diff --stat`). No production source file is part of this commit.
