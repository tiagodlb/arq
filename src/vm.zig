const std = @import("std");

pub const Error = error{ ReadOutOfBounds, UnknownInstruction, WriteOutOfBounds };

pub const program_load_addr = 0x200;

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

    pc: u12,
    i: u12, // registrador I
    vars: [16]u8,
    data: [total_memory_bytes]u8,

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

    pub fn step(random: std.Random, memory: *Memory, display: *Display, keypad: *Keypad) error{ UnknownInstruction, ReadOutOfBounds }!void {
        _ = random;
        _ = display;
        _ = keypad;

        const bytecode = try memory.readBytes(memory.pc, 2);
        memory.pc += 2;

        _ = bytecode;
        return error.UnknownInstruction;
    }

    pub fn loadProgram(
        self: *Self,
        program: []const u8,
    ) error{WriteOutOfBounds}!void {
        try self.writeBytes(program_load_addr, program);
        self.pc = program_load_addr;
    }

    pub fn readBytecode(memory: *Memory, bytecode: []const u8, random: std.Random) !void {
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
            0xF => switch (nibbles[3]) {
                0x1E => {
                    memory.i = @as(u12, memory.vars[nibbles[1]]) + memory.i;
                },
                else => return error.UnknownInstruction,
            },
            0x1 => { // JP addr
                const addr: u12 = (@as(u12, nibbles[1]) << 8) + bytecode[1];
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
