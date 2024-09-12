//! Programming language Dis implementation

const std = @import("std");

/// Dis data type creator.
pub fn uint(UintT: type, base_: UintT, digit_: UintT) !type {
    // Domain things
    if ( @typeInfo(UintT) != .Int or std.math.minInt(UintT) < 0 ) @compileError("UintT must be unsigned integer");
    if ( base_ <= 0 ) @compileError("base_ must be >0");
    if ( digit_ <= 0 ) @compileError("digit_ must be >0");

    const INT_END_ = try std.math.powi(UintT, base_, digit_);
    return struct {
	const Self = @This();
	pub const base = base_;
	pub const digit = digit_;
	pub const Type = UintT;

        pub const INT_END = INT_END_;

	/// Valid integer shall be 0<=n<=INT_MAX.
	pub const INT_MAX = INT_END_-1;

	/// Idk if necessary.
	pub fn is_valid_value(x: UintT) bool {
	    return 0 <= x and x <= INT_MAX;
	}

	/// Perform a right-rotate for one digit.
	pub fn rot(x: UintT) UintT {
	    const least_digit = x % Self.base;
	    const head_digits = x / Self.base;
	    const left_shift_mult = Self.INT_END / Self.base;
	    return head_digits + least_digit * left_shift_mult;
	}

        /// For each digit, do subtraction without carry.
	pub fn opr(x: UintT, y: UintT) UintT {
	    if ( x == 0 and y == 0 ) return 0;
	    return base * opr(x / base, y / base) + try opr_(x % base, y % base);
	}

	/// x, y is digit. Digit-subtraction.
	inline fn opr_(x: UintT, y: UintT) !UintT {
	    std.debug.assert(x < base);
	    std.debug.assert(y < base);
	    return (base + x - y) % base;
	}

	pub fn incr(x: UintT) UintT {
	    return (x + 1) % INT_END;
	}

	pub fn increment(x: UintT, y: UintT) UintT {
	    if ( y == 0 ) return x;
	    return increment(incr(x), y-1);
	}
    };
}

/// Official Dis specification constants.
pub const DEFAULT_BASE = 3;
pub const DEFAULT_DIGIT = 10;
pub const DEFAULT_UINT_T = u16;
pub const DefaultData = uint(DEFAULT_UINT_T, DEFAULT_BASE, DEFAULT_DIGIT) catch unreachable;

test DefaultData {
    try std.testing.expect(DefaultData.base == 3);
    try std.testing.expect(DefaultData.digit == 10);
    try std.testing.expect(DefaultData.INT_MAX == 59048);
    try std.testing.expect(DefaultData.INT_END == 59049);
}

test "DefaultData.rot" {
    const rot = DefaultData.rot;

    try std.testing.expect(rot(1) == 19683);
    try std.testing.expect(rot(19683) == 19683/3);
    try std.testing.expect(rot(2) == 19683 * 2);
    try std.testing.expect(rot(4) == 19683 + 1);
}

test "DefaultData.opr" {
    const opr = DefaultData.opr;

    try std.testing.expect(opr(0, 0) == 0);
    try std.testing.expect(opr(0, 1) == 2);
    try std.testing.expect(opr(0, 2) == 1);
    try std.testing.expect(opr(1, 0) == 1);
    try std.testing.expect(opr(1, 1) == 0);
    try std.testing.expect(opr(1, 2) == 2);
    try std.testing.expect(opr(2, 0) == 2);
    try std.testing.expect(opr(2, 1) == 1);
    try std.testing.expect(opr(2, 2) == 0);

    try std.testing.expect(
	opr(1 * 3 + 1 * 1,
	    2 * 3 + 2 * 2)
	==  2 * 3 + 2 * 2);

    {
	const x = 2 * 81 + 1 * 27 + 0 * 9 + 1 * 3 + 2 * 1;
	const y = 0 * 81 + 1 * 27 + 2 * 9 + 2 * 3 + 1 * 1;
	const z = 1 * 81 + 0 * 27 + 1 * 9 + 2 * 3 + 1 * 1;
	const my_result = opr(x, y);
	std.debug.print("{d} vs {d}\n", .{z, my_result});
	try std.testing.expect(my_result == z);
    }
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
	pub var mem: [Self.INT_END]UintT = .{0};

	// TODO
    }; // struct
} // pub fn factory

