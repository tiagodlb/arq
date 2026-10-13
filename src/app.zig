const std = @import("std");
const vm = @import("vm");

const c = @cImport({
    @cInclude("raylib.h");
});

const keypad_keys = [16]c_int{
    c.KEY_KP_0, c.KEY_KP_1, c.KEY_KP_2,   c.KEY_KP_3,
    c.KEY_KP_4, c.KEY_KP_5, c.KEY_KP_6,   c.KEY_KP_7,
    c.KEY_KP_8, c.KEY_KP_9, c.KEY_KP_ADD, c.KEY_KP_ENTER,
    c.KEY_Q,    c.KEY_W,    c.KEY_E,      c.KEY_R,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var seed: u64 = undefined;
    io.random(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var keypad: vm.Keypad = undefined;
    var display: vm.Display = undefined;
    display.clear();
    var memory: vm.Memory = undefined;
    const font_bytes = @embedFile("./font.bin");
    @memcpy(memory.data[0x050 .. 0x050 + font_bytes.len], font_bytes);

    const rom = @embedFile("kaleidoscope");
    try memory.loadProgram(rom);

    const cell_pix = 12;
    c.InitWindow(64 * cell_pix, 32 * cell_pix, "CHIP-8");
    defer c.CloseWindow();

    c.InitAudioDevice();
    defer c.CloseAudioDevice();

    const sound = c.LoadSound("res/tone.wav");
    defer c.UnloadSound(sound);

    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        for (keypad_keys, 0..) |key, i| {
            keypad.keys[i] = c.IsKeyDown(key);
        }

        for (0..15) |_| {
            try memory.step(random, &memory, &display, &keypad);
        }

        if (memory.st > 0) {
            if (!c.IsSoundPlaying(sound)) {
                c.PlaySound(sound);
            }
        } else if (c.IsSoundPlaying(sound)) {
            c.StopSound(sound);
        }

        memory.tickTimers();

        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.BLACK);

        for (0..32) |y| {
            for (0..64) |x| {
                if (display.pixels[y][x] != 1) continue;
                c.DrawRectangle(
                    @intCast(x * cell_pix),
                    @intCast(y * cell_pix),
                    cell_pix,
                    cell_pix,
                    c.WHITE,
                );
            }
        }
    }
}
