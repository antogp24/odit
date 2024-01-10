package odit

import "core:math"
import "core:strings"
import rl "vendor:raylib"

digit_count :: proc(number: int) -> int {
    if number == 0 do return 1
    return cast(int)math.log10_f32(cast(f32)number) + 1
}

get_line_number_width :: proc(using buffer: ^Buffer) -> f32 {
    return cast(f32)digit_count(len(lines))*font_width
}

string_to_u8_dyn :: proc(text: string) -> [dynamic]u8 {
    result := make([dynamic]u8)
    for c in text {
        append(&result, u8(c))
    }
    return result
}

u8_copy_to_cstring :: proc(text: [dynamic]u8, alloc := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(transmute(string)text[:], alloc)
}

get_font_dimentions :: proc(font: ^rl.Font) -> (width, height: f32) {
    mz := rl.MeasureTextEx(font^, "a", font_size, 0)
    width, height = mz.x, mz.y
    return 
}

is_selection_active :: proc(using buffer: ^Buffer) -> bool {
    return !(select.x == cursor.x && select.y == cursor.y)
}

reset_selection :: proc(using buffer: ^Buffer) {
    select = cursor
}

timer_update :: proc(key: rl.KeyboardKey, dt: f32) {
    if rl.IsKeyDown(key) {
        timers[key] += dt
    } else {
        timers[key] = 0
    }
}

// https://www.geogebra.org/calculator
square_wave :: proc (x, period: f32) -> bool {
    using math
    result := -floor(sin(x * PI / period))
    return bool(int(result))
}

key_is_pressed_or_down :: proc(pressed, key: rl.KeyboardKey, threshold: f32 = 0.3) -> bool {
    return pressed == key || (timers[key] > threshold && square_wave(timers[key], 0.015))
}

get_selection_boundaries :: proc(using buffer: ^Buffer) -> (start, end: [2]int) {
    if select.y == cursor.y {
        if select.x < cursor.x {
            return select, cursor
        } else if select.x > cursor.x {
            return cursor, select
        }
    } else if select.y < cursor.y {
        return select, cursor
    } else if select.y > cursor.y {
        return cursor, select
    }
    return
}

get_camera_rects :: proc(using buffer: ^Buffer) -> (camera_rect, scroll_rect: rl.Rectangle) {
    camera_rect = rl.Rectangle{camera.target.x, camera.target.y, screen_width - offset.x, screen_height - offset.y}
    scroll_rect = camera_rect
    scroll_rect.y += SCROLLOFF * font_height
    scroll_rect.height -= SCROLLOFF * font_height * 2

    return camera_rect, scroll_rect
}

check_camera_collision_x :: proc(using buffer: ^Buffer) {
    cursor_rect := rl.Rectangle{f32(cursor.x)*font_width, f32(cursor.y)*font_height, font_width, font_height }
    camera_rect, scroll_rect := get_camera_rects(buffer)

    for !rl.CheckCollisionRecs(camera_rect, cursor_rect) {
        if camera_rect.x < cursor_rect.x do camera.target.x += font_width
        if camera_rect.x > cursor_rect.x do camera.target.x -= font_width
        camera_rect, scroll_rect = get_camera_rects(buffer)
    }
}

check_camera_collision_y:: proc(using buffer: ^Buffer) {
    cursor_rect := rl.Rectangle{f32(cursor.x)*font_width, f32(cursor.y)*font_height, font_width, font_height }
    camera_rect, scroll_rect := get_camera_rects(buffer)

    if buffer.cursor.y >= SCROLLOFF {
        for !rl.CheckCollisionRecs(scroll_rect, cursor_rect) {
            if scroll_rect.y < cursor_rect.y do camera.target.y += font_height
            if scroll_rect.y > cursor_rect.y do camera.target.y -= font_height
            camera_rect, scroll_rect = get_camera_rects(buffer)
        }
    }
}
