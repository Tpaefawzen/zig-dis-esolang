//! Programming language Dis implementation

/// Submodules.
pub const math = @import("./dis-math.zig");

const std = @import("std");

/// UintT types unsigned integer.
/// Create a virtual machine of Dis.
pub fn factory(UintT: type, base: UintT, digit: UintT) !type {
    const INT_END_ = try @import("std.math").powi(UintT, base, digit);

    return struct {
        const Self = @This();

	/// Data. Actual valid integer shall be integer such that 0<=n<=INT_MAX.
	pub const INT_END = INT_END_;
	pub const INT_MAX = INT_END_ - 1;

	/// Registers
	pub var a: UintT = 0;
	pub var c: UintT = undefined;
	pub var d: UintT = undefined;

	/// Memory
	pub var mem: [Self.INT_END]UintT = .{0};

	// TODO
    }; // struct
} // pub fn factory
