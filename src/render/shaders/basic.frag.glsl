#version 410 core

in vec3 vNormal;
in vec3 vFragPos;
in vec3 vLightPos;

out vec4 FragColor;

uniform vec3 lightColor;

struct Material {
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
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
  vec3 ambient = light.ambient * material.ambient;

  vec3 norm = normalize(vNormal);
  vec3 lightDir = normalize(vLightPos - vFragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = light.diffuse * (diff * material.diffuse);

  vec3 viewDir = normalize(-vFragPos);
  vec3 reflectionDir = reflect(-lightDir, norm);
  float reflectionAngle = max(dot(viewDir, reflectionDir), 0.0);
  float spec = pow(reflectionAngle, material.shininess);
  vec3 specular = light.specular * (spec * material.specular);

  vec3 result = ambient + diffuse + specular;

  FragColor = vec4(result, 1.0);
}
