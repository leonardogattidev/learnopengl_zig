#version 410 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTexCoords;

out vec3 vNormal;
out vec3 vFragPos;
out vec3 vLightPos;
out vec2 vTexCoords;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

struct Light {
  vec3 position;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

uniform Light light;

void main(){
  vec4 local = vec4(aPos,1.0);
  vec4 world_pos = vec4(model * local);
  gl_Position = projection * view * world_pos;
  vFragPos = vec3(view * world_pos);
  vNormal = mat3(transpose(inverse(view * model))) * aNormal;
  vLightPos = vec3(view * vec4(light.position,1.0));
  vTexCoords = aTexCoords;
}
