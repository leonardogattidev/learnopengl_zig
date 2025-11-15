const Mesh = @This();
const std = @import("std");
const Vertex = @import("Vertex.zig");
const Allocator = std.mem.Allocator;

vertices: std.MultiArrayList(Vertex),
indices: []const c_uint,

pub fn deinit(self: *Mesh, gpa: Allocator) void {
    self.vertices.deinit(gpa);
    gpa.free(self.indices);
}
