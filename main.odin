package odit 
import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

DEBUG :: false
SCROLLOFF :: 4
CURSOR_COLOR :: rl.GREEN
SELECTION_COLOR :: rl.BLUE

font_size : f32 = 24
home_toggle := true

Line :: struct {
    text: [dynamic]u8
}

Buffer :: struct {
    offset: [2]f32,
    select: [2]int,
    cursor: [2]int,
    lines:  [dynamic]Line
}

timers := map[rl.KeyboardKey]f32 {
    .BACKSPACE = 0.0,
    .ENTER     = 0.0,
    .UP        = 0.0,
    .DOWN      = 0.0,
    .LEFT      = 0.0,
    .RIGHT     = 0.0,
}

main :: proc() {
    rl.SetTargetFPS(60)
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(600, 400, "Odit")
    defer rl.CloseWindow()

    camera := rl.Camera2D{}
    camera.zoom = 1

    font := rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
    buffer: Buffer
    buffer.lines = make([dynamic]Line, 0, 50)
    get_command_names()

    for !rl.WindowShouldClose() {

        dt := rl.GetFrameTime()
        screen_width, screen_height := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
        font_width, font_height := get_font_dimentions(&font)

        buffer.offset.x = get_line_number_width(&buffer, font_width) + font_width*2

        cursor_rect := rl.Rectangle{f32(buffer.cursor.x)*font_width, f32(buffer.cursor.y)*font_height, font_width, font_height }
        camera_rect, scroll_rect := get_camera_rects(&buffer, &camera, screen_width, screen_height, font_width, font_height)

        // Moving the camera.
        for !rl.CheckCollisionRecs(camera_rect, cursor_rect) {
            if camera_rect.x < cursor_rect.x do camera.target.x += font_width
            if camera_rect.x > cursor_rect.x do camera.target.x -= font_width
            camera_rect, scroll_rect = get_camera_rects(&buffer, &camera, screen_width, screen_height, font_width, font_height)
        }
        if buffer.cursor.y >= SCROLLOFF {
            for !rl.CheckCollisionRecs(scroll_rect, cursor_rect) {
                if scroll_rect.y < cursor_rect.y do camera.target.y += font_height
                if scroll_rect.y > cursor_rect.y do camera.target.y -= font_height
                camera_rect, scroll_rect = get_camera_rects(&buffer, &camera, screen_width, screen_height, font_width, font_height)
            }
        }

        char := i32(rl.GetCharPressed())

        // Typing into the buffer.
        if (char >= ' ' && char <= '~') && !(rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.LEFT_ALT)) {
            using buffer
            if len(lines) == 0 do append(&lines, Line{make([dynamic]u8)})
            if is_selection_active(&buffer) {
                delete_selection(&buffer)
            }
            inject_at(&lines[cursor.y].text, cursor.x, u8(char))
            cursor.x += 1
            reset_selection(&buffer)
        }

        // Updating the time the movement keys have been held.
        for key in timers {
            timer_update(key, dt)
        }

        key := rl.GetKeyPressed()

        if (rl.IsKeyPressed(.E) && rl.IsKeyDown(.LEFT_CONTROL))  || key == .END {
            home_toggle = true
            move_cursor_end(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }
        if (rl.IsKeyPressed(.A) && rl.IsKeyDown(.LEFT_CONTROL)) || key == .HOME {
            if home_toggle do move_cursor_home(&buffer)
            else do move_cursor_home_non_whitespace(&buffer)
            home_toggle = !home_toggle
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .BACKSPACE) {
            if is_selection_active(&buffer) do delete_selection(&buffer)
            else do press_backspace(&buffer)
            reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .ENTER) {
            if is_selection_active(&buffer) do delete_selection(&buffer)
            press_enter(&buffer)
            reset_selection(&buffer)
        }
        
        if key_is_pressed_or_down(key, .UP) {
            move_cursor_up(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .DOWN) {
            move_cursor_down(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .LEFT) {
            move_cursor_left(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .RIGHT) {
            move_cursor_right(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        // Scaling the font. Very expensive operation.
        if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_CONTROL) {
            font_size += 1
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        } else if rl.IsKeyPressed(.MINUS) && rl.IsKeyDown(.LEFT_CONTROL) {
            font_size -= 1
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode2D(camera)
        {
            using buffer

            when DEBUG do fmt.println("---------------------")

            start, end: [2]int
            if is_selection_active(&buffer) do start, end = get_selection_boundaries(&buffer)
            draw_cursor(cursor, offset, font_width, font_height)

            for _, i in lines {
                draw_line_number(&buffer, i, font_width, font_height, font)

                if is_selection_active(&buffer) {
                    draw_line_selection(&buffer, i, start, end, font_width, font_height)
                }

                when DEBUG do fmt.println(i+1, ":", transmute(string)lines[i].text[:])
                draw_line_text(&buffer, i, font_size, font)
            }
            free_all(context.temp_allocator)
            when DEBUG do fmt.println("---------------------")

        }
        rl.EndMode2D()

        when DEBUG {
            if len(lines) > 0 {
                rl.DrawText(rl.TextFormat("line width: %i", i32(len(lines[cursor.y].text))), 400, 0, 30, rl.WHITE)
            }
            rl.DrawText(rl.TextFormat("line count: %i", i32(len(lines))), 400, 30, 30, rl.WHITE)
            rl.DrawText(rl.TextFormat("cursor: %i, %i", i32(cursor.x), i32(cursor.y)), 400, 60, 30, rl.WHITE)
            rl.DrawText(rl.TextFormat("select: %i, %i", i32(select.x), i32(select.y)), 400, 90, 30, rl.WHITE)
        }
        rl.EndDrawing()
    }
}
