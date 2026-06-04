# iCloud Cross-Device Sync — Spec

**Status:** Scoped, not yet started. Target release: v1.9 or v2.x (TBD).
**Decision:** `.claude/memory/decisions/log.md` → "2026-05-21: iCloud cross-device sync via NSUbiquitousKeyValueStore, opt-in by default"
**Author/owner:** John

---

## Why

Users with multiple Apple devices (iPhone, iPad, Mac) currently have to enter and maintain data separately on each one. Real benefit: enter on Mac, review scenarios on iPad, check something on iPhone. Cross-device continuity is table stakes for a planning app once the user base is established.

Constraint: privacy positioning is a core differentiator. The current promise that "your data never leaves this app" is verified in the shipped code (`SSDataEntryView.swift:409`). Any sync feature must be **opt-in** so that promise stays absolutely true for users who don't enable it.

---

## Backend choice: `NSUbiquitousKeyValueStore`

Apple's iCloud Key-Value Store. Almost identical API shape to `UserDefaults`, syncs through the user's own iCloud account.

**Why this and not CloudKit / Core Data:**
- App's data is already key-value-shaped (UserDefaults with JSON-encoded blobs). KVS is a direct mapping; CloudKit would require migrating off UserDefaults first.
- Data footprint projects well inside KVS limits (1 MB total, 1,024 keys) given the fidelity assumption below. See "Sizing" section.
- CloudKit is reserved as a future migration path only if/when the fidelity assumption changes.

---

## Fidelity assumption this design depends on

**Position-level brokerage tracking only — no tax-lot history.** If the roadmap ever adds tax-lot-aware cap-gains projection on real portfolios, the brokerage data alone could approach 800 KB and KVS becomes the wrong backend. At that point: revisit and migrate to CloudKit + Core Data / SwiftData.

**Current roadmap does not include lot-level fidelity** (confirmed 2026-05-21).

---

## Sizing (projected over 5–10 years)

| Item | Estimated size |
|---|---|
| Profile, IRA accounts, income sources, prefs (today) | ~25 KB |
| Multi-year Roth conversion scenarios (3–5 saved) | ~150 KB |
| Subscription-model year-over-year retention (10 yrs) | ~300 KB |
| Position-level brokerage / crypto / bank accounts | ~50 KB |
| Income/expense projection for net worth | ~50 KB |
| **Realistic mid-fidelity total** | **~575 KB** |
| KVS budget | 1 MB |
| Headroom | ~40% |

Over 20 years of subscription retention: ~875 KB total. Still inside budget. Long-term margin tightens, but no architectural change needed within the planning horizon.

**Keys budget:** comfortable as long as we keep using coarse JSON-blob keys (one blob per collection, current pattern). Do NOT fragment into one-key-per-record — that would exceed 1,024 keys quickly.

---

## Architecture: storage abstraction protocol

Build a thin protocol so `DataManager` does not call `UserDefaults` or `NSUbiquitousKeyValueStore` directly. The protocol becomes the single seam for testing and any future backend swap.

```swift
protocol PlanStorage {
    func read<T: Codable>(_ key: String, as type: T.Type) -> T?
    func write<T: Codable>(_ key: String, value: T)
    func remove(_ key: String)
    func scalar(_ key: String) -> Any?
    func setScalar(_ key: String, value: Any?)
    var didChangeExternally: AnyPublisher<Void, Never> { get }
}
```

Backends:
- `LocalStorage` — wraps `UserDefaults.standard`. Used when iCloud sync is off, or as fallback when iCloud unavailable.
- `UbiquitousKVSStorage` — wraps `NSUbiquitousKeyValueStore.default`. Used when sync is on.
- (Future, if fidelity ever changes) `CloudKitStorage` — drop-in replacement; rest of app untouched.

`DataManager` reads/writes only through the protocol.

---

## UI / settings

New toggle in Settings:

> **iCloud Sync** — Off by default. When on, your plan syncs across your Apple devices through your private iCloud account.

When toggled on for the first time:
1. Confirm with the user (modal): "This will copy your plan to your iCloud account so it can sync to your other Apple devices. RetireSmartIRA never sees your data. Continue?"
2. Copy current local data into KVS.
3. Register for `NSUbiquitousKeyValueStore.didChangeExternallyNotification`.
4. From this point on, all writes go to both KVS and the local fallback (so toggling off later is safe).

When toggled off:
1. Confirm: "Your data will stop syncing to other devices. Your data on this device is unchanged."
2. Stop writing to KVS. Local data remains authoritative on this device.
3. (Do NOT delete the KVS copy — other devices may still have sync on.)

---

## One-time migration

