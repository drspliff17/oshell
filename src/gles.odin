package main

GL_COLOR_BUFFER_BIT :: u32(0x00004000)

foreign import gles_lib "system:libGLESv2.so.2"

@(default_calling_convention = "c")
foreign gles_lib {
	glClearColor :: proc(red: f32, green: f32, blue: f32, alpha: f32) ---
	glClear :: proc(mask: u32) ---
}
