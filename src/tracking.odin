package main

import "core:fmt"
import "core:mem"

tracking_init :: proc(track: ^mem.Tracking_Allocator) {
	mem.tracking_allocator_init(track, context.allocator)
	context.allocator = mem.tracking_allocator(track)
}

tracking_destroy :: proc(track: ^mem.Tracking_Allocator) {
	if len(track.allocation_map) > 0 {
		fmt.eprintf("%v allocations not freed:\n", len(track.allocation_map))
		for _, entry in track.allocation_map do fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
	} else {
		fmt.println("TEST: No unfreed allocations")
	}

	if len(track.bad_free_array) > 0 {
		fmt.eprintf("%v incorrect free:\n", len(track.bad_free_array))
		for entry in track.bad_free_array do fmt.eprintf("- %v bytes @ %v\n", entry.memory, entry.location)
	} else {
		fmt.println("TEST: No bad free")
	}

	mem.tracking_allocator_destroy(track)
}
