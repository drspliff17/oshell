package main

import "core:fmt"
import "core:strings"

compile_shader :: proc(kind: u32, source: string) -> u32 {
	shader := glCreateShader(kind)

	source_cstr := strings.clone_to_cstring(source)
	defer delete(source_cstr)

	glShaderSource(shader, 1, &source_cstr, nil)

	glCompileShader(shader)

	success: i32
	glGetShaderiv(shader, GL_COMPILE_STATUS, &success)

	if success == GL_FALSE {
		log_length: i32
		glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &log_length)

		if log_length > 0 {
			log := make([]byte, log_length)
			defer delete(log)

			glGetShaderInfoLog(shader, log_length, nil, &log[0])

			fmt.eprintln("Shader compilation failed:")
			fmt.eprintln(string(log))
		}
	}

	return shader
}


create_program :: proc(vertex_source, fragment_source: string) -> u32 {
	vertex_shader := compile_shader(GL_VERTEX_SHADER, vertex_source)

	fragment_shader := compile_shader(GL_FRAGMENT_SHADER, fragment_source)

	if vertex_shader == 0 || fragment_shader == 0 {
		if vertex_shader != 0 {
			glDeleteShader(vertex_shader)
		}

		if fragment_shader != 0 {
			glDeleteShader(fragment_shader)
		}

		return 0
	}

	program := glCreateProgram()

	glAttachShader(program, vertex_shader)
	glAttachShader(program, fragment_shader)

	glBindAttribLocation(program, 0, "position")

	glLinkProgram(program)

	success: i32
	glGetProgramiv(program, GL_LINK_STATUS, &success)

	if success == GL_FALSE {
		log_length: i32
		glGetProgramiv(program, GL_INFO_LOG_LENGTH, &log_length)

		if log_length > 0 {
			log := make([]byte, log_length)
			defer delete(log)

			glGetProgramInfoLog(program, log_length, nil, &log[0])

			fmt.eprintln("Program linking failed:")
			fmt.eprintln(string(log))
		}

		glDeleteProgram(program)
		program = 0
	}

	glDeleteShader(vertex_shader)
	glDeleteShader(fragment_shader)

	return program
}
