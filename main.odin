package odit 
import "core:fmt"
import "core:math"
import "core:strings"
import "core:mem"
import rl "vendor:raylib"

DEBUG :: false
SCROLLOFF :: 4
FONT_SIZE_MIN :: 8
FONT_SIZE_MAX :: 48
FPS :: 60

colors := map[string]rl.Color {
    "bg"      = rl.BLACK,
    "cursor"  = rl.BLACK,
    "text"    = rl.BLACK,
    "select"  = rl.BLACK,
    "ln_bg"   = rl.BLACK,
    "ln_fg"   = rl.BLACK,
    "cmd_bg"  = rl.BLACK,
    "cmd_fg"  = rl.BLACK,
    "cmd_err" = rl.BLACK,
}

// Globals
dt: f32 = 1.0/FPS
quit := false
home_toggle := true
camera := rl.Camera2D{}
font: rl.Font
font_size : f32 = 24
screen_width, screen_height, font_width, font_height: f32

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
    rl.SetTargetFPS(FPS)
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(600, 400, "Odit")
    defer rl.CloseWindow()

    rl.SetExitKey(.KEY_NULL)
    assert(load_theme())

    camera.zoom = 1

    load_font()
    buffer: Buffer
    buffer.lines = make([dynamic]Line, 0, 50)
    append(&buffer.lines, Line{make([dynamic]u8)})

    screen_width, screen_height = f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
    font_width, font_height = get_font_dimentions(&font)

    for !rl.WindowShouldClose() && !quit {

        dt = rl.GetFrameTime()

        screen_width, screen_height = f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
        font_width, font_height = get_font_dimentions(&font)

        buffer.offset.x = get_line_number_width(&buffer) + font_width*2

        // Moving the camera.
        check_camera_collision_x(&buffer)
        check_camera_collision_y(&buffer)

        char := i32(rl.GetCharPressed())

        // Typing into the buffer.
        if (char >= ' ' && char <= '~') && !(rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.LEFT_ALT)) {
            if !command_bar.active {
                using buffer
                if len(lines) == 0 do append(&lines, Line{make([dynamic]u8)})
                if is_selection_active(&buffer) {
                    delete_selection(&buffer)
                }
                inject_at(&lines[cursor.y].text, cursor.x, u8(char))
                cursor.x += 1
                reset_selection(&buffer)
            } else {
                using command_bar
                inject_at(&text, cursor, u8(char))
                cursor += 1
            }
        }

        // Updating the time the movement keys have been held.
        for key in timers {
            timer_update(key, dt)
        }
        cursor_blink_t += dt

        key := rl.GetKeyPressed()

        if key == .TAB && !command_bar.active {
            using buffer
            if len(lines) == 0 do append(&lines, Line{make([dynamic]u8)})
            if is_selection_active(&buffer) {
                delete_selection(&buffer)
            }
            indent := "    "
            inject_at_elem_string(&lines[cursor.y].text, cursor.x, indent)
            cursor.x += len(indent)
            reset_selection(&buffer)
        }
        if (rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.E))  || key == .END {
            home_toggle = true
            move_cursor_end(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }
        if (rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.A)) || key == .HOME {
            if home_toggle do move_cursor_home(&buffer)
            else do move_cursor_home_non_whitespace(&buffer)
            home_toggle = !home_toggle
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyPressed(.X) {
            command_bar.active = true
            command_bar.error_t = 0
        }
        if rl.IsKeyPressed(.ESCAPE) && command_bar.active {
            command_bar.active = false
        }

        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.BACKSPACE) {
            if !command_bar.active {
            } else {
                command_bar_ctrl_backspace(&buffer)
            }
        } else if key_is_pressed_or_down(key, .BACKSPACE) {
            if !command_bar.active {
                if is_selection_active(&buffer) do delete_selection(&buffer)
                else do press_backspace(&buffer)
                reset_selection(&buffer)
            } else {
                press_backspace(&buffer)
            }
        }

        if key_is_pressed_or_down(key, .ENTER) {
            if !command_bar.active {
                if is_selection_active(&buffer) do delete_selection(&buffer)
                press_enter(&buffer)
                reset_selection(&buffer)
            } else {
                command_bar_execute(&buffer, string(command_bar.text[:]))
                command_bar.active = false
            }
        }
        
        if key_is_pressed_or_down(key, .UP) {
            if !command_bar.active {
                move_cursor_up(&buffer)
                if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
            } else {
                using command_bar
                cursor = 0
            }
        }

        if key_is_pressed_or_down(key, .DOWN) {
            if !command_bar.active {
                move_cursor_down(&buffer)
                if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
            } else {
                using command_bar
                cursor = len(text)
            }
        }

        if key_is_pressed_or_down(key, .LEFT) {
            if !command_bar.active {
                move_cursor_left(&buffer)
                if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
            } else {
                using command_bar
                cursor -= 1
                cursor = clamp(cursor, 0, len(text))
            }
        }

        if key_is_pressed_or_down(key, .RIGHT) {
            if !command_bar.active {
                move_cursor_right(&buffer)
                if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
            } else {
                using command_bar
                cursor += 1
                cursor = clamp(cursor, 0, len(text))
            }
        }

        // Scaling the font. Very expensive operation.
        if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_CONTROL) {
            font_size += 1
            font_size = clamp(font_size, FONT_SIZE_MIN, FONT_SIZE_MAX)
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        } else if rl.IsKeyPressed(.MINUS) && rl.IsKeyDown(.LEFT_CONTROL) {
            font_size -= 1
            font_size = clamp(font_size, FONT_SIZE_MIN, FONT_SIZE_MAX)
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        }

        rl.BeginDrawing()
        rl.ClearBackground(colors["bg"])
        rl.BeginMode2D(camera)
        {
            using buffer

            when DEBUG do fmt.println("---------------------")

            start, end: [2]int
            if is_selection_active(&buffer) do start, end = get_selection_boundaries(&buffer)
            if !command_bar.active {
                draw_cursor(cursor, offset, colors["cursor"])
            }

            for _, i in lines {
                draw_line_number(&buffer, i, font)

                if is_selection_active(&buffer) {
                    draw_line_selection(&buffer, i, start, end)
                }

                when DEBUG do fmt.println(i+1, ":", transmute(string)lines[i].text[:])
                draw_line_text(&buffer, i, font)
            }


            when DEBUG do fmt.println("---------------------")

        }
        rl.EndMode2D()

        command_bar.error_t = max(command_bar.error_t - dt, 0)
        draw_command_bar(font);
        if command_bar.active {
            draw_command_bar_cursor(colors["cursor"])
            draw_command_bar_text(font)
        } else if command_bar.error_t > 0 {
            draw_command_bar_error(font)
        }

        when DEBUG {
            if len(lines) > 0 {
                rl.DrawText(rl.TextFormat("line width: %i", i32(len(lines[cursor.y].text))), 400, 0, 30, colors["text"])
            }
            rl.DrawText(rl.TextFormat("line count: %i", i32(len(lines))), 400, 30, 30, colors["text"])
            rl.DrawText(rl.TextFormat("cursor: %i, %i", i32(cursor.x), i32(cursor.y)), 400, 60, 30, colors["text"])
            rl.DrawText(rl.TextFormat("select: %i, %i", i32(select.x), i32(select.y)), 400, 90, 30, colors["text"])
        }
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }
}
