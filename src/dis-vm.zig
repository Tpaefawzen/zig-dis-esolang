//! The Dis language virtual machine.

const std = @import("std");

const dis_math = @import("dis-math.zig");

/// Make a virtual machine that works on specified Math type.
pub fn Vm(
	/// dis-math.zig Math()
	comptime Math: type,
	/// As in std.io.GenericReader. Has method `readByte`.
	comptime reader: anytype,
	/// As in std.io.GenericWriter. Has method `writeByte`.
	comptime writer: anytype
) type {

    const T: type = Math.T;
    return struct {
	/// Accumulator.
	a: T = 0,

	/// Program counter.
	c: T = 0,

	/// Math pointer.
	d: T = 0,

	/// Program memory that shares both code and data.
	mem: [Math.END]T = [_]T{0} ** Math.END,

	/// Running status.
	status: VmStatus = .running,

	/// Run a machine with a step.
	/// Must be running one.
	pub fn step(self: *@This()) error{NotRunning, ReadError, WriteError}!VmStatus {
	    if ( self.status != .running ) return error.NotRunning;

	    const cmdfn = self.fetchCommand();
	    if ( cmdfn ) |f| f(self);

	    if ( self.isHalt() ) return self.status;
	    if ( self.hasError() ) return self.status;

	    self.incrCAndD();

	    return self.status;
	}

	/// Simple halting-checker.
	pub fn isHalt(self: @This()) bool {
	    return self.status == .haltByHaltCommand
		or self.status == .haltByEofWrite
		or self.status == .writeError;
	}

	pub fn hasError(self: @This()) bool {
	    return self.status == .readError
		or self.status == .writeError;
	}

	/// Increment C and D; the Dis machine increments both registers C, D
	/// after each step.
	pub fn incrementCAndD(self: *@This(), y: Math.T) void {
	    const increment = Math.increment;
	    self.c = increment(self.c, y);
	    self.d = increment(self.d, y);
	}

	/// Same as incrementCAndD except increment by one.
	pub fn incrCAndD(self: *@This()) void {
	    incrementCAndD(self, 1);
	}

	/// Fetch a command.
	fn fetchCommand(self: @This()) ?(*const fn(*@This()) void) {
	    return fetchCommandOf(self.mem[self.c]);
	}

	/// Same as fetchCommand but the user supplies value.
	pub fn fetchCommandOf(x: T) ?(*const fn(*@This()) void) {
	    return switch ( decodeCommand(x) ) {
	    .halt => halt, .load => load, .rot => rot,
	    .jmp => jmp, .nop => null, .write => write,
	    .opr => opr, .read => read,
	    };
	}

	fn halt(self: *@This()) void {
	    self.status = .haltByHaltCommand;
	}

	fn load(self: *@This()) void {
	    self.d = self.mem[self.d];
	}

	fn rot(self: *@This()) void {
	    const x = self.mem[self.d];
	    const z = Math.rot(x);
	    self.a = z;
	    self.mem[self.d] = z;
	}

	fn jmp(self: *@This()) void {
	    self.c = self.mem[self.d];
	}

	fn write(self: *@This()) void {
	    const a = self.a;
	    if ( a == Math.MAX ) {
		self.status = .haltByEofWrite;
		return;
	    }

	    writer.writeByte(@truncate(a)) catch |err| {
		self.status.writeError = err;
	    };
	}

	fn opr(self: *@This()) void {
	    const z = Math.opr(self.a, self.mem[self.d]);
	    self.a = z;
	    self.mem[self.d] = z;
	}

	/// Assumes ReadError-s other than EndOfStream are
	/// equivalent to EndOfStream.
	fn read(self: *@This()) void {
	    self.a = reader.readByte() catch |err| l: {
		if ( err != error.EndOfStream ) {
		    self.status.readError = err;
		}
		break :l Math.MAX;
	    };
	}
    };
}

/// Eight commands specified in Dis.
pub const Command = enum { halt, load, rot, jmp, nop, write, opr, read, };

