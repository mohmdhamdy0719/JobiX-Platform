---
name: Flutter layout quirks in Jobix
description: Theme-level button sizing constraint to respect when placing themed buttons side by side.
---
The app theme gives buttons an infinite-width minimum size (full-width by default). A themed button inside a Row or Wrap must be given a finite minimum width or be wrapped in Expanded/Flexible.
**Why:** an unbounded minimum width inside a Row throws during layout and breaks every screen that uses the row.
**How to apply:** whenever buttons share a horizontal row.
