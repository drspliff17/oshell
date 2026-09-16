package main

foreign import freetype_lib "system:libfreetype.so.6"

FT_Library :: rawptr
FT_Face :: rawptr
FT_GlyphSlot :: rawptr

FT_Error :: i32

FT_Long :: i64
FT_ULong :: u64

FT_Int :: i32
FT_UInt :: u32

FT_Short :: i16
FT_UShort :: u16

FT_Pos :: i64
FT_Fixed :: i64

FT_LOAD_DEFAULT :: i32(0)
FT_LOAD_RENDER :: i32(1 << 2)

@(default_calling_convention = "c")
foreign freetype_lib {
	FT_Init_FreeType :: proc(alibrary: ^FT_Library) -> FT_Error ---

	FT_Done_FreeType :: proc(library: FT_Library) -> FT_Error ---

	FT_New_Face :: proc(library: FT_Library, pathname: cstring, face_index: FT_Long, aface: ^FT_Face) -> FT_Error ---

	FT_Done_Face :: proc(face: FT_Face) -> FT_Error ---

	FT_Set_Pixel_Sizes :: proc(face: FT_Face, pixel_width: FT_UInt, pixel_height: FT_UInt) -> FT_Error ---

	FT_Load_Char :: proc(face: FT_Face, char_code: FT_ULong, load_flags: i32) -> FT_Error ---
}

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

FT_Bitmap_Size :: struct {
	height: FT_Short,
	width:  FT_Short,
	size:   FT_Pos,
	x_ppem: FT_Pos,
	y_ppem: FT_Pos,
}

FT_ListRec :: struct {
	head: rawptr,
	tail: rawptr,
}

FT_GlyphSlotRec :: struct {
	// FT_Library
	library:           rawptr,

	// FT_Face
	face:              rawptr,

	// FT_GlyphSlot
	next:              rawptr,

	// FT_UInt
	glyph_index:       FT_UInt,
	generic:           FT_Generic,
	metrics:           FT_Glyph_Metrics,

	// FT_Fixed
	linearHoriAdvance: FT_Fixed,
	linearVertAdvance: FT_Fixed,
	advance:           FT_Vector,

	// FT_Glyph_Format / FT_Tag / FT_UInt32
	format:            u32,
	bitmap:            FT_Bitmap,
	bitmap_left:       FT_Int,
	bitmap_top:        FT_Int,
	outline:           FT_Outline,
	num_subglyphs:     FT_UInt,

	// FT_SubGlyph
	subglyphs:         rawptr,
	control_data:      rawptr,

	// C long
	control_len:       FT_Long,
	lsb_delta:         FT_Pos,
	rsb_delta:         FT_Pos,
	other:             rawptr,

	// FT_Slot_Internal
	internal:          rawptr,
}

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

	// FT_CharMap*
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

	// FT_GlyphSlot
	glyph:               ^FT_GlyphSlotRec,

	// FT_Size
	size:                rawptr,

	// FT_CharMap
	charmap:             rawptr,

	// Private FreeType fields.
	driver:              rawptr,
	memory:              rawptr,
	stream:              rawptr,
	sizes_list:          FT_ListRec,
	autohint:            FT_Generic,
	extensions:          rawptr,
	internal:            rawptr,
}

Font :: struct {
	texture: u32,
	width:   int,
	height:  int,
	glyphs:  [256]Glyph,
}

Glyph :: struct {
	x:         i32,
	y:         i32,
	width:     i32,
	height:    i32,
	bearing_x: i32,
	bearing_y: i32,
	advance:   i32,
}
