package main

import "core:fmt"

draw_glyph :: proc(
	layer: ^Layer,
	face: FT_Face,
	character: rune,
	pen_x: f32,
	baseline_y: f32,
	r, g, b, a: f32,
) -> f32 {
	if FT_Load_Char(face, FT_ULong(character), FT_LOAD_RENDER) != 0 {
		fmt.eprintln("Failed to load glyph:", character)
		return pen_x
	}

	face_rec := cast(^FT_FaceRec)face
	glyph := face_rec.glyph

	if glyph == nil {
		return pen_x
	}

	width := glyph.bitmap.width
	height := glyph.bitmap.rows

	// Spaces etc. can have no bitmap but still have an advance.
	if width == 0 || height == 0 {
		return pen_x + f32(glyph.advance.x >> 6)
	}

	x := pen_x + f32(glyph.bitmap_left)
	y := baseline_y - f32(glyph.bitmap_top)

	w := f32(width)
	h := f32(height)

	vertices := [24]f32 {
		// position       // UV
		x,
		y,
		0.0,
		0.0,
		x + w,
		y,
		1.0,
		0.0,
		x + w,
		y + h,
		1.0,
		1.0,
		x,
		y,
		0.0,
		0.0,
		x + w,
		y + h,
		1.0,
		1.0,
		x,
		y + h,
		0.0,
		1.0,
	}

	texture: u32

	glGenTextures(1, &texture)
	defer glDeleteTextures(1, &texture)

	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, texture)

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

	glTexImage2D(
		GL_TEXTURE_2D,
		0,
		i32(GL_ALPHA),
		i32(width),
		i32(height),
		0,
		GL_ALPHA,
		GL_UNSIGNED_BYTE,
		glyph.bitmap.buffer,
	)

	glBindBuffer(GL_ARRAY_BUFFER, layer.text_vbo)

	glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])

	glUniform4f(layer.text_color_location, r, g, b, a)

	glUniform1i(layer.text_texture_location, 0)

	glDrawArrays(GL_TRIANGLES, 0, 6)

	return pen_x + f32(glyph.advance.x >> 6)
}
