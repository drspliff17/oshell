package main

import "core:fmt"
import "core:os"
import "core:strings"

DEFAULT_FONT_PATH :: "/home/drspliff/.local/share/fonts/BigBlueTerm437NerdFontMono-Regular.ttf"
DEFAULT_FONT_SIZE :: 14

app_get_font_path :: proc(app: ^App) -> string {
	if !app.config_initialised do return DEFAULT_FONT_PATH
	if len(app.config.font_filepath) == 0 do return DEFAULT_FONT_PATH
	if !os.exists(app.config.font_filepath) do return DEFAULT_FONT_PATH
	return app.config.font_filepath
}

app_get_font_size :: proc(app: ^App) -> FT_UInt {
	if !app.config_initialised do return DEFAULT_FONT_SIZE
	if app.config.font_size <= 0 do return DEFAULT_FONT_SIZE
	return app.config.font_size
}

app_reset_font_cache :: proc(app: ^App) {
	if app.font.glyphs != nil do clear(&app.font.glyphs)
	app.font.pen_x = 1
	app.font.pen_y = 1
	app.font.row_height = 0
	media_reset_scroll(&app.media)
}

app_reload_font :: proc(app: ^App) -> bool {
	if app.font_library == nil {
		fmt.eprintln("Cannot reload font without FreeType")
		return false
	}

	font_path := app_get_font_path(app)
	font_path_cstr := strings.clone_to_cstring(font_path)
	defer delete(font_path_cstr)

	new_face: FT_Face

	if FT_New_Face(app.font_library, font_path_cstr, 0, &new_face) != 0 {
		fmt.eprintln("Failed to load font:", font_path)
		return false
	}

	old_face := app.font_face
	app.font_face = new_face
	if old_face != nil do FT_Done_Face(old_face)

	app_reset_font_cache(app)

	if DEBUG do fmt.println("FreeType font loaded:", font_path)
	return true
}

app_init_font :: proc(app: ^App) -> bool {
	if FT_Init_FreeType(&app.font_library) != 0 {
		fmt.eprintln("Failed to initialize FreeType")
		app.font_library = nil
		return false
	}

	if !app_reload_font(app) {
		FT_Done_FreeType(app.font_library)
		app.font_library = nil
		return false
	}

	return true
}

app_destroy_font :: proc(app: ^App) {
	if app.font_face != nil {
		FT_Done_Face(app.font_face)
		app.font_face = nil
	}

	if app.font_library != nil {
		FT_Done_FreeType(app.font_library)
		app.font_library = nil
	}
}
