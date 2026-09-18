package main

import "core:mem"
import "core:os"

DEBUG :: true

run_app :: proc() {
	track: mem.Tracking_Allocator
	tracking_init(&track)
	defer tracking_destroy(&track)

	setup_signals()
	update_colours()

	app := App{}
	context.user_ptr = &app

	app.layers = make([dynamic]^Layer)
	defer delete(app.layers)

	if !app_init_wayland(&app) do return
	defer app_destroy_wayland(&app)

	if !app_init_egl(&app) {
		app_destroy_egl(&app)
		return
	}
	defer app_destroy_egl(&app)

	layer := app_init_primary_layer(&app)
	if layer == nil do return
	defer app_destroy_layers(&app)

	font_library, font_ok := app_init_font(&app)
	if !font_ok do return
	defer app_destroy_font(&app, font_library)

	if !app_init_renderer(&app) do return
	defer app_destroy_renderer(&app)

	if !app_init_hyprland(&app) do return
	defer app_destroy_hyprland(&app)

	if !oshell_ipc_init(&app) do return
	defer oshell_ipc_destroy(&app)

	request_redraw(layer)
	run_event_loop(layer)
}

main :: proc() {
	if len(os.args) > 1 {
		run_ipc_client(os.args[1:])
		return
	}
	run_app()
}
