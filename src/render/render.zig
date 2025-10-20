const std = @import("std");
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

pub fn setup(ctx: *Context) !void {
    const appstate = &ctx.appstate;
    const render = &appstate.render;
    const context = &appstate.render.context;
    const resources = &appstate.render.resources;
    const gpa = appstate.allocator;

    if (!sdl.SDL_SetWindowRelativeMouseMode(ctx.appstate.window, true)) return error.could_not_set_relative_mouse_mode;

    try resources.programs.store.ensureTotalCapacity(gpa, 3);
    const basic_program_key = try resources.programs.newVF(
        gpa,
        @ptrCast(@embedFile("shaders/basic.vert.glsl")),
        @ptrCast(@embedFile("shaders/basic.frag.glsl")),
    );
    const light_source_program_key = try resources.programs.newVF(
        gpa,
        @ptrCast(@embedFile("shaders/light_source.vert.glsl")),
        @ptrCast(@embedFile("shaders/light_source.frag.glsl")),
    );

    // CUBE BUFFERS
    const vbo = context.buffers.create();
    // TODO: deinit
    context.buffers.bind(.array, vbo);
    context.buffers.setData(.array, vertex_data.vertices, .static_draw);
    //

    const vbo_stride = 8 * @sizeOf(f32);
    // LIGHTING VAO
    const basic_vao = context.vao.create();
    context.vao.bind(basic_vao);
    context.vao.attributePointer(.{
        .index = 0,
        .size = 3,
        .pointer = 0,
        .stride = vbo_stride,
    });
    context.vao.enableVertexAttribArray(0);
    context.vao.attributePointer(.{
        .index = 1,
        .size = 3,
        .pointer = @sizeOf(f32) * 3,
        .stride = vbo_stride,
    });
    context.vao.enableVertexAttribArray(1);
    context.vao.attributePointer(.{
        .index = 2,
        .size = 2,
        .pointer = @sizeOf(f32) * 6,
        .stride = vbo_stride,
    });
    context.vao.enableVertexAttribArray(2);
    //

    const light_source_vao = context.vao.create();
    context.vao.bind(light_source_vao);
    context.vao.attributePointer(.{
        .index = 0,
        .size = 3,
        .pointer = 0,
        .stride = vbo_stride,
    });
    context.vao.enableVertexAttribArray(0);

    context.vao.unbind();
    context.buffers.unbind(.element_array);

    const diffuse_map_img = try assets.decodeImage(@embedFile("../assets/container2.png"));
    try context.textures.setActive(gpa, 0);
    const tex1 = resources.textures.create();
    context.textures.bind(.tex_2d, tex1);
    context.textures.setImage2D(.tex_2d, diffuse_map_img);
    context.textures.generateMipmap(.tex_2d);

    const specular_map_img = try assets.decodeImage(@embedFile("../assets/container2_specular.png"));
    const tex2 = resources.textures.create();
    context.textures.bind(.tex_2d, tex2);
    context.textures.setImage2D(.tex_2d, specular_map_img);
    context.textures.generateMipmap(.tex_2d);
    context.textures.bind(.tex_2d, .zero);

    const basic_renderable_textures = texbinds: {
        const TextureBindings = Renderable.Material.TextureBindings;
        const texture_bindings = try gpa.alloc(TextureBindings, 2);
        const bindings1 = try gpa.alloc(TextureBindings.Binding, 1);
        const bindings2 = try gpa.alloc(TextureBindings.Binding, 1);
        texture_bindings[0] = TextureBindings{
            .texture_unit = 0,
            .textures = bindings1,
        };
        bindings1[0] = TextureBindings.Binding{
            .target = .tex_2d,
            .texture = tex1,
        };
        texture_bindings[1] = TextureBindings{
            .texture_unit = 1,
            .textures = bindings2,
        };
        bindings2[0] = TextureBindings.Binding{
            .target = .tex_2d,
            .texture = tex2,
        };
        break :texbinds texture_bindings;
    };

    const basic_renderable = Renderable{
        .material = .{
            .program = basic_program_key,
            .textures = basic_renderable_textures,
        },
        .mesh = .{
            .vao = basic_vao,
        },
        .draw_params = .{
            .draw_arrays = .{
                .count = 36,
                .mode = .triangles,
                .offset = 0,
            },
        },
    };
    const light_source_renderable = Renderable{
        .material = .{
            .program = light_source_program_key,
        },
        .mesh = .{
            .vao = light_source_vao,
        },
        .draw_params = .{
            .draw_arrays = .{
                .count = 36,
                .mode = .triangles,
                .offset = 0,
            },
        },
    };

    try render.renderables.appendSlice(gpa, &.{ basic_renderable, light_source_renderable });

    gl.Enable(gl.DEPTH_TEST);

    render.projection = math.Mat4.perspective(45, 640 / 480, 0.1, 100);

    render.camera = .{
        .position = .vec3(0, 0, 3),
        .front = .vec3(0, 0, -1),
        .up = .vec3(0, 1, 0),
    };

    render.view_input.yaw = -90;
    render.view_input.pitch = 0;

    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
}

