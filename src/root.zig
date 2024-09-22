//! Programming language Dis implementation

// Submodules.
pub const math = @import("./dis-math.zig");
pub const vm = @import("./dis-vm.zig");
pub const compile = @import("./compile.zig");
pub const runners = @import("./runners.zig");

test {
    _ = math;
    _ = vm;
    _ = compile;
    _ = runners;
}
