// assimp to mesh
const std = @import("std");
const Allocator = std.mem.Allocator;
const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/postprocess.h");
    @cInclude("assimp/scene.h");
});
const engine = @import("engine");
const gl = engine.gl;
const Vertex = @import("Vertex.zig");
const MeshData = @import("MeshData.zig");
const assets = engine.assets;
const Texture2D = assets.Texture2D;

const Material = struct {
    diffuse_map: ?usize,
    specular_map: ?usize,
};
const Renderable = struct {
    mesh: usize,
    material: usize,
};
const Result = struct {
    meshes: []MeshData,
    materials: []Material,
    textures: []Texture2D,
    renderables: []Renderable,

    pub fn deinit(self: Result, gpa: Allocator) void {
        gpa.free(self.renderables);
        gpa.free(self.materials);
        for (self.meshes) |*mesh| mesh.deinit(gpa);
        gpa.free(self.meshes);
        for (self.textures) |*tex| tex.deinit(gpa);
        gpa.free(self.textures);
    }
};

pub fn load(gpa: Allocator, file_path: [:0]const u8) !Result {
    const scene: *const assimp.aiScene = scene: {
        const scene: ?*const assimp.aiScene = assimp.aiImportFile(file_path.ptr, assimp.aiProcess_Triangulate | assimp.aiProcess_FlipUVs);

        if (scene == null or scene.?.mFlags & assimp.AI_SCENE_FLAGS_INCOMPLETE != 0 or scene.?.mRootNode == null) {
            std.log.err("assimp: {s}", .{assimp.aiGetErrorString()});
            return error.assimp_load_error;
        }
        break :scene scene.?;
    };

    const mesh_count = scene.mNumMeshes;
    const scene_meshes = scene.mMeshes[0..mesh_count];
    const out_meshes = try gpa.alloc(MeshData, scene_meshes.len);

    const out_renderables = try gpa.alloc(Renderable, scene_meshes.len);

    for (0..scene_meshes.len, scene_meshes, out_meshes, out_renderables) |idx, in_mesh, *out_mesh, *out_renderable| {
        out_mesh.* = try meshDataFromAiMesh(gpa, in_mesh);
        out_renderable.* = .{
            .material = in_mesh.*.mMaterialIndex,
            .mesh = idx,
        };
    }

    const material_count = scene.mNumMaterials;
    const scene_materials = scene.mMaterials[0..material_count];
    const out_materials = try gpa.alloc(Material, material_count);
    var texture_sources = std.StringArrayHashMapUnmanaged(void).empty;
    defer texture_sources.deinit(gpa);

    for (scene_materials, out_materials) |in_mat, *out_mat| {
        out_mat.* = .{
            .diffuse_map = try processTexture(gpa, &texture_sources, in_mat, assimp.aiTextureType_DIFFUSE),
            .specular_map = try processTexture(gpa, &texture_sources, in_mat, assimp.aiTextureType_SPECULAR),
        };
    }

    const out_textures = try gpa.alloc(Texture2D, texture_sources.entries.len);

    const cwd_to_model_dir = std.fs.path.dirname(file_path) orelse "./";
    for (texture_sources.keys(), out_textures) |path, *out_texture| {
        const texture_path = try std.fs.path.resolve(gpa, &.{ cwd_to_model_dir, path });
        gpa.free(path);

        std.log.info("loading texture from: {s}", .{texture_path});
        out_texture.* = try loadTextureFromFile(gpa, texture_path);
    }

    return .{
        .meshes = out_meshes,
        .materials = out_materials,
        .renderables = out_renderables,
        .textures = out_textures,
    };
}

pub fn loadTextureFromFile(gpa: Allocator, path: []const u8) !Texture2D {
    const tex_file = try std.fs.cwd().openFile(path, .{});
    defer tex_file.close();
    const file_data = try getMmappedFile(tex_file);
    defer std.posix.munmap(@ptrCast(@alignCast(file_data)));
    return try assets.decodeImage(gpa, file_data);
}

fn processTexture(gpa: Allocator, tex_sources: *std.StringArrayHashMapUnmanaged(void), mat: *assimp.aiMaterial, kind: assimp.enum_aiTextureType) !?usize {
    const tex_count = assimp.aiGetMaterialTextureCount(mat, kind);
    if (tex_count > 0) {
        var path_buf: assimp.aiString = undefined;
        if (assimp.aiReturn_SUCCESS !=
            assimp.aiGetMaterialTexture(mat, kind, 0, &path_buf, null, null, null, null, null, null))
            return error.failed_to_get_texture;
        const path = path_buf.data[0..path_buf.length];
        const result = try tex_sources.getOrPutValue(gpa, path, {});
        if (!result.found_existing) result.key_ptr.* = try gpa.dupe(u8, path);
        return result.index;
    }
    return null;
}

fn getMmappedFile(file: std.fs.File) ![]const u8 {
    const stat = try file.stat();
    const mem = try std.posix.mmap(null, stat.size, std.posix.PROT.READ, .{ .TYPE = .SHARED }, file.handle, 0);
    return mem;
}

fn meshDataFromAiMesh(gpa: Allocator, mesh: *const assimp.aiMesh) !MeshData {
    const vertices_len = mesh.mNumVertices;
    var mesh_data_out = MeshData{
        .vertices = .empty,
        .indices = undefined,
    };
    try mesh_data_out.vertices.setCapacity(gpa, vertices_len);
    try mesh_data_out.vertices.resize(gpa, vertices_len);

    const positions_in: [][3]f32 = @ptrCast(mesh.mVertices[0..vertices_len]);
    const normals_in: [][3]f32 = @ptrCast(mesh.mNormals[0..vertices_len]);

    std.debug.assert(mesh.mTextureCoords[0] != null);
    const uvs_in: [][3]f32 = @ptrCast(mesh.mTextureCoords[0][0..vertices_len]);

    const fields = mesh_data_out.vertices.slice();
    @memcpy(fields.items(.position), positions_in);
    @memcpy(fields.items(.normal), normals_in);

    const uvs_out: [][2]f32 = fields.items(.uv);
    for (uvs_in, uvs_out) |uv_in, *uv_out| {
        @memcpy(uv_out, uv_in[0..2]);
    }

    const faces = mesh.mFaces[0..mesh.mNumFaces];
    var indices = try gpa.alloc(c_uint, faces.len * 3);
    var i: usize = 0;
    for (faces) |f| {
        const face = f.mIndices[0..f.mNumIndices];
        for (face) |index| {
            indices[i] = index;
            i += 1;
        }
    }
    mesh_data_out.indices = indices;
    return mesh_data_out;
}
