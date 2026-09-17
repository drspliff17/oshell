package main

import "core:sys/posix"
import wl "wayland"

process_updates :: proc(layer: ^Layer) {
	if g_reload_colours {
		GetPywalColours(PYWAL_PATH)
		g_reload_colours = false

		request_redraw(layer)
	}
}

run_event_loop :: proc(layer: ^Layer) {
	wayland_fd := wl.display_get_fd(layer.display)

	fds := [1]posix.pollfd{{fd = posix.FD(wayland_fd), events = {.IN}}}

	for {
		for wl.display_prepare_read(layer.display) != 0 {
			if wl.display_dispatch_pending(layer.display) < 0 {
				return
			}
		}

		if wl.display_flush(layer.display) < 0 {
			wl.display_cancel_read(layer.display)
			return
		}

		fds[0].revents = {}

		timeout := milliseconds_until_next_minute()

		result := posix.poll(&fds[0], 1, timeout)

		if result < 0 {
			wl.display_cancel_read(layer.display)

			if posix.get_errno() == .EINTR {
				process_updates(layer)
				continue
			}

			return
		}

		if result == 0 {
			wl.display_cancel_read(layer.display)

			request_redraw(layer)
			process_updates(layer)

			continue
		}

		if .ERR in fds[0].revents || .HUP in fds[0].revents || .NVAL in fds[0].revents {
			wl.display_cancel_read(layer.display)
			return
		}

		if .IN in fds[0].revents {
			if wl.display_read_events(layer.display) < 0 {
				return
			}
		} else {
			wl.display_cancel_read(layer.display)
		}

		if wl.display_dispatch_pending(layer.display) < 0 {
			return
		}

		process_updates(layer)
	}
}
