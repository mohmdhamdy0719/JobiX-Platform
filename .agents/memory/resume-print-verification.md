---
name: Resume print verification
description: Avoid false renderer regressions from bidi extraction and font-box geometry
---

Keep logical DOM/source preservation and physical print checks separate; do not
change the product renderer just to make Poppler's output resemble logical
Arabic text.

**Why:** Poppler can expose presentation ligatures, reorder mixed-direction
digits, and report font ascent/descent boxes extending beyond the CSS line box.
A valid Arabic section word can also occur in ordinary metadata. These produced
false failures while the canonical rendered document was correct.

**How to apply:** Normalize shaping and bidi controls without discarding
punctuation or repeated text. Check source order in the DOM, preservation in
extracted print text, and heading cohesion using real positions/font boxes.
Retain unique fixture markers for pagination assertions. Never treat offline
Chromium proof as native WebView, signing, phone or restart acceptance.
