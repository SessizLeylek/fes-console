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
        terminal_update()
    }

    window_destroy()

}
