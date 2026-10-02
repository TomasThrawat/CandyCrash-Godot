# Candy Crash

A polished mobile-first 2D match-3 game built with Godot 4.7.

## Included systems

- 8x8 match-3 board with touch, mouse, and swap input
- Match detection, cascades, combo scoring, and safe refill
- Horizontal, vertical, wrapped, and color-bomb special candies
- Special-candy combo handling
- Score, moves, blockers, collect-color, and jelly objectives
- 36 playable levels with progressive difficulty
- Level map with unlock progression and 1-3 star ratings
- Hammer, shuffle, color-bomb, and extra-move boosters
- Animated swaps, pops, falling refills, pulses, and particle bursts
- Win/lose/pause/settings overlays
- Persistent progress and settings in user://candy_crash_save.json
- Sound effects and an original procedural background loop
- Portrait 720x1280 layout with mobile-friendly touch targets
- Procedural candy rendering, so the core gameplay has no external art dependency

## Audio

Gameplay sound effects were selected from the SFXMint puzzle-game set, which reports CC0-1.0 licensing. The project keeps the selected WAV files under assets/audio/.

## Running

Open the project with Godot 4.7+ and run Main.tscn.

The CI workflow validates project parsing and performs a headless startup smoke test.
