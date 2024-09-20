//! Dis program compiler.

const std = @import("std");

const math = @import("./dis-math.zig");
const vm = @import("./dis-vm.zig");

pub const SyntaxError = error {
    /// Not one of "!*>^_{|}(".
    NotACommand,
    UnclosedComment,
    /// Reached to `Math().MAX`-th command.
    TooLong,
};

/// Given ascii source, compile to `VmT`. Loaded to memory.
pub fn parseFromReader(
	/// Specify the `Vm` type here.
	comptime VmT: type,
	/// `std.io.GenericReader` or `std.io.AnyReader`; has method `readByte`.
	reader: anytype
) (SyntaxError||anyerror)!VmT {
    const MAX = VmT.Math.MAX;
    var my_vm = VmT{};
    var i: VmT.Math.END_T = 0;
    var c: u8 = reader.readByte() catch |err| {
	if ( err == error.EndOfStream ) return my_vm;
	return err;
    };

    while ( true ) : ( c = reader.readByte() catch |err| {
	    if ( err == error.EndOfStream ) return my_vm;
	    return err;
    }) {
	switch ( c ) {
	33, 42, 62, 94, 95, 123, 124, 125 => {
	    if ( i > MAX ) return SyntaxError.TooLong;
	    my_vm.mem[i] = c;
	    i += 1;
	},
	'(' => {
	    while ( c != ')' ) {
		c = reader.readByte() catch |err| {
		    if ( err == error.EndOfStream ) return SyntaxError.UnclosedComment;
		    return err;
		};
	    }
	},
	else => {
	    if ( std.ascii.isWhitespace(c) ) {}
	    else return SyntaxError.NotACommand;
	}
	}
    }
}

// test parseFromReader {
//     const dummyRead = struct {
// 	fn dummyRead0(context: void, buffer: []u8) error{}!usize { _ = context; _ = buffer; return 0; }
//     }.dummyRead0;
//     const NullReader = std.io.GenericReader(void, error{}, dummyRead);
//     const null_reader: NullReader = .{ .context = {} };
//     const DefaultVm = vm.Vm(math.DefaultMath, null_reader, std.io.null_writer);
// 
//     const source0 =
// 	\\ (123456789012345678)
// 	\\ }|||}||*|^__*___!!!^
// 	\\ (123456789012345678901234567890)
// 	\\ !}_}_{{>>>>__>>>!!}^^^}|||{}!!!_
// 	;
//     var fbs0 = std.io.fixedBufferStream(source0);
//     const reader0 = fbs0.reader();
//     var vm0 = try parseFromReader(DefaultVm, reader0);
//     try std.testing.expect(vm0.mem[51] == '_');
//     try std.testing.expect(vm0.mem[52] == 0);
//     _ = try vm0.step();
// 
//     const s1 = "";
//     var f1 = std.io.fixedBufferStream(s1);
//     const r1 = f1.reader();
//     var vm1 = try parseFromReader(DefaultVm, r1);
//     try std.testing.expect(vm1.mem[0] == 0);
//     _ = try vm1.step();
// 
//     const s2 = "Illegal!";
//     var f2 = std.io.fixedBufferStream(s2);
//     const r2 = f2.reader();
//     try std.testing.expectError(SyntaxError.NotACommand, parseFromReader(DefaultVm, r2));
// 
//     const s3 =
// 	\\ ( A a a a a 
// 	\\
// 	\\
// 	\\
// 	\\ (
// 	\\ UNCLOSED EVENTUALLY
// 	;
//     var f3 = std.io.fixedBufferStream(s3);
//     const r3 = f3.reader();
//     try std.testing.expectError(SyntaxError.UnclosedComment, parseFromReader(DefaultVm, r3));
// 
//     const s4 = "_" ** 59049;
//     var m4 = try parseFromReader(DefaultVm, @constCast(&std.io.fixedBufferStream(s4)).reader());
//     for ( 0..59049 ) |_| _ = try m4.step();
//     try std.testing.expect(m4.c == 0);
// 
//     const s5 = "_" ** 59050;
//     try std.testing.expectError(
// 	    SyntaxError.TooLong,
// 	    parseFromReader(
// 		    DefaultVm,
// 		    @constCast(&std.io.fixedBufferStream(s5)).reader()));
// 
//     const Vm2_8 = vm.Vm(math.Math(u8, 2, 8), null_reader, std.io.null_writer);
// 
//     const s6 = "}" ** 256;
//     var m6 = try parseFromReader(Vm2_8, @constCast(&std.io.fixedBufferStream(s6)).reader());
//     _ = try m6.step();
// 
//     const s7 = "}" ** 257;
//     try std.testing.expectError(
// 	    SyntaxError.TooLong,
// 	    parseFromReader(
// 		    Vm2_8,
// 		    @constCast(&std.io.fixedBufferStream(s7)).reader()));
// }
