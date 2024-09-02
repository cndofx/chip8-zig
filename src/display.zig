const std = @import("std");

pub const Display = struct {
    pixels: [width * height]u8,

    pub const width: usize = 64;
    pub const height: usize = 32;

    pub fn init() Display {
        return Display{ .pixels = std.mem.zeroes([width * height]u8) };
    }

    pub fn clear(self: *Display) void {
        for (0..self.pixels.len) |i| {
            self.pixels[i] = 0;
        }
    }

    pub fn draw(self: *Display, x: u8, y: u8, sprite: []const u8) bool {
        var erased = false;
        for (sprite, 0..) |b, i| {
            if (self.drawByte(x, @intCast(y + i), b)) {
                erased = true;
            }
        }
        return erased;
    }

    fn drawByte(self: *Display, x: u8, y: u8, byte: u8) bool {
        var x2 = @as(usize, x);
        const y2 = @as(usize, y);
        var byte2 = byte;

        var erased = false;
        for (0..8) |_| {
            if (x2 >= width or y2 >= height) {
                continue;
            }
            const i = y2 * width + x2;
            const old = self.pixels[i];
            self.pixels[i] ^= (byte2 & 0b10000000) >> 7;
            if (old != 0 and self.pixels[i] == 0) {
                erased = true;
            }
            x2 = (x2 + 1) % width;
            byte2 <<= 1;
        }
        return erased;
    }

    pub fn print(self: *Display) void {
        for (0..height) |y| {
            for (0..width) |x| {
                if (self.pixels[y * width + x] == 0) {
                    std.debug.print(" ", .{});
                } else {
                    std.debug.print("#", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};
