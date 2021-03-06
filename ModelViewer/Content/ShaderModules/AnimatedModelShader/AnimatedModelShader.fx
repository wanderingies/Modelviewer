﻿/*
Copyright(c) 2017 by kosmonautgames

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Uniform color for skinned meshes
// Draws a mesh with one color only

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Variables
#include "helper.fx"

#define SKINNED_EFFECT_MAX_BONES   72

float3 CameraPosition;

float4x4 ViewProj;
float4x4 View;
float4x4 World;
float3x3 WorldIT;

float FarClip = 500;

float4x3 Bones[SKINNED_EFFECT_MAX_BONES];

float Metallic = 0.3f;
bool UseMetallicMap = false;
float Roughness = 0.3f;
bool UseRoughnessMap = false;

float4 AlbedoColor = float4(1, 1, 1, 1);
bool UseAlbedoMap = false;

bool UseNormalMap = false;
bool UseLinear = true;
bool UseAo = false;
bool UsePOM = false;
bool UseBumpmap = false;
float POMScale = 0.05f;
float POMQuality = 1;
bool POMCutoff = true;


float CubeSize = 512;

Texture2D<float4> NormalMap;
Texture2D<float4> AlbedoMap;
Texture2D<float4> MetallicMap;
Texture2D<float4> RoughnessMap;
Texture2D<float4> AoMap;
Texture2D<float4> HeightMap;

Texture2D<float4> FresnelMap;
TextureCube<float4> EnvironmentMap;

SamplerState TextureSampler
{
	Texture = <AlbedoMap>;
	/*MinFilter = LINEAR;
	MagFilter = LINEAR;
	Mipfilter = LINEAR;*/
	Filter = Anisotropic;
	MaxAnisotropy = 8;
	AddressU = Wrap;
	AddressV = Wrap;
};

SamplerState FresnelSampler
{
	Texture = <FresnelMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR; 
	Mipfilter = LINEAR;

	AddressU = Clamp;
	AddressV = Clamp;
};

SamplerState AoSampler
{
	Texture = <AoMap>;
	MinFilter = LINEAR;
	MagFilter = POINT;
	Mipfilter = POINT;

	AddressU = Clamp;
	AddressV = Clamp;
};

