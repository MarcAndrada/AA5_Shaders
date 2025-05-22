Shader "Custom/E2"
{
    Properties
    {
        _BlendPower("Blend Power", Float) = 2.5
        _TextureScale("Texture Scale", Float) = 0.42
        _ColorTint("Color Tint", Color) = (1,1,1,1)

        _DiffuseTex("Diffuse Texture", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}

        [Toggle(_USE_EMISSION)] _EnableEmission("Enable Emission", Float) = 0
        _EmissionTex("Emission Texture", 2D) = "black" {}
        _EmissionColor("Emission Color", Color) = (0,0,0,0)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _USE_EMISSION

            #include "UnityCG.cginc"

            struct VS_INPUT
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct VS_OUTPUT
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangent : TEXCOORD2;
                float3 worldBitangent : TEXCOORD3;
            };

            sampler2D _DiffuseTex;
            sampler2D _NormalMap;

            sampler2D _EmissionTex;
            float4 _EmissionColor;

            float _BlendPower;
            float _TextureScale;
            float4 _ColorTint;

            VS_OUTPUT vert(VS_INPUT input)
            {
                VS_OUTPUT output;

                output.pos = UnityObjectToClipPos(input.vertex);
                output.worldPos = mul(unity_ObjectToWorld, input.vertex).xyz;
                output.worldNormal = UnityObjectToWorldNormal(input.normal);

                float3 tangentWorld = UnityObjectToWorldDir(input.tangent.xyz);
                float tangentSign = input.tangent.w;
                float3 bitangentWorld = cross(output.worldNormal, tangentWorld) * tangentSign;

                output.worldTangent = tangentWorld;
                output.worldBitangent = bitangentWorld;

                return output;
            }

            float3 ComputeBlendWeights(float3 normal)
            {
                float3 weights = pow(abs(normal), _BlendPower);
                weights /= (weights.x + weights.y + weights.z);
                return weights;
            }

            float4 TriplanarSample(sampler2D tex, float3 worldPos, float3 normal)
            {
                float3 blendWeights = ComputeBlendWeights(normal);
                float2 uvX = worldPos.yz * _TextureScale;
                float2 uvY = worldPos.xz * _TextureScale;
                float2 uvZ = worldPos.xy * _TextureScale;

                float4 sampleX = tex2D(tex, uvX);
                float4 sampleY = tex2D(tex, uvY);
                float4 sampleZ = tex2D(tex, uvZ);

                return sampleX * blendWeights.x + sampleY * blendWeights.y + sampleZ * blendWeights.z;
            }

            float3 TriplanarNormalSample(sampler2D normalTex, float3 worldPos, float3 normal, float3 tangent, float3 bitangent)
            {
                float3 weights = ComputeBlendWeights(normal);

                float2 uvX = worldPos.yz * _TextureScale;
                float2 uvY = worldPos.xz * _TextureScale;
                float2 uvZ = worldPos.xy * _TextureScale;

                float3 nX = UnpackNormal(tex2D(normalTex, uvX));
                float3 nY = UnpackNormal(tex2D(normalTex, uvY));
                float3 nZ = UnpackNormal(tex2D(normalTex, uvZ));

                float3 worldN_X = normalize(tangent * nX.x + bitangent * nX.y + normal * nX.z);
                float3 worldN_Y = normalize(tangent * nY.x + bitangent * nY.y + normal * nY.z);
                float3 worldN_Z = normalize(tangent * nZ.x + bitangent * nZ.y + normal * nZ.z);

                float3 blendedNormal = worldN_X * weights.x + worldN_Y * weights.y + worldN_Z * weights.z;

                return normalize(blendedNormal);
            }

            fixed4 frag(VS_OUTPUT input) : SV_Target
            {
                float3 norm = normalize(input.worldNormal);
                float3 tan = normalize(input.worldTangent);
                float3 bitan = normalize(input.worldBitangent);

                float4 baseCol = TriplanarSample(_DiffuseTex, input.worldPos, norm) * _ColorTint;

                float3 normalSample = TriplanarNormalSample(_NormalMap, input.worldPos, norm, tan, bitan);


                float3 lightDir = normalize(float3(0.3, 0.7, 0.5));
                float diff = saturate(dot(normalSample, lightDir));

                baseCol.rgb *= (0.2 + 0.8 * diff);

                #ifdef _USE_EMISSION
                    float4 emissive = TriplanarSample(_EmissionTex, input.worldPos, norm);
                    baseCol.rgb += emissive.rgb * _EmissionColor.rgb;
                #endif

                return baseCol;
            }

            ENDCG
        }
    }
}
