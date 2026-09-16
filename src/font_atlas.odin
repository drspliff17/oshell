package main

import "core:fmt"

cache_glyph :: proc(layer: ^Layer, character: rune, size: FT_UInt) -> (Glyph, bool) {
	if FT_Set_Pixel_Sizes(layer.font_face, 0, size) != 0 {
		fmt.eprintln("Failed to set FreeType pixel size")
		return {}, false
	}

	if FT_Load_Char(layer.font_face, FT_ULong(character), FT_LOAD_RENDER) != 0 {
		fmt.eprintln("Failed to load glyph:", character)
		return {}, false
	}

	face_rec := cast(^FT_FaceRec)layer.font_face
	slot := face_rec.glyph

	if slot == nil {
		return {}, false
	}

	width := i32(slot.bitmap.width)
	height := i32(slot.bitmap.rows)

	glyph := Glyph {
		width     = width,
		height    = height,
		bearing_x = slot.bitmap_left,
		bearing_y = slot.bitmap_top,
		advance   = i32(slot.advance.x >> 6),
	}

	// Spaces and similar glyphs can have an advance
	// without having any bitmap pixels.
	if width == 0 || height == 0 {
		return glyph, true
	}

	padding := i32(1)

	// Move to a new row if this glyph doesn't fit.
	if layer.font.pen_x + width + padding >= layer.font.width {
		layer.font.pen_x = padding
		layer.font.pen_y += layer.font.row_height + padding
		layer.font.row_height = 0
	}

	// Make sure the atlas still has room.
	if layer.font.pen_y + height + padding >= layer.font.height {
		fmt.eprintln("Font atlas is full")
		return {}, false
	}

	glyph.x = layer.font.pen_x
	glyph.y = layer.font.pen_y

	glActiveTexture(GL_TEXTURE0)

	glBindTexture(GL_TEXTURE_2D, layer.font.texture)

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1)

	glTexSubImage2D(
		GL_TEXTURE_2D,
		0,
		glyph.x,
		glyph.y,
		glyph.width,
		glyph.height,
		GL_ALPHA,
		GL_UNSIGNED_BYTE,
		slot.bitmap.buffer,
	)

	layer.font.pen_x += width + padding

	if height > layer.font.row_height {
		layer.font.row_height = height
	}

	return glyph, true
}