SamplerState CubeMapSampler
{
	Texture = <EnvironmentMap>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	Mipfilter = LINEAR;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Structs

struct VertexShaderInput
{
	float4 Position : POSITION0;
	float3 Normal   : NORMAL0;
	float2 TexCoord : TEXCOORD0;
};

struct NoNormal_VertexShaderInput
{
	float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

struct Depth_VertexShaderInput
{
	float4 Position : POSITION0;
};

struct Normal_VertexShaderInput
{
	float4 Position : POSITION0;
	float3 Normal : NORMAL0;
	float3 Binormal : BINORMAL0;
	float3 Tangent : TANGENT0;
	float2 TexCoord : TEXCOORD0;
};

struct SkinnedVertexShaderInput
{
	float4 Position : POSITION0;
	float3 Normal   : NORMAL0;
	float2 TexCoord : TEXCOORD0;
	uint4  Indices  : BLENDINDICES0;
	float4 Weights  : BLENDWEIGHT0;
};

struct Depth_SkinnedVertexShaderInput
{
	float4 Position : POSITION0;
	uint4  Indices  : BLENDINDICES0;
	float4 Weights  : BLENDWEIGHT0;
};

struct SkinnedNormal_VertexShaderInput
{
	float4 Position : POSITION0;
	float3 Normal : NORMAL0;
	float3 Binormal : BINORMAL0;
	float3 Tangent : TANGENT0;
	float2 TexCoord : TEXCOORD0;
	uint4  Indices  : BLENDINDICES0;
	float4 Weights  : BLENDWEIGHT0;
};

struct VertexShaderOutput
{
	float4 Position : SV_POSITION;
    float3 Normal : NORMAL;
	float2 TexCoord : TEXCOORD1;
	float3 WorldPosition : TEXCOORD2;
	float4 ScreenTexCoord :TEXCOORD3;
}; 

struct NoNormal_VertexShaderOutput
{
	float4 Position : SV_POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 WorldPosition : TEXCOORD2;
	float4 ScreenTexCoord :TEXCOORD3;
};

struct Depth_VertexShaderOutput
{
	float4 Position : SV_POSITION;
	float3 ViewPosition : POSITION1;
	float Depth : DEPTH;
};

struct Normal_VertexShaderOutput
{
	float4 Position : SV_POSITION0;
	float3x3 WorldToTangentSpace : TEXCOORD4;
	float2 TexCoord : TEXCOORD1;
	float3 WorldPosition : TEXCOORD2;
	float4 ScreenTexCoord : TEXCOORD3;
	//float Depth : TEXCOORD0;
};

struct LightingParams
{
	float4 Color : COLOR0;
	float3 Normal : TEXCOORD0;
	float Metallic : TEXCOORD1;
	float Roughness : TEXCOORD2;
	float3 WorldPosition : TEXCOORD3;
	float2 ScreenTexCoord : TeXCOORD4;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Functions

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  VS

void SkinWorld(inout Depth_SkinnedVertexShaderInput vin, uniform int boneCount)
{
	float4x3 skinning = 0;

	[unroll]
	for (int i = 0; i < boneCount; i++)
	{
		skinning += Bones[vin.Indices[i]] * vin.Weights[i];
	}

	vin.Position.xyz = mul(vin.Position, skinning);
}

void SkinNormal(inout SkinnedVertexShaderInput vin, uniform int boneCount)
{
	float4x3 skinning = 0;

	[unroll]
	for (int i = 0; i < boneCount; i++)
	{
		skinning += Bones[vin.Indices[i]] * vin.Weights[i];
	}

	vin.Position.xyz = mul(vin.Position, skinning);
	vin.Normal = mul(vin.Normal, (float3x3)skinning);
}

void SkinTangentSpace(inout SkinnedNormal_VertexShaderInput vin, uniform int boneCount)
{
	float4x3 skinning = 0;

	[unroll]
	for (int i = 0; i < boneCount; i++)
	{
		skinning += Bones[vin.Indices[i]] * vin.Weights[i];
	}

	vin.Position.xyz = mul(vin.Position, skinning);
	vin.Normal = mul(vin.Normal, (float3x3)skinning);
	vin.Binormal = mul(vin.Binormal, (float3x3)skinning);
	vin.Tangent = mul(vin.Tangent, (float3x3)skinning);
}

VertexShaderOutput Unskinned_VertexShaderFunction(VertexShaderInput input)
{
	VertexShaderOutput output;

	float4 WorldPosition = mul(input.Position, World);
	output.WorldPosition = WorldPosition.xyz;
	output.Position = mul(WorldPosition, ViewProj);
	output.Normal = mul(input.Normal, WorldIT).xyz;
	output.TexCoord = input.TexCoord;
	output.ScreenTexCoord = output.Position; /*0.5f * (float2(output.Position.x, -output.Position.y) / output.Position.w + float2(1, 1));*/
	return output;
}

NoNormal_VertexShaderOutput NoNormalNoTex_Unskinned_VertexShaderFunction(float4 Position : POSITION0)
{
	NoNormal_VertexShaderOutput output;

	float4 WorldPosition = mul(Position, World);
	output.WorldPosition = WorldPosition.xyz;
	output.Position = mul(WorldPosition, ViewProj);
	output.TexCoord = float2(0,0);
	output.ScreenTexCoord = output.Position;
	return output;
}

NoNormal_VertexShaderOutput NoNormal_Unskinned_VertexShaderFunction(NoNormal_VertexShaderInput input)
{
	NoNormal_VertexShaderOutput output;

	float4 WorldPosition = mul(input.Position, World);
	output.WorldPosition = WorldPosition.xyz;
	output.Position = mul(WorldPosition, ViewProj);
	output.TexCoord = input.TexCoord;
	output.ScreenTexCoord = output.Position;
	return output;
}


Normal_VertexShaderOutput UnskinnedNormalMapped_VertexShaderFunction(Normal_VertexShaderInput input)
{
	Normal_VertexShaderOutput output;

	float4 WorldPosition = mul(input.Position, World);
	output.WorldPosition = WorldPosition.xyz;

	output.Position = mul(WorldPosition, ViewProj);
	output.WorldToTangentSpace[0] = mul(input.Tangent, WorldIT);
	output.WorldToTangentSpace[1] = mul(input.Binormal, WorldIT);
	output.WorldToTangentSpace[2] = mul(input.Normal, WorldIT);
	output.TexCoord = input.TexCoord; 
	output.ScreenTexCoord = output.Position;

	//output.WorldPosition = WorldPos.xyz;
	return output;
}

//4 weights per vertex
VertexShaderOutput Skinned_VertexShaderFunction(SkinnedVertexShaderInput input)
{
	VertexShaderOutput output;

	SkinNormal(input, 4);

	float4 WorldPosition = mul(input.Position, World);
	output.WorldPosition = WorldPosition.xyz;
    output.Position = mul(WorldPosition, ViewProj);
	output.Normal = mul(input.Normal, WorldIT).xyz;
	output.TexCoord = input.TexCoord;
	output.ScreenTexCoord = output.Position;
	return output;
}


Normal_VertexShaderOutput SkinnedNormalMapped_VertexShaderFunction(SkinnedNormal_VertexShaderInput input)
{
	Normal_VertexShaderOutput output;

	SkinTangentSpace(input, 4);

	float4 WorldPosition = mul(input.Position, World);
	output.WorldPosition = WorldPosition.xyz;

	output.Position = mul(WorldPosition,ViewProj);
	output.WorldToTangentSpace[0] = mul(input.Tangent, WorldIT);
	output.WorldToTangentSpace[1] = mul(input.Binormal, WorldIT);
	output.WorldToTangentSpace[2] = mul(input.Normal, WorldIT);
	output.TexCoord = input.TexCoord;
	output.ScreenTexCoord = output.Position;
	//output.WorldPosition = WorldPos.xyz;
	return output;
}

Depth_VertexShaderOutput UnskinnedDepth_VertexShaderFunction(Depth_VertexShaderInput input)
{
	Depth_VertexShaderOutput output;

	float4 WorldPosition = mul(input.Position, World);
	output.Position = mul(WorldPosition, ViewProj);
	float4 viewPosition = mul(WorldPosition, View);
	output.Depth = viewPosition.z / -FarClip;
	output.ViewPosition = viewPosition.xyz / viewPosition.w;
	return output;
}

Depth_VertexShaderOutput SkinnedDepth_VertexShaderFunction(Depth_SkinnedVertexShaderInput input)
{
	Depth_VertexShaderOutput output;

	SkinWorld(input, 4);

	float4 WorldPosition = mul(input.Position, World);
	output.Position = mul(WorldPosition, ViewProj);
	float4 viewPosition = mul(WorldPosition, View);
	output.Depth = viewPosition.z / -FarClip;
	output.ViewPosition = viewPosition.xyz / viewPosition.w;
	return output;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  PS

float3 GetNormalMap(float2 TexCoord)
{
	//This gets normalized anyways, so it doesn't matter that it's technically only half the length
	return NormalMap.Sample(TextureSampler, TexCoord).rgb - float3(0.5f, 0.5f, 0.5f);
}

//http://the-witness.net/news/2012/02/seamless-cube-map-filtering/

float3 FixCubeLookup(float3 v, int level)
{
	float M = max(max(abs(v.x), abs(v.y)), abs(v.z));
	//float size = CubeSize >> level;
	//float scale = (size - 1) / size;
	float scale = 1 - exp2(level) / CubeSize;
	if (abs(v.x) != M) v.x *= scale;
	if (abs(v.y) != M) v.y *= scale;
	if (abs(v.z) != M) v.z *= scale;
	return v;
}

float4 Lighting(LightingParams input)
{
	float3 normal = normalize(input.Normal);

	float4 color = input.Color;
	if (UseLinear) color = pow(abs(color), 2.2f);

	float metallic = input.Metallic;
	float roughness = input.Roughness;

	float3 viewDir = normalize(input.WorldPosition - CameraPosition);

	float f0 = lerp(0.04f, color.g * 0.25 + 0.75, metallic);

	float2 fresnelFactor = FresnelMap.SampleLevel(FresnelSampler, float2(roughness, 1-dot(-viewDir, normal)), 0).rg;

	float3 reflectVector = -reflect(-viewDir, normal);

	float3 specularReflection = EnvironmentMap.SampleLevel(CubeMapSampler, FixCubeLookup(reflectVector.xzy, roughness * 7), roughness * 7).rgb;
	if (UseLinear) specularReflection = pow(abs(specularReflection), 2.2f);

	specularReflection = specularReflection * (fresnelFactor.r * f0 + fresnelFactor.g);
	//specularReflection = lerp(float4(0, 0, 0, 0), specularReflection, fresnelFactor);

	float3 diffuseReflection = EnvironmentMap.SampleLevel(CubeMapSampler, FixCubeLookup(reflectVector.xzy, 7),7).rgb ;
	if (UseLinear) diffuseReflection = pow(abs(diffuseReflection), 2.2f);

	diffuseReflection *= (1 - (fresnelFactor.r * f0 + fresnelFactor.g));

	float3 plasticFinal = color.rgb * (/*diffuseLight +*/ diffuseReflection)/*+specularLight*/ + specularReflection; //ambientSpecular;
	if (UseLinear) plasticFinal = pow(abs(plasticFinal), 0.45454545f);

	float3 metalFinal = (/*specularLight +*/ specularReflection)* color.rgb;
	if (UseLinear) metalFinal = pow(abs(metalFinal), 0.45454545f);

	float3 finalValue = lerp(plasticFinal, metalFinal, metallic);

	[branch]
	if (UseAo)
	{
		float ao = AoMap.SampleLevel(AoSampler, input.ScreenTexCoord, 0).r;

		//increase ao
		ao = 1 - ((1 - ao) * 2);

		finalValue *= ao;
	}

	return float4(finalValue, 1);
}

//http://www.rorydriscoll.com/2012/01/11/derivative-maps/

// Project the surface gradient (dhdx, dhdy) onto the surface (n, dpdx, dpdy)
float3 CalculateSurfaceGradient(float3 n, float3 dpdx, float3 dpdy, float dhdx, float dhdy)
{
	float3 r1 = cross(dpdy, n);
	float3 r2 = cross(n, dpdx);

	return (r1 * dhdx + r2 * dhdy) / dot(dpdx, r1);
}

float ApplyChainRule(float dhdu, float dhdv, float dud_, float dvd_)
{
	return dhdu * dud_ + dhdv * dvd_;
}

// Move the normal away from the surface normal in the opposite surface gradient direction
float3 PerturbNormal(float3 normal, float3 dpdx, float3 dpdy, float dhdx, float dhdy)
{
	return normalize(normal - CalculateSurfaceGradient(normal, dpdx, dpdy, dhdx, dhdy));
}

// Calculate the surface normal using screen-space partial derivatives of the height field
//float3 CalculateSurfaceNormal(float3 position, float3 normal, float height, float2 uv)
//{
//	float3 dpdx = ddx(position);
//	float3 dpdy = ddy(position);
//
//	float2 gradient = float2(ddx(height), ddy(height));
//
//	float dhdx = ApplyChainRule(gradient.x, gradient.y, ddx(uv.x), ddx(uv.y));
//	float dhdy = ApplyChainRule(gradient.x, gradient.y, ddy(uv.x), ddy(uv.y));
//
//	return PerturbNormal(normal, dpdx, dpdy, dhdx, dhdy);
//}
//
float3 CalculateSurfaceNormal(float3 position, float3 normal, float2 texCoord, float sampleLevel)
{
	float3 dpdx = ddx_fine(position);
	float3 dpdy = ddy_fine(position);

	float height = HeightMap.SampleLevel(TextureSampler, texCoord, sampleLevel).r;

	/*float dhdx = ddx_fine(height);
	float dhdy = ddy_fine(height);*/

	float2 dudx = float2(ddx(texCoord.x), ddx(texCoord.y));
	float2 dudy = float2(ddy(texCoord.x), ddy(texCoord.y));

	float dhdx = height - HeightMap.SampleLevel(TextureSampler, texCoord + dudx, sampleLevel).r;
	float dhdy = height - HeightMap.SampleLevel(TextureSampler, texCoord + dudy, sampleLevel).r;

	/*dhdx += -height + HeightMap.SampleLevel(TextureSampler, texCoord - dudx, sampleLevel);
	dhdy += -height + HeightMap.SampleLevel(TextureSampler, texCoord - dudy, sampleLevel);

	dhdx /= 2;
	dhdy /= 2;*/

	dhdx *= -POMScale; /** (1 + !UsePOM * 19);*/
	dhdy *= -POMScale; // *(1 + !UsePOM * 19);

	/*dhdx = ApplyChainRule(dhdx, dhdy, dudx.x, dudx.y);
	dhdy = ApplyChainRule(dhdx, dhdy, dudy.x, dudy.x);*/

	return PerturbNormal(normal, dpdx, dpdy, dhdx, dhdy);
}



float4 PixelShaderFunction(VertexShaderOutput input) : SV_TARGET0
{
	float3 normal = normalize(input.Normal);

	float sampleLevel = AlbedoMap.CalculateLevelOfDetailUnclamped(TextureSampler, input.TexCoord);

	float4 albedo = AlbedoColor;

	[branch]
	if (UseAlbedoMap)
	{
		albedo = AlbedoMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel);
	}

	float roughness = Roughness;
	[branch]
	if (UseRoughnessMap)
	{
		roughness = RoughnessMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel).r;
	}

	float metallic = Metallic;
	[branch]
	if (UseMetallicMap)
	{
		metallic = MetallicMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel).r;
	}

	//Derivative gradient
	[branch]
	if (UseBumpmap)
	{
		normal = CalculateSurfaceNormal(input.WorldPosition, normal, input.TexCoord, sampleLevel);
	}

	LightingParams renderParams;

	renderParams.Color = albedo;
	renderParams.Normal = normal;
	////renderParams.Depth = input.Depth;
	renderParams.Metallic = metallic;
	renderParams.Roughness = roughness;
	renderParams.WorldPosition = input.WorldPosition;
	renderParams.ScreenTexCoord = 0.5f * (float2(input.ScreenTexCoord.x, -input.ScreenTexCoord.y) / input.ScreenTexCoord.w + float2(1, 1));

	return Lighting(renderParams);
}

float4 NoNormal_PixelShaderFunction(NoNormal_VertexShaderOutput input) : SV_TARGET0
{
	float3 normal = normalize(cross(ddy(input.WorldPosition.xyz), ddx(input.WorldPosition.xyz)));

	VertexShaderOutput output;
	output.WorldPosition = input.WorldPosition;
	output.Position = input.Position;
	output.Normal = normal;
	output.TexCoord = input.TexCoord;
	output.ScreenTexCoord = input.ScreenTexCoord;

	return PixelShaderFunction(output);
}

float2 CalculatePOM(float3 WorldPosition, float3x3 TangentSpace, float2 texCoords, float sampleLevel)
{
	float height_scale = POMScale / 5.0f;
	TangentSpace = transpose(TangentSpace);
	float3 cameraPositionTS = mul(CameraPosition, TangentSpace);
	float3 positionTS = mul(WorldPosition, TangentSpace);
	//Vector TO camera
	float3 viewDir = normalize(cameraPositionTS - positionTS);

	//steepness
	float steepness = (1 - viewDir.z);

	//float height = HeightMap.SampleLevel(TextureSampler, texCoords, sampleLevel);

	//texCoords = texCoords + viewDir.xy * height * height_scale;

	// number of depth layers
	float numLayers = lerp(10, 40, steepness) * POMQuality;
	// calculate the size of each layer
	float layerDepth = 1.0 / numLayers;
	// depth of current layer
	float currentLayerDepth = 0.0;

	float2 P = viewDir.xy/(max(viewDir.z, 0.2f)) * abs(height_scale);
	float2 deltaTexCoords = P / numLayers;

	float f1 = saturate(sign(height_scale));
	float f2 = sign(-height_scale);

	float2  currentTexCoords = texCoords;
	float currentDepthMapValue = f1 + f2 *HeightMap.SampleLevel(TextureSampler, currentTexCoords, sampleLevel).r;

	[loop]
	while (currentLayerDepth < currentDepthMapValue)
	{
		// shift texture coordinates along direction of P
		currentTexCoords -= deltaTexCoords;
		// get depthmap value at current texture coordinates
		currentDepthMapValue = f1 + f2 *HeightMap.SampleLevel(TextureSampler, currentTexCoords, sampleLevel).r;
		// get depth of next layer
		currentLayerDepth += layerDepth;
	}

	float2 prevTexCoords = currentTexCoords + deltaTexCoords;

	// get depth after and before collision for linear interpolation
	float afterDepth = currentDepthMapValue - currentLayerDepth;
	float beforeDepth = f1 + f2 *HeightMap.SampleLevel(TextureSampler, prevTexCoords, sampleLevel).r - currentLayerDepth + layerDepth;

	// interpolation of texture coordinates
	float weight = afterDepth / (afterDepth - beforeDepth);
	float2 finalTexCoords = lerp(currentTexCoords, prevTexCoords, weight); /* prevTexCoords * weight + currentTexCoords * (1.0 - weight);*/

	if (POMCutoff)
	if (finalTexCoords.x != saturate(finalTexCoords.x) || finalTexCoords.y != saturate(finalTexCoords.y))
	{
		discard;
	}

	return finalTexCoords;
}

float4 TangentSpace_PixelShaderFunction(Normal_VertexShaderOutput input) : SV_TARGET0
{
	float sampleLevel = AlbedoMap.CalculateLevelOfDetailUnclamped(TextureSampler, input.TexCoord);

	float4 albedo = AlbedoColor;

	/*[branch]*/
	if (UsePOM)
	{
		input.TexCoord = CalculatePOM(input.WorldPosition, input.WorldToTangentSpace, input.TexCoord, sampleLevel);

		sampleLevel = AlbedoMap.CalculateLevelOfDetailUnclamped(TextureSampler, input.TexCoord);
	}

	[branch]
	if (UseAlbedoMap)
	{
		albedo = AlbedoMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel);
	}

	float roughness = Roughness;
	[branch]
	if (UseRoughnessMap)
	{
		roughness = RoughnessMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel).r;
	}

	float metallic = Metallic;
	[branch]
	if (UseMetallicMap)
	{
		metallic = MetallicMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel).r;
	}

	float3 normal;

	[branch]
	if (UseNormalMap)
	{
		float3 normalMap = NormalMap.SampleLevel(TextureSampler, input.TexCoord, sampleLevel).xyz - float3(0.5f, 0.5f, 0.5f);

		normal = normalize(mul(normalMap, input.WorldToTangentSpace));
	}
	else
	{
		normal = normalize(input.WorldToTangentSpace[2]);

		/*[branch]*/
		if (UseBumpmap)
		{
			normal = CalculateSurfaceNormal(input.WorldPosition, normal, input.TexCoord, sampleLevel);
		}
	}

	LightingParams renderParams;

	renderParams.Color = albedo;
	renderParams.Normal = normal;
	renderParams.Metallic = metallic;
	renderParams.Roughness = roughness;
	renderParams.WorldPosition = input.WorldPosition;
	renderParams.ScreenTexCoord = 0.5f * (float2(input.ScreenTexCoord.x, -input.ScreenTexCoord.y) / input.ScreenTexCoord.w + float2(1, 1));

	return Lighting(renderParams);
}

