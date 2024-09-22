//! Runtimes for the Dis machine.
//! `snake_case` identifiers are namespaces.
//! `TypenameCase` identifiers name runtime structs; methods `init()` and `step()`.
//! `thisCase` identifiers: given the struct instance, return `CorrespondingRunners(@TypeOf(vm)).init(vm)`.

// Runners by optimization level.
pub const Opt0Runner = NaiveRunner;
pub const opt0Runner = naiveRunner;

pub const naive_runner = @import("./naive-runner.zig");
pub const NaiveRunner = naive_runner.NaiveRunner;
pub const naiveRunner = naive_runner.naiveRunner;
