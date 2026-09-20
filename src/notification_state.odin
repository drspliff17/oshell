package main

import "core:sys/posix"

Notification_State :: struct {
	bus:     ^sd_bus,
	slot:    ^sd_bus_slot,
	fd:      posix.FD,
	next_id: u32,
}

notification_state_init :: proc(state: ^Notification_State) {
	state^ = {}
	state.fd = posix.FD(-1)
	state.next_id = 1
}
