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
frame_calc: FrameCalculator,

pub fn init(self: *State, gpa: Allocator) !void {
    self.* = .{
        .context = undefined,
        .resources = try .init(gpa),
        .renderables = .empty,
        .view = undefined,
        .projection = undefined,
        .camera = undefined,
        .view_input = undefined,
        .frame_calc = .empty,
    };
    self.context = try .init(gpa, &self.resources);
}

const ViewInput = struct {
    yaw: f32,
    pitch: f32,
};

pub const FrameCalculator = struct {
    prev_time: u64,
    frames_since: u64,

    pub const empty = FrameCalculator{
        .frames_since = 0,
        .prev_time = 0,
    };

    pub fn reset(self: *FrameCalculator, current_time: u64) void {
        self.* = .{
            .prev_time = current_time,
            .frames_since = 0,
        };
    }

    pub fn update(self: *FrameCalculator) void {
        self.frames_since += 1;
    }

    pub fn getFPS(self: *FrameCalculator, current_time: u64) f32 {
        const diff: f128 = @floatFromInt(current_time - self.prev_time);
        const duration_s = diff / std.time.ns_per_s;
        const fps = calculateFPS(duration_s, self.frames_since);
        return fps;
    }

    pub fn calculateFPS(duration_s: f128, frame_count: u64) f32 {
        return @floatCast((1 / duration_s) * @as(f128, @floatFromInt(frame_count)));
    }

    pub fn durationTo(self: *FrameCalculator, current_time: u64, T: type) T {
        const diff: T = @floatFromInt(current_time - self.prev_time);
        return diff / std.time.ns_per_s;
    }

    pub fn framesSince(self: *FrameCalculator, T: type) T {
        return @floatFromInt(self.frames_since);
    }
};
