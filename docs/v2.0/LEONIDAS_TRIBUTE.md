# Leonidas’s victory tribute

The built-in Great Dane is a tribute to the owner’s dog, Leonidas. On a winning result, his portrait becomes a quiet Easter egg. The first tap says “Good boy, Leo!” and plays a short happy bow, hop and proud pose with small pixel hearts. The third tap says “Goodnight, handsome.” with an affectionate settle. He remains visibly present. This uses the existing Great Dane artwork and four authored poses.

The interaction is limited to actual winners: a solo winner, a winning team member (the MVP portrait when applicable), a tournament match winner and a tournament champion. Other portraits keep their existing behavior. Custom fighters cannot opt into the tribute by using the same name or identifier.

A new result resets the interaction. Taps do not affect rewards, battle resolution, saved data or network services. A single cancellable sequence prevents overlapping animations; covered, offscreen and inactive views stop moving without replay on return. Reduce Motion retains the affectionate message and a static happy pose. A reserved speech slot keeps readable messages above the artwork without shifting Leo or neighboring fighters when tapped. Horizontal placement stays within the visible viewport, including the small team roster portrait. VoiceOver names the action “Celebrate with Leonidas.”

Implementation and QA belong to the separate develop/2.0 branch. Build 118 is available in internal TestFlight, verified with Apple on September 27, 2026. The [release report](TESTFLIGHT_118_REPORT.md) records the exact build, measured native/visual/motion checks, scoped retained evidence and owner-device checks.
