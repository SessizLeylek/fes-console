package console

import "core:fmt"
printf :: fmt.printf
printfln :: fmt.printfln

frame_count : u32

main :: proc()
{
    window_init()

	terminal_data = INITIAL_TERMINAL_DATA

    for window_update()
    {
        frame_count += 1
        update_keyboard_state()
        terminal_update()
    }

    window_destroy()

}
