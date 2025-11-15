#version 410 core

struct DirectionalLight {
  vec3 direction;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

struct PointLight {
  vec3 position;

  float constant;
  float linear;
  float quadratic;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

struct SpotLight {
  vec3 position;
  vec3 direction;
  float cutoff;
  float outer_cutoff;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;

  float constant;
  float linear;
  float quadratic;
};

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aUv;

#define NR_POINT_LIGHTS 4

out VS_OUT {
  DirectionalLight directional_light;
  PointLight point_lights[NR_POINT_LIGHTS];
  SpotLight spot_light;
} vs_out;

out vec3 vNormal;
out vec3 vFragPos;
out vec2 vUv;

uniform DirectionalLight u_directional_light;
uniform PointLight u_point_lights[NR_POINT_LIGHTS];
uniform SpotLight u_spot_light;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
  vec4 local = vec4(aPos, 1.0);
  vec4 world_pos = vec4(model * local);
  gl_Position = projection * view * world_pos;
  vFragPos = vec3(view * world_pos);
  vNormal = mat3(transpose(inverse(view * model))) * aNormal;
  vUv = vec2(aUv.x,1.0 - aUv.y);

  vs_out.directional_light = u_directional_light;
  vs_out.directional_light.direction = normalize(mat3(view) * vs_out.directional_light.direction);
  for (int i = 0; i < NR_POINT_LIGHTS; i++) {
    vs_out.point_lights[i] = u_point_lights[i];
    vs_out.point_lights[i].position = vec3(view * vec4(vs_out.point_lights[i].position, 1.0));
  }
  vs_out.spot_light = u_spot_light;
  vs_out.spot_light.position = vec3(view * vec4(vs_out.spot_light.position, 1.0));
  vs_out.spot_light.direction = normalize(mat3(view) * vs_out.spot_light.direction);
}
