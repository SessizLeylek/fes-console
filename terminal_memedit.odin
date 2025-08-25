package console

import "core:slice"

nibble_to_hex_ascii :: proc(nibble : u8) -> u8
{
    if nibble < 10 do return nibble + '0'
    return nibble - 9 + 'A'
}

terminal_memedit_draw_all :: proc(v : TerminalMemoryEditor)
{
    memory_position := v.top_left_index
    for i in 0..<TERMINAL_HEIGHT
    {
        for j in 0..<(int)(v.row_length / 2)
        {
            first_nibble := console_memory[memory_position] & 0b11110000 >> 4
            second_nibble := console_memory[memory_position] & 0b1111

            terminal_data.chars[i][j * 2] = 0
            terminal_data.char_colors[i][j * 2] = first_nibble << 4
            terminal_data.chars[i][j * 2 + 1] = 0
            terminal_data.char_colors[i][j * 2 + 1] = second_nibble << 4
            memory_position += 1
        }
    }

    terminal_data.should_refresh = true
}

terminal_update_memedit :: proc(memeditor : ^TerminalMemoryEditor)
{
    should_redraw : bool
    if !memeditor.is_initted
    {
        memeditor.is_initted = true

        should_redraw = true
    }

    // Cursor blink
    if get_time() > memeditor.last_cursor_blink + CURSOR_BLINK_INTERVAL
    {
        memeditor.last_cursor_blink = get_time()
        terminal_invert_cell_color(memeditor.cursor.x, memeditor.cursor.y)
    }

    // Move Cursor
    if keyboard_state.key == .RIGHT
    {
        memeditor.cursor.x += 1
    }

    if should_redraw
    {
        terminal_memedit_draw_all(memeditor^)
    }
}