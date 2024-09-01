const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const rom = try std.fs.cwd().readFileAlloc(allocator, "roms/IBM Logo.ch8", std.math.maxInt(usize));
    defer allocator.free(rom);

    var cpu = Cpu.init();
    cpu.loadRom(rom);
    while (true) {
        cpu.step();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
