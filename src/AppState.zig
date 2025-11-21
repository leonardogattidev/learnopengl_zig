const AppState = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("self").engine;
const sdl = engine.sdl;
const RenderState = @import("App.zig").render.State;

debug_allocator: std.heap.DebugAllocator(.{}),
arena_allocator: std.heap.ArenaAllocator,
allocator: Allocator,
window: ?*sdl.SDL_Window,
render: RenderState,
window_size: WindowSize,

const WindowSize = struct { width: c_int, height: c_int };

pub fn init(self: *AppState) !void {
    self.* = .{
        .debug_allocator = .init,
        .arena_allocator = undefined,
        .allocator = undefined,
        .window = null,
        .render = undefined,
        .window_size = undefined,
    };
    self.arena_allocator = std.heap.ArenaAllocator.init(self.debug_allocator.allocator());
    self.allocator = self.arena_allocator.allocator();

    try self.render.init(self.allocator);
}
