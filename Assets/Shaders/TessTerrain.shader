Shader "Custom/TessTerrain"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _Height("Height", Range(0, 100)) = 0
        [KeywordEnum(Uniform, Edge)] _Tessellation("Tessellation mode", Float) = 0
        _TessellationUniform("_Tessellation Uniform", Range(1, 64)) = 1
        _TessellationEdgeLength("_Tessellation Edge Length", Range(5, 100)) = 50
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "5.0"}
        LOD 300

        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma only_renderers metal vulkan
            #pragma target 5.0

            #pragma vertex   TerrainPassVertex;
            #pragma hull     TerrainPassHull;
            #pragma domain   TerrainPassDomain;
            #pragma fragment TerrainPassFragment;

            #pragma shader_feature_local _TESSELLATION_EDGE

            #include "TessTerrain.hlsl"
            ENDHLSL
        }
    }
}
