package main

Rect :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
	radius: f32,
}

Vec2 :: distinct [2]f32

Col :: distinct [4]f32


draw_rect :: proc(layer: ^Layer, rect: Rect, col: Col) {
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

draw_text :: proc(layer: ^Layer, text: string, pos: Vec2, col: Col, size: FT_UInt = 16) {
	if FT_Set_Pixel_Sizes(layer.font_face, 0, size) != 0 {
		return
	}

	pen_x := pos.x

	for character in text {
		pen_x = draw_glyph(
			layer,
			layer.font_face,
			character,
			pen_x,
			pos.y,
			col.r,
			col.g,
			col.b,
			col.a,
		)
	}
}
