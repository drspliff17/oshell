package main

import "core:mem"
import "core:time"

DEBUG :: true

main :: proc() {
	track: mem.Tracking_Allocator
	tracking_init(&track)
	defer tracking_destroy(&track)

	setup_signals()
	UpdateColours()

	app := App{}
	context.user_ptr = &app

	app.layers = make([dynamic]^Layer)
	defer delete(app.layers)

	// Wayland
	if !app_init_wayland(&app) do return
	defer app_destroy_wayland(&app)

	// EGL
	if !app_init_egl(&app) {
		app_destroy_egl(&app)
		return
	}
	defer app_destroy_egl(&app)

	// Initial layer
	layer := app_init_primary_layer(&app)
	if layer == nil do return

	defer app_destroy_layers(&app)

	// FreeType
	font_library, font_ok := app_init_font(&app)
	if !font_ok do return
	defer app_destroy_font(&app, font_library)

	// Renderer
	if !app_init_renderer(&app) do return
	defer app_destroy_renderer(&app)

	// Hyprland
	if !app_init_hyprland(&app) do return
	defer app_destroy_hyprland(&app)

	// Run
	request_redraw(layer)
	run_event_loop(layer, 10 * time.Second)
}
