Shader "Custom/E1"
{
    Properties
    {
        _BaseTexture("Base Texture", 2D) = "white" {}
        [HDR] _TintColor("Tint Color", Color) = (1, 1, 1, 1)

        _ScanSpeed("Scanline Scroll Speed", Float) = 1
        _ScanDensity("Scanline Density", Float) = 1

        _FresnelExponent("Fresnel Power", Float) = 1

        _DepthBlendAmount("Depth Blend", Float) = 1
        _IntersectWidth("Intersection Width", Float) = 1

        _HexScrollSpeed("Hexagon Scroll Speed", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex CalculateVertexOutput
            #pragma fragment CalculateFragmentOutput

            #include "UnityCG.cginc"

            sampler2D _CameraDepthTexture;

            struct VertexShaderInput
            {
                float4 vertexPositionOS : POSITION;
                float2 baseUV : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct VertexShaderOutput
            {
                float4 vertexPositionCS : SV_POSITION;
                float2 baseUV : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 viewVector : TEXCOORD2;
                float4 screenPosition : TEXCOORD3;
            };

            sampler2D _BaseTexture;
            float4 _BaseTexture_ST;
            float4 _TintColor;
            float _ScanSpeed;
            float _ScanDensity;
            float _FresnelExponent;
            float _DepthBlendAmount;
            float _IntersectWidth;
            float _HexScrollSpeed;

            float ComputeFresnel(float3 normalWS, float3 viewWS, float exponent)
            {
                float dotResult = dot(normalWS, viewWS);
                dotResult = saturate(1.0 - dotResult);
                return pow(dotResult, exponent);
            }

            float SampleSceneDepth(float2 uvCoords, sampler2D depthTex)
            {
                float rawDepth = SAMPLE_DEPTH_TEXTURE(depthTex, uvCoords);
                return LinearEyeDepth(rawDepth);
            }

            float BlendSoftLight(float baseValue, float blendValue)
            {
                float resultA = (1.0 - 2.0 * blendValue) * (baseValue * baseValue) + 2.0 * baseValue * blendValue;
                float resultB = (2.0 * blendValue - 1.0) * sqrt(baseValue) + 2.0 * baseValue * (1.0 - blendValue);
                return blendValue < 0.5 ? resultA : resultB;
            }

            float CreateScanlineMask(float2 uv, float scrollSpeed, float lineDensity)
            {
                float linePattern = frac(uv.y * lineDensity + scrollSpeed * _Time.x);
                return step(linePattern, 0.7);
            }

            VertexShaderOutput CalculateVertexOutput(VertexShaderInput input)
            {
                VertexShaderOutput output;

                output.vertexPositionCS = UnityObjectToClipPos(input.vertexPositionOS);
                output.baseUV = TRANSFORM_TEX(input.baseUV, _BaseTexture);

                float3 worldPosition = mul(unity_ObjectToWorld, input.vertexPositionOS).xyz;
                output.worldNormal = UnityObjectToWorldNormal(input.normalOS);
                output.viewVector = normalize(_WorldSpaceCameraPos - worldPosition);

                output.screenPosition = ComputeScreenPos(output.vertexPositionCS);
                return output;
            }

            fixed4 CalculateFragmentOutput(VertexShaderOutput input) : SV_Target
            {
                float2 sceneUV = input.screenPosition.xy / input.screenPosition.w;

                float sceneLinearDepth = SampleSceneDepth(sceneUV, _CameraDepthTexture);
                float fragmentDepth = input.screenPosition.w;

                float intersectionFade = pow(saturate(1.0 - (sceneLinearDepth - fragmentDepth)), _FresnelExponent);

                float3 normalWS = normalize(input.worldNormal);
                float3 viewWS = normalize(input.viewVector);

                float fresnelFactor = ComputeFresnel(normalWS, viewWS, _FresnelExponent);

                float2 animatedUV = frac(input.baseUV * float2(1.0, 1.0) + float2(0.0, _HexScrollSpeed * _Time.y));

                float hexTexValue = tex2D(_BaseTexture, animatedUV).r;

                float scanline = CreateScanlineMask(input.baseUV, _ScanSpeed, _ScanDensity);

                fixed4 finalColor = _TintColor;
                finalColor.a = BlendSoftLight(intersectionFade + fresnelFactor, 1.0 - hexTexValue + scanline);

                return finalColor;
            }

            ENDCG
        }
    }
}
