#version 460
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_GOOGLE_include_directive : enable

#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_buffer_reference2 : require

#include "raycommon.glsl"
#include "wavefront.glsl"

hitAttributeEXT vec3 attribs;

layout(location = 0) rayPayloadInEXT hitPayload prd;
layout(location = 1) rayPayloadEXT bool isShadowed;

layout(buffer_reference, scalar) buffer Vertices { Vertex v[]; }; // Position of an object
layout(buffer_reference, scalar) buffer Indices { ivec3 i[]; };   // Triangle indices
layout(buffer_reference, scalar) buffer Materials { WaveFrontMaterial m[]; };  // Array of all materials on an object
layout(buffer_reference, scalar) buffer MatIndices { int i[]; };   // Material ID for each triangle
layout(set = 0, binding = eTlas) uniform accelerationStructureEXT topLevelAS;
layout(set = 1, binding = eObjDescs, scalar) buffer ObjDesc_ { ObjDesc i[]; } objDesc;
layout(set = 1, binding = eTextures) uniform sampler2D textureSamplers[];

layout(push_constant) uniform _PushConstantRay { PushConstantRay pcRay; };

void main()
{
  /*!  gl_InstanceCustomIndexEXT tells which object was hit */
  ObjDesc objRsrc = objDesc.i[gl_InstanceCustomIndexEXT];

  MatIndices  matIndices  = MatIndices(objRsrc.materialAddress);
  Materials   materials   = Materials(objRsrc.materialAddress);
  Indices     indices     = Indices(objRsrc.indexAddress);
  Vertices    vertices    = Vertices(objRsrc.vertexAddress);

  /*! gl_PrimitiveID allows us to find the vertices of the triangle hit by ray */
  ivec3 ind = indices.i[gl_PrimitiveID];

  /*! the 3 vertices of triangle hit by ray */
  Vertex v0 = vertices.v[ind.x];
  Vertex v1 = vertices.v[ind.y];
  Vertex v2 = vertices.v[ind.z];

  /*! Compute the barycentrics coordinates of hitted triangle */
  const vec3 barycentrics = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);

  /*! Compute the coordinates of hit position */
  const vec3 hitPos = v0.pos * barycentrics.x + 
                      v1.pos * barycentrics.y + 
                      v2.pos * barycentrics.z;
  /*! and the world-space position */
  const vec3 worldPos = vec3(gl_ObjectToWorldEXT * vec4(hitPos, 1.0));

  /*! Compute the normal at hit position */
  const vec3 nrm = v0.nrm * barycentrics.x + v1.nrm * barycentrics.y + v2.nrm * barycentrics.z;
  const vec3 worldNrm = normalize(vec3(nrm * gl_WorldToObjectEXT));   // Transform the normal to world space

  /*! Compute the light source */
  vec3 L;
  float lightIntensity = pcRay.lightIntensity;
  float lightDistance = 100000.0;
  if (pcRay.lightType == 0)   // point light source
  {
    vec3 lightSourcePos = pcRay.lightPosition - worldPos;
    lightDistance = length(lightSourcePos);
    lightIntensity = pcRay.lightIntensity / (lightDistance * lightDistance);
    
    L = normalize(lightSourcePos);
  }
  else  // Directional light
  {
    L = normalize(pcRay.lightPosition);
  }

  /*==============================================================================================*/

  // Material of the object
  int               materialIdx = matIndices.i[gl_PrimitiveID];
  WaveFrontMaterial material    = materials.m[materialIdx];

  /*! Compute the diffuse lighting */
  vec3 diffuse = computeDiffuse(material, L, worldNrm);
  if (material.textureId >= 0)
  {
    uint textureId = material.textureId + objDesc.i[gl_InstanceCustomIndexEXT].txtOffset;
    vec2 textureCoord = v0.texCoord * barycentrics.x + 
                        v1.texCoord * barycentrics.y +
                        v2.texCoord * barycentrics.z;
    diffuse *= texture(textureSamplers[nonuniformEXT(textureId)], textureCoord).xyz;
  }
  // vec3 specular = computeSpecular(material, gl_WorldRayDirectionEXT, L, worldNrm);

  vec3 specular = vec3(0);
  float attenuation = 1;

  /*!
   *  \note   Tracing shadow ray, only if the light is visible from the surface.
   */
  if (dot(worldNrm, L) > 0)
  {
    float tMin = 0.001;
    float tMax = lightDistance;
    vec3 origin = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
    vec3 rayDirection = L;
    uint flags = gl_RayFlagsTerminateOnFirstHitEXT | 
                 gl_RayFlagsOpaqueEXT | 
                 gl_RayFlagsSkipClosestHitShaderEXT;
    isShadowed = true;

    traceRayEXT(topLevelAS,   // top-level acceleration
                flags,        // ray flags
                0xFF,         // cull mask
                0,            // SBT record's offset
                0,            // SBT record's stride
                1,            // the index of miss shader group array
                origin,       // ray origin
                tMin,         // ray min range
                rayDirection, // ray direction
                tMax,         // ray max range
                1);           // payload (location = 1)
  }
  
  if (isShadowed)
  {
    attenuation = 0.3;
  }
  else
  {
    specular = computeSpecular(material, gl_WorldRayDirectionEXT, L, worldNrm);
  }

  prd.hitValue = vec3(lightIntensity * attenuation * (diffuse + specular));
}
