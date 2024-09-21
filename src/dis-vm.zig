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
	status: VmStatus = .running,

	/// Method-chain-style constructor for `Runner`.
	pub fn runner(self: @This(), comptime Runner: type) Runner {
	    return .{ .vm = self };
	}

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

	/// Maybe called by Runner{}.step(); reference implementation of
	/// executing a command based on current mem[c].
	pub fn runCommand(
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
	    switch ( decodeCommand(self.mem[self.c]) ) {
		.halt => halt(self),
		.load => load(self),
		.rot => rot(self),
		.jmp => jmp(self),
		.nop => {},
		.write => write(self, writer),
		.opr => opr(self),
		.read => read(self, reader),
	    }
	}

	fn halt(self: *@This()) void {
	    self.status = .{ .halt = .haltCommand };
	}
	fn load(self: *@This()) void { self.d = self.mem[self.d]; }
	fn rot(self: *@This()) void {
	    self.a = Math.rot(self.mem[self.d]);
	    self.mem[self.d] = self.a;
	}
	fn jmp(self: *@This()) void { self.c = self.mem[self.d]; }

	fn write(self: *@This(), writer: anytype) void {
	    if ( self.a == Math.MAX ) {
		self.status = .{ .halt = .eofWrite };
		return;
	    }
	    
	    switch ( @typeInfo(@TypeOf(writer)) ) {
		.Null => return,
		.Pointer => return write(self, writer.*),
		.Optional => if ( writer ) return write(self, writer.?) else return,
		.Struct, .Enum, .Union, .Opaque => {},
		else => {},
	    }

	    writer.writeByte(@truncate(self.a)) catch |err| {
		self.status = .{ .halt = .{ .writeError = err }};
	    };
	}

	fn opr(self: *@This()) void {
	    self.a = Math.opr(self.a, self.mem[self.d]);
	    self.mem[self.d] = self.a;
	}

	fn read(self: *@This(), reader: anytype) void {
	    self.a = switch ( @typeInfo(@TypeOf(reader)) ) {
		.Null => Math.MAX,
		.Pointer => return read(self, reader.*),
		.Optional => if ( reader ) return read(self, reader.?) else Math.MAX,
		else => reader.readByte() catch |err| l: {
		    if ( err != error.EndOfStream ) {
			self.status = .{ .readError = err };
		    }
		    break :l Math.MAX;
		},
	    };
	}
    };
}

pub const VmStatusTag = enum {
    running, halt, readError,
};

pub const VmStatus = union(VmStatusTag) {
    running, halt: HaltReason, readError: anyerror,

    pub const HaltReason = union(enum) {
	/// mem[C] is halt command.
	haltCommand,
	/// A is Math().MAX and mem[C] is write command.
	eofWrite,
	/// E.g. SIGPIPE, or something
	writeError: anyerror,
    };
};

/// Naive runner.
pub const SimpleRunner = struct {
    vm: *anyopaque,

    pub fn init(self: *@This()) void { _ = self; }

    pub const RunError = error { NotRunning, ReadErrorFixMe } || anyerror;
    pub fn step(self: *@This()) RunError!VmStatus {
	if ( self.vm.status != .running ) return error.NotRunning;
	self.vm.runCommand();
    }
};

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

/// Officially defined Dis machine.
pub const DefaultVm = Vm(dis_math.DefaultMath);

test DefaultVm {
    try std.testing.expect(@hasField(DefaultVm, "a"));
    try std.testing.expect(@hasField(DefaultVm, "mem"));

    var vm1 = DefaultVm{};
    try std.testing.expect(vm1.mem[429] == 0);

    vm1.runCommand(null, null);

    vm1.c = 59048;
    vm1.incrC();
    try std.testing.expect(vm1.c == 0 and vm1.d == 1);

    vm1.d = 59040;
    vm1.incrementC(10);
    try std.testing.expect(vm1.c == 10 and vm1.d == 1);

    // Run a command with specified reader and writer.
    vm1.runCommand(std.io.getStdIn().reader(), std.io.getStdOut().writer());
    vm1.runCommand(&@constCast(&std.io.getStdIn().reader()), &@constCast(&std.io.getStdOut().writer()));

    // Cat test
    vm1.c = 0; vm1.d = 0; vm1.mem[0] = '}'; vm1.mem[1] = '{';
    vm1.runCommand(null, null);
    vm1.incrC();
    vm1.runCommand(null, null);
    vm1.incrC();
    vm1.runCommand(null, null);
    vm1.incrC();
    try std.testing.expect(vm1.status == .halt);

    // const rs = "Hi";

    // vm1.c = 0; vm1.d = 0; vm1.mem[0] = '}'; vm1.mem[1] = '{';
    // vm1.runCommand(std.io.getStdIn().reader(), std.io.getStdOut().writer());
}

