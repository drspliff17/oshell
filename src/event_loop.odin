package main

import "core:fmt"
import "core:sys/posix"
import "core:time"
import wl "wayland"

process_updates :: proc(app: ^App) {
	if g_reload_colours {
		update_colours()
		g_reload_colours = false
		request_redraw_all(app)
	}
}

run_event_loop :: proc(layer: ^Layer, test_duration: time.Duration = 0) {
	app := layer.app

	wayland_fd := wl.display_get_fd(app.display)
	fds := [3]posix.pollfd {
		{fd = posix.FD(wayland_fd), events = {.IN}},
		{fd = app.hypr.fd, events = {.IN}},
		{fd = app.ipc.fd, events = {.IN}},
	}

	test_start := time.tick_now()

	for {

		// TEST: Duration mem test
		if test_duration > 0 {
			if time.tick_since(test_start) >= test_duration {
				if DEBUG do fmt.println("TEST: event loop timeout")
				return
			}
		}

		for wl.display_prepare_read(app.display) != 0 do if wl.display_dispatch_pending(app.display) < 0 do return

		if wl.display_flush(app.display) < 0 {
			wl.display_cancel_read(app.display)
			return
		}

		fds[0].revents = {}
		fds[1].revents = {}
		fds[2].revents = {}

		timeout := milliseconds_until_next_minute()

		if app.hypr.redraw_pending do timeout = min(timeout, 5)

		// TEST: Duration mem test
		if test_duration > 0 {
			remaining := test_duration - time.tick_since(test_start)

			if remaining <= 0 {
				wl.display_cancel_read(app.display)
				if DEBUG do fmt.println("TEST: event loop timeout")
				return
			}

			test_timeout := int(time.duration_milliseconds(remaining))
			if test_timeout < 1 do test_timeout = 1
			timeout = min(timeout, i32(test_timeout))
		}

		result := posix.poll(&fds[0], len(fds), timeout)

		if result < 0 {
			wl.display_cancel_read(app.display)
			if posix.get_errno() == .EINTR {
				process_updates(app)
				continue
			}
			return
		}

		// TEST: Duration mem test
		if test_duration > 0 && time.tick_since(test_start) >= test_duration {
			wl.display_cancel_read(app.display)
			if DEBUG do fmt.println("TEST: event loop timeout")
			return
		}

		if result == 0 {
			wl.display_cancel_read(app.display)
			app.hypr.redraw_pending = false
			request_redraw_all(app)
			process_updates(app)
			continue
		}

		// Wayland
		if .ERR in fds[0].revents || .HUP in fds[0].revents || .NVAL in fds[0].revents {
			wl.display_cancel_read(app.display)
			return
		}

		if .IN in fds[0].revents {
			if wl.display_read_events(app.display) < 0 do return
		} else {
			wl.display_cancel_read(app.display)
		}

		if wl.display_dispatch_pending(app.display) < 0 do return

		// Hyprland IPC
		if .ERR in fds[1].revents || .HUP in fds[1].revents || .NVAL in fds[1].revents do return

		if .IN in fds[1].revents {
			if !hyprland_read_events(&app.hypr, layer) do return
		}

		// oshell IPC
		if .ERR in fds[2].revents || .HUP in fds[2].revents || .NVAL in fds[2].revents do return

		if .IN in fds[2].revents {
			if !oshell_ipc_handle(app) do fmt.eprintln("oshell IPC: Failed to handle connection")
		}

		if app.exit_requested do return
		process_updates(app)
	}
}
