#version 410 core

layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUv;

out vec3 vNormal;
out vec2 vUv;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main(){
  vec4 local = vec4(aPosition,1.0);
  gl_Position = projection * view * model * local;
  vNormal = aNormal;
  vUv = aUv;
}
