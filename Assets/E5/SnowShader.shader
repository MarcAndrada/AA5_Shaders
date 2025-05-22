Shader "Custom/SnowShader" {
    Properties {
        [Header(Tesselation)]
        _MaxTessDistance("Max Tessellation Distance", Range(10, 100)) = 50
        _Tess("Tessellation", Range(1, 32)) = 20

        [Space]
        [Header(Snow)]
        _SnowHeight("Snow Height", Range(0,2)) = 0.3
        _SnowDepth("Snow Path Depth", Range(-2,2)) = 0.3
        
        [Header(Top)]
        _Top_Albedo("Top Albedo", 2D) = "white" {}
        _Top_Normal("Top Normal", 2D) = "bump" {}
        _Top_Mask("Top Mask", 2D) = "white" {}

        [Header(Middle)]
        _Middle_Albedo("Middle Albedo", 2D) = "white" {}
        _Middle_Normal("Middle Normal", 2D) = "bump" {}
        _Middle_Mask("Middle Mask", 2D) = "white" {}

        [Header(Bottom)]
        _Bottom_Albedo("Bottom Albedo", 2D) = "white" {}
        _Bottom_Normal("Bottom Normal", 2D) = "bump" {}
        _Bottom_Mask("Bottom Mask", 2D) = "white" {}
        
        [Space]
        _Range("Blend Range", Range(0,1)) = 0.1
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "Tessellation.cginc"

    #pragma require tessellation tessHW
    #pragma vertex TessellationVertexProgram
    #pragma hull hull
    #pragma domain domain

    ControlPoint TessellationVertexProgram(Attributes v)
    {
        ControlPoint p;
        p.vertex = v.vertex;
        p.uv = v.uv;
        p.normal = v.normal;
        p.color = v.color;
        return p;
    }
    float4 HeightBlend3(float4 top, float4 middle, float4 bottom, float height, float range)
    {
        float topBlend = smoothstep(1.0 - range, 1.0, height);
        float middleBlend = smoothstep(0.5 - range, 0.5 + range, height);
        float bottomBlend = 1.0 - middleBlend - topBlend;

        return top * topBlend + middle * middleBlend + bottom * bottomBlend;
    }


    ENDCG


    SubShader {
        Tags { "RenderType" = "Opaque" }
        Pass {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #pragma fragment frag

            sampler2D _Top_Albedo, _Middle_Albedo, _Bottom_Albedo;
            float _Range, _TopStart, _MiddleStart;
            float _DepthMax, _Offset;
            float _MinHeight, _MaxHeight;

            float4 frag(VertexSOutput IN) : SV_Target {
                // Asegúrate de que las coordenadas UV estén bien mapeadas
                float2 uv = (IN.worldPos.xz - _Position.xz) / (_OrthographicCamSize * 2.0) + 0.5;

                // Ajustar el cálculo del enmascarado
                float mask = tex2D(_Mask, uv).a;
                float4 effect = tex2D(_GlobalEffectRT, uv) * mask;

                // Texturas
                float4 topAlbedo = tex2D(_Top_Albedo, uv);
                float4 middleAlbedo = tex2D(_Middle_Albedo, uv);
                float4 bottomAlbedo = tex2D(_Bottom_Albedo, uv);

                // Calcular altura y asegurar que esté entre 0 y 1
                float height = saturate((IN.worldPos.y - _MinHeight) / (_MaxHeight - _MinHeight));

                // Ajustar la mezcla de texturas
                float4 blended = HeightBlend3(
                    topAlbedo, 
                    middleAlbedo, 
                    bottomAlbedo, 
                    height, 
                    _Range
                );
                
                blended.rgb = lerp(blended.rgb, middleAlbedo.rgb * effect.g * 2, saturate(effect.g * 4));
                blended.rgb = lerp(blended.rgb, bottomAlbedo.rgb * effect.g * 2, saturate(effect.g * 1));
                
                return blended;
            }
            ENDCG
        }
    }

}
