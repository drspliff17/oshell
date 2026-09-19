package main

import fmt "core:fmt"
import os "core:os"
import strconv "core:strconv"
import strings "core:strings"

Pywal_Colours :: struct {
	Background: Col,
	Foreground: Col,
	Color0:     Col,
	Color1:     Col,
	Color2:     Col,
	Color3:     Col,
	Color4:     Col,
	Color5:     Col,
	Color6:     Col,
	Color7:     Col,
	Color8:     Col,
	Color9:     Col,
	Color10:    Col,
	Color11:    Col,
	Color12:    Col,
	Color13:    Col,
	Color14:    Col,
	Color15:    Col,
}

PYWAL_COLOURS: Pywal_Colours
PYWAL_PATH :: "/home/drspliff/.cache/wal/colors-rgb"

Shifted_Colours :: struct {
	//
	Background:             Col,
	Background_Raised:      Col,
	Background_Sunken:      Col,
	//
	Border:                 Col,
	Border_Raised:          Col,
	Border_Sunken:          Col,
	Border_Contrast_Widget: Col,
	//
	Widget:                 Col,
	Widget_Raised:          Col,
	Widget_Sunken:          Col,
	//
	Font:                   Col,
	Font_Dim:               Col,
	Font_Muted:             Col,
}

COLOURS: Shifted_Colours

update_colours :: proc(alpha: f32 = 0.96) {
	if !os.exists(PYWAL_PATH) do fmt.panicf("Could not find the given file: %s\n", PYWAL_PATH)

	data, read_err := os.read_entire_file(PYWAL_PATH, context.allocator)
	if read_err != nil {
		fmt.eprintln("update_colours: Failed to read pywal cached file")
		os.exit(1)
	}
	defer delete(data)

	lines := strings.split(string(data), "\n", context.allocator)
	defer delete(lines)

	colours: [16]Col
	i := 0

	for line in lines {
		if line == "" do continue
		parts := strings.split(line, ",", context.allocator)
		if len(parts) != 3 {
			delete(parts)
			continue
		}
		r, r_ok := strconv.parse_int(strings.trim_space(parts[0]))
		g, g_ok := strconv.parse_int(strings.trim_space(parts[1]))
		b, b_ok := strconv.parse_int(strings.trim_space(parts[2]))
		delete(parts)
		if !r_ok || !g_ok || !b_ok do continue

		if i < 16 {
			c := rgb_to_col(r, g, b)
			colours[i] = Col{c.r, c.g, c.b, alpha}
			i += 1
		}
		if i >= 16 do break
	}

	PYWAL_COLOURS = Pywal_Colours {
		Background = colours[0],
		Foreground = colours[15],
		Color0     = colours[0],
		Color1     = colours[1],
		Color2     = colours[2],
		Color3     = colours[3],
		Color4     = colours[4],
		Color5     = colours[5],
		Color6     = colours[6],
		Color7     = colours[7],
		Color8     = colours[8],
		Color9     = colours[9],
		Color10    = colours[10],
		Color11    = colours[11],
		Color12    = colours[12],
		Color13    = colours[13],
		Color14    = colours[14],
		Color15    = colours[15],
	}

	update_shifted_colours()
}
