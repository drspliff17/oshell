package main

import "core:fmt"

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

snap_pixel :: proc(value: f32) -> f32 {
	if value >= 0 do return f32(i32(value + 0.5))
	return f32(i32(value - 0.5))
}

centered_text_baseline :: proc(layer: ^Layer, rect: Rect, size: FT_UInt) -> f32 {
	// Fixed ascender + descender reference so vertical positioning
	// does not depend on the actual characters being drawn.
	metrics := measure_text(layer, "Hg", size)
	text_height := metrics.ascent + metrics.descent

	return snap_pixel(rect.y + (rect.height - text_height) * 0.5 + metrics.ascent)
}

draw_rect :: proc(layer: ^Layer, rect: Rect, col: Col) {
	if rect.width <= 0 || rect.height <= 0 do return

	x0 := snap_pixel(rect.x)
	y0 := snap_pixel(rect.y)

	x1 := snap_pixel(rect.x + rect.width)
	y1 := snap_pixel(rect.y + rect.height)

	width := x1 - x0
	height := y1 - y0

	if width <= 0 || height <= 0 do return

	radius := min(max(rect.radius, 0), min(width, height) * 0.5)
	border_size := min(max(rect.border_size, 0), min(width, height) * 0.5)
	border_col := rect.border_col
	if border_size <= 0 do border_col = col

	vertices := [12]f32{x0, y0, x1, y0, x1, y1, x0, y0, x1, y1, x0, y1}

	glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])
	glUniform2f(layer.rect_position_location, x0, y0)
	glUniform2f(layer.rect_size_location, width, height)
	glUniform1f(layer.rect_radius_location, radius)
	glUniform1f(layer.border_size_location, border_size)
	glUniform4f(layer.color_location, col.r, col.g, col.b, col.a)

	glUniform4f(
		layer.border_color_location,
		border_col.r,
		border_col.g,
		border_col.b,
		border_col.a,
	)

	glDrawArrays(GL_TRIANGLES, 0, 6)
}

draw_text :: proc(layer: ^Layer, text: string, pos: Vec2, col: Col, size: FT_UInt = 16) {
	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, layer.font.texture)

	glUniform1i(layer.text_texture_location, 0)
	glUniform4f(layer.text_color_location, col.r, col.g, col.b, col.a)

	pen_x := snap_pixel(pos.x)
	baseline_y := snap_pixel(pos.y)

	for character in text do pen_x = draw_glyph(layer, character, size, pen_x, baseline_y)
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

	if glyph.width == 0 || glyph.height == 0 do return pen_x + f32(glyph.advance)

	x := snap_pixel(pen_x + f32(glyph.bearing_x))
	y := snap_pixel(baseline_y - f32(glyph.bearing_y))

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

truncate_text :: proc(
	layer: ^Layer,
	text: string,
	size: FT_UInt,
	max_width: f32,
	buffer: []u8,
) -> string {
	if text == "" do return ""
	if measure_text(layer, text, size).width <= max_width do return text

	ellipsis :: "..."
	ellipsis_width := measure_text(layer, ellipsis, size).width
	if ellipsis_width > max_width do return ""

	width: f32
	end := 0

	for character, index in text {
		glyph, ok := cache_glyph(layer, character, size)
		if !ok do continue

		next_width := width + f32(glyph.advance)
		if next_width + ellipsis_width > max_width do break

		width = next_width
		end = index

		if character < 0x80 {
			end += 1
		} else if character < 0x800 {
			end += 2
		} else if character < 0x10000 {
			end += 3
		} else {
			end += 4
		}
	}

	if end <= 0 do return ellipsis
	return fmt.bprintf(buffer, "%s%s", text[:end], ellipsis)
}
