package main

draw_glyph :: proc(
	layer: ^Layer,
	character: rune,
	size: FT_UInt,
	pen_x: f32,
	baseline_y: f32,
) -> f32 {
	glyph, ok := cache_glyph(layer, character, size)

	if !ok {
		return pen_x
	}

	// Spaces and similar glyphs can have an advance
	// without having any pixels to draw.
	if glyph.width == 0 || glyph.height == 0 {
		return pen_x + f32(glyph.advance)
	}

	x := pen_x + f32(glyph.bearing_x)
	y := baseline_y - f32(glyph.bearing_y)

	w := f32(glyph.width)
	h := f32(glyph.height)

	u0 := f32(glyph.x) / f32(layer.font.width)

	v0 := f32(glyph.y) / f32(layer.font.height)

	u1 := f32(glyph.x + glyph.width) / f32(layer.font.width)

	v1 := f32(glyph.y + glyph.height) / f32(layer.font.height)

	vertices := [24]f32 {
		x,
		y,
		u0,
		v0,
		x + w,
		y,
		u1,
		v0,
		x + w,
		y + h,
		u1,
		v1,
		x,
		y,
		u0,
		v0,
		x + w,
		y + h,
		u1,
		v1,
		x,
		y + h,
		u0,
		v1,
	}

	glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])

	glDrawArrays(GL_TRIANGLES, 0, 6)

	return pen_x + f32(glyph.advance)
}
