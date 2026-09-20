package main

import "core:fmt"
import "core:mem"
import "core:os"

DEBUG :: ODIN_DEBUG

run_app :: proc() {
	track: mem.Tracking_Allocator
	tracking_init(&track)
	defer tracking_destroy(&track)

	app := App{}
	context.user_ptr = &app

	setup_signals()
	update_colours()

	config_init(&app)
	defer config_destroy(&app)

	app.layers = make([dynamic]^Layer)
	defer delete(app.layers)

	if !app_init_wayland(&app) do return
	defer app_destroy_wayland(&app)

	if !app_init_egl(&app) {
		app_destroy_egl(&app)
		return
	}
	defer app_destroy_egl(&app)

	layer := app_init_primary_layers(&app)
	if layer == nil do return
	defer app_destroy_layers(&app)

	if !app_init_font(&app) do return
	defer app_destroy_font(&app)

	if !app_init_renderer(&app) do return
	defer app_destroy_renderer(&app)

	if !media_init(&app) do fmt.eprintln("Media integration unavailable")
	defer media_destroy(&app)

	if !volume_init_with_retry(&app) do fmt.eprintln("Volume integration unavailable")
	defer volume_destroy(&app)

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
