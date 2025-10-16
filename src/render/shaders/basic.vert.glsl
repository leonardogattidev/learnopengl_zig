#version 410 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;

out vec3 vNormal;
out vec3 vFragPos;
out vec3 vLightPos;

uniform vec3 lightPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main(){
  vec4 local = vec4(aPos,1.0);
  vec4 world_pos = vec4(model * local);
  gl_Position = projection * view * world_pos;
  vFragPos = vec3(view * world_pos);
  vNormal = mat3(transpose(inverse(view * model))) * aNormal;
  vLightPos = vec3(view * vec4(lightPos,1.0));
}
