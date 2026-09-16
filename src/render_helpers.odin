package main

draw_rect :: proc(layer: ^Layer, x, y, width, height: f32, r, g, b, a: f32) {
	vertices := [12]f32 {
		x,
		y,
		x + width,
		y,
		x + width,
		y + height,
		x,
		y,
		x + width,
		y + height,
		x,
		y + height,
	}

	glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])

	glUniform4f(layer.color_location, r, g, b, a)

	glDrawArrays(GL_TRIANGLES, 0, 6)
}
