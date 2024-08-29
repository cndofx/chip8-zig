const std = @import("std");
const memory = @import("memory.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/IBM Logo.ch8", std.math.maxInt(usize));
    defer allocator.free(rom);

    var mem = memory.Memory{};

    const data = [_]u8{ 0x12, 0x34, 0x56, 0x78 };
    mem.write_slice(0xFF0, data[0..]);

    for (mem.data) |byte| {
        std.debug.print("0x{X} ", .{byte});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
