package main

import "core:fmt"

app_init_renderer :: proc(app: ^App) -> bool {
	if len(app.layers) == 0 {
		fmt.eprintln("Cannot initialize renderer without a layer")
		return false
	}
	if !layer_make_current(app.layers[0]) do return false

	// Font atlas
	app.font.width = 1024
	app.font.height = 1024

	app.font.pen_x = 1
	app.font.pen_y = 1
	app.font.row_height = 0

	app.font.glyphs = make(map[Glyph_Key]Glyph)

	glGenTextures(1, &app.font.texture)

	if app.font.texture == 0 {
		fmt.eprintln("Failed to create font atlas texture")
		app_destroy_renderer(app)
		return false
	}

	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, app.font.texture)

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

	glTexImage2D(
		GL_TEXTURE_2D,
		0,
		i32(GL_ALPHA),
		app.font.width,
		app.font.height,
		0,
		GL_ALPHA,
		GL_UNSIGNED_BYTE,
		nil,
	)
	if DEBUG do fmt.println("font atlas created:", app.font.width, "x", app.font.height)

	// Rectangle shader
	app.program = create_program(RECT_VERTEX_SHADER, RECT_FRAGMENT_SHADER)

	if app.program == 0 {
		fmt.eprintln("Failed to create rectangle shader program")
		app_destroy_renderer(app)
		return false
	}

	app.rect_vertex_position_location = glGetAttribLocation(app.program, "position")
	app.resolution_location = glGetUniformLocation(app.program, "resolution")
	app.color_location = glGetUniformLocation(app.program, "color")
	app.rect_position_location = glGetUniformLocation(app.program, "rect_position")
	app.rect_size_location = glGetUniformLocation(app.program, "rect_size")
	app.rect_radius_location = glGetUniformLocation(app.program, "rect_radius")

	if app.rect_vertex_position_location < 0 {
		fmt.eprintln("Failed to find rectangle position attribute")
		app_destroy_renderer(app)
		return false
	}

	if app.resolution_location < 0 {
		fmt.eprintln("Failed to find resolution uniform")
		app_destroy_renderer(app)
		return false
	}

	if app.color_location < 0 {
		fmt.eprintln("Failed to find color uniform")
		app_destroy_renderer(app)
		return false
	}

	if app.rect_position_location < 0 {
		fmt.eprintln("Failed to find rect_position uniform")
		app_destroy_renderer(app)
		return false
	}

	if app.rect_size_location < 0 {
		fmt.eprintln("Failed to find rect_size uniform")
		app_destroy_renderer(app)
		return false
	}

	if app.rect_radius_location < 0 {
		fmt.eprintln("Failed to find rect_radius uniform")
		app_destroy_renderer(app)
		return false
	}

	if DEBUG do fmt.println("rectangle shader program created")

	// Rectangle VBO
	glGenBuffers(1, &app.vbo)

	glBindBuffer(GL_ARRAY_BUFFER, app.vbo)
	glBufferData(GL_ARRAY_BUFFER, 12 * size_of(f32), nil, GL_DYNAMIC_DRAW)

	// Text shader
	app.text_program = create_program(TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)

	if app.text_program == 0 {
		fmt.eprintln("Failed to create text shader program")
		app_destroy_renderer(app)
		return false
	}

	app.text_position_location = glGetAttribLocation(app.text_program, "position")
	app.text_uv_location = glGetAttribLocation(app.text_program, "tex_coord")
	app.text_resolution_location = glGetUniformLocation(app.text_program, "resolution")
	app.text_color_location = glGetUniformLocation(app.text_program, "text_color")
	app.text_texture_location = glGetUniformLocation(app.text_program, "glyph_texture")

	if app.text_position_location < 0 {
		fmt.eprintln("Failed to find text position attribute")
		app_destroy_renderer(app)
		return false
	}

	if app.text_uv_location < 0 {
		fmt.eprintln("Failed to find text tex_coord attribute")
		app_destroy_renderer(app)
		return false
	}

	if app.text_resolution_location < 0 {
		fmt.eprintln("Failed to find text resolution uniform")
		app_destroy_renderer(app)
		return false
	}

	if app.text_color_location < 0 {
		fmt.eprintln("Failed to find text color uniform")
		app_destroy_renderer(app)
		return false
	}

	if app.text_texture_location < 0 {
		fmt.eprintln("Failed to find glyph texture uniform")
		app_destroy_renderer(app)
		return false
	}

	if DEBUG do fmt.println("text shader program created")

	// Text VBO
	glGenBuffers(1, &app.text_vbo)

	glBindBuffer(GL_ARRAY_BUFFER, app.text_vbo)
	glBufferData(GL_ARRAY_BUFFER, 24 * size_of(f32), nil, GL_DYNAMIC_DRAW)

	// Blending
	glEnable(GL_BLEND)
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	if DEBUG do fmt.println("renderer initialized")

	return true
}

app_destroy_renderer :: proc(app: ^App) {
	gl_available := false

	if len(app.layers) > 0 && app.layers[0].egl_surface != nil do gl_available = layer_make_current(app.layers[0])

	if gl_available {
		if app.text_vbo != 0 {
			glDeleteBuffers(1, &app.text_vbo)
			app.text_vbo = 0
		}

		if app.text_program != 0 {
			glDeleteProgram(app.text_program)
			app.text_program = 0
		}

		if app.vbo != 0 {
			glDeleteBuffers(1, &app.vbo)
			app.vbo = 0
		}

		if app.program != 0 {
			glDeleteProgram(app.program)
			app.program = 0
		}

		if app.font.texture != 0 {
			glDeleteTextures(1, &app.font.texture)
			app.font.texture = 0
		}
	}

	if app.font.glyphs != nil {
		delete(app.font.glyphs)
		app.font.glyphs = nil
	}
}
