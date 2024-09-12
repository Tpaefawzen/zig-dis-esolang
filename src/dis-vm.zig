//! The Dis language virtual machine.

const data = @import("dis-math.zig");

/// Make a virtual machine that works on specified Data type.
pub fn Vm(comptime Data: anytype) type {
    const T: type = Data.T;
    return struct {
	/// Data.
	Data: type = Data,

	/// Accumulator.
	a: T = 0,

	/// Program counter.
	c: T = undefined,

	/// Data pointer.
	d: T = undefined,

	/// Program memory that shares both code and data.
	mem: [Data.END]T = [_]T{0} ** Data.END,
    };
}

pub const VmStatus = enum {
    running,
    haltByEofWrite,
    haltByHaltCommand,
    noIoInfiniteLoop,
};

/// Officially defined Dis machine.
pub const DefaultVm = Vm(data.DefaultData);

const std = @import("std");

test DefaultVm {
    try std.testing.expect(@hasField(DefaultVm, "a"));
    try std.testing.expect(@hasField(DefaultVm, "mem"));
}
