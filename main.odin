package console

import "core:fmt"
printf :: fmt.printf
printfln :: fmt.printfln

main :: proc()
{
    window_init()

    terminal_data.state = TerminalEntry {}
    terminal_data.color = 15
    
    terminal_draw_all()
    update_buffer24_from_buffer4(console_get_video_buffer())

    for window_update()
    {
        terminal_update(get_time(), get_key_pressed())
    }

    window_destroy()

}
