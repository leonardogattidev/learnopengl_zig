const State = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const math = engine.math;
const Mat4 = math.Mat4;
const types = engine.renderer.types.gl;
const ContextManager = types.ContextManager;
const ResourceManager = types.ResourceManager;
const Camera = @import("Camera.zig");
const Renderable = @import("Renderable.zig");

context: ContextManager,
resources: ResourceManager,
renderables: std.ArrayList(Renderable),
view: Mat4,
projection: Mat4,
camera: Camera,
view_input: ViewInput,

pub fn init(self: *State, gpa: Allocator) !void {
    self.* = .{
        .context = undefined,
        .resources = try .init(gpa),
        .renderables = .empty,
        .view = undefined,
        .projection = undefined,
        .camera = undefined,
        .view_input = undefined,
    };
    self.context = try .init(gpa, &self.resources);
}

const ViewInput = struct {
    yaw: f32,
    pitch: f32,
};
