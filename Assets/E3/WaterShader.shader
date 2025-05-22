Shader "Custom/WaterShader"
{
    Properties
    {
        _Normals("Normal Map", 2D) = "bump" {}
        _NormalsStrength("Normal Strength", Float) = 1

        _FlowMap("Flow Map", 2D) = "white" {}
        _FlowStrength("Flow Strength", Float) = 1
        _Speed("Speed", Float) = 1
        _DistortionStrength("Distortion Strength", Float) = 1

        _DepthFadeDistance("Depth Fade Distance", Float) = 15
        _DepthColor("Water Color", Color) = (0, 0, 1, 1)
    }

    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard alpha:fade vertex:vert
        #pragma target 3.0
        #include "UnityCG.cginc"

        sampler2D _CameraDepthTexture;

        sampler2D _Normals;
        float _Tiling;
        float _NormalsStrength;

        sampler2D _FlowMap;
        float _FlowStrength;
        float _Speed;
        float _DistortionStrength;

        float _DepthFadeDistance;
        fixed4 _DepthColor;

        struct Input
        {
            float2 uv_Normals;
            float2 uv_FlowMap;
            float3 worldPos;
            float4 screenPos;
        };
        
        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
            o.screenPos = ComputeScreenPos(UnityObjectToClipPos(v.vertex));
            o.uv_Normals = v.texcoord;
            o.uv_FlowMap = v.texcoord;
        }

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float2 uvFlow = IN.uv_FlowMap.xy * (1.0 + 0.0);
            float4 flowSample = tex2D(_FlowMap, uvFlow);

            float2 flowBaseDir = (flowSample.rg - float2(0.5, 0.5)) * 1.0;
            float flowMagnitude = saturate(length(flowBaseDir));
            
            float flowStrengthAdjusted = lerp(0.05, _FlowStrength * 0.25, flowMagnitude); 

            float2 flowDirection = flowBaseDir * flowStrengthAdjusted;

            flowDirection *= float2(0.2, -0.1);

            float slowTimer = _Time.y * 0.25;

            float remapFactor = 0.5 + 0.5 * sin(slowTimer * 3.1415 * 2.0); 

            float2 baseUV = IN.uv_Normals * float2(1.0, 1.0);
            float2 timeOffset = float2(0.0, 0.05) * slowTimer * _Speed * 0.5;

            float2 displacedUV = baseUV + timeOffset + (flowDirection * remapFactor);

            float4 sampledNormalCol = tex2D(_Normals, displacedUV);
            float3 unpackedNormal = normalize(UnpackNormal(sampledNormalCol));

            float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
            float sceneDepthRaw = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
            float sceneDepth = LinearEyeDepth(sceneDepthRaw);
            float surfaceDepth = LinearEyeDepth(IN.screenPos.z);
            float depthBlend = saturate((sceneDepth - surfaceDepth) / _DepthFadeDistance);
            float3 finalCol = lerp(sampledNormalCol.rgb, _DepthColor.rgb, depthBlend);

            o.Albedo = finalCol;
            o.Normal = unpackedNormal * _NormalsStrength;
            o.Alpha = depthBlend;
        }

        ENDCG
    }

    FallBack "Transparent/Diffuse"
}