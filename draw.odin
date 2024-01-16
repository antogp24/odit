package odit

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


cursor_blink_t: f32

// Buffer
// ----------------------------------------------------------------------------------------------------------------------------------- //

make_cursor_color_blink :: proc(c: rl.Color, freq: f32 = 0.7) -> (result: rl.Color) {
    t := (math.cos(cursor_blink_t*freq*2*math.PI) + 1) * 0.25
    s := (math.sin(cursor_blink_t*freq*2*math.PI) + 1) * 0.30
    result.r = u8(clamp(f32(c.r) + t*f32(c.r), 0, 255))
    result.g = u8(clamp(f32(c.g) + t*f32(c.g), 0, 255))
    result.b = u8(clamp(f32(c.b) + t*f32(c.b), 0, 255))
    result.a = u8(clamp(f32(c.a) - s*f32(c.a), 0, 255))
    return result
}

draw_cursor :: proc(pos: [2]int, offset: [2]f32, _color: rl.Color) {
    color := make_cursor_color_blink(_color)

    rect := rl.Rectangle {
        offset.x + f32(pos.x)*font_width,
        offset.y + f32(pos.y)*font_height,
        font_width,
        font_height,
    }
    rl.DrawRectangleRec(rect, color)
}

draw_line_selection :: proc(using buffer: ^Buffer, i: int, _start, end: [2]int) {
    rec: rl.Rectangle
    start := _start
    if cursor.x <= start.x && cursor.y == i do start.x += 1
    if start.y == end.y && i == start.y {
        rec = rl.Rectangle{f32(start.x)*font_width, f32(start.y)*font_height, f32(end.x - start.x)*font_width, font_height} }
    else if i == start.y {
        width := max(len(lines[i].text) - start.x, 0)
        rec = rl.Rectangle{f32(start.x)*font_width, f32(start.y)*font_height, f32(width)*font_width, font_height} }
    else if start.y < i && i < end.y {
        rec = rl.Rectangle{0, f32(i)*font_height, f32(len(lines[i].text))*font_width, font_height}
    }
    else if i == end.y {
        rec = rl.Rectangle{0, f32(end.y)*font_height, f32(end.x)*font_width, font_height}
    }
    if rec.width == 0 && i != cursor.y do rec.width = font_width / 4
    rec.x += offset.x
    rec.y += offset.y
    rl.DrawRectangleRec(rec, colors["select"])
}

draw_line_number :: proc(using buffer: ^Buffer, i: int, font: rl.Font) {
    rec := rl.Rectangle {
        0,
        f32(i)*font_height,
        get_line_number_width(buffer) + font_width*2,
        font_height,
    }
    pos := rl.Vector2 {
        rec.x + rec.width - font_width - cast(f32)digit_count(i+1)*font_width,
        rec.y,
    }
    rl.DrawRectangleRec(rec, colors["ln_bg"])
    rl.DrawTextEx(font, rl.TextFormat("%i", i+1), pos, font_size, 0, colors["ln_fg"])
}

draw_line_text :: proc(using buffer: ^Buffer, i: int, font: rl.Font) {
    text := buffer_copy_to_cstring(lines[i].text)
    pos := rl.Vector2{0, f32(i)*font_size}
    pos.x += offset.x
    pos.y += offset.y
    rl.DrawTextEx(font, text, pos, font_size, 0, colors["text"])
}

// Command Bar
// ----------------------------------------------------------------------------------------------------------------------------------- //

draw_command_bar :: proc(font: rl.Font) {
    rl.DrawRectangleRec(rl.Rectangle{0, screen_height - font_height, screen_width, font_height}, colors["cmd_bg"])
    if command_bar.active {
        rl.DrawTextEx(font, ":", rl.Vector2{0, screen_height - font_height}, font_size, 0, colors["cmd_fg"])
    }
}

draw_command_bar_cursor :: proc(_color: rl.Color) {
    color := make_cursor_color_blink(_color)

    using command_bar
    rect := rl.Rectangle {
        f32(cursor + 1) * font_width,
        screen_height - font_height,
        font_width,
        font_height,
    }
    rl.DrawRectangleRec(rect, color)
}

draw_command_bar_text :: proc(font: rl.Font) {
    using command_bar
    command_cstr := buffer_copy_to_cstring(command_bar.text)
    pos := rl.Vector2{font_width, screen_height - font_height}
    rl.DrawTextEx(font, command_cstr, pos, font_size, 0, colors["cmd_fg"])
}

draw_command_bar_error :: proc(font: rl.Font) {
    using command_bar
    pos := rl.Vector2{0, screen_height - font_height}
    rl.DrawTextEx(font, cstring("[command error]"), pos, font_size, 0, colors["cmd_err"])
}
