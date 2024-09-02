const std = @import("std");
const sdl = @import("sdl2");

const Cpu = @import("cpu.zig").Cpu;
const Display = @import("display.zig").Display;

pub const std_options = std.Options{
    .log_level = .info,
};

const fps = 60;
const ticks_per_frame = 1000 / fps;

const Config = struct {
    bgColor: u32,
    fgColor: u32,
    freq: u32,
};

// QWERTY     CHIP8
// 1 2 3 4    1 2 3 C
// Q W E R    4 5 6 D
// A S D F    7 8 9 E
// Z X C V    A 0 B F
const key_map = [_]sdl.Keycode{
    sdl.Keycode.x,
    sdl.Keycode.@"1",
    sdl.Keycode.@"2",
    sdl.Keycode.@"3",
    sdl.Keycode.q,
    sdl.Keycode.w,
    sdl.Keycode.e,
    sdl.Keycode.a,
    sdl.Keycode.s,
    sdl.Keycode.d,
    sdl.Keycode.z,
    sdl.Keycode.c,
    sdl.Keycode.@"4",
    sdl.Keycode.r,
    sdl.Keycode.f,
    sdl.Keycode.v,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const rom_path = args.next() orelse {
        std.debug.print("usage: chip8 <rom>\n", .{});
        return;
    };

    const config = Config{
        .bgColor = 0x000000FF,
        .fgColor = 0xFFFFFFFF,
        .freq = 1000,
    };

    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/IBM Logo.ch8", std.math.maxInt(usize)); // pass
    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/c8_test.c8", std.math.maxInt(usize)); // pass
    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/chip8-test-rom.ch8", std.math.maxInt(usize)); // pass

    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/timendus/1-chip8-logo.ch8", std.math.maxInt(usize)); // pass
    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/timendus/2-ibm-logo.ch8", std.math.maxInt(usize)); // pass
    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/timendus/3-corax+.ch8", std.math.maxInt(usize)); // pass
    // const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/timendus/4-flags.ch8", std.math.maxInt(usize)); // pass

    const rom = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize)); // currently broken
    defer allocator.free(rom);

    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();

    var window = try sdl.createWindow("Chip8 Zig", .{ .centered = {} }, .{ .centered = {} }, 1280, 640, .{ .vis = .shown, .resizable = true });
    defer window.destroy();

    var renderer = try sdl.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();

    var cpu = Cpu.init();
    cpu.loadRom(rom);

    var last_time: u64 = 0;
    mainLoop: while (true) {
        while (sdl.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                .key_down => |key| {
                    std.log.info("key down: {}", .{key.keycode});
                    keyLoop: for (key_map, 0..) |key_map_key, i| {
                        if (key.keycode == key_map_key) {
                            cpu.keyboard.keys[i] = true;
                            break :keyLoop;
                        }
                    }
                },
                .key_up => |key| {
                    std.log.info("key up: {}", .{key.keycode});
                    keyLoop: for (key_map, 0..) |key_map_key, i| {
                        if (key.keycode == key_map_key) {
                            cpu.keyboard.keys[i] = false;
                            break :keyLoop;
                        }
                    }
                },
                else => {},
            }
        }

        try render(&renderer, &cpu.display, config.bgColor, config.fgColor);
        renderer.present();

        for (0..config.freq) |_| {
            cpu.step();
        }

        while (sdl.getTicks() - last_time < ticks_per_frame) {
            sdl.delay(1);
        }
        last_time = sdl.getTicks64();
    }
}

fn unpackColor(color: u32) sdl.Color {
    const r: u8 = @intCast((color >> 24) & 0xFF);
    const g: u8 = @intCast((color >> 16) & 0xFF);
    const b: u8 = @intCast((color >> 8) & 0xFF);
    const a: u8 = @intCast((color >> 0) & 0xFF);
    return sdl.Color.rgba(r, g, b, a);
}

fn render(renderer: *sdl.Renderer, display: *const Display, bgColor: u32, fgColor: u32) !void {
    const texture = try sdl.createTexture(renderer.*, sdl.PixelFormatEnum.rgba8888, sdl.Texture.Access.target, Display.width, Display.height);
    defer texture.destroy();

    try renderer.setTarget(texture);
    try renderer.setColor(unpackColor(fgColor));
    for (0..Display.width) |x| {
        for (0..Display.height) |y| {
            const i = y * Display.width + x;
            if (display.pixels[i] != 0) {
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
