package main

import "base:runtime"
import "core:time"
import wl "wayland"

frame_listener := wl.callback_listener {
	done = frame_done,
}

frame_done :: proc "c" (data: rawptr, callback: ^wl.callback, frame_time: uint) {
	context = runtime.default_context()

	layer := cast(^Layer)data

	wl.callback_destroy(callback)

	layer.frame_pending = false
}

milliseconds_until_next_minute :: proc() -> i32 {
	now_ns := time.to_unix_nanoseconds(time.now())

	minute_ns := time.duration_nanoseconds(time.Minute)
	elapsed_ns := now_ns % minute_ns
	remaining_ns := minute_ns - elapsed_ns

	return i32((remaining_ns + 999_999) / 1_000_000)
}
