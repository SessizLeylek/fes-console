package console

import "core:fmt"
printf :: fmt.printf
printfln :: fmt.printfln

main :: proc()
{
    window_init()

	terminal_data = INITIAL_TERMINAL_DATA

    for window_update()
    {
        terminal_update(get_time(), get_key_pressed())
    }

    window_destroy()

}
