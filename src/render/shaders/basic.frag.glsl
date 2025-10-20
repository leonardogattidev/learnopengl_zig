#version 410 core

in vec3 vNormal;
in vec3 vFragPos;
in vec3 vLightPos;
in vec2 vTexCoords;

out vec4 FragColor;

uniform vec3 lightColor;

struct Material {
  sampler2D diffuse;
  sampler2D specular;
  float shininess;
};

uniform Material material;

struct Light {
  vec3 position;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

uniform Light light;

void main(){
  vec3 diffuseSample = vec3(texture(material.diffuse, vTexCoords));
  vec3 ambient = light.ambient * diffuseSample;

  vec3 norm = normalize(vNormal);
  vec3 lightDir = normalize(vLightPos - vFragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = light.diffuse * diff * diffuseSample;

  vec3 viewDir = normalize(-vFragPos);
  vec3 reflectionDir = reflect(-lightDir, norm);
  float reflectionAngle = max(dot(viewDir, reflectionDir), 0.0);
  float spec = pow(reflectionAngle, material.shininess);
  vec3 specularSample = vec3(texture(material.specular, vTexCoords));
  vec3 specular = light.specular * (spec * specularSample);

  FragColor = vec4(ambient + diffuse + specular, 1.0);
}
