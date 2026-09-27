# Readable paragraphs — September 27, 2026

The owner reported that battle stories and other text blocks were hard to read. The prior compatibility font converted nominal 12–13-point body copy into an 8–8.6-point pixel face. Pixel lettering remains appropriate for titles and short arcade labels; paragraphs now use a separate reading style.

`readingText` uses the native serif body font (17 points at the default text size), or its callout style (16 points) for secondary guidance. Both follow Dynamic Type. Five-point line spacing scales with the reading size, and text grows vertically instead of shrinking or truncating. Solo, team and tournament story cards cap their width at 640 points on larger displays and retain opaque cream reading surfaces.

The same style covers facts, help, settings, parent guidance, commerce disclosures, fighter-library explanations, setup instructions and story/fact share cards. Help-page, parent PIN and tournament daily-limit content scroll to keep their controls reachable with larger text. Pixel controls, scores and titles retain the arcade appearance.

A long-story preview also exposed an existing cleanup bug: removing emoji collapsed paragraph breaks. Cleanup now collapses horizontal whitespace while preserving CR/LF boundaries. A focused regression checks paragraph retention and the existing emoji-only fallback. This does not change winners, rewards or requests.

Dedicated isolated fixtures exercise three-paragraph solo, team and tournament stories plus longer animal facts. The existing screenshot test verifies full text, paragraph breaks, scrolling and reachable ending controls. A targeted AX3 pass uses the native preferred text size and verifies the value received by SwiftUI. These are simulator checks, not owner-device or live-account verification.

Build 117 is available in internal TestFlight, verified September 27, 2026. The [release report](TESTFLIGHT_117_REPORT.md) records the final iPhone/iPad and larger-text reviews, signed upload and Apple availability. No storage migration, backend deployment, paid artwork request or subscription change is part of this update.
