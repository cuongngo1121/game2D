# Map restoration prompts

Built-in image_gen; only local generated repairs were composited onto the original full-resolution PNG.

## Initial context repair

Use case: precise-object-edit.
Asset type: original high resolution top-down game map, local restoration patch.
Image 1 is the ONLY edit target: a 1248 by 1664 pixel original-resolution crop from a larger 5120x3840 map. Image 2 is an annotation/reference identifying defects only, DO NOT copy the red circles.
Restore defects in Image 1 with surgical local edits:
1. Remove the superfluous vertical rectangular wall/panel spur outside the upper-left corner of the upper room. This redundant block lies approximately at x=250..425, y=205..410 in Image 1, immediately LEFT of the real room's vertical upper-left wall at x=435. Replace the spur with matching very dark textured empty background. Preserve the legitimate leftward room step and its horizontal top wall around y=420, connecting cleanly to the real vertical room wall at x=440. The protruding rectangular two-panel column must be gone, leaving empty black-green background above the horizontal step, with a clean continuous exterior silhouette.
2. Repair the broken/torn misaligned L-shaped interior corner near x=385..480, y=910..1090 of Image 1, where the horizontal corridor wall meets the ascending left corridor wall. Remove the duplicate short floating corner/wall fragment; rebuild ONE continuous, crisp, aligned right-angle masonry wall with coherent cyan lighting and dark shadow.
3. Repair the obvious diagonal pasted-image seam on the passage floor approximately x=450..640, y=1080..1260 and the smeared horizontal splice across the right corridor wall around x=530..675,y=1160..1260. Restore continuous stone block edges, fine floor vine ornament and a crisp natural right-angle bend, retaining precisely the existing walkable route and exterior wall contour.
Keep every other region unchanged. This is a repair, no redesign, no new objects. LOCK original composition, pixel coordinates, framing, relative scale, all major geometry, all rooms and corridors, golden botanical filigree, turquoise/cyan neon strips, green stone, sharp detailed hand-painted material, original lighting and dark background. Do not shift, rotate, zoom, crop, reframe or change contrast. Especially preserve the main circular floor pattern and all intact wall blocks. Output the SAME 1248x1664 framing at original detail or higher, lossless PNG. NO red marks, labels, text, watermark or extra objects.

## Final restoration strip

Use case: precise-object-edit. Asset: surgical restoration strip for an existing 5120x3840 game map.
IMAGE 1 is the ONLY edit target: a 768x1408 crop at its native pixel size. Preserve EXACT framing and pixel-proportional coordinates, render at 1536x2816 if possible for fine detail, or at least 768x1408.
IMAGE 2 is a supporting reference showing the intended local wall repairs; do not adopt its reframing or alter the entire painting.
ONLY fix three neighboring defects in Image 1:
(1) DELETE the isolated redundant upright rectangular two-panel wall spur at x=65..240,y=95..300, outside LEFT of the upper room's real vertical wall x=250. Fill with original nearly-black green textured backdrop. Keep the legitimate horizontal step wall at y=313 and real vertical wall at x=250, meeting in one clean masonry corner.
(2) Restore ONE continuous L-shaped wall corner at x=185..295,y=775..960. The left-facing horizontal corridor wall at y=909 must turn smoothly upward into the vertical room access wall x=252. Remove the broken duplicated short stone corner currently at y=862; fill and align solid, crisp original stone blocks, cyan strips and dark exterior shadows.
(3) Repair the bad diagonal collage cut on the floor at x=276..435,y=965..1132 and the horizontally smeared wall splice at x=327..499,y=1047..1145. Continue the existing crisp stone wall vertically then leftwards around the bend, and continue the gold vine engravings naturally across the floor. Match surrounding material detail.
Do not redesign or change intact filigree. Keep ALL intact details, dark green values, cyan lighting, gold vine ornament, wall block texture, positions, scale, colors and route width exactly matched to Image 1. No global recoloring, lightening or smoothing. Do not add or remove any passages, room steps, or objects except the specifically redundant top-left spur. Output just the repaired Image 1 with exactly the same crop/framing and 6:11 aspect ratio, original sharp handpainted detail, lossless PNG. No annotations, circles, grid, text or watermarks.

