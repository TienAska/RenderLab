#ifndef TESSTERRAIN_INCLUDED
#define TESSTERRAIN_INCLUDED

//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

cbuffer UnityPerMaterial
{
    half4 _BaseColor;
    float _Height;
    float _TessellationUniform;
    float _TessellationEdgeLength;
};

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float4 color        : COLOR;
    float2 texcoord     : TEXCOORD0;
};

struct TessellationControlPoint
{
    float4 positionOS   : INTERNALTESSPOS;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float4 color        : COLOR;
    float2 texcoord     : TEXCOORD0;
};

struct TessellationFactors
{
    float edges[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

struct VaryingsTerrain
{
    float4 positionCS              : SV_POSITION;
    float2 uv                      : TEXCOORD0;
    float3 positionWS              : TEXCOORD1;
    half3 normalWS                 : TEXCOORD2;
    half4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
    half4 color                    : TEXCOORD4;
};

TessellationControlPoint TerrainPassVertex(Attributes input)
{
    TessellationControlPoint output;
    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.tangentOS = input.tangentOS;
    output.color = input.color;
    output.texcoord = input.texcoord;

    return output;
}

float TessellationEdgeFactor(TessellationControlPoint cp0, TessellationControlPoint cp1)
{
#if defined(_TESSELLATION_EDGE)
    //float4 p0 = TransformObjectToHClip(cp0.positionOS.xyz);
    //float4 p1 = TransformObjectToHClip(cp1.positionOS.xyz);

    //float edgeLength = distance(p0.xy / p0.w, p1.xy / p1.w);
    //return edgeLength * _ScreenParams.y / _TessellationEdgeLength;

    float3 p0 = TransformObjectToWorld(cp0.positionOS.xyz);
    float3 p1 = TransformObjectToWorld(cp1.positionOS.xyz);
    float edgeLength = distance(p0, p1);

    float3 edgeCenter = (p0 + p1) * 0.5;
    float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

    return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);
#else
    return _TessellationUniform;
#endif
}

TessellationFactors TerrainPassPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
    TessellationFactors f;
    f.edges[0] = TessellationEdgeFactor(patch[1], patch[2]);
    f.edges[1] = TessellationEdgeFactor(patch[2], patch[0]);
    f.edges[2] = TessellationEdgeFactor(patch[0], patch[1]);
    f.inside = (TessellationEdgeFactor(patch[1], patch[2]) + TessellationEdgeFactor(patch[2], patch[0]) + TessellationEdgeFactor(patch[0], patch[1])) / 3.0;
    return f; 
}

[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("fractional_odd")]
[patchconstantfunc("TerrainPassPatchConstantFunction")]
TessellationControlPoint TerrainPassHull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}

#define DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName =\
    patch[0].fieldName * barycentricCoordinates.x +\
    patch[1].fieldName * barycentricCoordinates.y +\
    patch[2].fieldName * barycentricCoordinates.z;

[domain("tri")]
VaryingsTerrain TerrainPassDomain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
    Attributes data;
    DOMAIN_PROGRAM_INTERPOLATE(positionOS);
    DOMAIN_PROGRAM_INTERPOLATE(normalOS);
    DOMAIN_PROGRAM_INTERPOLATE(tangentOS);
    DOMAIN_PROGRAM_INTERPOLATE(color);
    DOMAIN_PROGRAM_INTERPOLATE(texcoord);


    VaryingsTerrain output = (VaryingsTerrain)0;

    data.positionOS.xyz += float3(0, 1, 0) * _Height * data.color.rgb;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(data.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(data.normalOS, data.tangentOS);

    output.positionCS = vertexInput.positionCS;
    output.uv = data.texcoord;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;
    real sign = data.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    output.color = data.color;

    return output;
}

half4 TerrainPassFragment(VaryingsTerrain input) : SV_Target
{
    SurfaceData surfaceData = (SurfaceData)0;
    surfaceData.albedo = _BaseColor.rgb;
    surfaceData.specular = 0;
    surfaceData.metallic = 0;
    surfaceData.smoothness = 0.5h;
    surfaceData.normalTS = half3(0.0, 0.0, 1.0);
    surfaceData.emission = 0;
    surfaceData.occlusion = 1;
    surfaceData.alpha = 1;

    InputData inputData = (InputData)0;

    inputData.positionWS = input.positionWS;
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    inputData.tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    inputData.normalWS = input.normalWS;
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    color.rgb = input.color.rgb * _BaseColor.rgb;

    return color;
}

#endif // !TESSTERRAIN_INCLUDED