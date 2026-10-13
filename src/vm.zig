const std = @import("std");

pub const Error = error{ ReadOutOfBounds, UnknownInstruction, WriteOutOfBounds };

pub const program_load_addr = 0x200;

pub const font_start_addr: u12 = 0x050;

pub const fontset = [80]u8{
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

pub const Display = struct {
    // [y][x]
    pixels: [32][64]u1,

    pub fn clear(display: *Display) void {
        @memset(&display.pixels, [1]u1{0} ** 64);
    }
};

pub const Keypad = struct {
    keys: [16]bool,
};

pub const Memory = struct {
    const Self = @This();

    pub const total_memory_bytes = 0x1000;

    pc: u12, // program counter
    i: u12, // registrador I
    sp: u12, // stack pointer
    dt: u8, // delay timer
    st: u8, // sount timer
    vars: [16]u8,
    data: [total_memory_bytes]u8,

    pub fn tickTimers(self: *Self) void {
        if (self.dt > 0) self.dt -= 1;
        if (self.st > 0) self.st -= 1;
    }

    pub fn readBytes(self: *const Self, addr: u12, comptime nbytes: comptime_int) error{ReadOutOfBounds}![nbytes]u8 {
        if (addr + nbytes > total_memory_bytes) {
            return error.ReadOutOfBounds;
        }

        const bytes = self.data[addr .. addr + nbytes];
        return @as(*const [nbytes]u8, @ptrCast(bytes.ptr)).*;
    }

    pub fn writeBytes(self: *Self, addr: u12, data: []const u8) error{WriteOutOfBounds}!void {
        if (addr + data.len > total_memory_bytes) {
            return error.WriteOutOfBounds;
        }

        const target = self.data[addr .. addr + data.len];
        @memcpy(target, data);
    }

    pub fn step(self: *Self, random: std.Random, memory: *Memory, display: *Display, keypad: *Keypad) error{ UnknownInstruction, ReadOutOfBounds, WriteOutOfBounds }!void {
        const bytecode = try memory.readBytes(memory.pc, 2);

        // DEBUG
        //const opcode = (@as(u16, bytecode[0]) << 8 | bytecode[1]);
        //std.debug.print("exec PC 0x{X:0>3}: opcode 0x{X:0>4}\n", .{ memory.pc, opcode });

        self.pc += 2;

        try memory.readBytecode(&bytecode, display, keypad, random);
    }

    pub fn loadProgram(
        self: *Self,
        program: []const u8,
    ) error{WriteOutOfBounds}!void {
        @memcpy(self.data[font_start_addr .. font_start_addr + fontset.len], &fontset);
        try self.writeBytes(program_load_addr, program);
        self.pc = program_load_addr;
        self.sp = 0;
        self.dt = 0;
        self.st = 0;
    }

    pub fn readBytecode(memory: *Memory, bytecode: []const u8, display: *Display, keypad: *Keypad, random: std.Random) !void {
        const nibbles = [4]u4{
            @intCast(bytecode[0] >> 4),
            @truncate(bytecode[0]),
            @intCast(bytecode[1] >> 4),
            @truncate(bytecode[1]),
        };

        switch (nibbles[0]) {
            0xA => { // LD I
                const addr: u12 = (@as(u12, nibbles[1]) << 8) + bytecode[1];
                memory.i = addr;
            },
            0xB => { // JP
                // bitwise or em vez de +, nesse caso o resultado é o mesmo, a intenção por trás é outra
                const addr: u12 = (@as(u12, nibbles[1]) << 8) | bytecode[1];
                const offset: u12 = @as(u12, memory.vars[0]);

                memory.pc = addr + offset;
            },
            0xC => { // RND
                const x = nibbles[1];
                const kk = bytecode[1];

                const rand = random.int(u8);

                memory.vars[x] = rand & kk;
            },
            0xD => {
                const x = memory.vars[nibbles[1]];
                const y = memory.vars[nibbles[2]];
                const height = nibbles[3];

                memory.vars[0xF] = 0;

                for (0..height) |row| {
                    const sprite_byte = (try memory.readBytes(memory.i + @as(u12, @intCast(row)), 1))[0];

                    const py = (y % 32) + row;

                    if (py >= 32) break;

                    for (0..8) |col| {
                        const px = (x % 64) + col;

                        if (px >= 64) break;

                        const bit: u1 = @truncate(sprite_byte >> @intCast(7 - col));

                        if (bit == 1) {
                            if (display.pixels[py][px] == 1) {
                                memory.vars[0xF] = 1;
                            }

                            display.pixels[py][px] ^= 1;
                        }
                    }
                }
            },
            0xF => switch (bytecode[1]) {
                0x0A => {
                    const x = nibbles[1];
                    var key_pressed: ?u8 = null;

                    for (keypad.keys, 0..) |is_pressed, key_index| {
                        if (is_pressed) {
                            key_pressed = @intCast(key_index);
                            break;
                        }
                    }

                    if (key_pressed) |key| {
                        memory.vars[x] = key;
                        keypad.keys[key] = false;
                    } else {
                        memory.pc -= 2;
                    }
                },
                0x07 => {
                    memory.vars[nibbles[1]] = memory.dt;
                },
                0x15 => {
                    memory.dt = memory.vars[nibbles[1]];
                },
                0x18 => {
                    memory.st = memory.vars[nibbles[1]];
                },
                0x29 => {
                    const digit = memory.vars[nibbles[1]] & 0x0F;
                    memory.i = font_start_addr + (@as(u12, digit) * 5);
                },
                0x33 => {
                    const value = memory.vars[nibbles[1]];
                    memory.data[memory.i] = value / 100;
                    memory.data[memory.i + 1] = (value / 10) % 10;
                    memory.data[memory.i + 2] = value % 10;
                },
                0x1E => {
                    memory.i = @as(u12, memory.vars[nibbles[1]]) + memory.i;
                },
                0x55 => {
                    const x = nibbles[1];
                    for (0..x + 1) |idx| {
                        memory.data[memory.i + @as(u12, @intCast(idx))] = memory.vars[idx];
                    }
                },
                0x65 => {
                    const x = nibbles[1];
                    for (0..x + 1) |idx| {
                        memory.vars[idx] = memory.data[memory.i + @as(u12, @intCast(idx))];
                    }
                },
                else => return error.UnknownInstruction,
            },
            0x0 => switch (bytecode[1]) {
                0xE0 => {
                    display.clear();
                },
                0xEE => {
                    memory.sp -= 2;
                    const return_bytes = try memory.readBytes(memory.sp, 2);
                    memory.pc = (@as(u12, return_bytes[0]) << 8) | return_bytes[1];
                },
                else => return error.UnknownInstruction,
            },
            0x1 => { // JP addr
                const addr: u12 = (@as(u12, nibbles[1]) << 8) + bytecode[1];
                memory.pc = addr;
            },
            0x2 => {
                const addr: u12 = (@as(u12, nibbles[1]) << 8) | bytecode[1];

                const pc_bytes = [2]u8{ @intCast(memory.pc >> 8), @truncate(memory.pc) };
                try memory.writeBytes(memory.sp, &pc_bytes);

                memory.sp += 2;
                memory.pc = addr;
            },
            0x3 => {
                const x = nibbles[1];
                const kk = bytecode[1];
                if (memory.vars[x] == kk) {
                    memory.pc = memory.pc + 2;
                }
            },
            0x4 => {
                const x = nibbles[1];
                const kk = bytecode[1];
                if (memory.vars[x] != kk) {
                    memory.pc = memory.pc + 2;
                }
            },
            0x5 => {
                if (nibbles[3] == 0x0) {
                    const x = nibbles[1];
                    const y = nibbles[2];
                    if (memory.vars[x] == memory.vars[y]) {
                        memory.pc = memory.pc + 2;
                    }
                } else {
                    return error.UnknownInstruction;
                }
            },
            0x6 => { // SET
                memory.vars[nibbles[1]] = bytecode[1];
            },
            0x7 => { // ADD
                memory.vars[nibbles[1]] = @addWithOverflow(memory.vars[nibbles[1]], bytecode[1])[0];
            },
            0x8 => switch (nibbles[3]) {
                0x0 => { // LD
                    memory.vars[nibbles[1]] = memory.vars[nibbles[2]];
                },
                0x1 => { // OR
                    memory.vars[nibbles[1]] |= memory.vars[nibbles[2]];
                },
                0x2 => { // AND
                    memory.vars[nibbles[1]] &= memory.vars[nibbles[2]];
                },
                0x3 => { // XOR
                    memory.vars[nibbles[1]] ^= memory.vars[nibbles[2]];
                },
                0x4 => { // ADD Vx, Vy
                    const x = nibbles[1];
                    const y = nibbles[2];
                    const result, const overflow = @addWithOverflow(memory.vars[x], memory.vars[y]);

                    memory.vars[x] = result;
                    memory.vars[0xF] = overflow;
                },
                0x5 => { // SUB Vx, Vy
                    const x = nibbles[1];
                    const y = nibbles[2];

                    const no_borrow: u8 = if (memory.vars[x] >= memory.vars[y]) 1 else 0;
                    const result, _ = @subWithOverflow(memory.vars[x], memory.vars[y]);

                    memory.vars[x] = result;
                    memory.vars[0xF] = no_borrow;
                },
                else => {
                    return error.UnknownInstruction;
                },
            },
            0x9 => {
                if (nibbles[3] == 0x0) {
                    const x = nibbles[1];
                    const y = nibbles[2];

                    if (memory.vars[x] != memory.vars[y]) {
                        memory.pc = memory.pc + 2;
                    }
                } else {
                    return error.UnknownInstruction;
                }
            },
            else => {
                return error.UnknownInstruction;
            },
        }
    }
};