pub inline fn decodeCommand(char_code: anytype) Command {
    return switch ( char_code ) {
    33 => .halt,
    42 => .load,
    62 => .rot,
    94 => .jmp,
    95 => .nop,
    123 => .write,
    124 => .opr,
    125 => .read,
    else => .nop,
    };
}

pub const VmStatus = union(enum) {
    running,

    /// Reached to the "{" command and the accumulator had Math().MAX.
    haltByEofWrite,

    /// The "!" command.
    haltByHaltCommand,

    /// This status is used when the optimizer realized that there
    /// will be no I/O and the program shall never stop.
    noIoInfiniteLoop,

    /// Write-error is considered to result in halt;
    /// one example of such errors is BrokenPipe.
    writeError: anyerror,

    /// only error.EndOfStream is considered to be non-error read-error;
    /// whichever kind of readError happens,
    /// it is treated as if Math().MAX were read.
    readError: anyerror,
};

/// Officially defined Dis machine.
pub const DefaultVm = Vm(dis_math.DefaultMath, std.io.getStdIn().reader(), std.io.getStdOut().writer());

test DefaultVm {
    try std.testing.expect(@hasField(DefaultVm, "a"));
    try std.testing.expect(@hasField(DefaultVm, "mem"));

    const vm = DefaultVm{};
    try std.testing.expect(vm.mem[429] == 0);
}

test "Vm.step noncmd and !*>^_|" {
    var vm1 = DefaultVm{};
    _ = try vm1.step();
    _ = try vm1.step();
    _ = try vm1.step();
    try std.testing.expect(vm1.a == 0);
    try std.testing.expect(vm1.c == 3);
    try std.testing.expect(vm1.d == 3);

    vm1.mem[3] = 33;
    try std.testing.expect(try vm1.step() == .haltByHaltCommand);
    try std.testing.expect(vm1.c == 3);
    try std.testing.expect(vm1.d == 3);

    vm1.status = .running;
    vm1.mem[3] = 42;
    _ = try vm1.step();
    try std.testing.expect(vm1.c == 4);
    try std.testing.expect(vm1.d == 43);

    _ = try vm1.step();
    try std.testing.expect(vm1.c == 5);
    try std.testing.expect(vm1.d == 44);

    vm1.d = 59048;
    _ = try vm1.step();
    try std.testing.expect(vm1.c == 6);
    try std.testing.expect(vm1.d == 0);

    vm1.mem[6] = 62;
    vm1.mem[0] = 62;
    _ = try vm1.step();
    try std.testing.expect(vm1.a == 19683*2+20);
    try std.testing.expect(vm1.mem[0] == 19683*2+20);
    try std.testing.expect(vm1.c == 7);
    try std.testing.expect(vm1.d == 1);

    vm1.mem[7] = 94;
    _ = try vm1.step();
    try std.testing.expect(vm1.c == 1);
    try std.testing.expect(vm1.d == 2);

    vm1.mem[1] = 95;
    vm1.mem[2] = 33 + 256;
    _ = try vm1.step();
    _ = try vm1.step();
    try std.testing.expect(vm1.c == 3);
    try std.testing.expect(vm1.d == 4);
    try std.testing.expect(vm1.mem[1] == 95);
    try std.testing.expect(vm1.mem[2] == 33 + 256);
    try std.testing.expect(vm1.mem[3] == 42);

    // Skipping write, read at this point

    vm1.mem[3] = 124;
    vm1.mem[4] = 48272;
    try std.testing.expect(vm1.a == 19683*2+20);

    _ = try vm1.step();

    const xopr0 = dis_math.DefaultMath.opr(19683*2+20, 48272);
    try std.testing.expect(vm1.a == xopr0);
    try std.testing.expect(vm1.mem[4] == xopr0);
    try std.testing.expect(vm1.c == 4);
    try std.testing.expect(vm1.d == 5);
}

test "Vm().step {}" {
    // TODO
}
