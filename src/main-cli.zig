//! Commandline interface program implementation.

const std = @import("std");

const dis = @import("./root.zig");

/// Program name.
var arg0: []const u8 = undefined;

/// Print usage and exit.
fn usage(succeed: bool) noreturn {
    // std.debug.print("Usage: {s} [-Ev] [-k steps] [-O level] FILE\n", .{arg0});
    std.debug.print("Usage: {s} FILE\n", .{arg0});
    std.process.exit(if ( succeed ) 0 else 1);
}

/// Program entry.
pub fn main() !void {
    var args = std.process.args(); 
    defer args.deinit();

    arg0 = args.next() orelse "dis-esolang";

    const filename = args.next() orelse usage(false);
    const file = std.fs.cwd().openFile(filename, .{ .mode = .read_only }) catch |err| {
	    std.debug.print("{s}: Could not open {s}: {s}\n", .{ arg0, filename, @errorName(err) });
	    std.process.exit(1);
	};
    defer file.close();

    const Vm = dis.vm.DefaultVm;
    const vm = dis.compile.compileFromReader(Vm, file.reader()) catch |err| {
	    std.debug.print("{s}: Compile failed: {s}\n", .{ arg0, @errorName(err) });
	    std.process.exit(2);
	};

    var runningEnv = dis.runners.naiveRunner(vm);
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    while ( try runningEnv.step(stdin, stdout) ) {}

    std.process.exit(0);
}
