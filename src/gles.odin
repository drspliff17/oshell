package main

foreign import gles_lib "system:libGLESv2.so.2"

// Boolean values

GL_FALSE :: i32(0)
GL_TRUE :: i32(1)

// Clear buffers

GL_COLOR_BUFFER_BIT :: u32(0x00000000)

// Data types

GL_FLOAT :: u32(0x1406)
GL_UNSIGNED_BYTE :: u32(0x1401)
GL_ONE :: u32(1)

// Primitive types

GL_TRIANGLES :: u32(0x0004)

// Buffers

GL_ARRAY_BUFFER :: u32(0x8892)
GL_STATIC_DRAW :: u32(0x88E4)
GL_DYNAMIC_DRAW :: u32(0x88E8)

// Shaders

GL_VERTEX_SHADER :: u32(0x8B31)
GL_FRAGMENT_SHADER :: u32(0x8B30)
GL_COMPILE_STATUS :: u32(0x8B81)
GL_LINK_STATUS :: u32(0x8B82)
GL_INFO_LOG_LENGTH :: u32(0x8B84)
GL_SCISSOR_TEST :: u32(0x0C11)

// Textures

GL_TEXTURE_2D :: u32(0x0DE1)
GL_TEXTURE0 :: u32(0x84C0)
GL_ALPHA :: u32(0x1906)
GL_TEXTURE_MAG_FILTER :: u32(0x2800)
GL_TEXTURE_MIN_FILTER :: u32(0x2801)
GL_TEXTURE_WRAP_S :: u32(0x2802)
GL_TEXTURE_WRAP_T :: u32(0x2803)
GL_LINEAR :: i32(0x2601)
GL_CLAMP_TO_EDGE :: i32(0x812F)
GL_UNPACK_ALIGNMENT :: u32(0x0CF5)

// Blending

GL_BLEND :: u32(0x0BE2)
GL_SRC_ALPHA :: u32(0x0302)
GL_ONE_MINUS_SRC_ALPHA :: u32(0x0303)


@(default_calling_convention = "c")
foreign gles_lib {

	// Framebuffer

	glClearColor :: proc(red: f32, green: f32, blue: f32, alpha: f32) ---
	glClear :: proc(mask: u32) ---

	// Shader compilation

	glCreateShader :: proc(shader_type: u32) -> u32 ---
	glShaderSource :: proc(shader: u32, count: i32, string: ^cstring, length: ^i32) ---
	glCompileShader :: proc(shader: u32) ---
	glGetShaderiv :: proc(shader: u32, pname: u32, params: ^i32) ---
	glGetShaderInfoLog :: proc(shader: u32, buf_size: i32, length: ^i32, info_log: ^u8) ---
	glDeleteShader :: proc(shader: u32) ---

	// Shader programs

	glCreateProgram :: proc() -> u32 ---
	glAttachShader :: proc(program: u32, shader: u32) ---
	glBindAttribLocation :: proc(program: u32, index: u32, name: cstring) ---
	glLinkProgram :: proc(program: u32) ---
	glGetProgramiv :: proc(program: u32, pname: u32, params: ^i32) ---
	glGetProgramInfoLog :: proc(program: u32, buf_size: i32, length: ^i32, info_log: ^u8) ---
	glDeleteProgram :: proc(program: u32) ---
	glUseProgram :: proc(program: u32) ---

	// Buffer objects

	glGenBuffers :: proc(n: i32, buffers: ^u32) ---
	glBindBuffer :: proc(target: u32, buffer: u32) ---
	glBufferData :: proc(target: u32, size: int, data: rawptr, usage: u32) ---
	glBufferSubData :: proc(target: u32, offset: int, size: int, data: rawptr) ---
	glDeleteBuffers :: proc(n: i32, buffers: ^u32) ---

	// Vertex attributes

	glGetAttribLocation :: proc(program: u32, name: cstring) -> i32 ---
	glEnableVertexAttribArray :: proc(index: u32) ---
	glVertexAttribPointer :: proc(index: u32, size: i32, type: u32, normalized: i32, stride: i32, pointer: rawptr) ---

	// Uniforms

	glGetUniformLocation :: proc(program: u32, name: cstring) -> i32 ---
	glUniform1i :: proc(location: i32, v0: i32) ---
	glUniform1f :: proc(location: i32, v0: f32) ---
	glUniform2f :: proc(location: i32, v0: f32, v1: f32) ---
	glUniform4f :: proc(location: i32, v0: f32, v1: f32, v2: f32, v3: f32) ---

	// Textures

	glGenTextures :: proc(n: i32, textures: ^u32) ---
	glDeleteTextures :: proc(n: i32, textures: ^u32) ---
	glActiveTexture :: proc(texture: u32) ---
	glBindTexture :: proc(target: u32, texture: u32) ---
	glTexParameteri :: proc(target: u32, pname: u32, param: i32) ---
	glPixelStorei :: proc(pname: u32, param: i32) ---
	glTexImage2D :: proc(target: u32, level: i32, internal_format: i32, width: i32, height: i32, border: i32, format: u32, typ: u32, pixels: rawptr) ---
	glTexSubImage2D :: proc(target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, typ: u32, pixels: rawptr) ---

	// Drawing

	glDrawArrays :: proc(mode: u32, first: i32, count: i32) ---

	// Render state

	glViewport :: proc(x: i32, y: i32, width: i32, height: i32) ---
	glEnable :: proc(cap: u32) ---
	glDisable :: proc(cap: u32) ---
	glBlendFunc :: proc(sf: u32, df: u32) ---
	glScissor :: proc(x: i32, y: i32, width: i32, height: i32) ---

}
