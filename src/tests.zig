//! file tests.
//! https://stackoverflow.com/questions/75762207/how-to-test-multiple-files-in-zig

comptime {
    _ = @import("./root.zig");
    _ = @import("./dis-math.zig");
}
