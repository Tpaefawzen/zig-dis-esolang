//! Naive runtime for Dis virtual machine.

const std = @import("std");

pub fn init(self: anytype) @TypeOf(self) {
    return self;
}

pub fn step(self: anytype) !bool {
    std.debug.assert(self.vm.status == .Running);
    self.vm.runCommand(self.reader, self.writer);
    switch ( self.vm.status ) {
	.Running => self.vm.incrC(),
	.Halt => return false,
	.ReadError => |err| return err,
    }
    return true;
}

pub fn Runner0(comptime Vm: type, comptime Reader: type, comptime Writer: type) type {
    return struct {
	vm: Vm,
	reader: if (Reader == @TypeOf(null)) Reader else ?Reader,
	writer: if (Writer == @TypeOf(null)) Writer else ?Writer,

	pub fn init(vm: Vm, reader: ?Reader, writer: ?Writer) @This() {
	    return .{
		.vm = vm,
		.reader = reader,
		.writer = writer,
	    };
	}

	pub fn step(self: *@This()) anyerror!void {
	    std.testing.assert(self.vm.status == .Running);

	    self.vm.step(self.reader, self.writer);
	    switch ( self.vm.status ) {
		.Running => self.vm.status.incrC(),
		.Halt => return,
		.ReadError => |err| return err,
	    }
	}
    };
}

pub fn runner0(
	vm: anytype, reader: anytype, writer: anytype
) Runner0(@TypeOf(vm), @TypeOf(reader), @TypeOf(writer)) {
    return .{ .vm = vm, .reader = reader, .writer = writer, };
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
//     const compile = @import("./compile.zig");
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
//     var m0 = try compile.compileFromReader(M0, rp0);
//     while ( m0.step() != .haltByEofWrite ) {}
// 
//     try std.testing.expectEq(ws0, "Hi world");
// }
