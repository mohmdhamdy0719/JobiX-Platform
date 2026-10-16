---
name: Flutter layout quirks in Jobix
description: Theme-level sizing and overlay-lifetime constraints that affect Flutter UI behavior.
---
The app theme gives buttons an infinite-width minimum size (full-width by default). A themed button inside a Row or Wrap must be given a finite minimum width or be wrapped in Expanded/Flexible.
**Why:** an unbounded minimum width inside a Row throws during layout and breaks every screen that uses the row.
**How to apply:** whenever buttons share a horizontal row.

Dialog text controllers should be owned and disposed by the dialog's own State, not by the caller after `showDialog` returns; route completion precedes the exit animation. Floating feedback should reserve bottom space for fixed actions and system insets so it cannot cover primary buttons.
**Why:** immediate caller disposal can break the dialog during its transition, and bottom overlays can intercept taps on persistent actions.
**How to apply:** for dialogs containing editable fields and app-wide floating SnackBars on screens with bottom actions.
