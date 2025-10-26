#version 410 core

in vec3 vNormal;
in vec3 vFragPos;
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
  float cutoff;
  float outer_cutoff;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;

  float constant;
  float linear;
  float quadratic;
};

uniform Light light;

void main() {
  vec3 diffuse_sample = texture(material.diffuse, vTexCoords).rgb;
  vec3 ambient = light.ambient * diffuse_sample;

  vec3 frag_to_light = -vFragPos;
  vec3 frag_to_light_dir = normalize(frag_to_light);

  vec3 norm = normalize(vNormal);
  float diff = max(dot(norm, frag_to_light_dir), 0.0);
  vec3 diffuse = light.diffuse * diff * diffuse_sample;

  vec3 reflection_dir = reflect(-frag_to_light_dir, norm);
  float reflection_angle = max(dot(frag_to_light_dir, reflection_dir), 0.0);
  float spec = pow(reflection_angle, material.shininess);
  vec3 specular_sample = texture(material.specular, vTexCoords).rgb;
  vec3 specular = light.specular * (spec * specular_sample);

  vec3 spotlight_orientation = vec3(0.0, 0.0, -1.0); // normalized
  float theta = dot(frag_to_light_dir, -spotlight_orientation);
  float epsilon = light.cutoff - light.outer_cutoff;
  float intensity = clamp((theta - light.outer_cutoff) / epsilon, 0.0, 1.0);
  diffuse *= intensity;
  specular *= intensity;

  float frag_to_light_dist = length(frag_to_light);
  float attenuation = 1.0 / (
      light.constant + light.linear *
          frag_to_light_dist + light.quadratic *
          (frag_to_light_dist * frag_to_light_dist));
  ambient *= attenuation;
  diffuse *= attenuation;
  specular *= attenuation;

  FragColor = vec4(ambient + diffuse + specular, 1.0);
}
