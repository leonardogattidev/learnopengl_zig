#version 410 core

in vec3 vNormal;
in vec3 vFragPos;
in vec3 vLightPos;

out vec4 FragColor;

uniform vec3 objectColor;
uniform vec3 lightColor;

void main(){
  float ambientStrength = 0.1;
  vec3 ambient = ambientStrength * lightColor;

  vec3 norm = normalize(vNormal);
  vec3 lightDir = normalize(vLightPos - vFragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = diff * lightColor;

  float specularStrenght = 0.5;
  vec3 viewDir = normalize(-vFragPos);
  vec3 reflectionDir = reflect(-lightDir, norm);
  float shininess = 32;
  float reflectionAngle = max(dot(viewDir, reflectionDir), 0.0);
  float spec = pow(reflectionAngle, shininess);
  vec3 specular = specularStrenght * spec * lightColor;

  vec3 result = (ambient + diffuse + specular) * objectColor;

  FragColor = vec4(result, 1.0);
}
