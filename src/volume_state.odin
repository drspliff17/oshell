package main

import "core:os"
import "core:sys/posix"

VOLUME_EVENT_BUFFER_CAPACITY :: 4096

Volume_State :: struct {
	// Persistent `pactl subscribe` process
	process:    os.Process,

	// Read end of pactl stdout
	pipe:       ^os.File,
	fd:         posix.FD,

	// Buffered pactl output
	buffer:     [VOLUME_EVENT_BUFFER_CAPACITY]u8,
	buffer_len: int,

	// Current default sink state
	percent:    int,
	muted:      bool,

	// True after sink state read
	available:  bool,
}

volume_state_init :: proc(volume: ^Volume_State) {
	volume^ = {}
	volume.fd = posix.FD(-1)
}

volume_get_percent :: proc(volume: ^Volume_State) -> int {return volume.percent}

volume_is_muted :: proc(volume: ^Volume_State) -> bool {return volume.muted}

volume_available :: proc(volume: ^Volume_State) -> bool {return volume.available}
