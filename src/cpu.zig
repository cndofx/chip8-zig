const std = @import("std");
const sdl = @import("sdl2");

const Memory = @import("memory.zig").Memory;
const Display = @import("display.zig").Display;
const Keyboard = @import("keyboard.zig").Keyboard;

pub const Cpu = struct {
    memory: Memory,
    display: Display,
    keyboard: Keyboard,
    random: std.Random,
    pc: u16,
    vx: [16]u8,
    stack: [16]u16,
    sp: u8,
    st: u8,
    dt: u8,
    i: u16,
    last_timer_tick: u64,

    pub fn init(random: std.Random) Cpu {
        const cpu = Cpu{
            .memory = Memory.init(),
            .display = Display.init(),
            .keyboard = Keyboard.init(),
            .random = random,
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
        self.pc += 2;
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
            0x0 => switch (nnn) {
                0xE0 => {
                    std.log.info("CLS", .{});
                    self.display.clear();
                },
                0xEE => {
                    std.log.debug("RET", .{});
                    self.pc = self.pop();
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },
            0x1 => {
                std.log.debug("JP {X:0>4}", .{nnn});
                self.pc = nnn;
            },
            0x2 => {
                std.log.debug("CALL {X:0>4}", .{nnn});
                // self.push(self.pc + 2);
                self.push(self.pc);
                self.pc = nnn;
            },
            0x3 => {
                std.log.debug("SE V{X}, {X:0>2}", .{ x, kk });
                if (self.vx[x] == kk) {
                    self.pc += 2;
                }
            },
            0x4 => {
                std.log.debug("SNE V{x}, {X:0>2}", .{ x, kk });
                if (self.vx[x] != kk) {
                    self.pc += 2;
                }
            },
            0x5 => {
                std.log.debug("SE V{X}, V{X}", .{ x, y });
                if (self.vx[x] == self.vx[y]) {
                    self.pc += 2;
                }
            },
            0x6 => {
                std.log.debug("LD V{X}, {X:0>2}", .{ x, kk });
                self.vx[x] = kk;
            },
            0x7 => {
                std.log.debug("ADD V{X}, {X:0>2}", .{ x, kk });
                self.vx[x] = self.vx[x] +% kk;
            },
            0x8 => switch (n) {
                0x0 => {
                    std.log.debug("LD V{X}, V{X}", .{ x, y });
                    self.vx[x] = self.vx[y];
                },
                0x1 => {
                    std.log.debug("OR V{X}, V{X}", .{ x, y });
                    self.vx[x] |= self.vx[y];
                },
                0x2 => {
                    std.log.debug("AND V{X}, V{X}", .{ x, y });
                    self.vx[x] &= self.vx[y];
                },
                0x3 => {
                    std.log.debug("XOR V{X}, V{X}", .{ x, y });
                    self.vx[x] ^= self.vx[y];
                },
                0x4 => {
                    std.log.debug("ADD V{X}, V{X}", .{ x, y });
                    const sum = @as(u16, self.vx[x]) + @as(u16, self.vx[y]);
                    const flag: u8 = if (sum > 0xFF) 1 else 0;
                    self.vx[x] = @intCast(sum & 0xFF);
                    self.vx[0xF] = flag;
                },
                0x5 => {
                    std.log.debug("SUB V{X}, V{X}", .{ x, y });
                    const flag: u8 = if (self.vx[x] >= self.vx[y]) 1 else 0;
                    self.vx[x] = self.vx[x] -% self.vx[y];
                    self.vx[0xF] = flag;
                },
                0x6 => {
                    std.log.debug("SHR V{X}, V{X}", .{ x, y });
                    self.vx[x] = self.vx[y];
                    const flag: u8 = if (self.vx[x] & 0b00000001 != 0) 1 else 0;
                    self.vx[x] = self.vx[x] >> 1;
                    self.vx[0xF] = flag;
                },
                0x7 => {
                    std.log.debug("SUBN V{X}, V{X}", .{ x, y });
                    const flag: u8 = if (self.vx[y] >= self.vx[x]) 1 else 0;
                    self.vx[x] = self.vx[y] -% self.vx[x];
                    self.vx[0xF] = flag;
                },
                0xE => {
                    std.log.debug("SHL V{X}, V{X}", .{ x, y });
                    self.vx[x] = self.vx[y];
                    const flag: u8 = if (self.vx[x] & 0b10000000 != 0) 1 else 0;
                    self.vx[x] = self.vx[x] << 1;
                    self.vx[0xF] = flag;
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },
            0x9 => {
                std.log.debug("SNE V{X}, V{X}", .{ x, y });
                if (self.vx[x] != self.vx[y]) {
                    self.pc += 2;
                }
            },
            0xA => {
                std.log.debug("LD I, {X:0>4}", .{nnn});
                self.i = nnn;
            },
            0xB => {
                std.log.debug("JP V0, {X:0>4}", .{nnn});
                self.pc = nnn + self.vx[0];
            },
            0xC => {
                std.log.debug("RND V{X}, {X:0>2}", .{ x, kk });
                self.vx[x] = self.random.int(u8) & kk;
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
            },
            0xE => switch (kk) {
                0x9E => {
                    std.log.debug("SKP V{X}", .{x});
                    if (self.keyboard.keys[self.vx[x]]) {
                        self.pc += 2;
                    }
                },
                0xA1 => {
                    std.log.debug("SKNP V{X}", .{x});
                    if (!self.keyboard.keys[self.vx[x]]) {
                        self.pc += 2;
                    }
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },
            0xF => switch (kk) {
                0x07 => {
                    std.log.debug("LD V{X}, DT", .{x});
                    self.vx[x] = self.dt;
                },
                0x0A => {
                    std.log.debug("LD V{X}, K", .{x});
                    const key = self.keyboard.get_pressed();
                    if (key != null) {
                        self.vx[x] = key.?;
                        // self.pc += 2;
                    } else {
                        self.pc -= 2;
                    }
                },
                0x15 => {
                    std.log.debug("LD DT, V{X}", .{x});
                    self.dt = self.vx[x];
                },
                0x18 => {
                    std.log.debug("LD ST, V{X}", .{x});
                    self.st = self.vx[x];
                },
                0x1E => {
                    std.log.debug("ADD I, V{X}", .{x});
                    self.i = self.i +% self.vx[x];
                },
                0x29 => {
                    std.log.debug("LD F, V{X}", .{x});
                    self.i = @as(u16, self.vx[x]) * 5;
                },
                0x33 => {
                    std.log.debug("LD B, V{X}", .{x});
                    const vx = self.vx[x];
                    const hundreds = (vx / 100) % 10;
                    const tens = (vx / 10) % 10;
                    const ones = (vx / 1) % 10;
                    self.memory.write_slice(self.i, &[_]u8{ hundreds, tens, ones });
                },
                0x55 => {
                    std.log.debug("LD [I], V{X}", .{x});
                    for (0..x + 1) |i| {
                        self.memory.write_byte(self.i + i, self.vx[i]);
                    }
                },
                0x65 => {
                    std.log.debug("LD V{X}, [I]", .{x});
                    for (0..x + 1) |i| {
                        self.vx[i] = self.memory.read_byte(self.i + i);
                    }
                },
                else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
            },

            else => std.debug.panic("unrecognized instruction: {X:0>4}\n", .{inst}),
        }

        std.log.debug("\n", .{});
        self.tick();
    }

    fn push(self: *Cpu, value: u16) void {
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn pop(self: *Cpu) u16 {
        self.sp -= 1;
        return self.stack[self.sp];
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
