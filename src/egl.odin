package main

foreign import egl_lib "system:libEGL.so.1"

EGLDisplay :: rawptr
EGLConfig :: rawptr
EGLSurface :: rawptr
EGLContext :: rawptr

EGL_FALSE :: i32(0)
EGL_TRUE :: i32(1)

EGL_NONE :: i32(0x3038)
EGL_RENDERABLE_TYPE :: i32(0x3040)
EGL_OPENGL_ES2_BIT :: i32(0x0004)
EGL_SURFACE_TYPE :: i32(0x3033)
EGL_WINDOW_BIT :: i32(0x0004)
EGL_CONTEXT_CLIENT_VERSION :: i32(0x3098)

EGL_OPENGL_ES_API :: u32(0x30A0)

@(default_calling_convention = "c")
foreign egl_lib {
	eglGetDisplay :: proc(native_display: rawptr) -> EGLDisplay ---
	eglInitialize :: proc(display: EGLDisplay, major: ^i32, minor: ^i32) -> i32 ---
	eglTerminate :: proc(display: EGLDisplay) -> i32 ---

	eglChooseConfig :: proc(display: EGLDisplay, attributes: ^i32, configs: ^EGLConfig, config_size: i32, num_config: ^i32) -> i32 ---

	eglBindAPI :: proc(api: u32) -> i32 ---

	eglCreateContext :: proc(display: EGLDisplay, config: EGLConfig, share_context: EGLContext, attributes: ^i32) -> EGLContext ---

	eglDestroyContext :: proc(display: EGLDisplay, ctx: EGLContext) -> i32 ---

	eglCreateWindowSurface :: proc(display: EGLDisplay, config: EGLConfig, window: rawptr, attributes: ^i32) -> EGLSurface ---

	eglDestroySurface :: proc(display: EGLDisplay, surface: EGLSurface) -> i32 ---

	eglMakeCurrent :: proc(display: EGLDisplay, draw: EGLSurface, read: EGLSurface, ctx: EGLContext) -> i32 ---

	eglSwapBuffers :: proc(display: EGLDisplay, surface: EGLSurface) -> i32 ---

	eglGetError :: proc() -> i32 ---

}
