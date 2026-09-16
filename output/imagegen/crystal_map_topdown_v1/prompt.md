# Crystal map top-down correction

Tool: built-in image_gen.

Use case: precise-object-edit / projection correction and environment cleanup.
Asset: polished playable 2D top-down level background, desired delivery 5120x3840 PNG, landscape 4:3.
INPUT IMAGE 1 is the edit target: the blue-violet crystal sci-fi dungeon with SIX rooms and one dead-end side branch.
INPUT IMAGE 2 (green map) is ONLY a reference for an upright top-down camera, clean continuous wall silhouette, and easily traceable floor-to-wall edges. DO NOT adopt its layout, green palette, room count, plants or botanical patterns.

Edit IMAGE 1 into a TRUE VERTICAL OVERHEAD, ORTHOGRAPHIC TOP-DOWN MAP. Correct its tilted 3D perspective. All room and corridor footprint edges must be exactly horizontal or vertical in the image, opposite edges parallel, 90-degree corners, no vanishing point, no trapezoid perspective, no shear or camera roll. Preserve painted surface richness and subtle edge bevels, but remove tall south-facing 3D wall facades and uneven extruded platform depth. Use shallow, uniform-width low wall rims viewed directly from above with equally subtle shading on every side.

CRITICAL LAYOUT INVARIANTS: keep exactly the SAME SIX rooms, their relative sizes and positions, and the SAME connections and bends from IMAGE 1. Layout still runs diagonally across the canvas from bottom-left to top-right, although each individual wall segment is axis-aligned. Do not rotate the route to a horizontal line.
- Large start room near (8.5% width, 83% height).
- Bent stair-step corridor runs from its upper-right toward the first main junction room near (38.5%,55%).
- This first junction has a straight downward dead-end branch to the small room near (39.5%,78%).
- Its right-side route bends upwards then right into the next main chamber near (59.5%,41.5%).
- From that chamber a short upward corridor connects the cross-shaped chamber near (63.2%,16.5%).
- A straight horizontal corridor from that upper chamber connects to the large final rectangular room near (89.5%,18.5%).
Preserve all legitimate stepped room outlines and alcoves. No extra paths, holes, bridges, doors blocking paths, extra rooms or broken connections. All six rooms remain fully visible, no clipping at frame edges.

CLEAN BOUNDARIES FOR COLLISION TRACING: simplify the decorative clutter along EVERY wall and bend. Remove raised consoles, pipes, machinery, debris, protruding crystals and busy little ornaments close to walls. Make each inner floor boundary an uninterrupted, easily traced, sharp right-angle contour. Along the inside perimeter of each room leave a continuous plain dark slate floor strip about 7 percent of the room width, with very subdued stone texture and no intersecting luminous ornaments. Keep this edge band consistent through corners and openings. Corridors have clean open dark floor and clear straight edges, only sparse shallow panel joints; remove dense corridor filigree. Wall design is simple consistent rectangular blue-black stone/metal blocks with occasional thin cyan/violet light insets flush to the wall, nothing sticking over the walkable floor.

STYLE AND DETAIL: retain the original rich midnight-blue, indigo, purple and electric-cyan crystal-temple identity. Preserve a carefully drawn inset crystalline geometric diamond/star motif at the CENTER of each of the six room floors, with luminous fine facets. Concentrate ornamental detail in the central room medallions; taper down to clear uncluttered edge bands. High-quality detailed game environment art, crisp material seams, sophisticated controlled lighting, moderate glow that does not obscure the boundary, subtle worn crystalline stone surface. Do not replace it with a schematic, simple vector diagram, blank flat color mockup or cartoon.
BACKGROUND: retain the very dark nearly-black navy empty background, no scenery or added props outside the map.
Output a finished clean map ONLY, 4:3 full framing, maximum supported high resolution and sharp texture detail for 5120x3840 export. No text, labels, markers, collision overlays, grid, characters, UI, watermark or red circles.

