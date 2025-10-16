pub const Vertex = struct {
    position: [3]f32,
    // color: [3]f32,
    uv: [2]f32,
};

pub const vertices: []const Vertex = &[4]Vertex{
    .{
        .position = .{ -0.5, 0.5, 0 },
        // .color = .{ 1, 0, 0 },
        .uv = .{ 0, 1 },
    }, // top left
    .{
        .position = .{ 0.5, 0.5, 0 },
        // .color = .{ 0, 1, 0 },
        .uv = .{ 1, 1 },
    }, // top right
    .{
        .position = .{ 0.5, -0.5, 0 },
        // .color = .{ 0, 0, 1 },
        .uv = .{ 1, 0 },
    }, // bottom right
    .{
        .position = .{ -0.5, -0.5, 0 },
        // .color = .{ 0, 0, 0 },
        .uv = .{ 0, 0 },
    }, // bottom left
};

pub const indices: []const u32 = &.{
    0, 1, 2,
    2, 3, 0,
};
