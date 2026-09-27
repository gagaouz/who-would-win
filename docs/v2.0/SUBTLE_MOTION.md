# Restrained arcade motion — September 27, 2026

Owner direction: add subtle life to winners and selected design elements, with occasional surprises and no large or constant effects.

- Home features gently staggered creature breaths, with long resting intervals. Only the selected carousel page animates. The existing animated logo uses the same visibility/lifecycle clock.
- Solo winners, team MVPs and tournament champions make a 2-point lift with a small lean and receive a single fading pixel glint, separated in time. Facts show a gentle idle breath. Text, frames, rosters and collection grids remain still.
- The selected-fighter remove icon now contrasts with its dark background and names the fighter for VoiceOver; selection/clear behavior is checked through the real picker.
- Raised buttons settle over 100ms. Toggle feedback is shortened; coin rewards scale to 1.06 rather than 1.18. Confetti remains a finite one-shot, with cancellable delayed work. The sticker-book entrance is softened.
- Ambient clocks run at most 12 Hz and require an active scene, uncovered screen, visible element and more than half the artwork inside the screen viewport. Reduce Motion disables the new ambient transforms. Exported cards use static defaults. No added sound, haptics, network requests or reward triggers.

Implementation remains on develop/2.0. The original 1.1.7 checkout, result logic, settlement, saved data, subscription rules, artwork generation and backend are unchanged. Build 116 passed native, visual, temporal and upgrade QA and is available in the existing internal TestFlight group. See [the release report](TESTFLIGHT_116_REPORT.md) for measured evidence and the remaining physical-device checks.
