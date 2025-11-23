const std = @import("std");
const Allocator = std.mem.Allocator;
pub const State = @import("State.zig");
const engine = @import("engine");
const gl = engine.gl;
const sdl = engine.sdl;
const assets = engine.assets;
const math = engine.math;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Context = @import("self").Context;
const types = engine.renderer.types.gl;
const ShaderProgram = types.ShaderProgram;
const vertex_data = @import("cube_data.zig");
const Renderable = @import("Renderable.zig");
const model_loader = @import("model_loader.zig");
const MeshData = @import("MeshData.zig");
const TextureBindings = Renderable.Material.TextureBindings;
const Binding = TextureBindings.Binding;
const cube = @import("cube.zig");
const VertexArrayHandle = types.ContextManager.VertexArrayManager.VertexArrayHandle;
const Model = @import("model.zig");

pub fn setup(ctx: *Context) !void {
    const appstate = &ctx.appstate;
    const render = &appstate.render;
    // const context = &appstate.render.context;
    const resources = &appstate.render.resources;
    const gpa = appstate.allocator;
    if (!sdl.SDL_SetWindowRelativeMouseMode(ctx.appstate.window, true)) return error.could_not_set_relative_mouse_mode;
    stb_image.stbi_set_flip_vertically_on_load(1);

    try resources.programs.store.ensureTotalCapacity(gpa, 3);
    const phong_shader = try resources.programs.new(gpa, .init(.{
        .vertex = &.{@ptrCast(@embedFile("shaders/basic.vert.glsl"))},
        .fragment = &.{@ptrCast(@embedFile("shaders/basic.frag.glsl"))},
    }));

    try Model.setupModel(ctx, phong_shader);

    render.projection = math.Mat4.perspective(45, 640 / 480, 0.1, 100);

    render.camera = .{
        .position = .vec3(0, 0, 3),
        .front = .vec3(0, 0, -1),
        .up = .vec3(0, 1, 0),
    };

    render.view_input.yaw = -90;
    render.view_input.pitch = 0;

    render.frame_calc.reset(ctx.elapsed);

    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);

    // gl.Enable(gl.CULL_FACE);
    // gl.CullFace(gl.FRONT);
    // gl.FrontFace(gl.CCW);

    gl.Enable(gl.DEPTH_TEST);
    gl.Enable(gl.MULTISAMPLE);

    fbo = undefined;
    gl.GenFramebuffers(1, @ptrCast(&fbo));
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    try setRBOs(ctx);
}

var fbo: c_uint = undefined;
var rbo_color: c_uint = undefined;
var rbo_depth_stencil: c_uint = undefined;

const point_light_positions: []const Vec3 = &.{
    .vec3(0.7, 0.2, 2.0),
    .vec3(2.3, -3.3, -4.0),
    .vec3(-4.0, 2.0, -12.0),
    .vec3(0.0, 0.0, -3.0),
};

pub fn update(ctx: *Context) !void {
    const appstate = &ctx.appstate;

    {
        const frame_calc = &ctx.appstate.render.frame_calc;
        frame_calc.update();
        if (ctx.elapsed - frame_calc.prev_time > 0.05 * std.time.ns_per_s) {
            const duration_s = frame_calc.durationTo(ctx.elapsed, f128);
            const frames_since = frame_calc.framesSince(f128);
            const fps = (1 / duration_s) * frames_since;
            const ms = (duration_s / frames_since) * 1000;
            frame_calc.reset(ctx.elapsed);
            var buf = std.mem.zeroes([512:0]u8);
            const title: [:0]u8 = @ptrCast(try std.fmt.bufPrint(&buf, "{d:0<7.2} FPS | {d:0<6.3} ms", .{ fps, ms }));
            // std.log.info("title={s}", .{title});
            _ = sdl.SDL_SetWindowTitle(ctx.appstate.window, @ptrCast(title));
        }
    }

    const width = appstate.window_size.width;
    const height = appstate.window_size.height;
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    // gl.Viewport(0, 0, width, height);
    gl.ClearColor(6.0 / 255.0, 21.0 / 255.0, 88.0 / 255.0, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    const render = &appstate.render;

    processCameraInput(ctx);
    render.view = render.camera.viewMat4();

    // render all meshes

    const renderables = render.renderables.items;
    try setupLights(ctx);
    try renderBasic(ctx, renderables);
    // try renderLightSources(ctx, renderables[renderables.len - 1]);

    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, fbo);
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
    gl.BlitFramebuffer( //
        0, 0, width, height, //
        0, 0, width, height, //
        gl.COLOR_BUFFER_BIT, gl.NEAREST);
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
    _ = sdl.SDL_GL_SwapWindow(appstate.window);
}

