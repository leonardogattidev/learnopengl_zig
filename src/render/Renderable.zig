const Renderable = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const gl = engine.gl;
const types = engine.renderer.types.gl;
const VertexArray = types.VertexArray;
const Texture = types.Texture;
const ContextManager = types.ContextManager;
const ResourceManager = types.ResourceManager;
const ShaderProgramKey = ResourceManager.ShaderProgramManager.Key;

const ViewInput = struct {
    yaw: f32,
    pitch: f32,
};

mesh: Mesh,
material: Material,
draw_params: DrawParams,
// transform: Transform,

pub fn draw(self: Renderable, gpa: Allocator, context: *ContextManager) !void {
    try self.material.bind(gpa, context);
    self.mesh.bind(context);
    self.draw_params.draw();
}

pub const Mesh = struct {
    vao: VertexArray,

    pub fn bind(self: Mesh, context: *ContextManager) void {
        context.vao.bind(self.vao);
    }
};

pub const Material = struct {
    program: ShaderProgramKey,
    textures: ?[]TextureBindings = null,

    pub const TextureBindings = struct {
        texture_unit: u16,
        textures: []Binding,

        pub const Binding = struct {
            target: ContextManager.TextureManager.TextureUnit.Target,
            texture: Texture,
        };
    };

    pub fn bind(self: Material, gpa: Allocator, context: *ContextManager) !void {
        context.program.bind(self.program);
        if (self.textures) |textures|
            for (textures) |binding_set| {
                try context.textures.setActive(gpa, binding_set.texture_unit);
                for (binding_set.textures) |binding|
                    context.textures.bind(binding.target, binding.texture);
            };
    }
};

pub const DrawParams = union(enum) {
    draw_arrays: DrawArraysParams,
    draw_elements: DrawElementsParams,

    pub fn draw(self: DrawParams) void {
        switch (self) {
            .draw_arrays => |params| {
                gl.DrawArrays(params.mode.getEnum(), @intCast(params.offset), @intCast(params.count));
            },
            .draw_elements => |params| {
                gl.DrawElements(params.mode.getEnum(), @intCast(params.count), params.type.getEnum(), @intCast(params.offset));
            },
        }
    }

    pub const DrawMode = enum {
        triangles,

        pub fn getEnum(self: DrawMode) gl.@"enum" {
            return switch (self) {
                .triangles => gl.TRIANGLES,
            };
        }
    };

    pub const DrawArraysParams = struct {
        offset: usize,
        count: usize,
        mode: DrawMode,
    };
    pub const DrawElementsParams = struct {
        offset: usize,
        count: usize,
        mode: DrawMode,
        type: Type,

        pub const Type = enum {
            unsigned_byte,
            unsigned_short,
            unsigned_int,

            pub fn getEnum(self: Type) gl.@"enum" {
                return switch (self) {
                    .unsigned_byte => gl.UNSIGNED_BYTE,
                    .unsigned_short => gl.UNSIGNED_SHORT,
                    .unsigned_int => gl.UNSIGNED_INT,
                };
            }
        };
    };
};