pub fn update(ctx: *Context) !void {
    const appstate = &ctx.appstate;
    gl.ClearColor(6.0 / 255.0, 21.0 / 255.0, 88.0 / 255.0, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    const elapsedSecs: f32 = @floatCast(ctx.elapsedSeconds());

    const render = &appstate.render;
    const gpa = ctx.appstate.allocator;

    processCameraInput(ctx);
    const view: Mat4 = render.camera.viewMat4();

    const lightPosition: Vec3 = .vec3(1.2, 1, 2);

    {
        const renderable = render.renderables.items[0];
        render.context.program.bind(renderable.material.program);

        try render.context.program.setVec3(gpa, "light.position", &lightPosition.data);
        try render.context.program.setVec3(gpa, "light.ambient", &.{ 0.2, 0.2, 0.2 });
        try render.context.program.setVec3(gpa, "light.diffuse", &.{ 0.5, 0.5, 0.5 });
        try render.context.program.setVec3(gpa, "light.specular", &.{ 1, 1, 1 });
        try render.context.program.setInt(gpa, "material.diffuse", 0);
        try render.context.program.setInt(gpa, "material.specular", 1);
        try render.context.program.setFloat(gpa, "material.shininess", 32);

        var model: Mat4 = .identity;
        const rotate = @mod(elapsedSecs + 355, 360);
        // std.log.info("rotate = {}", .{rotate});
        model.rotate(math.radians(rotate * 20), .vec3(0, 1, 0));
        try render.context.program.setMat4(gpa, "model", @ptrCast(&model));
        try render.context.program.setMat4(gpa, "view", @ptrCast(&view));
        try render.context.program.setMat4(gpa, "projection", @ptrCast(&render.projection));

        try renderable.draw(gpa, &render.context);
    }

    {
        const renderable = render.renderables.items[1];
        render.context.program.bind(renderable.material.program);

        var model: Mat4 = .identity;
        model.translate(lightPosition);
        model.scale(.vec3(0.2, 0.2, 0.2));
        try render.context.program.setMat4(gpa, "model", @ptrCast(&model));
        try render.context.program.setMat4(gpa, "view", @ptrCast(&view));
        try render.context.program.setMat4(gpa, "projection", @ptrCast(&render.projection));

        try renderable.draw(gpa, &render.context);
    }

    _ = sdl.SDL_GL_SwapWindow(appstate.window);
}

fn processCameraInput(ctx: *Context) void {
    const camera = &ctx.appstate.render.camera;

    // camera position
    var camera_speed: f32 = 5 * @as(f32, @floatCast(ctx.delta_time));
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
    std.log.info(
        \\yaw = {}
        \\pitch = {}
        \\relx = {}
        \\rely = {}
    , .{ view_input.yaw, view_input.pitch, mouse_x, mouse_y });
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
