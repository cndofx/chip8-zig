const std = @import("std");
const sdl = @import("sdl2");

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
    last_timer_tick: u64,

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
            .last_timer_tick = 0,
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
        std.log.debug("Executing instruction {X:0>4}", .{inst});

        switch ((inst & 0xF000) >> 12) {
            0x0 => switch (kk) {
                0xE0 => {
                    std.log.debug("CLS\n", .{});
                    self.display.clear();
                    self.pc += 2;
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },
            0x1 => {
                std.log.debug("JP {X:0>4}", .{nnn});
                self.pc = nnn;
            },
            0x3 => {
                std.log.debug("SE V{X}, {X:0>2}", .{ x, kk });
                if (self.vx[x] == kk) {
                    self.pc += 2;
                }
                self.pc += 2;
            },
            0x4 => {
                std.log.debug("SNE V{x}, {X:0>2}", .{ x, kk });
                if (self.vx[x] != kk) {
                    self.pc += 2;
                }
                self.pc += 2;
            },
            0x5 => {
                std.log.debug("SE V{X}, V{X}", .{ x, y });
                if (self.vx[x] == self.vx[y]) {
                    self.pc += 2;
                }
                self.pc += 2;
            },
            0x6 => {
                std.log.debug("LD V{X}, {X:0>2}", .{ x, kk });
                self.vx[x] = kk;
                self.pc += 2;
            },
            0x7 => {
                std.log.debug("ADD V{X}, {X:0>2}", .{ x, kk });
                self.vx[x] = self.vx[x] +% kk;
                self.pc += 2;
            },
            0x8 => switch (n) {
                0x0 => {
                    std.log.debug("LD V{X}, V{X}", .{ x, y });
                    self.vx[x] = self.vx[y];
                    self.pc += 2;
                },
                0x1 => {
                    std.log.debug("OR V{X}, V{X}", .{ x, y });
                    self.vx[x] |= self.vx[y];
                    self.pc += 2;
                },
                0x2 => {
                    std.log.debug("AND V{X}, V{X}", .{ x, y });
                    self.vx[x] &= self.vx[y];
                    self.pc += 2;
                },
                0x3 => {
                    std.log.debug("XOR V{X}, V{X}", .{ x, y });
                    self.vx[x] ^= self.vx[y];
                    self.pc += 2;
                },
                0x4 => {
                    std.log.debug("ADD V{X}, V{X}", .{ x, y });
                    const sum = @as(u16, self.vx[x]) + @as(u16, self.vx[y]);
                    if (sum > 0xFF) {
                        self.vx[0xF] = 1;
                    } else {
                        self.vx[0xF] = 0;
                    }
                    self.vx[x] = @intCast(sum & 0xFF);
                    self.pc += 2;
                },
                0x5 => {
                    std.log.debug("ADD V{X}, V{X}", .{ x, y });
                    if (self.vx[x] > self.vx[y]) {
                        self.vx[0xF] = 1;
                    } else {
                        self.vx[0xF] = 0;
                    }
                    self.vx[x] = self.vx[x] -% self.vx[y];
                    self.pc += 2;
                },
                0x6 => {
                    std.log.debug("SHR V{X}, V{X}", .{ x, y });
                    if (self.vx[x] & 0b00000001 != 0) {
                        self.vx[0xF] = 1;
                    } else {
                        self.vx[0xF] = 0;
                    }
                    self.vx[x] = self.vx[x] >> 1;
                    self.pc += 2;
                },
                0x7 => {
                    std.log.debug("SUBN V{X}, V{X}", .{ x, y });
                    if (self.vx[y] > self.vx[x]) {
                        self.vx[0xF] = 1;
                    } else {
                        self.vx[0xF] = 0;
                    }
                    self.vx[y] = self.vx[y] -% self.vx[x];
                    self.pc += 2;
                },
                0xE => {
                    std.log.debug("SHL V{X}, V{X}", .{ x, y });
                    if (self.vx[x] & 0b10000000 != 0) {
                        self.vx[0xF] = 1;
                    } else {
                        self.vx[0xF] = 0;
                    }
                    self.vx[x] = self.vx[x] << 1;
                    self.pc += 2;
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },
            0xA => {
                std.log.debug("LD I, {X:0>4}", .{nnn});
                self.i = nnn;
                self.pc += 2;
            },
            0xD => {
                std.log.debug("DRW V{X}, V{X}, {X}", .{ x, y, n });
                const vx = self.vx[x];
                const vy = self.vx[y];
                const sprite = self.memory.read_slice(self.i, n);
                if (self.display.draw(vx, vy, sprite)) {
                    self.vx[0xF] = 1;
                } else {
                    self.vx[0xF] = 0;
                }
                // self.display.print();
                self.pc += 2;
            },
            0xF => {
                switch (kk) {
                    0x15 => {
                        std.log.debug("LD DT, V{X}", .{x});
                        self.dt = self.vx[x];
                        self.pc += 2;
                    },
                    else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
                }
            },
            else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
        }

        std.log.debug("\n", .{});
        self.tick();
    }

    fn tick(self: *Cpu) void {
        const wait_ticks = 16; // 16ms, 60 timer ticks per second
        const current_tick = sdl.getTicks64();
        if (current_tick - self.last_timer_tick > wait_ticks) {
            self.last_timer_tick = current_tick;
            if (self.dt > 0) {
                self.dt -= 1;
            }
            if (self.st > 0) {
                self.st -= 1;
            }
        }
    }

    fn printState(self: *Cpu) void {
        std.log.debug("CPU State:", .{});
        std.log.debug("VX: {X:0>2}", .{self.vx});
        std.log.debug("Stack: {X:0>4}", .{self.stack});
        std.log.debug("SP: {X:0>2} PC: {X:0>4} I: {X:0>4}", .{ self.sp, self.pc, self.i });
        std.log.debug("DT: {X:0>2} ST: {X:0>2}", .{ self.dt, self.st });

        // ====

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
