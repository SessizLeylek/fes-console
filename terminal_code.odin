package console

terminal_code_shift_buffer :: proc(x, y : int, to_right : bool)
{
    shift_value := int(to_right)
    start_value := to_right ? (CODELINE_SIZE - 2) : x
    end_value := to_right ? x - 1 : (CODELINE_SIZE - 1)
    step := to_right ? -1 : 1

    if (end_value - start_value) * step <= 0 do return   // to prevent infinite loops

    for i := start_value; i != end_value; i += step
    {
        terminal_data.code[y][i + shift_value] = terminal_data.code[y][i + (1 - shift_value)]
    }
}
 
terminal_code_insert :: proc(x, y : int, char : u8)
{
    terminal_code_shift_buffer(x, y, true)
    terminal_data.code[y][x] = char
}

terminal_code_remove :: proc(x, y : int)
{
    terminal_code_shift_buffer(x, y, false)
    terminal_data.code[y][CODELINE_SIZE - 1] = 0
}

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
        terminal_data.chars[TERMINAL_HEIGHT - 1] = {0, 0, 0, 0, 'C', 'O', 'D', 'E', 0, 'E', 'D', 'I', 'T', 'O', 'R', 0, 0,
                                                    0, 0, 1, 1, 1, ':', 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
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
        should_redraw = true

        code_editor.cursor.x += 1
        terminal_code_shift_screen(code_editor)

        code_editor.desired_cursor_x = code_editor.cursor.x
    }

    // Deleting
    if get_key_pressed() == .BACKSPACE
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())

        if code_editor.cursor.x > 0
        {   // Delete letter
            code_editor.cursor.x -= 1
            terminal_code_remove(code_editor.cursor.x, code_editor.cursor.y)
            should_redraw = true
            
            terminal_code_shift_screen(code_editor)
            
            code_editor.desired_cursor_x = code_editor.cursor.x
        }
        else if code_editor.cursor.y > 0 && terminal_data.code[code_editor.cursor.y] == empty_line
        {   
            // Delete line
            ordered_remove(&terminal_data.code, code_editor.cursor.y)

            code_editor.cursor.y -= 1
            code_editor.cursor.x = terminal_code_line_end(code_editor.cursor.y)
            terminal_code_shift_screen(code_editor)
            should_redraw = true
        }
    }

    // New line
    if get_key_pressed() == .ENTER
    {
        inject_at(&terminal_data.code, code_editor.cursor.y + 1, empty_line)

        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        code_editor.cursor.y += 1
        code_editor.cursor.x = 0

        terminal_code_shift_screen(code_editor)
        should_redraw = true

        code_editor.desired_cursor_x = 0
    }

    // Move Cursor
    if get_key_pressed() == .RIGHT
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.x < CODELINE_SIZE && code_editor.cursor.x < terminal_code_line_end(code_editor.cursor.y) 
        {
            code_editor.cursor.x += 1
        }
        else if code_editor.cursor.y < len(terminal_data.code) - 1 
        {
            code_editor.cursor.x = 0
            code_editor.cursor.y += 1
        }

        code_editor.desired_cursor_x = code_editor.cursor.x

        terminal_code_shift_screen(code_editor)
        should_redraw = true
    }
    else if get_key_pressed() == .LEFT
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.x > 0 
        {
            code_editor.cursor.x -= 1
        }
        else if code_editor.cursor.y > 0
        {
            code_editor.cursor.x = 0
            code_editor.cursor.y -= 1
        }

        code_editor.desired_cursor_x = code_editor.cursor.x

        terminal_code_shift_screen(code_editor)
        should_redraw = true
    }
    else if get_key_pressed() == .DOWN
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.y < len(terminal_data.code) - 1 
        {
            code_editor.cursor.y += 1
        }

        code_editor.cursor.x = min(code_editor.desired_cursor_x, terminal_code_line_end(code_editor.cursor.y))

        terminal_code_shift_screen(code_editor)
        should_redraw = true
    }
    else if get_key_pressed() == .UP
    {
        terminal_reset_cell_color(terminal_code_relative_cursor_position())
        if code_editor.cursor.y > 0 
        {
            code_editor.cursor.y -= 1
        }
        
        code_editor.cursor.x = min(code_editor.desired_cursor_x, terminal_code_line_end(code_editor.cursor.y))

        terminal_code_shift_screen(code_editor)
        should_redraw = true
    }

    if should_redraw 
    {
        terminal_code_draw_all(code_editor.cursor, code_editor.top_left_position)
    }

    // Exit code editor
    if get_key_pressed() == .ESCAPE
    {
        terminal_data.state = TerminalEntry {cursor = {0, TERMINAL_HEIGHT - 1}}
    }
}
