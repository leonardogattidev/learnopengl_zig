#version 410 core

struct DirectionalLight {
  vec3 direction;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

// struct PointLight {
//   vec3 position;
//
//   float constant;
//   float linear;
//   float quadratic;
//
//   vec3 ambient;
//   vec3 diffuse;
//   vec3 specular;
// };

// #define NR_POINT_LIGHTS 4
// uniform PointLight u_point_lights[NR_POINT_LIGHTS];

in vec3 vNormal;
in vec3 vFragPos;
in vec2 vTexCoords;
in VS_OUT {
  DirectionalLight directional_light;
  // PointLight point_lights[NR_POINT_LIGHTS];
} fs_in;

out vec4 FragColor;

struct Material {
  sampler2D diffuse;
  sampler2D specular;
  float shininess;
};

uniform Material material;

vec3 calculate_directional_light(DirectionalLight light, vec3 normal, vec3 to_view_dir) {
  vec3 from_light_dir = normalize(light.direction);
  vec3 to_light_dir = -from_light_dir;

  float diffuse_factor = max(dot(normal, to_light_dir), 0.0);

  vec3 to_reflection_dir = reflect(from_light_dir, normal);
  float reflection_angle = max(dot(to_view_dir, to_reflection_dir), 0.0);
  float specular_factor = pow(reflection_angle, material.shininess);

  vec3 diffuse_sample = texture(material.diffuse, vTexCoords).rgb;
  vec3 specular_sample = texture(material.specular, vTexCoords).rgb;

  vec3 ambient = light.ambient * diffuse_sample;
  vec3 diffuse = light.diffuse * diffuse_factor * diffuse_sample;
  vec3 specular = light.specular * specular_factor * specular_sample;
  return (ambient + diffuse + specular);
}

// vec3 calculate_point_light(PointLight light, vec3 normal, vec3 frag_pos, vec3 to_view_dir) {
//   vec3 from_light = frag_pos - light.position;
//   vec3 to_light = -from_light;
//   vec3 from_light_dir = normalize(from_light);
//   vec3 to_light_dir = -from_light_dir;
//
//   float diffuse_factor = max(dot(normal, to_light_dir), 0.0);
//
//   vec3 to_reflection_dir = reflect(from_light_dir, normal);
//   float reflection_angle = max(dot(to_view_dir, to_reflection_dir), 0.0);
//   float specular_factor = pow(reflection_angle, material.shininess);
//
//   float to_light_dist = length(to_light);
//   float attenuation = 1.0 / (
//       light.constant + light.linear *
//           to_light_dist + light.quadratic *
//           (to_light_dist * to_light_dist));
//
//   vec3 diffuse_sample = texture(material.diffuse, vTexCoords).rgb;
//   vec3 specular_sample = texture(material.specular, vTexCoords).rgb;
//
//   vec3 ambient = light.ambient * diffuse_sample;
//   vec3 diffuse = light.diffuse * diffuse_factor * diffuse_sample;
//   vec3 specular = light.specular * specular_factor * specular_sample;
//   ambient *= attenuation;
//   diffuse *= attenuation;
//   specular *= attenuation;
//
//   return (ambient + diffuse + specular);
// }

// struct Light {
//   float cutoff;
//   float outer_cutoff;
//
//   vec3 ambient;
//   vec3 diffuse;
//   vec3 specular;
//
//   float constant;
//   float linear;
//   float quadratic;
// };
//
// uniform Light light;

void main() {
  vec3 normal = normalize(vNormal);
  vec3 to_view_dir = normalize(-vFragPos);

  vec3 color = calculate_directional_light(fs_in.directional_light, normal, to_view_dir);

  // for (int i = 0; i < NR_POINT_LIGHTS; i++)
  //   color += calculate_point_light(u_point_lights[i], normal, vFragPos, to_view_dir);
  FragColor = vec4(color, 1.0);
}

// void coso() {
//   vec3 diffuse_sample = texture(material.diffuse, vTexCoords).rgb;
//   vec3 ambient = light.ambient * diffuse_sample;
//
//   vec3 frag_to_light = -vFragPos;
//   vec3 frag_to_light_dir = normalize(frag_to_light);
//
//   vec3 norm = normalize(vNormal);
//   float diff = max(dot(norm, frag_to_light_dir), 0.0);
//   vec3 diffuse = light.diffuse * diff * diffuse_sample;
//
//   vec3 reflection_dir = reflect(-frag_to_light_dir, norm);
//   float reflection_angle = max(dot(to_view_dir, reflection_dir), 0.0);
//   float spec = pow(reflection_angle, material.shininess);
//   vec3 specular_sample = texture(material.specular, vTexCoords).rgb;
//   vec3 specular = light.specular * (spec * specular_sample);
//
//   vec3 spotlight_orientation = vec3(0.0, 0.0, -1.0); // normalized
//   float theta = dot(frag_to_light_dir, -spotlight_orientation);
//   float epsilon = light.cutoff - light.outer_cutoff;
//   float intensity = clamp((theta - light.outer_cutoff) / epsilon, 0.0, 1.0);
//   diffuse *= intensity;
//   specular *= intensity;
//
//   float frag_to_light_dist = length(frag_to_light);
//   float attenuation = 1.0 / (
//       light.constant + light.linear *
//           frag_to_light_dist + light.quadratic *
//           (frag_to_light_dist * frag_to_light_dist));
//   ambient *= attenuation;
//   diffuse *= attenuation;
//   specular *= attenuation;
//
//   FragColor = vec4(ambient + diffuse + specular, 1.0);
// }
