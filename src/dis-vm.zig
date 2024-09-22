//! The Dis language virtual machine.

const std = @import("std");

const dis_math = @import("dis-math.zig");

/// Make a virtual machine that works on specified Math type.
pub fn Vm(
	/// dis-math.zig Math()
	comptime Math_: type
) type {
    return struct {
	pub const Math = Math_;
	const T = Math.T;

	/// Accumulator.
	a: T = 0,
	/// Program counter.
	c: T = 0,
	/// Data pointer.
	d: T = 0,
	/// Program memory, data and code are shared.
	mem: [Math.END]T = [_]T{0} ** Math.END,
	/// Running status.
	status: VmStatus = .Running,

	/// Constructor.
	pub fn init() @This() { return @This(){}; }

	/// Increment C and D by one; in Dis this is how it is stepped.
	pub fn incrC(self: *@This()) void {
	    self.c = Math.incr(self.c);
	    self.d = Math.incr(self.d);
	}

	/// Like `incrC`; custom incrementation-value.
	pub fn incrementC(self: *@This(), x: T) void {
	    self.c = Math.increment(self.c, x);
	    self.d = Math.increment(self.d, x);
	}

	/// Like `incrC` but decrement version
	pub fn decrC(self: *@This()) void {
	    self.c = Math.decr(self.c);
	    self.d = Math.decr(self.d);
	}

	/// Like `decrC` but custom decrementation-value.
	pub fn decrementC(self: *@This(), x: T) void {
	    self.c = Math.decrement(self.c, x);
	    self.d = Math.decrement(self.d, x);
	}

	/// `incrementC` until `self.c` gets to `z`.
	pub fn setC(self: *@This(), z: T) void {
	    if ( z < self.c ) {
		const diff = self.c - z;
		self.c = z;
		self.d = Math.decrement(self.d, diff);
		return;
	    }
	    // z > self.c
	    const diff = z - self.c;
	    self.c = z;
	    self.d = Math.increment(self.d, diff);
	}

	/// Maybe called by `Runner{}.step()`; reference implementation of
	/// executing a command based on current mem[c].
	/// Note it does not check `self.status`.
	pub fn runCommand(
		/// Must `self.status == .Running`.
		self: *@This(),
		/// `null` or something that has method `readByte`.
		/// If `null` is given then it's like a null-device;
		/// treats as if error.EndOfStream were reached.
		reader: anytype,
		/// `null` or something that has method `writeByte`.
		/// If `null` is given then `output` command results in doing
		/// nothing with no error.
		writer: anytype
	) void {
	    std.debug.assert(self.status == .Running);

	    switch ( decodeCommand(self.mem[self.c]) ) {
		.Halt => halt(self),
		.Load => load(self),
		.Rot => rot(self),
		.Jmp => jmp(self),
		.Nop => {},
		.Write => write(self, writer),
		.Opr => opr(self),
		.Read => read(self, reader),
	    }
	}

	fn halt(self: *@This()) void {
	    self.status = .{ .Halt = .HaltCommand };
	}
	fn load(self: *@This()) void { self.d = self.mem[self.d]; }
	fn rot(self: *@This()) void {
	    self.a = Math.rot(self.mem[self.d]);
	    self.mem[self.d] = self.a;
	}
	fn jmp(self: *@This()) void { self.c = self.mem[self.d]; }

	fn write(self: *@This(), writer: anytype) void {
	    if ( self.a == Math.MAX ) {
		self.status = .{ .Halt = .EofWrite };
		return;
	    }

	    // @compileLog(writer);
	    
	    const w = switch ( @typeInfo(@TypeOf(writer)) ) {
		.Null => return,
		.Pointer => writer.*,
		.Optional => if ( writer ) return write(self, writer.?) else return,
		else => writer,
	    };

	    w.writeByte(@truncate(self.a)) catch |err| {
		self.status = .{ .Halt = .{ .WriteError = err }};
	    };
	}

	fn opr(self: *@This()) void {
	    self.a = Math.opr(self.a, self.mem[self.d]);
	    self.mem[self.d] = self.a;
	}

	fn read(self: *@This(), reader: anytype) void {
	    // @compileLog(reader);

	    self.a = switch ( @typeInfo(@TypeOf(reader)) ) {
		.Null => Math.MAX,
		.Pointer => reader.*.readByte() catch |err| l: {
			    if ( err != error.EndOfStream ) {
				self.status = .{ .ReadError = err };
			    }
			    break :l Math.MAX;
			},
		.Optional => if ( reader ) return read(self, reader.?) else Math.MAX,
		else => reader.readByte() catch |err| l: {
			    if ( err != error.EndOfStream ) {
				self.status = .{ .ReadError = err };
			    }
			    break :l Math.MAX;
			},
	    };
	}
    };
}

pub const VmStatusTag = enum {
    Running, Halt, ReadError,
};

pub const VmStatus = union(VmStatusTag) {
    Running, Halt: HaltReason, ReadError: anyerror,

    pub const HaltReason = union(enum) {
	/// mem[C] is halt command.
	HaltCommand,
	/// A is Math().MAX and mem[C] is write command.
	EofWrite,
	/// E.g. SIGPIPE, or something
	WriteError: anyerror,
    };
};

/// Eight commands specified in Dis.
pub const Command = enum { Halt, Load, Rot, Jmp, Nop, Write, Opr, Read, };

pub inline fn decodeCommand(char_code: anytype) Command {
    return switch ( char_code ) {
    33 => .Halt,
    42 => .Load,
    62 => .Rot,
    94 => .Jmp,
    95 => .Nop,
    123 => .Write,
    124 => .Opr,
    125 => .Read,
    else => .Nop,
    };
}

