#version 410 core

in vec3 vNormal;
in vec2 vUv;

out vec4 FragColor;

uniform sampler2D diffuse_map;
uniform sampler2D specular_map;

struct Material {
  sampler2D diffuse;
  // sampler2D specular;
};

uniform Material material;

void main(){
  FragColor = texture(diffuse_map, vUv);
}
