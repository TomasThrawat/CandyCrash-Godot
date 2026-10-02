# Candy Crash Visual Design Spec

Designed in OpenPencil on a 720x1280 mobile canvas.

## Active Level Geometry

- Header: 24,24 -> 696,124
- Back: 42,46 -> 84,98
- Title: 104,42
- Pause: 584,46 -> 666,98
- HUD bar: 28,142 -> 692,238
- Score card: 44,157 -> 240,223
- Moves card: 262,157 -> 458,223
- Goal card: 480,157 -> 676,223
- Board: 48,254 -> 672,878
- Play grid: 8 columns x 8 rows, 72px cells, origin 72,278
- Boosters: 40,900 -> 680,1064
- Footer: 40,1082 -> 680,1158

## Candy Art

Each candy has a different silhouette:
1. Heart / cherry
2. Diamond / blueberry
3. Five-point star / lemon
4. Leaf / mint
5. Organic jelly blob / grape
6. Faceted hex / orange

Colors are secondary identifiers. Silhouette is primary.

## Fit Rules

The 576px playable grid stays centered inside the 624px board with 24px padding on all sides. HUD never overlaps the board. Booster controls stay below the board. Controls remain touch-friendly.
