package main

import "core:fmt"
import "core:strings"

app_init_font :: proc(app: ^App) -> (FT_Library, bool) {
	library: FT_Library

	if FT_Init_FreeType(&library) != 0 {
		fmt.eprintln("Failed to initialize FreeType")
		return nil, false
	}

	font_path := "/usr/share/fonts/TTF/JetBrainsMono-Regular.ttf"
	font_path_cstr := strings.clone_to_cstring(font_path)
	defer delete(font_path_cstr)

	face: FT_Face
	if FT_New_Face(library, font_path_cstr, 0, &face) != 0 {
		fmt.eprintln("Failed to load font")
		FT_Done_FreeType(library)
		return nil, false
	}

	app.font_face = face
	if DEBUG do fmt.println("FreeType font loaded")
	return library, true
}

app_destroy_font :: proc(app: ^App, library: FT_Library) {
	if app.font_face != nil {
		FT_Done_Face(app.font_face)
		app.font_face = nil
	}
	if library != nil do FT_Done_FreeType(library)
}
