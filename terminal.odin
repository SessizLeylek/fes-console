package console

CODELINE_SIZE :: 64
TERMINAL_WIDTH :: SCREEN_WIDTH / CHARSIZE
TERMINAL_HEIGHT :: SCREEN_HEIGHT / CHARSIZE
CURSOR_BLINK_INTERVAL :: 0.25

TerminalEntry :: struct
{
    is_initted : bool,
    cursor : [2]int,
    last_cursor_blink : f64,
}

TerminalCodeEditor :: struct
{
    is_initted : bool,
    desired_cursor_x : int,
    cursor : [2]int,
    top_left_position : [2]int,
    last_cursor_blink : f64,
}

TerminalMemoryEditor :: struct
{

}

TerminalData :: struct
{
    should_refresh : bool,
    color : u8,
    chars : [TERMINAL_HEIGHT][TERMINAL_WIDTH]u8,
    char_colors : [TERMINAL_HEIGHT][TERMINAL_WIDTH]u8,
    state : union {
        TerminalEntry,
        TerminalCodeEditor,
        TerminalMemoryEditor,
    },
    code : [dynamic][CODELINE_SIZE]u8,
}

INITIAL_TERMINAL_DATA := TerminalData{
    should_refresh = true,
    color = 15,
    state = TerminalEntry {},
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
            terminal_draw_cell(i, j, terminal_data.chars[j][i], terminal_data.char_colors[j][i])
        }
    }
}

terminal_reset_cell_color :: proc(x, y : int)
{
    terminal_data.char_colors[y][x] = terminal_data.color

    terminal_data.should_refresh = true
}

terminal_invert_cell_color :: proc(x, y : int)
{
    old_color := terminal_data.char_colors[y][x]
    new_color := (old_color >> 4) + (old_color << 4)
    terminal_data.char_colors[y][x] = new_color

    terminal_data.should_refresh = true
}

terminal_clear_line :: proc(line_number : int)
{
    terminal_data.chars[line_number] = 0

    terminal_data.should_refresh = true
}

terminal_scroll_up :: proc()
{
    for i in 0..<TERMINAL_WIDTH
    {
        for j in 0..<(TERMINAL_HEIGHT - 1)
        {
            terminal_data.chars[j][i] = terminal_data.chars[j + 1][i]
            terminal_data.char_colors[j][i] = terminal_data.char_colors[j + 1][i]

        }
    }

    #partial switch &v in terminal_data.state
    {
        case TerminalEntry:
            if v.cursor.y > 0 
            {
                v.cursor.y -= 1
            }
    }

    terminal_clear_line(TERMINAL_HEIGHT - 1)
}

terminal_update :: proc()
{
    
    switch &v in terminal_data.state
    {
        case TerminalEntry:
            terminal_update_entry(&v)
        case TerminalCodeEditor:
            terminal_update_code_editor(&v)
        case TerminalMemoryEditor:
    }

    if terminal_data.should_refresh
    {
    	terminal_data.should_refresh = false
    	
		terminal_draw_all()
    	update_buffer24_from_buffer4(console_get_video_buffer())    	
    }

}

terminal_buffer_from_code :: proc() -> (buffer: []u8, size: int)
{
    line_count := len(terminal_data.code)
    buff_size := line_count * CODELINE_SIZE
    buff := make([]u8, buff_size)

    for i in 0..<line_count
    {
        for j in 0..<CODELINE_SIZE
        {
            buff[j + i * CODELINE_SIZE] = terminal_data.code[i][j]
        }
    }

    return buff[:], buff_size
}

terminal_buffer_to_code :: proc(buffer : []u8)
{
    line_count := (len(buffer) / 64)
    resize(&terminal_data.code, line_count)

    for i in 0..<line_count
    {
        for j in 0..<CODELINE_SIZE
        {
            terminal_data.code[i][j] = buffer[j + i * CODELINE_SIZE]
        }
    }
}