fn setupLights(ctx: *Context) !void {
    const appstate = &ctx.appstate;
    const gpa = appstate.allocator;
    const render = &appstate.render;
    const renderables = render.renderables.items;
    try renderables[0].material.bind(gpa, &render.context);
    try render.context.program.setMat4(gpa, "view", @ptrCast(&render.view));
    try render.context.program.setMat4(gpa, "projection", @ptrCast(&render.projection));

    try render.context.program.setInt(gpa, "material.diffuse", 0);
    try render.context.program.setInt(gpa, "material.specular", 1);
    try render.context.program.setFloat(gpa, "material.shininess", 100.0);

    // directional light
    const u_dir_light_prefix = "u_directional_light.";
    try render.context.program.setVec3(gpa, u_dir_light_prefix ++ "direction", .{ -0.2, -1.0, -0.3 });
    try render.context.program.setVec3(gpa, u_dir_light_prefix ++ "ambient", .{ 0.05, 0.05, 0.05 });
    try render.context.program.setVec3(gpa, u_dir_light_prefix ++ "diffuse", .{ 0.4, 0.4, 0.4 });
    try render.context.program.setVec3(gpa, u_dir_light_prefix ++ "specular", .{ 0.5, 0.5, 0.5 });

    // point lights
    inline for (0..point_light_positions.len, point_light_positions) |idx, pos| {
        const prefix = std.fmt.comptimePrint("u_point_lights[{}].", .{idx});
        try render.context.program.setVec3(gpa, prefix ++ "position", pos.data);
        try render.context.program.setVec3(gpa, prefix ++ "ambient", .{ 0.05, 0.05, 0.05 });
        try render.context.program.setVec3(gpa, prefix ++ "diffuse", .{ 0.8, 0.8, 0.8 });
        try render.context.program.setVec3(gpa, prefix ++ "specular", .{ 1.0, 1.0, 1.0 });
        try render.context.program.setFloat(gpa, prefix ++ "constant", 1.0);
        try render.context.program.setFloat(gpa, prefix ++ "linear", 0.09);
        try render.context.program.setFloat(gpa, prefix ++ "quadratic", 0.032);
    }

    // spot light
    const u_spot_light = "u_spot_light.";
    try render.context.program.setVec3(gpa, u_spot_light ++ "position", render.camera.position.data);
    try render.context.program.setVec3(gpa, u_spot_light ++ "direction", render.camera.front.data);
    try render.context.program.setVec3(gpa, u_spot_light ++ "ambient", .{ 0, 0, 0 });
    try render.context.program.setVec3(gpa, u_spot_light ++ "diffuse", .{ 1, 1, 1 });
    try render.context.program.setVec3(gpa, u_spot_light ++ "specular", .{ 1, 1, 1 });
    try render.context.program.setFloat(gpa, u_spot_light ++ "constant", 1.0);
    try render.context.program.setFloat(gpa, u_spot_light ++ "linear", 0.09);
    try render.context.program.setFloat(gpa, u_spot_light ++ "quadratic", 0.032);
    try render.context.program.setFloat(gpa, u_spot_light ++ "cutoff", @cos(math.radians(12.5)));
    try render.context.program.setFloat(gpa, u_spot_light ++ "outer_cutoff", @cos(math.radians(13.5)));
}

fn renderBasic(ctx: *Context, renderables: []const Renderable) !void {
    const appstate = &ctx.appstate;
    const gpa = appstate.allocator;
    const render = &appstate.render;

    try renderables[0].material.bind(gpa, &render.context);

    var model: Mat4 = .identity;
    // model.scale(.vec3(10, 10, 10));
    try render.context.program.setMat4(gpa, "model", @ptrCast(&model));

    for (renderables) |renderable| {
        // _ = renderable;
        try renderable.draw(gpa, &render.context);
        // std.debug.assert(0 == render.context.program.getBound().getUniformInteger("material.diffuse"));
        // std.debug.assert(1 == render.context.program.getBound().getUniformInteger("material.specular"));
    }
}

fn renderLightSources(ctx: *Context, renderable: Renderable) !void {
    const appstate = &ctx.appstate;
    const render = &appstate.render;
    const gpa = appstate.allocator;

    try renderable.material.bind(gpa, &render.context);

    try render.context.program.setMat4(gpa, "view", @ptrCast(&render.view));
    try render.context.program.setMat4(gpa, "projection", @ptrCast(&render.projection));

    for (point_light_positions) |pos| {
        var model: Mat4 = .identity;
        model.translate(pos);
        try render.context.program.setMat4(gpa, "model", @ptrCast(&model.data));

        try renderable.draw(gpa, &render.context);
    }
}

