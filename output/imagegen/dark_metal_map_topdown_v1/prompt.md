# Dark metal map refinement

Tool: built-in ImageGen. Deliverable: a standalone PNG, no runtime integration.

Use case: precise-object-edit / top-down game map visual refinement.
Asset type: a finished full 2D gameplay background, 4:3 landscape, for a 5120x3840 PNG export.

Image 1 is the ONLY edit target and geometry reference: the dark graphite industrial map with SIX rooms, fine dusty rose/soft white lighting, and concentric circular floor motifs.
Image 2 (the violet crystal map) is ONLY a visual reference for a true overhead camera, simplified flat wall borders, and clean uninterrupted floor-to-wall boundaries. Never adopt Image 2's room positions, diamond motifs, blue/violet lighting or palette.

Improve Image 1 in the same practical way:
1. TRUE TOP-DOWN ORTHOGRAPHIC VIEW. The camera looks vertically straight down. Wall footprints are upright horizontal/vertical parallel segments with 90-degree corners. Remove the leaning 3D camera appearance and thick extruded south-facing wall facades. Retain subtle top-surface bevel shading and convincing painted metal texture. Keep the existing inner and outer wall contours, doorway positions and walkway widths fixed; correct visual perspective through consistent surface rendering, not by relocating walls.
2. CLEAN COLLISION-TRACING EDGES. Simplify small machinery, greebles, uneven protrusions, raised fittings and busy decoration immediately beside walls. There must be a clear, sharp continuous inside edge between the floor and the wall at every bend and doorway. Leave a plain dark graphite floor border just inside room walls (about 5% of the local room width); only subdued material grain in this border. Existing floor and wall footprints must remain intact. Do not enlarge the walkable area. Corridor floors should be open, clean, quiet and have sparse straight panel seams.
3. MATERIAL FIDELITY. Refine the quality of the existing dark industrial metal: crisp aligned modular panels, fine joints, subtle wear, brushed graphite, inset border trims and small recessed light strips. Keep the center floor motifs as elegant concentric machined rings with restrained straight radial/cross circuit lines. Make the material more legible through a small local contrast improvement, but retain the dark atmospheric tone and keep floor brightness low enough for gameplay. Avoid a shiny plastic/cartoon/vector appearance.
4. COLOR LOCK. Preserve charcoal, gunmetal, near-black muted graphite and very subtle smoky brown/dusty rose accents, with restrained pale rose/off-white light strips as in Image 1. No cyan, electric blue, green, purple or magenta recoloring. No plants, organic roots or crystal motifs. Outside the map remains the original almost-black lightly textured empty void.

EXACT LAYOUT TO PRESERVE: keep all SIX rooms at the same relative positions, same sizes, same contour steps, same routes, same openings and same crop. Five rooms form the main path from bottom-left toward top-right, with one left dead-end branch near the top:
- Large start room centered near (12%,82%).
- Its upper-right opening enters a corridor that goes up, right, then enters the small main room near (33%,62%).
- From that room the right opening enters a stepped corridor bending upwards/right into the larger chamber near (58%,53%).
- From that larger chamber's upper-right side, a straight vertical corridor rises into the upper junction chamber near (62.5%,25%).
- From the upper junction, a horizontal left corridor ends at the small side room near (44%,25%).
- From the upper junction, a horizontal right corridor reaches the large final room near (87%,24%).
This is the same exact connected route as Image 1. Do not move, add, remove or resize rooms. Preserve all existing right-angle steps and the single side branch. Do not widen corridors, add doors, block passages, cut the map at the edges, or turn the whole diagonal route into a straight line.

Render as ONE coherent seamless continuous map, consistent texture detail across rooms/corridors and junctions. No rectangular patches, lighting bands, abrupt resolution shifts or collage seams. No props, furniture, crates, towers, characters, enemies, weapons, UI, grid overlays, arrows, labels, numbers, text or watermarks. Output the complete map only, maximum supported sharp high resolution for 5120x3840 delivery. Preserve the exact full 4:3 canvas framing.

