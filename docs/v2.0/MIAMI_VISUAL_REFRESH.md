# Miami arcade presentation — September 27, 2026

Owner direction: make the home preview actionable, use the existing retro type across app-owned screens, restore the animated 1.1.7 logo in a matching style, and replace the mint/gray look with a Miami-inspired arcade palette.

Implemented on develop/2.0:

- Five randomly selected, unlocked catalog matchups per home session. Native horizontal paging, previous/next controls, visible page state, and a button that starts exactly the displayed pair. The normal picker is now labelled “Pick Your Fighters”; Surprise Me and every existing navigation route remain available.
- A compact two-line animated pixel logo with independent gentle rocking and pulse, paused when hidden, inactive, or Reduce Motion is enabled.
- Sunset pink, turquoise, gold and plum tokens; cut-corner cards/buttons and hard raised shadows; a sunset skyline and grid on the featured stage. App-owned surfaces share the palette, while system sheets keep their native behavior.
- Bundled Press Start 2P replaces proportional text in shared helpers, explicit text styles, forms, library, settings, commerce, facts, stories, and exports. SF Symbols remain icons. Dynamic Type and paragraph spacing are retained; sticker and team-share labels wrap instead of shrinking, and tournament exports use wider matchup cards.

This changes presentation and adds an entry to the existing battle route. Battle results, rewards, saved data, custom artwork service, subscriptions, product identifiers, entitlement checks and server configuration are unchanged. The protected 1.1.7 checkout and deployment remain separate.

Validation before the release-candidate freeze: the full first phone pass executed 76 unit and 16 UI tests with zero failures. Native phone and tablet screen review found and corrected low-contrast accent labels, tight paragraph leading, truncated sticker names and tournament export labels. Compact-phone captures covered the home, picker, settings and library at normal and accessibility text sizes; large settings labels were adjusted to wrap. Final candidate runs, upgrade evidence and release availability are recorded separately; these initial checks are not a claim that the candidate is already in TestFlight.
