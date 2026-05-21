# RetireSmartIRA — Podcast & Press Talking Points

*Internal reference for cold outreach, podcast appearances, and press conversations. Not for publication.*

---

## Core Differentiation (the 30-second version)

Most retirement-planning apps either skip state tax or treat it as a single rate per state. RetireSmartIRA models retirement-specific state tax rules — age thresholds, pension exclusions, Roth conversion treatment, Social Security treatment — across all 41 income-tax states. Because that level of detail can go wrong in interesting ways, we built a five-source verification system to keep it honest. Every rule traces to a primary state source. Every release is cross-checked against an academic tax calculator that researchers have used since the 1970s. And real users — including practicing planners — surface what synthetic tests miss.

## The Story Hook (for narrative shows)

Earlier this year we shipped the same Pennsylvania state-tax bug twice in four days — once in one release, then again in the follow-up — through a test suite with nearly a thousand tests. The pattern that made it possible: I wrote the code with AI help, I wrote the tests with AI help, and I declared the audit complete with AI help. Five layers of verification that were all, fundamentally, the same source.

A user from Pennsylvania eventually caught it — a sharp, tax-literate retiree who looked at the screen and said, *that's not right, PA doesn't tax IRA distributions at retirement age.* He was correct.

What we built out of that experience is the methodology we now run on every release: five genuinely independent verification sources, primary-source citation mandatory, an actual academic tax calculator as one of the cross-checks. The lesson — that single-source verification is structurally insufficient for tax engines — generalizes well beyond our app.

*(Use the tester's name only with his explicit permission.)*

## Key Talking Points

1. **Planning estimator, not tax software.** Same lane as Boldin — helping people think clearly about retirement decisions, not file returns. That positioning sets the right expectations and frees the design to focus on decision-relevance over filing-grade dollar precision.

2. **Primary sources, cited in code.** Every encoded tax rule references a state revenue department publication or statute, quoted in the code itself. Anyone can audit the math against the actual law.

3. **NBER TAXSIM-35 as an independent cross-check.** Representative scenarios get POSTed to TAXSIM — the academic-standard calculator since 1974, cited in over a thousand papers — and have to agree within tight tolerance. Independent academic infrastructure is a different kind of check than "more tests of your own."

4. **Multi-model review.** Before state-tax engine changes ship, independent AI systems with different training data review the diff against the primary sources and flag disagreements. Cheap, fast, catches edge cases.

5. **Real-user feedback as a first-class verification source.** Tester reports trigger a regression test *before* any code change, plus an audit of the surrounding code for sibling bugs. Reporters get a transparent reply naming what's fixed now and what's coming.

6. **Free, on-device, privacy-first.** No server sees your numbers. No revenue model that depends on selling data. Apple-native on iPhone, iPad, and Mac.

## Anticipated Questions

**"How is this different from Boldin or Fidelity Full View?"**
Boldin and Full View are long-horizon planning tools — excellent for asking *will I have enough?* We're complementary, focused on the *what should I do this year* layer — Roth conversion sizing, withdrawal mix, state-tax implications of timing. Same person uses both for different questions.

**"Are you a CPA or financial advisor?"**
No. I'm a developer who hit the same questions personally and didn't find a tool that gave concrete annual answers. The app produces a planning estimate; it doesn't substitute for a professional. We're explicit about that throughout the app.

**"How do I know the numbers are right?"**
We publish the methodology. Every encoded rule traces to a primary state source, quoted in code. Federal scenarios are cross-checked against TAXSIM. Structural invariants are pinned in tests. And when we get something wrong, we name it in the release notes and reach out to the person who reported it.

**"Why is it free?"**
Because gating planning math behind a subscription felt wrong for what's effectively a public-good calculator. The cost to maintain it is bounded, and I built it on the back of an earlier career that lets me do this without needing it to fund itself.

**"What about AI making mistakes in tax calculations?"**
That's exactly what the Pennsylvania bug story is about. AI is great at writing tax code; it's also great at writing tests that confirm its own bias. The methodology we now use treats the AI as one tool in a five-source verification system, not as the verifier of its own work. That's what the system is for.

**"What's your background?"**
Co-founded GT Nexus — a global supply chain visibility platform — back in 1999. Acquired by Infor in 2015. Came back to building because retirement-planning tools left obvious gaps and I had the time and the skill to do something about it.

## Soundbites

- "Single-source verification is structurally insufficient for tax engines."
- "Five layers that are all the same source aren't actually five layers."
- "Every encoded rule traces to a primary state source — we quote it in the code itself."
- "A planning estimate that leads you to the same decision a tax pro would, without pretending to be filing software."
- "The user who caught our bug is the most important quality system we have."

## Logistical Background for Hosts

- **Founder:** John Urban. Co-founded GT Nexus (acquired by Infor, 2015). Solo developer on RetireSmartIRA.
- **App:** RetireSmartIRA. iPhone, iPad, Mac. Apple-native, Swift. Currently ranked in the App Store Finance category.
- **Pricing:** Free, ad-free, on-device. No subscription tier.
- **Site:** retiresmartira.com
- **Best contact for press:** john.urban@alamoventuresgroup.com