// test "Vm.step noncmd and !*>^_|" {
//     var vm1 = @constCast(
// 		    &DefaultVm.withRw(
// 			std.io.getStdIn().reader(),
// 			std.io.getStdOut().writer())
// 		    .runner(SimpleRunner))
// 	    .init();
//     _ = try vm1.step();
//     _ = try vm1.step();
//     _ = try vm1.step();
//     try std.testing.expect(vm1.a == 0);
//     try std.testing.expect(vm1.c == 3);
//     try std.testing.expect(vm1.d == 3);
// 
//     vm1.mem[3] = 33;
//     try std.testing.expect(try vm1.step() == .haltByHaltCommand);
//     try std.testing.expect(vm1.c == 3);
//     try std.testing.expect(vm1.d == 3);
// 
//     vm1.status = .running;
//     vm1.mem[3] = 42;
//     _ = try vm1.step();
//     try std.testing.expect(vm1.c == 4);
//     try std.testing.expect(vm1.d == 43);
// 
//     _ = try vm1.step();
//     try std.testing.expect(vm1.c == 5);
//     try std.testing.expect(vm1.d == 44);
// 
//     vm1.d = 59048;
//     _ = try vm1.step();
//     try std.testing.expect(vm1.c == 6);
//     try std.testing.expect(vm1.d == 0);
// 
//     vm1.mem[6] = 62;
//     vm1.mem[0] = 62;
//     _ = try vm1.step();
//     try std.testing.expect(vm1.a == 19683*2+20);
//     try std.testing.expect(vm1.mem[0] == 19683*2+20);
//     try std.testing.expect(vm1.c == 7);
//     try std.testing.expect(vm1.d == 1);
// 
//     vm1.mem[7] = 94;
//     _ = try vm1.step();
//     try std.testing.expect(vm1.c == 1);
//     try std.testing.expect(vm1.d == 2);
// 
//     vm1.mem[1] = 95;
//     vm1.mem[2] = 33 + 256;
//     _ = try vm1.step();
//     _ = try vm1.step();
//     try std.testing.expect(vm1.c == 3);
//     try std.testing.expect(vm1.d == 4);
//     try std.testing.expect(vm1.mem[1] == 95);
//     try std.testing.expect(vm1.mem[2] == 33 + 256);
//     try std.testing.expect(vm1.mem[3] == 42);
// 
//     // Skipping write, read at this point
// 
//     vm1.mem[3] = 124;
//     vm1.mem[4] = 48272;
//     try std.testing.expect(vm1.a == 19683*2+20);
// 
//     _ = try vm1.step();
// 
//     const xopr0 = dis_math.DefaultMath.opr(19683*2+20, 48272);
//     try std.testing.expect(vm1.a == xopr0);
//     try std.testing.expect(vm1.mem[4] == xopr0);
//     try std.testing.expect(vm1.c == 4);
//     try std.testing.expect(vm1.d == 5);
// }
// 
// test "Vm().step {}" {
//     const parse = @import("./parse.zig");
// 
//     const rs0 = "Hi world";
//     var rf0 = std.io.fixedBufferStream(rs0);
//     const r0 = rf0.reader();
// 
//     var ws0: [8]u8 = undefined;
//     var wf0 = std.io.fixedBufferStream(&ws0);
//     const w0 = wf0.writer();
// 
//     const M0 = Vm(dis_math.DefaultMath, r0, w0);
// 
//     // Taken from Ben Olmstead's example program.
//     const cat0 = "*^********************************}{*^*****!***";
//     var fp0 = std.io.fixedBufferStream(cat0);
//     const rp0 = fp0.reader();
// 
//     var m0 = try parse.parseFromReader(M0, rp0);
//     while ( m0.step() != .haltByEofWrite ) {}
// 
//     try std.testing.expectEq(ws0, "Hi world");
// }
