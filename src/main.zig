const std = @import("std");
const sdl = @import("sdl2");

const Cpu = @import("cpu.zig").Cpu;
const display = @import("display.zig");

const fps = 60;
const ticks_per_frame = 1000 / fps;

const Config = struct {
    bgColor: u32,
    fgColor: u32,
    freq: u32,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const config = Config{
        .bgColor = 0x000000FF,
        .fgColor = 0xFFFFFFFF,
        .freq = 1,
    };

    const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/IBM Logo.ch8", std.math.maxInt(usize));
    defer allocator.free(rom);

    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();

    var window = try sdl.createWindow("Chip8 Zig", .{ .centered = {} }, .{ .centered = {} }, 640, 320, .{ .vis = .shown, .resizable = true });
    defer window.destroy();

    var renderer = try sdl.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();

    var cpu = Cpu.init();
    cpu.loadRom(rom);

    var last_time: u32 = 0;
    mainLoop: while (true) {
        while (sdl.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        while (sdl.getTicks() - last_time < ticks_per_frame) {
            sdl.delay(1);
        }

        try render(&renderer, &cpu.display, config.bgColor, config.fgColor);
        renderer.present();

        for (0..config.freq) |_| {
            cpu.step();
        }

        last_time = sdl.getTicks();
    }
}

fn unpackColor(color: u32) sdl.Color {
    const r: u8 = @intCast((color >> 24) & 0xFF);
    const g: u8 = @intCast((color >> 16) & 0xFF);
    const b: u8 = @intCast((color >> 8) & 0xFF);
    const a: u8 = @intCast((color >> 0) & 0xFF);
    return sdl.Color.rgba(r, g, b, a);
}

fn render(renderer: *sdl.Renderer, disp: *const display.Display, bgColor: u32, fgColor: u32) !void {
    const texture = try sdl.createTexture(renderer.*, sdl.PixelFormatEnum.rgba8888, sdl.Texture.Access.target, display.width, display.height);
    defer texture.destroy();

    try renderer.setTarget(texture);
    try renderer.setColor(unpackColor(fgColor));
    for (0..display.width) |x| {
        for (0..display.height) |y| {
            const i = y * display.width + x;
            if (disp.pixels[i] != 0) {
                try renderer.drawPoint(@intCast(x), @intCast(y));
            }
        }
    }

    try renderer.setTarget(null);
    try renderer.setColor(unpackColor(bgColor));
    try renderer.clear();
    try renderer.copy(texture, null, null);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
