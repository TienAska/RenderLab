Shader "Custom/TessTerrain"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _Height("Height", Range(0, 100)) = 0
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "4.5"}
        LOD 300

        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 5.0
            
            #pragma vertex   TerrainPassVertex;
            #pragma hull     TerrainPassHull;
            #pragma domain   TerrainPassDomain;
            #pragma fragment TerrainPassFragment;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            cbuffer UnityPerMaterial
            {
                half4 _BaseColor;
                float _Height;
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

            TessellationFactors TerrainPassPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
            {
                TessellationFactors f;
                f.edges[0] = 1;
                f.edges[1] = 1;
                f.edges[2] = 1;
                f.inside = 1;
                return f;
            }

            [domain("tri")]
            [outputcontrolpoints(3)]
            [outputtopology("triangle_cw")]
            [partitioning("integer")]
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


            ENDHLSL
        }
    }
}
