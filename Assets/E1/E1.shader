Shader "Custom/E1"
{
    Properties
    {
        _BaseTexture("Base Texture", 2D) = "white" {}
        [HDR] _TintColor("Tint Color", Color) = (1, 1, 1, 1)

        _ScanSpeed("Scanline Scroll Speed", Float) = -0.1
        _ScanDensity("Scanline Density", Float) = 50

        _FresnelExponent("Fresnel Power", Float) = 5

        _DepthBlendAmount("Depth Blend", Float) = 0.5
        _IntersectWidth("Intersection Width", Float) = 1

        _HexScrollSpeed("Hexagon Scroll Speed", Range(0, 0.3)) = 0.1
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
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _CameraDepthTexture;

            struct VertexInput
            {
                float4 pos : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 norm : NORMAL;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNorm : TEXCOORD1;
                float3 viewDirection : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
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

            // Calculates the Fresnel effect based on normal and view direction
            float ComputeFresnelTerm(float3 norm, float3 viewDir, float power)
            {
                float facing = dot(norm, viewDir);
                facing = saturate(1.0 - facing);
                return pow(facing, power);
            }

            // Samples linear eye depth from camera depth texture
            float SampleLinearDepth(float2 uv, sampler2D depthTex)
            {
                float rawDepth = SAMPLE_DEPTH_TEXTURE(depthTex, uv);
                return LinearEyeDepth(rawDepth);
            }

            // Soft light blend between two values A and B
            float SoftLightBlend(float A, float B)
            {
                float cond1 = (1.0 - 2.0 * B) * (A * A) + 2.0 * A * B;
                float cond2 = (2.0 * B - 1.0) * sqrt(A) + 2.0 * A * (1.0 - B);
                return B < 0.5 ? cond1 : cond2;
            }

            // Generates scanline pattern (returns 0 or 1)
            float GenerateScanlines(float2 uv, float speed, float density)
            {
                float linePos = frac(uv.y * density + speed * _Time.x);
                return step(linePos, 0.7);
            }

            VertexOutput vert(VertexInput input)
            {
                VertexOutput output;

                output.pos = UnityObjectToClipPos(input.pos);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseTexture);

                float3 worldPosition = mul(unity_ObjectToWorld, input.pos).xyz;
                output.worldNorm = UnityObjectToWorldNormal(input.norm);
                output.viewDirection = normalize(_WorldSpaceCameraPos - worldPosition);

                output.screenPos = ComputeScreenPos(output.pos);
                return output;
            }

            fixed4 frag(VertexOutput input) : SV_Target
            {
                // Calculate screen UV coordinates for depth sampling
                float2 screenUV = input.screenPos.xy / input.screenPos.w;

                // Get scene depth at this pixel
                float sceneDepth = SampleLinearDepth(screenUV, _CameraDepthTexture);
                float shieldDepth = input.screenPos.w;

                // Calculate intersection fade factor
                float intersectionFactor = pow(saturate(1.0 - (sceneDepth - shieldDepth)), _FresnelExponent);

                // Normalize vectors
                float3 norm = normalize(input.worldNorm);
                float3 viewDir = normalize(input.viewDirection);

                // Calculate fresnel effect term
                float fresnelTerm = ComputeFresnelTerm(norm, viewDir, _FresnelExponent);

                // UV movement for hexagon texture scrolling
                float2 movingUV = frac(input.uv * float2(1.0, 1.0) + float2(0.0, _HexScrollSpeed * _Time.y));

                // Sample hexagon texture (assumed _BaseTexture)
                float hexSample = tex2D(_BaseTexture, movingUV).r;

                // Generate scanline pattern
                float scanlinePattern = GenerateScanlines(input.uv, _ScanSpeed, _ScanDensity);

                // Compose final color
                fixed4 outputColor = _TintColor;
                outputColor.a = SoftLightBlend(intersectionFactor + fresnelTerm, 1.0 - hexSample + scanlinePattern);

                return outputColor;
            }

            ENDCG
        }
    }
}
