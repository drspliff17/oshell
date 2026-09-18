package main

import "core:sys/posix"

MEDIA_TITLE_CAPACITY :: 512
MEDIA_PLAYER_CAPACITY :: 256

Media_State :: struct {
	// Session D-Bus connection.
	bus:             ^sd_bus,
	fd:              posix.FD,

	// Signal matches.
	properties_slot: ^sd_bus_slot,
	name_owner_slot: ^sd_bus_slot,

	// Currently selected MPRIS player.
	player:          [MEDIA_PLAYER_CAPACITY]u8,
	player_len:      int,

	// Current media title.
	title:           [MEDIA_TITLE_CAPACITY]u8,
	title_len:       int,
	playing:         bool,
	dirty:           bool,
}

media_state_init :: proc(media: ^Media_State) {
	media^ = {}
	media.fd = posix.FD(-1)
}

media_clear_title :: proc(media: ^Media_State) {
	media.title_len = 0
}

media_set_title :: proc(media: ^Media_State, title: string) {
	media.title_len = min(len(title), len(media.title))

	if media.title_len > 0 {
		copy(media.title[:media.title_len], title[:media.title_len])
	}
}

media_get_title :: proc(media: ^Media_State) -> string {
	if media.title_len == 0 do return ""
	return string(media.title[:media.title_len])
}

media_clear_player :: proc(media: ^Media_State) {
	if media.player_len > 0 {
		media.player[0] = 0
	}

	media.player_len = 0
}

media_set_player :: proc(media: ^Media_State, player: string) {
	// Keep one byte spare for NUL so this may safely be used as a cstring.
	media.player_len = min(len(player), len(media.player) - 1)

	if media.player_len > 0 {
		copy(media.player[:media.player_len], player[:media.player_len])
	}

	media.player[media.player_len] = 0
}

media_get_player :: proc(media: ^Media_State) -> string {
	if media.player_len == 0 do return ""
	return string(media.player[:media.player_len])
}

media_clear_playback :: proc(media: ^Media_State) {
	media.playing = false

	media_clear_title(media)
	media_clear_player(media)
}

media_has_player :: proc(media: ^Media_State) -> bool {
	return media.player_len > 0
}

media_visible :: proc(media: ^Media_State) -> bool {
	return media.playing && media.title_len > 0
}