fn processCameraInput(ctx: *Context) void {
    const camera = &ctx.appstate.render.camera;

    // camera position
    var camera_speed: f32 = 5 * ctx.deltaTimeS(f32);
    if (ctx.key_state[sdl.SDL_SCANCODE_LSHIFT])
        camera_speed *= 2;
    if (ctx.key_state[sdl.SDL_SCANCODE_W])
        camera.position.add(camera.front.scaled(camera_speed));
    if (ctx.key_state[sdl.SDL_SCANCODE_S])
        camera.position.sub(camera.front.scaled(camera_speed));
    if (ctx.key_state[sdl.SDL_SCANCODE_A])
        camera.position.add(camera.up.cross(camera.front).normalized().scaled(camera_speed));
    if (ctx.key_state[sdl.SDL_SCANCODE_D])
        camera.position.add(camera.front.cross(camera.up).normalized().scaled(camera_speed));
    if (ctx.key_state[sdl.SDL_SCANCODE_SPACE])
        camera.position.add(camera.up.normalized().scaled(camera_speed));
    if (ctx.key_state[sdl.SDL_SCANCODE_LCTRL])
        camera.position.sub(camera.up.normalized().scaled(camera_speed));

    // camera orientation
    var mouse_x: f32 = undefined;
    var mouse_y: f32 = undefined;
    _ = sdl.SDL_GetRelativeMouseState(&mouse_x, &mouse_y);
    if (mouse_x == 0 and mouse_y == 0) return;
    const camera_sensitivity = 0.1;
    const view_input = &ctx.appstate.render.view_input;
    view_input.yaw += mouse_x * camera_sensitivity;
    view_input.pitch = @max(@min(view_input.pitch - mouse_y * camera_sensitivity, 89), -89);
    const direction: Vec3 = .vec3(
        @cos(math.radians(view_input.yaw)) * @cos(math.radians(view_input.pitch)),
        @sin(math.radians(view_input.pitch)),
        @sin(math.radians(view_input.yaw)) * @cos(math.radians(view_input.pitch)),
    );

    camera.front = direction.normalized();
}

pub fn onEvent(ctx: *Context, event: *sdl.SDL_Event) !void {
    switch (event.type) {
        sdl.SDL_EVENT_WINDOW_RESIZED => {
            const rbos: [2]c_uint = .{ rbo_color, rbo_depth_stencil };
            gl.DeleteRenderbuffers(2, &rbos);
            try setRBOs(ctx);
            gl.Viewport(0, 0, event.window.data1, event.window.data2);
        },
        else => {},
    }
}

fn setRBOs(ctx: *Context) !void {
    const width = ctx.appstate.window_size.width;
    const height = ctx.appstate.window_size.height;

    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    var rbo_handles: [2]c_uint = undefined;
    gl.GenRenderbuffers(2, &rbo_handles);

    rbo_color = rbo_handles[0];
    gl.BindRenderbuffer(gl.RENDERBUFFER, rbo_color);
    const sample_count = 4;
    gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, sample_count, gl.RGBA8, width, height);
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, rbo_color);

    rbo_depth_stencil = rbo_handles[1];
    gl.BindRenderbuffer(gl.RENDERBUFFER, rbo_depth_stencil);
    gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, sample_count, gl.DEPTH24_STENCIL8, width, height);
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo_depth_stencil);

    const fbo_status = gl.CheckFramebufferStatus(gl.FRAMEBUFFER);
    if (fbo_status != gl.FRAMEBUFFER_COMPLETE) {
        std.log.info("Framebuffer error, status: {} ", .{fbo_status});
        return error.framebuffer_error;
    }
}

pub fn onExit(ctx: *Context) void {
    _ = ctx;
    // const gpa = ctx.appstate.allocator;
    // ctx.appstate.render.resources.programs.deinit(gpa);
}

fn getIntegerV(pname: gl.@"enum") gl.int {
    var value: gl.int = -1000;
    gl.GetIntegerv(pname, @ptrCast(&value));
    return value;
}

fn getUniformInteger(program: ShaderProgram, loc: gl.int) gl.int {
    var current_value: gl.int = -1000;
    gl.GetUniformiv(program.handle, loc, @ptrCast(&current_value));
    return current_value;
}
