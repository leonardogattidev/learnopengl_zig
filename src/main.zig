const std = @import("std");
const log = std.log.scoped(.main);
const SampleApp = @import("App.zig");
pub const engine = @import("engine");
const app = engine.app;

pub const App = app.App(SampleApp);
pub const Context = app.Context(SampleApp.State);

pub fn main() !u8 {
    return App.run();
}
