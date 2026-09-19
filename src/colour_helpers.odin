package main

import "core:math"

rgb_to_col :: proc(r: int, g: int, b: int) -> [3]f32 {
	return {f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0}
}

colour_shift :: proc(c: Col, amount: i16) -> Col {
	shift := f32(amount) / 255.0

	return Col {
		clamp(c.r + shift, 0.0, 1.0),
		clamp(c.g + shift, 0.0, 1.0),
		clamp(c.b + shift, 0.0, 1.0),
		c.a,
	}
}

srgb_to_lower :: proc(v: f32) -> f32 {
	if v <= 0.04045 do return v / 12.92
	return f32(math.pow(f64((v + 0.055) / 1.055), 2.4))
}

colour_luminance :: proc(c: Col) -> f32 {
	r := srgb_to_lower(c.r)
	g := srgb_to_lower(c.g)
	b := srgb_to_lower(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

contrast_ratio :: proc(a: Col, b: Col) -> f32 {
	l1 := colour_luminance(a)
	l2 := colour_luminance(b)
	lighter := max(l1, l2)
	darker := min(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)
}

get_contrasting_colour :: proc(bg: Col, dark: Col, light: Col) -> Col {
	dc := contrast_ratio(bg, dark)
	lc := contrast_ratio(bg, light)
	if lc > dc do return light
	return dark
}

set_alpha :: proc(c: Col, alpha: f32) -> Col {return Col{c.r, c.g, c.b, alpha}}

update_shifted_colours :: proc(amt: i16 = 20) {
	fc := get_contrasting_colour(
		PYWAL_COLOURS.Color4,
		{0.22, 0.22, 0.22, 1},
		{0.78, 0.78, 0.78, 1},
	)

	COLOURS = {
		Background        = PYWAL_COLOURS.Background,
		Background_Raised = colour_shift(PYWAL_COLOURS.Background, -amt),
		Background_Sunken = colour_shift(PYWAL_COLOURS.Background, amt),
		//
		Border            = PYWAL_COLOURS.Color9,
		Border_Raised     = colour_shift(PYWAL_COLOURS.Color9, -amt),
		Border_Sunken     = colour_shift(PYWAL_COLOURS.Color9, amt),
		//
		Widget            = PYWAL_COLOURS.Color4,
		Widget_Raised     = colour_shift(PYWAL_COLOURS.Color4, -amt),
		Widget_Sunken     = colour_shift(PYWAL_COLOURS.Color4, amt),
		//
		Font              = fc,
		Font_Dim          = set_alpha(fc, 0.8),
		Font_Muted        = set_alpha(fc, 0.65),
	}

	COLOURS.Border_Contrast_Widget = get_contrasting_colour(
		PYWAL_COLOURS.Color4,
		COLOURS.Border_Sunken,
		COLOURS.Border_Raised,
	)

}
