package console

import "core:slice"

terminal_code_copy_buffer :: proc(from, to : [2]int, length : int)
{
    temp_buffer := terminal_data.code[to.y]

    clamped_length := min(length + from.x, CODELINE_SIZE) - from.x
    clamped_length = min(length + to.x, CODELINE_SIZE) - to.x
    for i := 0; i < clamped_length; i += 1
    {
        temp_buffer[to.x + i] = terminal_data.code[from.y][from.x + i]
    }

    terminal_data.code[to.y] = temp_buffer
}

terminal_code_shift_buffer :: proc(x, y, step : int, hole_filler : u8 = 0)
{
    temp_buffer := terminal_data.code[y]

    // clear old slice
    slice.fill(temp_buffer[x:], hole_filler)

    // rewrite buffer
    for i := x; i < CODELINE_SIZE; i += 1
    {
        if i + step < 0 || i + step >= CODELINE_SIZE do continue

        temp_buffer[i + step] = terminal_data.code[y][i]
    }

    terminal_data.code[y] = temp_buffer
}
 
terminal_code_insert :: proc(x, y : int, char : u8)
{
    terminal_code_shift_buffer(x, y, 1)
    terminal_data.code[y][x] = char
}

terminal_code_remove :: proc(x, y : int)
{
    if x == CODELINE_SIZE
    {
        terminal_data.code[y][x - 1] = 0
    }
    else
    {
        terminal_code_shift_buffer(x, y, -1)
    }
}

// the next null char in a line
terminal_code_line_end :: proc(line_number : int) -> int
{
    line_end := CODELINE_SIZE
    for i in 0..<CODELINE_SIZE
    {
        if terminal_data.code[line_number][i] == 0
        {
            line_end = i
            break
        }
    }

    return line_end
}

displacement_to_range :: proc(val, min_val, max_val : $T) -> T
{
    return max(min_val, min(val, max_val)) - val
}

terminal_code_shift_screen :: proc(ce : ^TerminalCodeEditor)
{
    cursor_dx := displacement_to_range(ce.cursor.x, ce.top_left_position.x, ce.top_left_position.x + TERMINAL_WIDTH - 1)
    cursor_dy := displacement_to_range(ce.cursor.y, ce.top_left_position.y, ce.top_left_position.y + TERMINAL_HEIGHT - 2)

    ce.top_left_position -= {cursor_dx, cursor_dy}
}

