package main

Text_Metrics :: struct {
	width:   f32,
	ascent:  f32,
	descent: f32,
}

Padding_Type :: enum {
	TOP,
	LEFT,
	BOTTOM,
	RIGHT,
	HORIZONTAL,
	VERTICAL,
	ALL,
}

Padding :: struct {
	top:    f32,
	left:   f32,
	bottom: f32,
	right:  f32,
}

Rect :: struct {
	border_col:  Col,
	padding:     Padding,
	x:           f32,
	y:           f32,
	width:       f32,
	height:      f32,
	radius:      f32,
	border_size: f32,
}

Vec2 :: distinct [2]f32

Col :: distinct [4]f32


get_padding :: proc(value: f32, kind: Padding_Type = .ALL) -> Padding {
	switch kind {
	case .TOP:
		return Padding{top = value}

	case .LEFT:
		return Padding{left = value}

	case .BOTTOM:
		return Padding{bottom = value}

	case .RIGHT:
		return Padding{right = value}

	case .HORIZONTAL:
		return Padding{left = value, right = value}

	case .VERTICAL:
		return Padding{top = value, bottom = value}

	case .ALL:
		return Padding{top = value, left = value, bottom = value, right = value}
	}

	return {}
}

rect_content :: proc(rect: Rect) -> Rect {
	return Rect {
		x = rect.x + rect.padding.left,
		y = rect.y + rect.padding.top,
		width = max(0, rect.width - rect.padding.left - rect.padding.right),
		height = max(0, rect.height - rect.padding.top - rect.padding.bottom),
	}
}

draw_rect_raw :: proc(layer: ^Layer, rect: Rect, col: Col) {
	if rect.width <= 0 || rect.height <= 0 {
		return
	}

	rad := min(rect.radius, min(rect.width, rect.height) * 0.5)

	vertices := [12]f32 {
		rect.x,
		rect.y,
		rect.x + rect.width,
		rect.y,
		rect.x + rect.width,
		rect.y + rect.height,
		rect.x,
		rect.y,
		rect.x + rect.width,
		rect.y + rect.height,
		rect.x,
		rect.y + rect.height,
	}

	glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])

	glUniform2f(layer.rect_position_location, rect.x, rect.y)

	glUniform2f(layer.rect_size_location, rect.width, rect.height)

	glUniform1f(layer.rect_radius_location, rad)

	glUniform4f(layer.color_location, col.r, col.g, col.b, col.a)

	glDrawArrays(GL_TRIANGLES, 0, 6)
}

draw_rect :: proc(layer: ^Layer, rect: Rect, col: Col) {
	border_size := max(rect.border_size, 0)

	if border_size > 0 {
		// Draw the border as the outer rounded rectangle.
		draw_rect_raw(layer, rect, rect.border_col)

		// Draw the fill slightly inset on top.
		inner := Rect {
			x      = rect.x + border_size,
			y      = rect.y + border_size,
			width  = rect.width - border_size * 2,
			height = rect.height - border_size * 2,
			radius = max(0, rect.radius - border_size),
		}

		draw_rect_raw(layer, inner, col)

		return
	}

	draw_rect_raw(layer, rect, col)
}

draw_text :: proc(layer: ^Layer, text: string, pos: Vec2, col: Col, size: FT_UInt = 16) {
	glActiveTexture(GL_TEXTURE0)

	glBindTexture(GL_TEXTURE_2D, layer.font.texture)

	glUniform1i(layer.text_texture_location, 0)

	glUniform4f(layer.text_color_location, col.r, col.g, col.b, col.a)

	pen_x := pos.x

	for character in text {
		pen_x = draw_glyph(layer, character, size, pen_x, pos.y)
	}
}

draw_glyph :: proc(
	layer: ^Layer,
	character: rune,
	size: FT_UInt,
	pen_x: f32,
	baseline_y: f32,
) -> f32 {
	glyph, ok := cache_glyph(layer, character, size)
	if !ok do return pen_x

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

measure_text :: proc(layer: ^Layer, text: string, size: FT_UInt = 16) -> Text_Metrics {
	metrics := Text_Metrics{}

	for character in text {
		glyph, ok := cache_glyph(layer, character, size)
		if !ok do continue

		metrics.width += f32(glyph.advance)

		ascent := f32(glyph.bearing_y)
		descent := f32(glyph.height) - f32(glyph.bearing_y)

		metrics.ascent = max(metrics.ascent, ascent)
		metrics.descent = max(metrics.descent, descent)
	}

	return metrics
}
