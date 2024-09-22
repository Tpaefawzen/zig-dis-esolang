//! Naive runtime for Dis virtual machine.

const std = @import("std");

pub fn NaiveRunner(comptime Vm: type) type {
    return struct {
	vm: Vm,

	pub fn init(vm: Vm) @This() { return .{ .vm = vm, }; }

	/// Run a program for one step. Must `self.status == .Running`.
	/// Return result of `self.status == .Running`.
	pub fn step(self: *@This(), reader: anytype, writer: anytype) !bool {
	    std.debug.assert(self.vm.status == .Running);
	    self.vm.runCommand(reader, writer);
	    switch ( self.vm.status ) {
		.Running => self.vm.incrC(),
		.Halt => return false,
		.ReadError => |err| return err,
	    }
	    return true;
	}
    };
}

pub fn naiveRunner(vm: anytype) NaiveRunner(@TypeOf(vm)) {
    return NaiveRunner(@TypeOf(vm)).init(vm);
}
