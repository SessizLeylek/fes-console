package console

TERMINAL_WIDTH :: SCREEN_WIDTH / CHARSIZE
TERMINAL_HEIGHT :: SCREEN_HEIGHT / CHARSIZE

TerminalEntry :: struct
{
    is_initted : bool,
    cursor_x, cursor_y : int,
    line_text : [TERMINAL_WIDTH]u8,
    last_cursor_blink : f64,
}

TerminalCodeEditor :: struct
{

}

TerminalMemoryEditor :: struct
{

}

TerminalData :: struct
{
    chars : [TERMINAL_WIDTH][TERMINAL_HEIGHT]u8,
    char_colors : [TERMINAL_WIDTH][TERMINAL_HEIGHT]u8,
    state : union {
        TerminalEntry,
        TerminalCodeEditor,
        TerminalMemoryEditor,
    }
}

terminal_data : TerminalData

terminal_draw_cell :: proc(x, y : int, char, color : u8)
{
    color_bg := color >> 4
    color_fg := (color << 4) >> 4

    real_x := x * CHARSIZE
    real_y := y * CHARSIZE

    char_info := charset_get_char_info(char)

    for row in 0..<CHARSIZE
    {
        for col in 0..<CHARSIZE
        {
            pixel_color := char_info[row][col] ? color_bg : color_fg
            console_draw_single_pixel(real_x + col, real_y + row, pixel_color)
        }
    }
}

terminal_draw_all :: proc()
{
    for i in 0..<TERMINAL_WIDTH
    {
        for j in 0..<TERMINAL_HEIGHT
        {
            terminal_draw_cell(i, j, terminal_data.chars[i][j], terminal_data.char_colors[i][j])
        }
    }
}

terminal_update :: proc(time : f64, pressed_key : i32)
{
    
    switch &v in terminal_data.state
    {
        case TerminalEntry:
            if !v.is_initted
            {
                v.is_initted = true

                terminal_data.char_colors = 0b00001111

                printf("%v", terminal_data.char_colors[0][0])
            }

            // Cursor blink
            if time > v.last_cursor_blink + 0.5
            {
                v.last_cursor_blink = time

                old_color := terminal_data.char_colors[v.cursor_x][v.cursor_y]
                new_color := (old_color >> 4) + (old_color << 4)
                terminal_data.char_colors[v.cursor_x][v.cursor_y] = new_color
            }

            // Letter typing
            if pressed_key > 31 && pressed_key < 127
            {
                new_char := u8(pressed_key)

                terminal_data.char_colors[v.cursor_x][v.cursor_y] = 0b00001111
                terminal_data.chars[v.cursor_x][v.cursor_y] = new_char

                v.line_text[v.cursor_x] = new_char
                v.cursor_x += 1

                if v.cursor_x == TERMINAL_WIDTH
                {
                    v.cursor_x = 0
                    v.cursor_y += 1
                }

            }
        case TerminalCodeEditor:
        case TerminalMemoryEditor:
    }

    terminal_draw_all()
    update_buffer24_from_buffer4(console_get_video_buffer())
}
