package main

import "core:sys/posix"
import "core:time"

NOTIFICATION_SUMMARY_CAPACITY :: 1024
NOTIFICATION_BODY_CAPACITY :: 4096

NOTIFICATION_DEFAULT_TIMEOUT :: 5 * time.Second

Notification :: struct {
	body:        [NOTIFICATION_BODY_CAPACITY]u8,
	summary:     [NOTIFICATION_SUMMARY_CAPACITY]u8,
	views:       [dynamic]^Layer,
	started_at:  time.Tick,
	timeout:     time.Duration,
	id:          u32,
	summary_len: int,
	body_len:    int,
	expires:     bool,
}

Notification_State :: struct {
	// D-Bus
	bus:     ^sd_bus,
	slot:    ^sd_bus_slot,
	fd:      posix.FD,

	// ID state
	next_id: u32,

	// Active notifications
	items:   [dynamic]Notification,
}

notification_state_init :: proc(state: ^Notification_State) {
	state^ = {}
	state.fd = posix.FD(-1)
	state.next_id = 1
	state.items = make([dynamic]Notification)
}

notification_get_summary :: proc(notification: ^Notification) -> string {
	if notification.summary_len <= 0 do return ""
	return string(notification.summary[:notification.summary_len])
}

notification_get_body :: proc(notification: ^Notification) -> string {
	if notification.body_len <= 0 do return ""
	return string(notification.body[:notification.body_len])
}
