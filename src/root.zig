//! Programming language Dis implementation

const std = @import("std");

/// Official Dis specification constants.
pub const DEFAULT_BASE = 3;
pub const DEFAULT_DIGIT = 10;
pub const DEFAULT_UINT_T = u16;

/// Dis data type creator.
pub fn uint(UintT: type, base_: UintT, digit_: UintT) !type {
    // Domain things
    if ( @typeInfo(UintT) != .Int or std.math.minInt(UintT) < 0 ) @compileError("UintT must be unsigned integer");
    if ( base_ <= 0 ) @compileError("base_ must be >0");
    if ( digit_ <= 0 ) @compileError("digit_ must be >0");

    const INT_END_ = try std.math.powi(UintT, base_, digit_);
    return struct {
	const Self = @This();
	const base = base_;
	const digit = digit_;

        pub const INT_END = INT_END_;

	/// Valid integer shall be 0<=n<=INT_MAX.
	pub const INT_MAX = INT_END_-1;
    };
}

test uint {
    const myMath = try uint(DEFAULT_UINT_T, DEFAULT_BASE, DEFAULT_DIGIT);
    try std.testing.expect(myMath.INT_MAX == 59048);
}

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
	pub var mem: [0:Self.INT_END]UintT = .{0};

	// TODO
    }; // struct
} // pub fn factory

