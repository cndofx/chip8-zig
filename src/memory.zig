const std = @import("std");

const memory_size: usize = 4096;

pub const Memory = struct {
    data: [memory_size]u8,

    pub fn init() Memory {
        const font = [_]u8{
            0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
            0x20, 0x60, 0x20, 0x20, 0x70, // 1
            0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
            0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
            0x90, 0x90, 0xF0, 0x10, 0x10, // 4
            0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
            0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
            0xF0, 0x10, 0x20, 0x40, 0x40, // 7
            0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
            0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
            0xF0, 0x90, 0xF0, 0x90, 0x90, // A
            0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
            0xF0, 0x80, 0x80, 0x80, 0xF0, // C
            0xE0, 0x90, 0x90, 0x90, 0xE0, // D
            0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
            0xF0, 0x80, 0xF0, 0x80, 0x80, // F
        };

        var memory = Memory{
            .data = std.mem.zeroes([memory_size]u8),
        };
        std.mem.copyForwards(u8, memory.data[0..], font[0..]);
        return memory;
    }

    pub fn read_byte(self: *Memory, addr: usize) u8 {
        if (addr >= memory_size) {
            return 0;
        }
        return self.data[addr];
    }

    pub fn write_byte(self: *Memory, addr: usize, value: u8) void {
        if (addr >= memory_size) {
            return;
        }
        self.data[addr] = value;
    }

    pub fn read_slice(self: *Memory, addr: usize, len: usize) []u8 {
        return self.data[addr .. addr + len];
    }

    pub fn write_slice(self: *Memory, addr: usize, value: []const u8) void {
        std.mem.copyForwards(u8, self.data[addr..], value);
    }
};
