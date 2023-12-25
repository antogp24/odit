package odit
import rl "vendor:raylib"

draw_cursor :: proc(pos: [2]int, offset: [2]f32, font_width, font_height: f32, color := CURSOR_COLOR) {
    rect := rl.Rectangle {
        offset.x + f32(pos.x)*font_width,
        offset.y + f32(pos.y)*font_height,
        font_width,
        font_height,
    }
    rl.DrawRectangleRec(rect, color)
}

draw_line_selection :: proc(using buffer: ^Buffer, i: int, _start, end: [2]int, font_width, font_height: f32) {
    rec: rl.Rectangle
    start := _start
    if cursor.x <= start.x && cursor.y == i do start.x += 1
    if start.y == end.y && i == start.y {
        rec = rl.Rectangle{f32(start.x)*font_width, f32(start.y)*font_height, f32(end.x - start.x)*font_width, font_height}
    }
    else if i == start.y {
        width := max(len(lines[i].text) - start.x, 0)
        rec = rl.Rectangle{f32(start.x)*font_width, f32(start.y)*font_height, f32(width)*font_width, font_height}
    }
    else if start.y < i && i < end.y {
        rec = rl.Rectangle{0, f32(i)*font_height, f32(len(lines[i].text))*font_width, font_height}
    }
    else if i == end.y {
        rec = rl.Rectangle{0, f32(end.y)*font_height, f32(end.x)*font_width, font_height}
    }
    if rec.width == 0 && i != cursor.y do rec.width = font_width / 4
    rec.x += offset.x
    rec.y += offset.y
    rl.DrawRectangleRec(rec, SELECTION_COLOR)
}

draw_line_number :: proc(using buffer: ^Buffer, i: int, font_width, font_height: f32, font: rl.Font) {
    rec := rl.Rectangle {
        0,
        f32(i)*font_height,
        get_line_number_width(buffer, font_width) + font_width*2,
        font_height,
    }
    pos := rl.Vector2 {
        rec.x + rec.width - font_width - cast(f32)digit_count(i+1)*font_width,
        rec.y,
    }
    rl.DrawRectangleRec(rec, rl.Color{20, 20, 50, 255})
    rl.DrawTextEx(font, rl.TextFormat("%i", i+1), pos, font_size, 0, rl.WHITE)
}

draw_line_text :: proc(using buffer: ^Buffer, i: int, font_size: f32, font: rl.Font) {
    text := u8_copy_to_cstring(lines[i].text)
    pos := rl.Vector2{0, f32(i)*font_size}
    pos.x += offset.x
    pos.y += offset.y
    rl.DrawTextEx(font, text, pos, font_size, 0, rl.WHITE)
}