terminal_code_draw_all :: proc(cursor_position : [2]int, top_left_position : [2]int)
{
    // Coding area
    for j in 0..<(TERMINAL_HEIGHT - 1)
    {
        for i in 0..<TERMINAL_WIDTH
        {
            char : u8 = 0
            if j + top_left_position.y < len(terminal_data.code) && i + top_left_position.x < CODELINE_SIZE
            {
                char = terminal_data.code[j + top_left_position.y][i + top_left_position.x]
            } 

            terminal_data.chars[j][i] = char
        }
    }

    // Bottom line
    for i in 0..<TERMINAL_WIDTH
    {
        BLACK_ON_WHITE :: 0b11110000
        terminal_data.char_colors[TERMINAL_HEIGHT - 1] = BLACK_ON_WHITE
        terminal_data.chars[TERMINAL_HEIGHT - 1] = {0, 0, 0, 0, 'C', 'O', 'D', 'E', 0, 'E', 'D', 'I', 'T', 'O', 'R', 0, 0, 0,
                                                    0, 1, 1, 1, ':', 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        // Cursor position
        terminal_data.chars[TERMINAL_HEIGHT - 1][19] = u8(cursor_position.y / 100) + '0'
        terminal_data.chars[TERMINAL_HEIGHT - 1][20] = u8(cursor_position.y / 10 % 10) + '0'
        terminal_data.chars[TERMINAL_HEIGHT - 1][21] = u8(cursor_position.y % 10) + '0'

        terminal_data.chars[TERMINAL_HEIGHT - 1][23] = u8(cursor_position.x / 10 % 10) + '0'
        terminal_data.chars[TERMINAL_HEIGHT - 1][24] = u8(cursor_position.x % 10) + '0'
    }

    terminal_data.should_refresh = true
}

terminal_code_relative_cursor_position :: proc() -> (int, int)
{
    ce := terminal_data.state.(TerminalCodeEditor)
    return ce.cursor.x - ce.top_left_position.x, ce.cursor.y - ce.top_left_position.y
}

terminal_update_code_editor :: proc(code_editor : ^TerminalCodeEditor)
{
    should_redraw : bool
    empty_line : [64]u8
    if !code_editor.is_initted
    {
        code_editor.is_initted = true

        terminal_data.char_colors = terminal_data.color

        if len(terminal_data.code) == 0
        {
            append(&terminal_data.code, empty_line)
        }

        should_redraw = true
    }

    // Cursor blink
    if get_time() > code_editor.last_cursor_blink + CURSOR_BLINK_INTERVAL
    {
        code_editor.last_cursor_blink = get_time()
        terminal_invert_cell_color(terminal_code_relative_cursor_position())
    }

    // Letter typing
    if new_char := get_key_letter(); new_char != 0 && code_editor.cursor.x < CODELINE_SIZE
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())

        terminal_code_insert(code_editor.cursor.x, code_editor.cursor.y, new_char)
        
        code_editor.cursor.x += 1
        code_editor.desired_cursor_x = code_editor.cursor.x
        should_redraw = true
    }

    // Deleting
    if keyboard_state.key == .BACKSPACE
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())

        if code_editor.cursor.x > 0
        {   // Delete letter
            terminal_code_remove(code_editor.cursor.x, code_editor.cursor.y)
            code_editor.cursor.x -= 1
            should_redraw = true
            
            code_editor.desired_cursor_x = code_editor.cursor.x
        }
        else if code_editor.cursor.y > 0
        {   // Delete line
            cursor_position_after_deletion := [2]int {terminal_code_line_end(code_editor.cursor.y - 1), code_editor.cursor.y - 1}

            if terminal_data.code[code_editor.cursor.y] != empty_line
            {
                // copy current line to upper
                upper_line_no := code_editor.cursor.y - 1
                upper_line_end := terminal_code_line_end(upper_line_no)
                terminal_code_shift_buffer(0, code_editor.cursor.y, upper_line_end, hole_filler = ' ')
                terminal_code_copy_buffer({upper_line_end, code_editor.cursor.y}, {upper_line_end, upper_line_no}, terminal_code_line_end(code_editor.cursor.y) - upper_line_end)
            }

            // remove line
            ordered_remove(&terminal_data.code, code_editor.cursor.y)

            code_editor.cursor = cursor_position_after_deletion
            should_redraw = true    
            
        }
    }

    // New line
    if keyboard_state.key == .ENTER
    {
        inject_at(&terminal_data.code, code_editor.cursor.y + 1, empty_line)

        terminal_code_copy_buffer(code_editor.cursor, {0, code_editor.cursor.y + 1}, terminal_code_line_end(code_editor.cursor.y) - code_editor.cursor.x)
        slice.fill(terminal_data.code[code_editor.cursor.y][code_editor.cursor.x:], 0)

        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        code_editor.cursor.y += 1
        code_editor.cursor.x = 0

        should_redraw = true

        code_editor.desired_cursor_x = 0
    }

    // Double space
    if keyboard_state.key == .TAB
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())

        if code_editor.cursor.x < CODELINE_SIZE - 1
        {
            terminal_code_insert(code_editor.cursor.x, code_editor.cursor.y, ' ')
            terminal_code_insert(code_editor.cursor.x, code_editor.cursor.y, ' ')
            code_editor.cursor.x += 2
        } 
        else if code_editor.cursor.x < CODELINE_SIZE
        {
            terminal_code_insert(code_editor.cursor.x, code_editor.cursor.y, ' ')
            code_editor.cursor.x += 1
        }

        should_redraw = true
    }

    // Move Cursor
    if keyboard_state.key == .RIGHT
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.x < CODELINE_SIZE && code_editor.cursor.x < terminal_code_line_end(code_editor.cursor.y) 
        {
            code_editor.cursor.x += 1

            if keyboard_state.is_ctrl_pressed
            {
                for code_editor.cursor.x < CODELINE_SIZE && terminal_data.code[code_editor.cursor.y][code_editor.cursor.x] > ' '
                {
                    code_editor.cursor.x += 1
                }
            }
        }
        else if code_editor.cursor.y < len(terminal_data.code) - 1 
        {
            code_editor.cursor.x = 0
            code_editor.cursor.y += 1
        }

        code_editor.desired_cursor_x = code_editor.cursor.x

        should_redraw = true
    }
    else if keyboard_state.key == .LEFT
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.x > 0 
        {
            code_editor.cursor.x -= 1

            if keyboard_state.is_ctrl_pressed
            {
                for code_editor.cursor.x > 0 && terminal_data.code[code_editor.cursor.y][code_editor.cursor.x] > ' '
                {
                    code_editor.cursor.x -= 1
                }
            }
        }
        else if code_editor.cursor.y > 0
        {
            code_editor.cursor.y -= 1
            code_editor.cursor.x = terminal_code_line_end(code_editor.cursor.y)
        }

        code_editor.desired_cursor_x = code_editor.cursor.x

        should_redraw = true
    }
    else if keyboard_state.key == .DOWN
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.y < len(terminal_data.code) - 1 
        {
            code_editor.cursor.y += 1
        }

        code_editor.cursor.x = min(code_editor.desired_cursor_x, terminal_code_line_end(code_editor.cursor.y))

        should_redraw = true
    }
    else if keyboard_state.key == .UP
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.y > 0 
        {
            code_editor.cursor.y -= 1
        }
        
        code_editor.cursor.x = min(code_editor.desired_cursor_x, terminal_code_line_end(code_editor.cursor.y))

        should_redraw = true
    }

    if should_redraw 
    {
        terminal_code_shift_screen(code_editor)
        terminal_code_draw_all(code_editor.cursor, code_editor.top_left_position)
    }

    // Exit code editor
    if keyboard_state.key == .ESCAPE
    {
        terminal_data.state = TerminalEntry {cursor = {0, TERMINAL_HEIGHT - 1}}
    }
}
