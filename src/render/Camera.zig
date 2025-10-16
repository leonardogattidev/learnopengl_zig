const Camera = @This();
const engine = @import("engine");
const math = engine.math;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;

position: Vec3,
front: Vec3,
up: Vec3,

pub fn viewMat4(self: Camera) Mat4 {
    return .lookAt(self.position, self.position.added(self.front), self.up);
}
