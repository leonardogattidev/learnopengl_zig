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

pub fn setupMeshes(gpa: Allocator, context: *types.ContextManager, resources: *types.ResourceManager, meshes: []MeshData) ![]const VertexArrayHandle {
    const vaos = try context.vaos.addMany(gpa, meshes.len);
    for (meshes, vaos) |mesh, vao| {
        context.vaos.bind(vao);

        const buffer_count = 4;
        const buffers = try resources.buffers.addMany(gpa, buffer_count);

        const ebo = buffers[0];
        context.buffers.bind(.element_array, ebo);
        context.buffers.setData(.element_array, std.mem.sliceAsBytes(mesh.indices), .static_draw);

        gl.EnableVertexAttribArray(0);

        const vbo_positions = buffers[1];
        context.buffers.bind(.array, vbo_positions);
        context.buffers.setData(
            .array,
            std.mem.sliceAsBytes(mesh.vertices.items(.position)),
            .static_draw,
        );
        context.vaos.attributePointer(.{ .index = 0, .size = 3 });
        context.vaos.enableVertexAttribArray(0);

        const vbo_normals = buffers[2];
        context.buffers.bind(.array, vbo_normals);
        context.buffers.setData(
            .array,
            std.mem.sliceAsBytes(mesh.vertices.items(.normal)),
            .static_draw,
        );
        context.vaos.attributePointer(.{ .index = 1, .size = 3 });
        context.vaos.enableVertexAttribArray(1);

        const vbo_uvs = buffers[3];
        context.buffers.bind(.array, vbo_uvs);
        context.buffers.setData(
            .array,
            std.mem.sliceAsBytes(mesh.vertices.items(.uv)),
            .static_draw,
        );
        context.vaos.attributePointer(.{ .index = 2, .size = 2 });
        context.vaos.enableVertexAttribArray(2);
    }
    return vaos;
}

fn setup2DTextures(gpa: Allocator, texture_buffers: []const assets.Texture2D) ![]types.ResourceManager.TextureManager.TextureHandle {
    const texture_ids = try gpa.alloc(c_uint, texture_buffers.len);
    gl.GenTextures(@intCast(texture_buffers.len), texture_ids.ptr);
    gl.ActiveTexture(gl.TEXTURE0);

    for (texture_ids, texture_buffers) |tex_id, texture_buffer| {
        gl.BindTexture(gl.TEXTURE_2D, tex_id);

        const element_n = @divFloor(@as(c_int, @intCast(texture_buffer.data.len)), texture_buffer.channel);
        const height: c_int = @divFloor(element_n, texture_buffer.width);
        std.log.info("w = {}, h = {}", .{ texture_buffer.width, height });
        std.debug.assert(height == texture_buffer.width);
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            texture_buffer.width,
            height,
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            texture_buffer.data.ptr,
        );
        gl.GenerateMipmap(gl.TEXTURE_2D);
    }
    return @ptrCast(texture_ids);
}

pub fn setup(ctx: *Context) !void {
    const appstate = &ctx.appstate;
    const render = &appstate.render;
    // const context = &appstate.render.context;
    const resources = &appstate.render.resources;
    const gpa = appstate.allocator;
    if (!sdl.SDL_SetWindowRelativeMouseMode(ctx.appstate.window, true)) return error.could_not_set_relative_mouse_mode;

    try resources.programs.store.ensureTotalCapacity(gpa, 3);
    const phong_shader = try resources.programs.new(gpa, .init(.{
        .vertex = &.{@ptrCast(@embedFile("shaders/basic.vert.glsl"))},
        .fragment = &.{@ptrCast(@embedFile("shaders/basic.frag.glsl"))},
    }));

    const result = try model_loader.load(gpa, "./src/assets/backpack/backpack.obj");
    defer result.deinit(gpa);

    const renderables = try render.renderables.addManyAsSlice(gpa, result.renderables.len);
    const vaos = try setupMeshes(gpa, &render.context, &render.resources, result.meshes);
    const textures = try setup2DTextures(gpa, result.textures);
    std.debug.assert(textures.len == 2);
    for (renderables, result.meshes, vaos, result.renderables) |*renderable, mesh, vao, render_item| {
        const material = result.materials[render_item.material];

        std.debug.assert(render_item.material == 1);

        const diffuse_map = if (material.diffuse_map) |idx| textures[idx] else null;
        const specular_map = if (material.specular_map) |idx| textures[idx] else null;
        var texture_count: usize = 0;
        if (null != diffuse_map) texture_count += 1;
        if (null != specular_map) texture_count += 1;

        const tex_bindings = if (texture_count < 1) null else tex_bindings: {
            const tex_bindings = try gpa.alloc(TextureBindings, texture_count);
            const bindings = try gpa.alloc(Binding, texture_count);

            if (diffuse_map) |diff_map| {
                bindings[0] = .{
                    .target = .tex_2d,
                    .texture = diff_map,
                };
                tex_bindings[0] = .{
                    .texture_unit = @enumFromInt(0),
                    .textures = bindings[0..1],
                };
            }

            if (specular_map) |_specular_map| {
                const idx: usize = if (null != diffuse_map) 1 else 0;
                bindings[idx] = .{
                    .target = .tex_2d,
                    .texture = _specular_map,
                };
                tex_bindings[idx] = .{
                    .texture_unit = @enumFromInt(1),
                    .textures = bindings[idx .. idx + 1],
                };
            }
            break :tex_bindings tex_bindings;
        };

        renderable.* = .{
            .material = .{
                .program = phong_shader,
                .textures = tex_bindings,
            },
            .mesh = .{
                .vao = vao,
            },
            .draw_params = .{
                .draw_elements = .{
                    .count = mesh.indices.len,
                    .mode = .triangles,
                    .type = .unsigned_int,
                    .offset = 0,
                },
            },
        };
    }

    const cube_renderable = try render.renderables.addOne(gpa);

    cube_renderable.* = try cube.getRenderable(ctx);

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
    // gl.Enable(gl.MULTISAMPLE);

    // var fbo: c_uint = undefined;
    // gl.GenFramebuffers(1, &fbo);
    // gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    //
    // var rbo: c_uint = undefined;
    // gl.GenRenderbuffers(1, &rbo);
}

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

    gl.ClearColor(6.0 / 255.0, 21.0 / 255.0, 88.0 / 255.0, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    const render = &appstate.render;

    processCameraInput(ctx);
    render.view = render.camera.viewMat4();

    // render all meshes

    const renderables = render.renderables.items;
    try setupLights(ctx);
    try renderBasic(ctx, renderables[0 .. renderables.len - 1]);
    // try renderLightSources(ctx, renderables[renderables.len - 1]);

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

pub fn onEvent(ctx: *Context, event: *sdl.SDL_Event) void {
    _ = ctx;
    switch (event.type) {
        sdl.SDL_EVENT_WINDOW_RESIZED => gl.Viewport(0, 0, event.window.data1, event.window.data2),
        else => {},
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
