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

  float constant;
  float linear;
  float quadratic;
};

uniform Light light;

void main(){
  vec3 fragToLight = vLightPos - vFragPos;
  float fragToLightDistance = length(fragToLight);
  float attenuation = 1.0 / (
      light.constant + light.linear *
      fragToLightDistance + light.quadratic *
      (fragToLightDistance * fragToLightDistance));

  vec3 diffuseSample = texture(material.diffuse, vTexCoords).rgb;
  vec3 ambient = light.ambient * diffuseSample * attenuation;

  vec3 norm = normalize(vNormal);
  vec3 lightDir = normalize(fragToLight);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = light.diffuse * diff * diffuseSample;

  vec3 viewDir = normalize(-vFragPos);
  vec3 reflectionDir = reflect(-lightDir, norm);
  float reflectionAngle = max(dot(viewDir, reflectionDir), 0.0);
  float spec = pow(reflectionAngle, material.shininess);
  vec3 specularSample = texture(material.specular, vTexCoords).rgb;
  vec3 specular = light.specular * (spec * specularSample);

  ambient *= attenuation;
  diffuse *= attenuation;
  specular *= attenuation;

  FragColor = vec4(ambient + diffuse + specular, 1.0);
}
