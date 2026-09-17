package main

import "core:fmt"
import "core:mem"
import "core:strings"
import wl "wayland"

DEBUG :: true

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("%v allocations not feed:\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		} else {
			fmt.println("TEST: No unfreed allocations")
		}

		if len(track.bad_free_array) > 0 {
			fmt.eprintf("%v incorrect free:\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %v bytes @ %v\n", entry.memory, entry.location)
			}
		} else {
			fmt.println("TEST: No bad free")
		}

		mem.tracking_allocator_destroy(&track)
	}

	setup_signals()
	GetPywalColours(PYWAL_PATH)

	// Wayland
	layer := Layer{}

	layer.display = wl.display_connect(nil)

	if layer.display == nil {
		fmt.eprintln("Failed to connect")
		return
	}

	defer wl.display_disconnect(layer.display)

	layer.registry = wl.display_get_registry(layer.display)

	registry_listener := wl.registry_listener {
		global        = registry_global,
		global_remove = registry_global_remove,
	}

	wl.registry_add_listener(layer.registry, &registry_listener, &layer)
	wl.display_roundtrip(layer.display)

	if DEBUG do fmt.println("connected")

	if layer.compositor == nil {
		fmt.eprintln("No wl_compositor")
		return
	}

	if DEBUG do fmt.println("found wl_compositor")

	if layer.layer_shell == nil {
		fmt.eprintln("No wlr-layer-shell")
		return
	}

	if DEBUG do fmt.println("found wlr-layer-shell")

	layer.surface = wl.compositor_create_surface(layer.compositor)

	if layer.surface == nil {
		fmt.eprintln("Failed to create wl_surface")
		return
	}

	layer.layer_surface = wl.layer_shell_v1_get_layer_surface(
		layer.layer_shell,
		layer.surface,
		nil,
		.overlay,
		"oshell",
	)

	if layer.layer_surface == nil {
		fmt.eprintln("Failed to create layer surface")
		return
	}

	layer_surface_listener := wl.layer_surface_v1_listener {
		configure = layer_surface_configure,
		closed    = layer_surface_closed,
	}

	wl.layer_surface_v1_add_listener(layer.layer_surface, &layer_surface_listener, &layer)

	wl.layer_surface_v1_set_size(layer.layer_surface, 1920, 28)
	wl.layer_surface_v1_set_anchor(layer.layer_surface, .bottom | .left | .right)
	wl.layer_surface_v1_set_exclusive_zone(layer.layer_surface, 32)
	wl.layer_surface_v1_set_keyboard_interactivity(layer.layer_surface, .none)

	wl.surface_commit(layer.surface)

	if DEBUG do fmt.println("layer surface created")

	for {
		if wl.display_dispatch(layer.display) < 0 do return
		if layer.configured do break
	}

	wl.layer_surface_v1_ack_configure(layer.layer_surface, layer.serial)

	if DEBUG do fmt.println("configured:", layer.width, layer.height)

	// EGL window
	layer.egl_window = wl.egl_window_create(layer.surface, int(layer.width), int(layer.height))

	if layer.egl_window == nil {
		fmt.eprintln("Failed to create EGL window")
		return
	}

	defer wl.egl_window_destroy(layer.egl_window)

	layer.egl_display = eglGetDisplay(cast(rawptr)layer.display)

	if layer.egl_display == nil {
		fmt.eprintln("Failed to get EGL display")
		return
	}

	major: i32
	minor: i32

	if eglInitialize(layer.egl_display, &major, &minor) == EGL_FALSE {
		fmt.eprintln("Failed to initialize EGL")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	defer eglTerminate(layer.egl_display)

	if DEBUG do fmt.println("EGL:", major, ".", minor)

	if eglBindAPI(EGL_OPENGL_ES_API) == EGL_FALSE {
		fmt.eprintln("Failed to bind OpenGL ES API")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	config_attributes := [7]i32 {
		EGL_SURFACE_TYPE,
		EGL_WINDOW_BIT,
		EGL_RENDERABLE_TYPE,
		EGL_OPENGL_ES2_BIT,
		EGL_ALPHA_SIZE,
		8,
		EGL_NONE,
	}

	num_configs: i32

	if eglChooseConfig(
		   layer.egl_display,
		   &config_attributes[0],
		   &layer.egl_config,
		   1,
		   &num_configs,
	   ) ==
	   EGL_FALSE {
		fmt.eprintln("Failed to choose EGL config")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if num_configs == 0 {
		fmt.eprintln("No suitable EGL configs")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("EGL config selected")

	// OpenGL ES context
	context_attributes := [3]i32{EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE}

	layer.egl_context = eglCreateContext(
		layer.egl_display,
		layer.egl_config,
		nil,
		&context_attributes[0],
	)

	if layer.egl_context == nil {
		fmt.eprintln("Failed to create EGL context")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	defer eglDestroyContext(layer.egl_display, layer.egl_context)

	layer.egl_surface = eglCreateWindowSurface(
		layer.egl_display,
		layer.egl_config,
		cast(rawptr)layer.egl_window,
		nil,
	)

	if layer.egl_surface == nil {
		fmt.eprintln("Failed to create EGL surface")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	defer eglDestroySurface(layer.egl_display, layer.egl_surface)

	if eglMakeCurrent(
		   layer.egl_display,
		   layer.egl_surface,
		   layer.egl_surface,
		   layer.egl_context,
	   ) ==
	   EGL_FALSE {
		fmt.eprintln("Failed to make EGL context current")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("OpenGL ES context created")

	// FreeType
	library: FT_Library
	if FT_Init_FreeType(&library) != 0 {
		fmt.eprintln("Failed to initialize FreeType")
		return
	}
	defer FT_Done_FreeType(library)

	font_path := "/usr/share/fonts/TTF/JetBrainsMono-Regular.ttf"
	font_path_cstr := strings.clone_to_cstring(font_path)
	defer delete(font_path_cstr)

	face: FT_Face

	if FT_New_Face(library, font_path_cstr, 0, &face) != 0 {
		fmt.eprintln("Failed to load font")
		return
	}

	defer FT_Done_Face(face)

	layer.font_face = face

	if DEBUG do fmt.println("FreeType font loaded")

	// Font atlas
	layer.font.width = 1024
	layer.font.height = 1024

	layer.font.pen_x = 1
	layer.font.pen_y = 1
	layer.font.row_height = 0

	layer.font.glyphs = make(map[Glyph_Key]Glyph)
	defer delete(layer.font.glyphs)

	glGenTextures(1, &layer.font.texture)
	defer glDeleteTextures(1, &layer.font.texture)

	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, layer.font.texture)

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

	glTexImage2D(
		GL_TEXTURE_2D,
		0,
		i32(GL_ALPHA),
		layer.font.width,
		layer.font.height,
		0,
		GL_ALPHA,
		GL_UNSIGNED_BYTE,
		nil,
	)

	if DEBUG do fmt.println("font atlas created:", layer.font.width, "x", layer.font.height)

	// Rectangle shader
	layer.program = create_program(RECT_VERTEX_SHADER, RECT_FRAGMENT_SHADER)

	layer.rect_vertex_position_location = glGetAttribLocation(layer.program, "position")

	if layer.rect_vertex_position_location < 0 {
		fmt.eprintln("Failed to find rectangle position attribute")
		return
	}

	if layer.program == 0 {
		fmt.eprintln("Failed to create rectangle shader program")
		return
	}

	defer glDeleteProgram(layer.program)

	layer.resolution_location = glGetUniformLocation(layer.program, "resolution")
	layer.color_location = glGetUniformLocation(layer.program, "color")
	layer.rect_position_location = glGetUniformLocation(layer.program, "rect_position")
	layer.rect_size_location = glGetUniformLocation(layer.program, "rect_size")
	layer.rect_radius_location = glGetUniformLocation(layer.program, "rect_radius")

	if layer.resolution_location < 0 {
		fmt.eprintln("Failed to find resolution uniform")
		return
	}

	if layer.color_location < 0 {
		fmt.eprintln("Failed to find color uniform")
		return
	}

	if layer.rect_position_location < 0 {
		fmt.eprintln("Failed to find rect_position uniform")
		return
	}

	if layer.rect_size_location < 0 {
		fmt.eprintln("Failed to find rect_size uniform")
		return
	}

	if layer.rect_radius_location < 0 {
		fmt.eprintln("Failed to find rect_radius uniform")
		return
	}

	if DEBUG do fmt.println("rectangle shader program created")

	// Rectangle VBO
	glGenBuffers(1, &layer.vbo)

	defer glDeleteBuffers(1, &layer.vbo)

	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)
	glBufferData(GL_ARRAY_BUFFER, 12 * size_of(f32), nil, GL_DYNAMIC_DRAW)

	// Text shader
	layer.text_program = create_program(TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)

	if layer.text_program == 0 {
		fmt.eprintln("Failed to create text shader program")
		return
	}

	defer glDeleteProgram(layer.text_program)

	layer.text_position_location = glGetAttribLocation(layer.text_program, "position")
	layer.text_uv_location = glGetAttribLocation(layer.text_program, "tex_coord")

	layer.text_resolution_location = glGetUniformLocation(layer.text_program, "resolution")
	layer.text_color_location = glGetUniformLocation(layer.text_program, "text_color")
	layer.text_texture_location = glGetUniformLocation(layer.text_program, "glyph_texture")

	if layer.text_position_location < 0 {
		fmt.eprintln("Failed to find text position attribute")
		return
	}

	if layer.text_uv_location < 0 {
		fmt.eprintln("Failed to find text tex_coord attribute")
		return
	}

	if layer.text_resolution_location < 0 {
		fmt.eprintln("Failed to find text resolution uniform")
		return
	}

	if layer.text_color_location < 0 {
		fmt.eprintln("Failed to find text color uniform")
		return
	}

	if layer.text_texture_location < 0 {
		fmt.eprintln("Failed to find glyph texture uniform")
		return
	}

	if DEBUG do fmt.println("text shader program created")

	// Text VBO
	glGenBuffers(1, &layer.text_vbo)

	defer glDeleteBuffers(1, &layer.text_vbo)

	glBindBuffer(GL_ARRAY_BUFFER, layer.text_vbo)
	glBufferData(GL_ARRAY_BUFFER, 24 * size_of(f32), nil, GL_DYNAMIC_DRAW)

	glEnable(GL_BLEND)
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	if DEBUG do fmt.println("renderer initialized")

	// Initial frame
	request_redraw(&layer)

	// Event loop
	run_event_loop(&layer)
}
