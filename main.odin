package console

main :: proc()
{
    window_init()

    console_randomize_video_buffer()
    update_buffer24_from_buffer4(console_get_video_buffer())

    for window_update()
    {}

    window_destroy()

}