/// Officially defined Dis machine.
pub const DefaultVm = Vm(dis_math.DefaultMath);

test DefaultVm {
    try std.testing.expect(@hasField(DefaultVm, "a"));
    try std.testing.expect(@hasField(DefaultVm, "mem"));

    var vm1 = DefaultVm{};
    try std.testing.expect(vm1.mem[429] == 0);

    vm1.runCommand(null, null);

    // incrC-like methods test
    // Wraparound test
    vm1.c = 59048;
    vm1.incrC();
    try std.testing.expect(vm1.c == 0 and vm1.d == 1);

    vm1.d = 59040;
    vm1.incrementC(10);
    try std.testing.expect(vm1.c == 10 and vm1.d == 1);
    vm1.setC(12);
    try std.testing.expect(vm1.c == 12 and vm1.d == 3);
    vm1.setC(10);
    try std.testing.expect(vm1.c == 10 and vm1.d == 1);
    vm1.decrementC(2);
    try std.testing.expect(vm1.c == 8 and vm1.d == 59048);

    vm1.c = 59048;
    vm1.d = 59048-16;
    vm1.setC(5);
    try std.testing.expect(vm1.c == 5 and vm1.d == 5-16+59049);

    // Run a command with specified reader and writer.
    // Note every item in vm1.mem is 0.
    for ( vm1.mem ) |x| try std.testing.expect(x == 0);
    vm1.runCommand(std.io.getStdIn().reader(), std.io.getStdOut().writer());
    vm1.runCommand(&@constCast(&std.io.getStdIn().reader()), &@constCast(&std.io.getStdOut().writer()));

    // Cat test with null reader and null writer
    vm1.c = 0; vm1.d = 0; vm1.mem[0] = '}'; vm1.mem[1] = '{';
    vm1.status = .Running;
    vm1.runCommand(null, null);
    vm1.incrC();
    vm1.runCommand(null, null);
    try std.testing.expect(vm1.status == .Halt);

    // Cat test with actual reader and writer
    const rs = [_]u8{ 'H', 'i' };
    const reader0 = @constCast(&std.io.fixedBufferStream(&rs)).reader();
    var ws: [2]u8 = undefined;
    const writer0 = @constCast(&std.io.fixedBufferStream(&ws)).writer();
    vm1.c = 0; vm1.d = 0; vm1.status = .Running;
    vm1.runCommand(&reader0, &writer0);
    vm1.incrC();
    vm1.runCommand(&reader0, &writer0);
    vm1.incrC();
    vm1.runCommand(&reader0, &writer0);
    vm1.incrC();
    try std.testing.expect(ws[0] == 'H');

    for ( 3..59049 ) |_| {
	vm1.runCommand(reader0, writer0); vm1.incrC(); // Doing reader/writer polymorphism test too
    }
    try std.testing.expect(vm1.c == 0 and vm1.d == 0);
    vm1.runCommand(reader0, writer0);
    vm1.incrC();
    vm1.runCommand(reader0, writer0);
    vm1.incrC();
    vm1.runCommand(reader0, writer0);
    vm1.incrC();
    try std.testing.expect(ws[0] == 'H');
    try std.testing.expect(ws[1] == 'i');

    for ( 3..59049 ) |_| {
	vm1.runCommand(reader0, writer0); vm1.incrC();
    }
    try std.testing.expect(vm1.c == 0 and vm1.d == 0);
    vm1.runCommand(reader0, writer0);
    vm1.incrC();
    vm1.runCommand(reader0, writer0);
    try std.testing.expect(vm1.status == .Halt and vm1.status.Halt == .EofWrite);

    // write() test with WriteError.
    var vm2 = DefaultVm.init();
    vm2.mem[0] = '{';
    var ws2: [0]u8 = undefined;
    const writer2 = @constCast(&std.io.fixedBufferStream(&ws2)).writer();
    vm2.runCommand(null, writer2);
    try std.testing.expect(vm2.status.Halt == .WriteError);

    // "!"
    var vm3 = DefaultVm.init();
    vm3.mem[0] = '!';
    vm3.runCommand(null, null);
    try std.testing.expect(vm3.status.Halt == .HaltCommand);

    // "*"
    vm3.status = .Running;
    vm3.mem[0] = '*';
    vm3.d = 25;
    vm3.mem[25] = 489;
    vm3.runCommand(null, null);
    try std.testing.expect(vm3.d == 489);

    // ">"
    vm3.mem[0] = '>';
    vm3.mem[489] = 62;
    vm3.runCommand(null, null);
    try std.testing.expect(vm3.a == 20 + 19683*2);
    try std.testing.expect(vm3.mem[489] == 20 + 19683*2);

    // "^"
    vm3.mem[0] = '^';
    vm3.mem[489] = 21;
    vm3.runCommand(null, null);
    try std.testing.expect(vm3.c == 21);

    // "_"
    vm3.mem[21] = '_';
    vm3.runCommand(null, null);
    try std.testing.expect(vm3.c == 21);
    try std.testing.expect(vm3.d == 489);
    try std.testing.expect(vm3.a == 20 + 19683*2);
    try std.testing.expect(vm3.mem[489] == 21);

    // "|"
    vm3.mem[489] = 238;
    vm3.a = 47;
    vm3.mem[21] = '|';
    vm3.runCommand(null, null);
    try std.testing.expect(vm3.a == DefaultVm.Math.opr(47, 238));
    try std.testing.expect(vm3.mem[489] == DefaultVm.Math.opr(47, 238));
}
