package main

import "core:fmt"

reset_font_atlas :: proc(layer: ^Layer) {
	font := &layer.font

	clear(&font.glyphs)

	font.pen_x = 1
	font.pen_y = 1
	font.row_height = 0

	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, font.texture)

	glTexImage2D(
		GL_TEXTURE_2D,
		0,
		i32(GL_ALPHA),
		font.width,
		font.height,
		0,
		GL_ALPHA,
		GL_UNSIGNED_BYTE,
		nil,
	)

	if DEBUG do fmt.println("font atlas reset")
}

cache_glyph :: proc(layer: ^Layer, character: rune, size: FT_UInt) -> (Glyph, bool) {
	font := &layer.font

	key := Glyph_Key{character, size}

	// Already cached.
	if glyph, ok := font.glyphs[key]; ok {
		return glyph, true
	}

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

	if slot == nil do return {}, false

	width := i32(slot.bitmap.width)
	height := i32(slot.bitmap.rows)

	glyph := Glyph {
		width     = width,
		height    = height,
		bearing_x = slot.bitmap_left,
		bearing_y = slot.bitmap_top,
		advance   = i32(slot.advance.x >> 6),
	}

	// Spaces and similar glyphs have metrics but no bitmap.
	if width == 0 || height == 0 {
		font.glyphs[key] = glyph
		return glyph, true
	}

	padding := i32(1)

	// Start a new atlas row if this glyph does not fit horizontally.
	if font.pen_x + width + padding >= font.width {
		font.pen_x = padding
		font.pen_y += font.row_height + padding
		font.row_height = 0
	}

	// Atlas full: throw away the cache and begin again.
	if font.pen_y + height + padding >= font.height {
		reset_font_atlas(layer)

		font.pen_x = padding
		font.pen_y = padding
	}

	glyph.x = font.pen_x
	glyph.y = font.pen_y

	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, font.texture)

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

	font.pen_x += width + padding

	if height > font.row_height do font.row_height = height

	// Actually cache it.
	font.glyphs[key] = glyph

	return glyph, true
}
