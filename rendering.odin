package console

import rl "vendor:raylib"

SCREEN_WIDTH :: 256
SCREEN_HEIGHT :: 192

COLOR_TABLE : [16][3]u8 = {
    {0, 0, 0},          // BLACK
    {0, 0, 170},        //BLUE
    {0, 170, 0},        //GREEN
    {0, 170, 170},      //CYAN
    {170, 0, 0,},       //RED
    {170, 0, 170},      //MAGENTA
    {170, 85, 0},       //BROWN
    {170, 170, 170},    //LIGHT GRAY
    {85, 85, 85},       //DARK GRAY
    {85, 85, 255},      //LIGHT BLUE
    {85, 255, 85},      //LIGHT GREEN
    {85, 255, 255},     //LIGHT CYAN
    {255, 85, 85},      //LIGHT RED
    {255, 85, 255},     //LIGHT MAGENTA
    {255, 255, 85},     //YELLOW
    {255, 255, 255},    //WHITE
}

screen_texture : rl.Texture
screen_buffer24 : [SCREEN_WIDTH * SCREEN_HEIGHT * 3]u8

// Updates the 24bit screen buffer according to 4bit buffer
update_buffer24_from_buffer4 :: proc(buffer4 : []u8)
{
    for i in 0..<(SCREEN_WIDTH*SCREEN_HEIGHT/2)
    {
        two_pixels := buffer4[i]
        first_pixel4 := two_pixels >> 4
        second_pixel4 := (two_pixels << 4) >> 4

        first_color := COLOR_TABLE[first_pixel4]
        second_color := COLOR_TABLE[second_pixel4]

        for j in 0..<3
        {
            screen_buffer24[i * 6] = first_color[0]
            screen_buffer24[i * 6 + 1] = first_color[1]
            screen_buffer24[i * 6 + 2] = first_color[2]
            screen_buffer24[i * 6 + 3] = second_color[0]
            screen_buffer24[i * 6 + 4] = second_color[1]
            screen_buffer24[i * 6 + 5] = second_color[2]
        }
    }

    rl.UpdateTexture(screen_texture, &screen_buffer24)
}

window_init :: proc()
{
    rl.InitWindow(1024, 640, "FES")

    temp_img := rl.Image {&screen_buffer24, SCREEN_WIDTH, SCREEN_HEIGHT, 1, .UNCOMPRESSED_R8G8B8}
    screen_texture = rl.LoadTextureFromImage(temp_img)

    rl.SetTargetFPS(50)
}

window_update :: proc() -> bool
{
    rl.BeginDrawing()

    rl.DrawTextureEx(screen_texture, {128, 32}, 0, 3, rl.WHITE)

    rl.EndDrawing()

    return !rl.WindowShouldClose()
}

window_destroy :: proc()
{
    rl.CloseWindow()
}