On the first launch after the update lands, regardless of sync state:
- If user enables sync later: copy local `UserDefaults` data into KVS atomically (whole-collection writes, not field-by-field, to avoid partial-state corruption).
- Never overwrite KVS data with local data without user confirmation (the user may have already enabled sync on another device).
- On enabling sync the second time on a device (e.g., new iPad), give the user the choice: "Use this device's data" or "Use the data already in your iCloud."

---

## Conflict resolution

KVS is eventually consistent with last-write-wins as default. For this app the risk is low (single user, single household), but two scenarios need handling:

1. **Both devices offline, both edit, then both come online.** Last write wins on whichever device syncs second. Mitigation: store a per-collection timestamp inside each JSON blob. On read after external change, compare timestamps and prefer the newer one when reconciling.
2. **One device offline for a long period, then comes online.** Could overwrite newer data from the other device. Mitigation: same timestamp check.

Conflict handling is **per-collection**, not per-field, because we write whole JSON blobs.

---

## Privacy copy changes

**Default (sync off):**
> "Your retirement data stays on this device. RetireSmartIRA does not operate servers and never sees your data."

**With sync on:**
> "Your data syncs privately through your own Apple iCloud account so you can use RetireSmartIRA across your Apple devices. It is never sent to us, never sold, never used for profiling, and never processed on our servers. RetireSmartIRA does not operate servers and cannot view your data. Sync is protected by Apple's iCloud security."

**Forbidden wording until verified:**
- "End-to-end encrypted" — only use if Apple's documentation explicitly confirms `NSUbiquitousKeyValueStore` falls under Advanced Data Protection's covered categories. Until then, "protected by Apple's iCloud security" is the conservative ceiling.

**In-app copy to audit and conditionally update:**
- `SSDataEntryView.swift:409` — "All calculations run on your device. Your data never leaves this app." → make conditional on the toggle, or change to neutral phrasing.
- Any other places marketing the device-only story (search the codebase before release).

**External copy to update:**
- App Store description and screenshots if they reference device-only storage
- Privacy policy
- App Store privacy nutrition labels — even though we never see the data, sync changes the answer to "Data Linked to You" questions and requires reassessment

---

## Open items requiring verification before release

1. **Apple's ADP coverage of NSUbiquitousKeyValueStore.** Check Apple's published list of categories covered by Advanced Data Protection. If KVS is covered, the user-facing copy can be strengthened to mention end-to-end encryption. If not, conservative wording stays.
2. **App Store privacy nutrition labels.** Walk through Apple's "App Privacy" questionnaire as if filing it fresh with sync enabled, and update the existing answers.
3. **Privacy policy.** Update the public privacy policy (linked from the App Store listing) to describe the optional iCloud sync.
4. **App-store-positioning.md memory note** (user auto-memory) — review and reconcile the device-only privacy positioning with the new optional-sync story.

---

## Risks

- **Sync delay.** KVS is eventually consistent; users may see a few seconds of lag. Document this in the toggle's help text.
- **Data loss from naive conflict resolution.** Per-collection timestamps mitigate; without them, the offline-and-edit case is real.
- **Privacy positioning dilution.** If the messaging around the toggle is sloppy, even non-sync users could lose confidence in the device-only promise. UI copy must be precise.
- **Future fidelity creep.** If product direction shifts toward tax-lot brokerage tracking, the KVS budget becomes a constraint rather than a comfortable fit. This decision needs to be revisited if the roadmap changes.

---

## Effort estimate

1–2 weeks engineering plus careful cross-device testing. The work is contained because save/load is already centralized in `DataManager`. The cost is in testing the lag, the migration, and the conflict cases — not in code volume.

---

## TriSTAR triangulation status (pre-build)

Performed 2026-05-21:
- **Primary source:** Apple documentation on `NSUbiquitousKeyValueStore` and ADP (partially reviewed; KVS-under-ADP question still open — see verification items above)
- **Claude analysis:** proposed KVS + opt-in toggle + storage abstraction
- **ChatGPT review:** concurred on architecture and opt-in; caught the ADP-coverage overclaim
- **Gemini review:** concurred on architecture and opt-in
- **Property/oracle tests, tester feedback:** N/A until build exists

Result: 2/2 multi-LLM MATCH on the architectural direction, 1 MISMATCH caught (ADP wording), corrected.

---

## Cross-references

- Persistence audit (current state): grep `UserDefaults` in `DataManager.swift` and `DataManager+SocialSecurity.swift`
- Privacy claim in code: `RetireSmartIRA/SSDataEntryView.swift:409`
- Conversation that produced this spec: 2026-05-21 session note (to be written)
- TriSTAR Protocol: `.claude/memory/policy/state-tax-accuracy-tristar-protocol.md`
