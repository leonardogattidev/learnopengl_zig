const std = @import("std");
const log = std.log.scoped(.App);
const engine = @import("engine");
const gl = engine.gl;
const sdl = engine.sdl;
const Result = @import("engine").app.Result;
pub const State = @import("AppState.zig");
pub const Context = @import("self").Context;
const window = engine.default_window;
pub const render = @import("./render/render.zig");

pub fn onInit(ctx: *Context) !Result {
    log.info("Initializing app.", .{});

    try ctx.appstate.init();

    try window.onInit(&ctx.appstate.window);
    {
        var w: c_int = undefined;
        var h: c_int = undefined;
        _ = sdl.SDL_GetWindowSize(ctx.appstate.window, @ptrCast(&w), @ptrCast(&h));
        gl.Viewport(0, 0, w, h);
    }
    try render.setup(ctx);
    return .CONTINUE;
}

pub fn onEvent(ctx: *Context, event: *sdl.SDL_Event) !Result {
    // _ = ctx;
    switch (event.type) {
        sdl.SDL_EVENT_QUIT => return .SUCCESS,
        else => {},
    }
    render.onEvent(ctx, event);
    return .CONTINUE;
}

pub fn onUpdate(ctx: *Context) !Result {
    try render.update(ctx);

    return .CONTINUE;
}

pub fn onExit(ctx: *Context, result: Result) !void {
    _ = result;
    const appstate = &ctx.appstate;
    defer appstate.arena_allocator.deinit();
    defer window.onExit(&appstate.window);
    defer render.onExit(ctx);
}