float4 Depth_PixelShaderFunction(Depth_VertexShaderOutput input) : SV_TARGET
{
	float3 normal = normalize(cross(ddy(input.ViewPosition), ddx(input.ViewPosition)));
	normal = (normal + float3(1, 1, 1)) * 0.5f;
	return float4(input.Depth, normal);// float4(normal.xyz, input.Depth);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Techniques

technique NoNormalNoTex_Unskinned
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 NoNormalNoTex_Unskinned_VertexShaderFunction();
		PixelShader = compile ps_5_0 NoNormal_PixelShaderFunction();
	}
}

technique NoNormal_Unskinned
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 NoNormal_Unskinned_VertexShaderFunction();
		PixelShader = compile ps_5_0 NoNormal_PixelShaderFunction();
	}
}

technique Unskinned
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 Unskinned_VertexShaderFunction();
		PixelShader = compile ps_5_0 PixelShaderFunction();
	}
}

technique UnskinnedNormalMapped
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 UnskinnedNormalMapped_VertexShaderFunction();
		PixelShader = compile ps_5_0 TangentSpace_PixelShaderFunction();
	}
}

technique Skinned
{
    pass Pass1
    {
        VertexShader = compile vs_5_0 Skinned_VertexShaderFunction();
        PixelShader = compile ps_5_0 PixelShaderFunction();
    }
}

technique SkinnedNormalMapped
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 SkinnedNormalMapped_VertexShaderFunction();
		PixelShader = compile ps_5_0 TangentSpace_PixelShaderFunction();
	}
}

technique UnskinnedDepth
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 UnskinnedDepth_VertexShaderFunction();
		PixelShader = compile ps_5_0 Depth_PixelShaderFunction();
	}
}

technique SkinnedDepth
{
	pass Pass1
	{
		VertexShader = compile vs_5_0 SkinnedDepth_VertexShaderFunction();
		PixelShader = compile ps_5_0 Depth_PixelShaderFunction();
	}
}