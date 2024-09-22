//! Template for Runner struct.
//! Mandatory members are vm, reader, writer; implementations may have
//! extension members. Mandatory methods are init() and step().

/// Dis machine itself.
vm: *anyopaque,
/// For self.vm.runCommand().
reader: ?*anyopaque,
/// For self.vm.runCommand().
writer: ?*anyopaque,

/// Create `@This()` made of given machine, reader and writer.
/// The implementation may do some initial optimization.
pub fn init(vm: *anyopaque, reader: ?*anyopaque, writer: ?*anyopaque) @This() {
    return .{ .vm = vm, .reader = reader, .writer = writer, };
}

/// Run a machine by one step.
pub fn step(self: *@This()) anyerror!bool {
    std.debug.assert(self.status == .Running);
    _ = &self;
    return self.status == .Running;
}

// Subdirectory things.
pub const @"0" = @import("./Runner/0.zig");
pub const Runner0 = @"0".Runner0;
pub const runner0 = @"0".runner0;
pub const NaiveRunner = Runner0;
pub const naiveRunner = runner0;

const std = @import("std");
