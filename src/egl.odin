package main

foreign import egl_lib "system:libEGL.so.1"

// EGL handles
EGLDisplay :: rawptr
EGLConfig :: rawptr
EGLSurface :: rawptr
EGLContext :: rawptr


// Boolean values
EGL_FALSE :: i32(0)
EGL_TRUE :: i32(1)


// Attribute terminator
EGL_NONE :: i32(0x3038)


// Configuration attributes
EGL_ALPHA_SIZE :: i32(0x3021)
EGL_RENDERABLE_TYPE :: i32(0x3040)
EGL_SURFACE_TYPE :: i32(0x3033)


// Configuration flags
EGL_OPENGL_ES2_BIT :: i32(0x0004)
EGL_WINDOW_BIT :: i32(0x0004)


// Context attributes
EGL_CONTEXT_CLIENT_VERSION :: i32(0x3098)


// Rendering APIs
EGL_OPENGL_ES_API :: u32(0x30A0)


@(default_calling_convention = "c")
foreign egl_lib {

	// Display lifecycle
	eglGetDisplay :: proc(native_display: rawptr) -> EGLDisplay ---

	eglInitialize :: proc(display: EGLDisplay, major: ^i32, minor: ^i32) -> i32 ---

	eglTerminate :: proc(display: EGLDisplay) -> i32 ---


	// Configuration selection
	eglChooseConfig :: proc(display: EGLDisplay, attributes: ^i32, configs: ^EGLConfig, config_size: i32, num_config: ^i32) -> i32 ---

	// Rendering API selection
	eglBindAPI :: proc(api: u32) -> i32 ---

	// Context lifecycle
	eglCreateContext :: proc(display: EGLDisplay, config: EGLConfig, share_context: EGLContext, attributes: ^i32) -> EGLContext ---

	eglDestroyContext :: proc(display: EGLDisplay, ctx: EGLContext) -> i32 ---


	// Surface lifecycle
	eglCreateWindowSurface :: proc(display: EGLDisplay, config: EGLConfig, window: rawptr, attributes: ^i32) -> EGLSurface ---

	eglDestroySurface :: proc(display: EGLDisplay, surface: EGLSurface) -> i32 ---


	// Current rendering context
	eglMakeCurrent :: proc(display: EGLDisplay, draw: EGLSurface, read: EGLSurface, ctx: EGLContext) -> i32 ---

	// Frame presentation
	eglSwapBuffers :: proc(display: EGLDisplay, surface: EGLSurface) -> i32 ---

	// Error reporting
	eglGetError :: proc() -> i32 ---
}
