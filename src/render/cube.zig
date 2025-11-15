const std = @import("std");
const Context = @import("self").Context;
const Renderable = @import("Renderable.zig");
const State = @import("State.zig");
const render_mod = @import("render.zig");
const MeshData = @import("MeshData.zig");

pub fn getRenderable(ctx: *Context) !Renderable {
    const render = &ctx.appstate.render;
    const gpa = ctx.appstate.allocator;

    const light_source_program_key = try render.resources.programs.new(gpa, .init(.{
        .vertex = &.{
            @ptrCast(@embedFile("shaders/light_source.vert.glsl")),
        },
        .fragment = &.{
            @ptrCast(@embedFile("shaders/light_source.frag.glsl")),
        },
    }));

    var mesh_data: MeshData = mesh_data: {
        var mesh_data = MeshData{ .indices = &indices, .vertices = .empty };
        try mesh_data.vertices.resize(gpa, positions.len);
        const slice = mesh_data.vertices.slice();
        @memcpy(slice.items(.position), &positions);
        @memcpy(slice.items(.normal), &normals);
        @memcpy(slice.items(.uv), &uvs);
        break :mesh_data mesh_data;
    };

    const vaos = try render_mod.setupMeshes(gpa, &render.context, &render.resources, @ptrCast(&mesh_data));
    std.debug.assert(1 == vaos.len);
    const light_source_vao = vaos[0];

    return Renderable{
        .material = .{
            .program = light_source_program_key,
        },
        .mesh = .{
            .vao = light_source_vao,
        },
        .draw_params = .{
            .draw_elements = .{
                .count = mesh_data.indices.len,
                .mode = .triangles,
                .type = .unsigned_int,
                .offset = 0,
            },
        },
    };
}

pub const positions = [_][3]f32{
    // Face 1: +X (Right)
    .{ 0.5, -0.5, -0.5 }, // 0
    .{ 0.5, 0.5, -0.5 }, // 1
    .{ 0.5, 0.5, 0.5 }, // 2
    .{ 0.5, -0.5, 0.5 }, // 3
    // Face 2: -X (Left)
    .{ -0.5, -0.5, 0.5 }, // 4
    .{ -0.5, 0.5, 0.5 }, // 5
    .{ -0.5, 0.5, -0.5 }, // 6
    .{ -0.5, -0.5, -0.5 }, // 7
    // Face 3: +Y (Top)
    .{ -0.5, 0.5, -0.5 }, // 8
    .{ -0.5, 0.5, 0.5 }, // 9
    .{ 0.5, 0.5, 0.5 }, // 10
    .{ 0.5, 0.5, -0.5 }, // 11
    // Face 4: -Y (Bottom)
    .{ -0.5, -0.5, 0.5 }, // 12
    .{ -0.5, -0.5, -0.5 }, // 13
    .{ 0.5, -0.5, -0.5 }, // 14
    .{ 0.5, -0.5, 0.5 }, // 15
    // Face 5: +Z (Front)
    .{ 0.5, -0.5, 0.5 }, // 16
    .{ 0.5, 0.5, 0.5 }, // 17
    .{ -0.5, 0.5, 0.5 }, // 18
    .{ -0.5, -0.5, 0.5 }, // 19
    // Face 6: -Z (Back)
    .{ -0.5, -0.5, -0.5 }, // 20
    .{ -0.5, 0.5, -0.5 }, // 21
    .{ 0.5, 0.5, -0.5 }, // 22
    .{ 0.5, -0.5, -0.5 }, // 23
};

pub const normals = [_][3]f32{
    // Face 1: +X (Right)
    .{ 1.0, 0.0, 0.0 },  .{ 1.0, 0.0, 0.0 },  .{ 1.0, 0.0, 0.0 },  .{ 1.0, 0.0, 0.0 },
    // Face 2: -X (Left)
    .{ -1.0, 0.0, 0.0 }, .{ -1.0, 0.0, 0.0 }, .{ -1.0, 0.0, 0.0 }, .{ -1.0, 0.0, 0.0 },
    // Face 3: +Y (Top)
    .{ 0.0, 1.0, 0.0 },  .{ 0.0, 1.0, 0.0 },  .{ 0.0, 1.0, 0.0 },  .{ 0.0, 1.0, 0.0 },
    // Face 4: -Y (Bottom)
    .{ 0.0, -1.0, 0.0 }, .{ 0.0, -1.0, 0.0 }, .{ 0.0, -1.0, 0.0 }, .{ 0.0, -1.0, 0.0 },
    // Face 5: +Z (Front)
    .{ 0.0, 0.0, 1.0 },  .{ 0.0, 0.0, 1.0 },  .{ 0.0, 0.0, 1.0 },  .{ 0.0, 0.0, 1.0 },
    // Face 6: -Z (Back)
    .{ 0.0, 0.0, -1.0 }, .{ 0.0, 0.0, -1.0 }, .{ 0.0, 0.0, -1.0 }, .{ 0.0, 0.0, -1.0 },
};

pub const uvs = [_][2]f32{
    // Face 1: +X (Right) - (0,0), (0,1), (1,1), (1,0) (assuming bottom-left is 0,0)
    .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 1.0 }, .{ 1.0, 0.0 },
    // Face 2: -X (Left)
    .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 1.0 }, .{ 1.0, 0.0 },
    // Face 3: +Y (Top)
    .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 1.0 }, .{ 1.0, 0.0 },
    // Face 4: -Y (Bottom)
    .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 1.0 }, .{ 1.0, 0.0 },
    // Face 5: +Z (Front)
    .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 1.0 }, .{ 1.0, 0.0 },
    // Face 6: -Z (Back)
    .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 1.0 }, .{ 1.0, 0.0 },
};

pub const indices = [_]c_uint{
    // Face 1: +X (Right) - Indices 0-3
    0,  1,  2,  2,  3,  0,
    // Face 2: -X (Left) - Indices 4-7
    4,  5,  6,  6,  7,  4,
    // Face 3: +Y (Top) - Indices 8-11
    8,  9,  10, 10, 11, 8,
    // Face 4: -Y (Bottom) - Indices 12-15
    12, 13, 14, 14, 15, 12,
    // Face 5: +Z (Front) - Indices 16-19
    16, 17, 18, 18, 19, 16,
    // Face 6: -Z (Back) - Indices 20-23
    20, 21, 22, 22, 23, 20,
};
