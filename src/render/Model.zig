const std = @import("std");
const Allocator = std.mem.Allocator;
const model_loader = @import("model_loader.zig");
const Context = @import("self").Context;
const Renderable = @import("Renderable.zig");
const TextureBindings = Renderable.Material.TextureBindings;
const Binding = TextureBindings.Binding;
const engine = @import("engine");
const gl = engine.gl;
const types = engine.renderer.types.gl;
const assets = engine.assets;
const MeshData = @import("MeshData.zig");
const VertexArrayHandle = types.ContextManager.VertexArrayManager.VertexArrayHandle;

pub fn setupModel(ctx: *Context, shader: types.ResourceManager.ShaderProgramManager.ShaderProgramHandle) !void {
    const gpa = ctx.appstate.allocator;

    const render = &ctx.appstate.render;

    const result = try model_loader.load(gpa, "./src/assets/coso/monke.obj");
    defer result.deinit(gpa);

    const renderables = try render.renderables.addManyAsSlice(gpa, result.renderables.len);
    const vaos = try setupMeshes(gpa, &render.context, &render.resources, result.meshes);
    const textures = try setup2DTextures(gpa, result.textures);
    // std.debug.assert(textures.len == 2);
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
                .program = shader,
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
}

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
