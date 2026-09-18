package main

import "core:sys/posix"

MEDIA_TITLE_CAPACITY :: 1024
MEDIA_ARTIST_CAPACITY :: 512
MEDIA_PLAYER_CAPACITY :: 256

MEDIA_SCROLL_INTERVAL :: 100
MEDIA_SCROLL_STEP :: 3.0
MEDIA_SCROLL_PADDING :: 12.0

Media_State :: struct {
	// Currently selected MPRIS player.
	player:          [MEDIA_PLAYER_CAPACITY]u8,

	// Current media metadata.
	artist:          [MEDIA_ARTIST_CAPACITY]u8,
	title:           [MEDIA_TITLE_CAPACITY]u8,

	// Session D-Bus connection.
	bus:             ^sd_bus,
	fd:              posix.FD,

	// Signal matches.
	properties_slot: ^sd_bus_slot,
	name_owner_slot: ^sd_bus_slot,

	// Title marquee.
	scroll_offset:   f32,
	scroll_max:      f32,

	// String lengths.
	player_len:      int,
	artist_len:      int,
	title_len:       int,

	// State.
	scroll_active:   bool,
	playing:         bool,
	dirty:           bool,
}

media_reset_scroll :: proc(media: ^Media_State) {
	media.scroll_offset = 0
	media.scroll_max = 0
	media.scroll_active = false
}

media_scroll_tick :: proc(app: ^App) {
	media := &app.media

	if !media.scroll_active do return
	if media.scroll_max <= 0 do return

	media.scroll_offset += MEDIA_SCROLL_STEP

	if media.scroll_offset > media.scroll_max {
		media.scroll_offset = 0
	}

	request_redraw_all(app)
}

media_state_init :: proc(media: ^Media_State) {
	media^ = {}
	media.fd = posix.FD(-1)
}

// Player

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

// Artist

media_clear_artist :: proc(media: ^Media_State) {
	media.artist_len = 0
}

media_set_artist :: proc(media: ^Media_State, artist: string) {
	media.artist_len = min(len(artist), len(media.artist))

	if media.artist_len > 0 {
		copy(media.artist[:media.artist_len], artist[:media.artist_len])
	}
}

media_get_artist :: proc(media: ^Media_State) -> string {
	if media.artist_len == 0 do return ""

	return string(media.artist[:media.artist_len])
}

// Title

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

// Playback

media_clear_playback :: proc(media: ^Media_State) {
	media.playing = false

	media_clear_player(media)
	media_clear_artist(media)
	media_clear_title(media)

	media_reset_scroll(media)
}

media_has_player :: proc(media: ^Media_State) -> bool {
	return media.player_len > 0
}

media_visible :: proc(media: ^Media_State) -> bool {
	return media.playing && media.title_len > 0
}
