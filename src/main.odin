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
	UpdateColours()

	// App
	app := App{}

	context.user_ptr = cast(rawptr)&app

	app.layers = make([dynamic]^Layer)
	defer delete(app.layers)

	// Wayland
	app.display = wl.display_connect(nil)
	if app.display == nil {
		fmt.eprintln("Failed to connect")
		return
	}
	defer wl.display_disconnect(app.display)

	app.registry = wl.display_get_registry(app.display)

	registry_listener := wl.registry_listener {
		global        = registry_global,
		global_remove = registry_global_remove,
	}

	wl.registry_add_listener(app.registry, &registry_listener, &app)

	// Discover globals.
	if wl.display_roundtrip(app.display) < 0 do return

	// Receive wl_output.name events.
	if wl.display_roundtrip(app.display) < 0 do return

	if DEBUG do fmt.println("connected")

	if app.compositor == nil {
		fmt.eprintln("No wl_compositor")
		return
	}
	if DEBUG do fmt.println("found wl_compositor")

	if app.layer_shell == nil {
		fmt.eprintln("No wlr-layer-shell")
		return
	}
	if DEBUG do fmt.println("found wlr-layer-shell")

	// Preferred output
	target_output := app_preferred_output(&app)
	if target_output == nil {
		fmt.eprintln("Neither HDMI-A-1 nor eDP-1 found")
		return
	}
	if DEBUG {
		if target_output == app.hdmi_output {
			fmt.println("using output: HDMI-A-1")
		} else {
			fmt.println("using output: eDP-1")
		}
	}

	// EGL
	if !app_init_egl(&app) do return
	defer app_destroy_egl(&app)

	// Layer
	layer := new(Layer)
	layer.app = &app

	append(&app.layers, layer)
	defer {
		layer_destroy_surface(layer)
		free(layer)
	}
	if !layer_create_surface(layer, target_output) do return

	if DEBUG do fmt.println("configured:", layer.width, layer.height)

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
	if layer.program == 0 {
		fmt.eprintln("Failed to create rectangle shader program")
		return
	}
	defer glDeleteProgram(layer.program)

	layer.rect_vertex_position_location = glGetAttribLocation(layer.program, "position")
	if layer.rect_vertex_position_location < 0 {
		fmt.eprintln("Failed to find rectangle position attribute")
		return
	}

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

	// Blending
	glEnable(GL_BLEND)
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	if DEBUG do fmt.println("renderer initialized")

	// Hyprland
	if !hyprland_connect(&app.hypr) {
		fmt.eprintln("Hyprland IPC unavailable")
		return
	}
	defer hyprland_disconnect(&app.hypr)

	// Initial frame
	request_redraw(layer)

	// Event loop
	run_event_loop(layer)
}
