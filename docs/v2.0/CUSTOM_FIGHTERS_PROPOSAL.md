# Custom fighter appearance — proposal

Status: proposed, not implemented in build 112. Existing typed custom creation is preserved.

Keep typing a name, then offer an optional **Change look** sheet with one animated preview and **Body · Colour · Extras**. The name suggests a starting appearance; players can correct it. For example, “Blue Lion” starts with a blue lion, while an invented name starts with a stable fantasy creature. Copy: “Name your fighter. Choose its retro look.”

Use bundled animated bodies and local colour/effect choices. This needs no image API, provider key, or per-character image charge. The visual kit has a defined set of shapes; it does not promise an exact likeness for every imagined character. Existing narration and custom-selection coin/ad rules are separate.

The initial editor should reuse the 143 catalog bodies and 12 fantasy bases, each with idle, anticipation, attack and reaction artwork. Four poses form the existing battle action cycle; they are not separate walk, flight, or multi-frame attack clips. Only the selected preview should animate, and it should respect Reduce Motion. Start Extras with the existing sparkle, frost, leaf and lightning effects. Attached hats, wings and equipment need body-and-pose-specific anchors or authored variants before they can be offered.

Save a versioned appearance recipe on the existing custom Animal, preserving its ID, name, category, stats, outcomes and selection costs. Missing, malformed or future appearance fields must fall back independently without invalidating an old active tournament. One shared resolver must drive portraits, battles, motion profiles and exports; cache keys must include the appearance so two identically named fighters can look different. Editing or cancelling must not consume coins or the free custom selection. Commit once at the existing selection boundary.

Before shipping an editor, verify legacy tournament decoding, appearance persistence through a cold launch, ID continuity through rematches/brackets/exports, cache clearing, duplicate-charge guards, and every exposed cosmetic in all four poses and both facing directions. A saved custom roster or a new custom entry in team setup would be separate product work.
