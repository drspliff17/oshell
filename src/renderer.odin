package main

import "core:fmt"
import wl "wayland"

Render_State :: struct {
	// Rectangle renderer
	program:                       u32,
	vbo:                           u32,
	resolution_location:           i32,
	color_location:                i32,
	border_color_location:         i32,
	rect_position_location:        i32,
	rect_size_location:            i32,
	rect_radius_location:          i32,
	border_size_location:          i32,
	rect_vertex_position_location: i32,

	// Text renderer
	text_program:                  u32,
	text_vbo:                      u32,
	text_position_location:        i32,
	text_uv_location:              i32,
	text_resolution_location:      i32,
	text_color_location:           i32,
	text_texture_location:         i32,
}

request_redraw :: proc(layer: ^Layer) {
	if layer == nil do return
	if layer.app.output_mode == .Hide do return
	if !layer.configured do return
	if layer.egl_surface == nil do return

	render(layer)
}

request_redraw_all :: proc(app: ^App) {
	for layer in app.layers {
		if !layer.configured do continue
		if layer.egl_surface == nil do continue
		request_redraw(layer)
	}
}

render :: proc(layer: ^Layer) {
	if layer == nil do return
	if layer.app.output_mode == .Hide do return
	if !layer.configured do return
	if layer.egl_surface == nil do return
	if !layer_make_current(layer) do return

	glViewport(0, 0, i32(layer.width), i32(layer.height))

	glClearColor(0.0, 0.0, 0.0, 0.0)
	glClear(GL_COLOR_BUFFER_BIT)

	// Rectangle renderer
	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))
	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	position_location := u32(layer.rect_vertex_position_location)

	glEnableVertexAttribArray(position_location)
	glVertexAttribPointer(position_location, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	// Bar background
	bar_rect := Rect {
		x       = 0,
		y       = 0,
		width   = f32(layer.width),
		height  = f32(layer.height),
		padding = get_padding(4, .VERTICAL),
	}

	glDisable(GL_BLEND)
	draw_rect(layer, bar_rect, PYWAL_COLOURS.Background)
	glEnable(GL_BLEND)

	bar_content := rect_content(bar_rect)

	// Clock

	clock_x: f32 = 10
	clock_width: f32 = 60

	draw_clock(
		layer,
		Clock_Widget {
			rect = {
				x = clock_x,
				y = bar_content.y,
				width = clock_width,
				height = bar_content.height,
				radius = 30,
				padding = get_padding(8, .VERTICAL),
				border_col = COLOURS.Border_Contrast_Widget,
				border_size = 2,
			},
			bg_col = COLOURS.Widget,
			text_col = COLOURS.Font_Dim,
			size = 14,
		},
	)

	// Media

	if media_visible(&layer.media) {
		title := media_get_title(&layer.media)
		artist := media_get_artist(&layer.media)

		media_text_buf: [1024]u8
		media_text := title

		if artist != "" {
			media_text = fmt.bprintf(media_text_buf[:], "%s - %s", artist, title)
		}

		media_text_size: FT_UInt = 14
		media_gap: f32 = 5
		media_padding: f32 = 5
		media_max_width: f32 = 300

		media_metrics := measure_text(layer, media_text, media_text_size)

		media_width := min(media_metrics.width + media_padding * 2, media_max_width)

		draw_media_widget(
			layer,
			Media_Widget {
				rect = {
					x = clock_x + clock_width + media_gap,
					y = bar_content.y,
					width = media_width,
					height = bar_content.height,
					radius = 30,
					padding = get_padding(media_padding, .HORIZONTAL),
					border_size = 2,
					border_col = COLOURS.Border_Contrast_Widget,
				},
				bg_col = COLOURS.Widget,
				text_col = COLOURS.Font,
				size = media_text_size,
			},
		)
	}

	// Workspaces
	draw_workspaces(
		layer,
		Workspace_Widget {
			rect = bar_content,
			size = 20,
			gap = 4,
			radius = 16,
			col = COLOURS.Widget_Sunken,
			active_col = COLOURS.Widget_Raised,
			text_col = COLOURS.Font_Dim,
			active_text_col = COLOURS.Font,
			border_size = 2,
			border_col = COLOURS.Border_Sunken,
			active_border_col = COLOURS.Border_Raised,
			text_size = 14,
		},
	)

	// Submap
	submap_text := hyprland_get_submap(&layer.hypr.state)

	submap_text_size: FT_UInt = 14
	submap_padding: f32 = 8

	submap_metrics := measure_text(layer, submap_text, submap_text_size)
	submap_width := submap_metrics.width + submap_padding * 2
	submap_x := f32(layer.width) - 10 - submap_width

	// Volume
	if volume_available(&layer.volume) {
		volume_text_buffer: [64]u8
		volume_text := volume_get_text(&layer.volume, volume_text_buffer[:])

		volume_text_size: FT_UInt = 13
		volume_padding: f32 = 8
		volume_gap: f32 = 5

		volume_metrics := measure_text(layer, volume_text, volume_text_size)
		volume_width := volume_metrics.width + volume_padding * 2

		draw_volume(
			layer,
			Volume_Widget {
				rect = {
					x = submap_x - volume_gap - volume_width,
					y = bar_content.y,
					width = volume_width,
					height = bar_content.height,
					radius = 30,
					padding = get_padding(volume_padding, .HORIZONTAL),
					border_col = COLOURS.Border_Contrast_Widget,
					border_size = 2,
				},
				bg_col = COLOURS.Widget,
				text_col = COLOURS.Font,
				text_size = volume_text_size,
			},
		)
	}

	draw_submap(
		layer,
		Submap_Widget {
			rect = {
				x = submap_x,
				y = bar_content.y,
				width = submap_width,
				height = bar_content.height,
				radius = 30,
				padding = get_padding(submap_padding, .HORIZONTAL),
				border_col = COLOURS.Border_Contrast_Widget,
				border_size = 2,
			},
			bg_col = COLOURS.Widget,
			text_col = COLOURS.Font,
			text_size = 13,
		},
	)

	if !layer.frame_pending {
		callback := wl.surface_frame(layer.surface)

		if callback == nil {
			fmt.eprintln("Failed to create frame callback")
		} else {
			layer.frame_callback = callback
			layer.frame_pending = true

			wl.callback_add_listener(callback, &frame_listener, layer)
		}
	}

	wl.surface_damage_buffer(layer.surface, 0, 0, int(layer.width), int(layer.height))

	// Present
	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("frame presented")
}
