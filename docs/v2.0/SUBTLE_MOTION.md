# Restrained arcade motion — September 27, 2026

Owner direction: add subtle life to winners and selected design elements, with occasional surprises and no large or constant effects.

- Home features gently staggered creature breaths, with long resting intervals. Only the selected carousel page animates. The existing animated logo uses the same visibility/lifecycle clock.
- Solo winners, team MVPs and tournament champions make a 2-point lift with a small lean and receive a single fading pixel glint, separated in time. Facts show a gentle idle breath. Text, frames, rosters and collection grids remain still.
- Raised buttons settle over 100ms. Toggle feedback is shortened; coin rewards scale to 1.06 rather than 1.18. Confetti remains a finite one-shot, with cancellable delayed work. The sticker-book entrance is softened.
- Ambient clocks run at most 12 Hz and require an active scene, uncovered screen, visible element and more than half the artwork inside the screen viewport. Reduce Motion disables the new ambient transforms. Exported cards use static defaults. No added sound, haptics, network requests or reward triggers.

Implementation remains on develop/2.0. The original 1.1.7 checkout, result logic, settlement, saved data, subscription rules, artwork generation and backend are unchanged. Build 116 is allocated for internal TestFlight; allocation alone is not release approval. Final native/temporal/upgrade evidence and actual availability will be recorded after verification.
