const std = @import("std");
const Memory = @import("memory.zig").Memory;
const Display = @import("display.zig").Display;

pub const Cpu = struct {
    memory: Memory,
    display: Display,
    pc: u16,
    vx: [16]u8,
    stack: [16]u16,
    sp: u8,
    st: u8,
    dt: u8,
    i: u16,

    pub fn init() Cpu {
        const cpu = Cpu{
            .memory = Memory.init(),
            .display = Display.init(),
            .pc = 0x200,
            .vx = std.mem.zeroes([16]u8),
            .stack = std.mem.zeroes([16]u16),
            .sp = 0,
            .st = 0,
            .dt = 0,
            .i = 0,
        };

        return cpu;
    }

    pub fn loadRom(self: *Cpu, rom: []const u8) void {
        self.memory.write_slice(0x200, rom);
    }

    pub fn step(self: *Cpu) void {
        const inst = self.fetch();
        self.execute(inst);
    }

    pub fn fetch(self: *Cpu) u16 {
        const bytes = self.memory.read_slice(self.pc, 2);
        const value = (@as(u16, bytes[0]) << 8) | bytes[1];
        return value;
    }

    pub fn execute(self: *Cpu, inst: u16) void {
        const nnn = inst & 0x0FFF; // 12-bit address, lower 12 bits of instruction
        const kk: u8 = @intCast(inst & 0x00FF); // 8-bit value, lower 8 bits of instruction
        const n: u8 = @intCast(inst & 0x000F); // 4-bit value, lowest 4 bits of instruction
        const x: u8 = @intCast((inst & 0x0F00) >> 8); // 4-bit value, lower 4 bits of upper byte
        const y: u8 = @intCast((inst & 0x00F0) >> 4); // 4-bit value, upper 4 bits of lower byte

        self.printState();
        std.debug.print("Executing instruction {X:0>4}\n", .{inst});

        switch ((inst & 0xF000) >> 12) {
            0x0 => switch (kk) {
                0xE0 => {
                    std.debug.print("CLS\n", .{});
                    self.display.clear();
                    self.pc += 2;
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },
            0x1 => {
                std.debug.print("JP {X:0>4}\n", .{nnn});
                self.pc = nnn;
            },
            0x6 => {
                std.debug.print("LD V{X}, {X:0>2}\n", .{ x, kk });
                self.vx[x] = kk;
                self.pc += 2;
            },
            0x7 => {
                std.debug.print("ADD V{X}, {X:0>2}\n", .{ x, kk });
                self.vx[x] = self.vx[x] +% kk;
                self.pc += 2;
            },
            0xA => {
                std.debug.print("LD I, {X:0>4}\n", .{nnn});
                self.i = nnn;
                self.pc += 2;
            },
            0xD => {
                std.debug.print("DRW V{X}, V{X}, {X}\n", .{ x, y, n });
                const vx = self.vx[x];
                const vy = self.vx[y];
                const sprite = self.memory.read_slice(self.i, n);
                if (self.display.draw(vx, vy, sprite)) {
                    self.vx[0xF] = 1;
                } else {
                    self.vx[0xF] = 0;
                }
                self.display.print();
                self.pc += 2;
            },
            else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
        }

        std.debug.print("\n", .{});
    }

    pub fn printState(self: *Cpu) void {
        std.debug.print("CPU State:\n", .{});
        std.debug.print("VX: {X:0>2}\n", .{self.vx});
        std.debug.print("Stack: {X:0>4}\n", .{self.stack});
        std.debug.print("SP: {X:0>2} PC: {X:0>4} I: {X:0>4}\n", .{ self.sp, self.pc, self.i });
        std.debug.print("DT: {X:0>2} ST: {X:0>2}\n", .{ self.dt, self.st });

        // if (self.sp > 0) {
        //     std.debug.print("Stack: [\n", .{});
        //     for (self.stack, 0..) |v, i| {
        //         if (i >= self.sp) {
        //             break;
        //         }
        //         std.debug.print("  {X:0>2}\n", .{v});
        //     }
        //     std.debug.print("]\n", .{});
        // } else {
        //     std.debug.print("Stack: []\n", .{});
        // }
    }
};
