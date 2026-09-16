package main

foreign import freetype_lib "system:libfreetype.so.6"

// FreeType handles

FT_Library :: rawptr
FT_Face :: rawptr
FT_GlyphSlot :: rawptr


// FreeType scalar types

FT_Error :: i32

FT_Long :: i64
FT_ULong :: u64

FT_Int :: i32
FT_UInt :: u32

FT_Short :: i16
FT_UShort :: u16

FT_Pos :: i64
FT_Fixed :: i64


// Glyph loading flags

FT_LOAD_DEFAULT :: i32(0)
FT_LOAD_RENDER :: i32(1 << 2)


@(default_calling_convention = "c")
foreign freetype_lib {

	// Library lifecycle

	FT_Init_FreeType :: proc(alibrary: ^FT_Library) -> FT_Error ---

	FT_Done_FreeType :: proc(library: FT_Library) -> FT_Error ---


	// Face lifecycle

	FT_New_Face :: proc(library: FT_Library, pathname: cstring, face_index: FT_Long, aface: ^FT_Face) -> FT_Error ---

	FT_Done_Face :: proc(face: FT_Face) -> FT_Error ---


	// Face sizing

	FT_Set_Pixel_Sizes :: proc(face: FT_Face, pixel_width: FT_UInt, pixel_height: FT_UInt) -> FT_Error ---


	// Glyph loading

	FT_Load_Char :: proc(face: FT_Face, char_code: FT_ULong, load_flags: i32) -> FT_Error ---
}


// Shared FreeType data structures

FT_Generic :: struct {
	data:      rawptr,
	finalizer: rawptr,
}

FT_BBox :: struct {
	xMin: FT_Pos,
	yMin: FT_Pos,
	xMax: FT_Pos,
	yMax: FT_Pos,
}

FT_Vector :: struct {
	x: FT_Pos,
	y: FT_Pos,
}


// Bitmap data

FT_Bitmap :: struct {
	rows:         u32,
	width:        u32,
	pitch:        i32,
	buffer:       ^u8,
	num_grays:    u16,
	pixel_mode:   u8,
	palette_mode: u8,
	palette:      rawptr,
}

FT_Bitmap_Size :: struct {
	height: FT_Short,
	width:  FT_Short,
	size:   FT_Pos,
	x_ppem: FT_Pos,
	y_ppem: FT_Pos,
}


// Glyph metrics and outlines

FT_Glyph_Metrics :: struct {
	width:        FT_Pos,
	height:       FT_Pos,
	horiBearingX: FT_Pos,
	horiBearingY: FT_Pos,
	horiAdvance:  FT_Pos,
	vertBearingX: FT_Pos,
	vertBearingY: FT_Pos,
	vertAdvance:  FT_Pos,
}

FT_Outline :: struct {
	n_contours: i16,
	n_points:   i16,
	points:     rawptr,
	tags:       rawptr,
	contours:   rawptr,
	flags:      i32,
}


// Internal list representation used by FT_FaceRec

FT_ListRec :: struct {
	head: rawptr,
	tail: rawptr,
}


// Glyph slot representation

FT_GlyphSlotRec :: struct {
	library:           rawptr,
	face:              rawptr,
	next:              rawptr,
	glyph_index:       FT_UInt,
	generic:           FT_Generic,
	metrics:           FT_Glyph_Metrics,
	linearHoriAdvance: FT_Fixed,
	linearVertAdvance: FT_Fixed,
	advance:           FT_Vector,
	format:            u32,
	bitmap:            FT_Bitmap,
	bitmap_left:       FT_Int,
	bitmap_top:        FT_Int,
	outline:           FT_Outline,
	num_subglyphs:     FT_UInt,
	subglyphs:         rawptr,
	control_data:      rawptr,
	control_len:       FT_Long,
	lsb_delta:         FT_Pos,
	rsb_delta:         FT_Pos,
	other:             rawptr,
	internal:          rawptr,
}


// Face representation

FT_FaceRec :: struct {
	num_faces:           FT_Long,
	face_index:          FT_Long,
	face_flags:          FT_Long,
	style_flags:         FT_Long,
	num_glyphs:          FT_Long,
	family_name:         rawptr,
	style_name:          rawptr,
	num_fixed_sizes:     FT_Int,
	available_sizes:     ^FT_Bitmap_Size,
	num_charmaps:        FT_Int,
	charmaps:            rawptr,
	generic:             FT_Generic,
	bbox:                FT_BBox,
	units_per_EM:        FT_UShort,
	ascender:            FT_Short,
	descender:           FT_Short,
	height:              FT_Short,
	max_advance_width:   FT_Short,
	max_advance_height:  FT_Short,
	underline_position:  FT_Short,
	underline_thickness: FT_Short,
	glyph:               ^FT_GlyphSlotRec,
	size:                rawptr,
	charmap:             rawptr,
	driver:              rawptr,
	memory:              rawptr,
	stream:              rawptr,
	sizes_list:          FT_ListRec,
	autohint:            FT_Generic,
	extensions:          rawptr,
	internal:            rawptr,
}


// Application glyph cache key

Glyph_Key :: struct {
	character: rune,
	size:      FT_UInt,
}


// Application font atlas

Font :: struct {
	texture:    u32,
	width:      i32,
	height:     i32,
	pen_x:      i32,
	pen_y:      i32,
	row_height: i32,
	glyphs:     map[Glyph_Key]Glyph,
}


// Cached glyph information

Glyph :: struct {
	x:         i32,
	y:         i32,
	width:     i32,
	height:    i32,
	bearing_x: i32,
	bearing_y: i32,
	advance:   i32,
}
