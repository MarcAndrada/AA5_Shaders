Shader "Custom/TriplanarShader"
{
    Properties
    {
        _BlendPower("Blend Power", Float) = 2                     // Controla la suavidad del blending triplanar
        _TextureScale("Texture Scale", Float) = 1                 // Escala de repetición de las texturas
        _ColorTint("Color Tint", Color) = (1,1,1,1)               // Tinte de color aplicado al resultado

        _DiffuseTex("Diffuse Texture", 2D) = "white" {}           // Textura base difusa
        _NormalMap("Normal Map", 2D) = "bump" {}                  // Mapa de normales

        [Toggle(_USE_EMISSION)] _EnableEmission("Enable Emission", Float) = 0 // Activar/emisión
        _EmissionTex("Emission Texture", 2D) = "black" {}         // Textura de emisión
        _EmissionColor("Emission Color", Color) = (0,0,0,0)       // Color multiplicador de la emisión
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex CalculateVertexData
            #pragma fragment CalculateFragmentColor
            #pragma multi_compile_local _USE_EMISSION

            #include "UnityCG.cginc"

            struct VertexInput
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct VertexOutput
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
            };

            sampler2D _DiffuseTex;
            sampler2D _NormalMap;

            sampler2D _EmissionTex;
            float4 _EmissionColor;

            float _BlendPower;
            float _TextureScale;
            float4 _ColorTint;

            // Transforma datos del espacio objeto al espacio mundo
            VertexOutput CalculateVertexData(VertexInput input)
            {
                VertexOutput output;

                output.positionCS = UnityObjectToClipPos(input.positionOS);
                output.positionWS = mul(unity_ObjectToWorld, input.positionOS).xyz;
                output.normalWS = UnityObjectToWorldNormal(input.normalOS);

                float3 tangentWorld = UnityObjectToWorldDir(input.tangentOS.xyz);
                float tangentSign = input.tangentOS.w;
                float3 bitangentWorld = cross(output.normalWS, tangentWorld) * tangentSign;

                output.tangentWS = tangentWorld;
                output.bitangentWS = bitangentWorld;

                return output;
            }

            // Calcula pesos para blending triplanar según la normal
            float3 CalculateTriplanarBlendWeights(float3 normalWS)
            {
                float3 weights = pow(abs(normalWS), _BlendPower);
                weights /= (weights.x + weights.y + weights.z);
                return weights;
            }

            // Muestra color difuso triplanar combinando proyecciones en 3 ejes
            float4 SampleTriplanarColor(sampler2D triplanarTexture, float3 positionWS, float3 normalWS)
            {
                float3 blendWeights = CalculateTriplanarBlendWeights(normalWS);
                float2 uvX = positionWS.yz * _TextureScale;
                float2 uvY = positionWS.xz * _TextureScale;
                float2 uvZ = positionWS.xy * _TextureScale;

                float4 sampleX = tex2D(triplanarTexture, uvX);
                float4 sampleY = tex2D(triplanarTexture, uvY);
                float4 sampleZ = tex2D(triplanarTexture, uvZ);

                return sampleX * blendWeights.x + sampleY * blendWeights.y + sampleZ * blendWeights.z;
            }

            // Muestra normales en triplanar combinadas y transformadas a espacio mundo
            float3 SampleTriplanarNormal(sampler2D normalMap, float3 positionWS, float3 normalWS, float3 tangentWS, float3 bitangentWS)
            {
                float3 blendWeights = CalculateTriplanarBlendWeights(normalWS);

                float2 uvX = positionWS.yz * _TextureScale;
                float2 uvY = positionWS.xz * _TextureScale;
                float2 uvZ = positionWS.xy * _TextureScale;

                float3 normalX = UnpackNormal(tex2D(normalMap, uvX));
                float3 normalY = UnpackNormal(tex2D(normalMap, uvY));
                float3 normalZ = UnpackNormal(tex2D(normalMap, uvZ));

                float3 worldNormalX = normalize(tangentWS * normalX.x + bitangentWS * normalX.y + normalWS * normalX.z);
                float3 worldNormalY = normalize(tangentWS * normalY.x + bitangentWS * normalY.y + normalWS * normalY.z);
                float3 worldNormalZ = normalize(tangentWS * normalZ.x + bitangentWS * normalZ.y + normalWS * normalZ.z);

                float3 finalNormal = worldNormalX * blendWeights.x + worldNormalY * blendWeights.y + worldNormalZ * blendWeights.z;

                return normalize(finalNormal);
            }

            // Fragment shader: calcula iluminación, tintado y emisión (si está activa)
            fixed4 CalculateFragmentColor(VertexOutput input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);
                float3 tangentWS = normalize(input.tangentWS);
                float3 bitangentWS = normalize(input.bitangentWS);

                float4 baseColor = SampleTriplanarColor(_DiffuseTex, input.positionWS, normalWS) * _ColorTint;

                float3 blendedNormal = SampleTriplanarNormal(_NormalMap, input.positionWS, normalWS, tangentWS, bitangentWS);

                float3 lightDirection = normalize(float3(0.3, 0.7, 0.5));
                float diffuseFactor = saturate(dot(blendedNormal, lightDirection));

                baseColor.rgb *= (0.2 + 0.8 * diffuseFactor); // Iluminación difusa simple

                #ifdef _USE_EMISSION
                    float4 emissionSample = SampleTriplanarColor(_EmissionTex, input.positionWS, normalWS);
                    baseColor.rgb += emissionSample.rgb * _EmissionColor.rgb;
                #endif

                return baseColor;
            }

            ENDCG
        }
    }
}
