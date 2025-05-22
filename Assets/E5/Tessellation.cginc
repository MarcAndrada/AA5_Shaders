// Activa la teselación sólo en plataformas compatibles
#if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
    #define UNITY_CAN_COMPILE_TESSELLATION 1
    #define UNITY_domain                 domain
    #define UNITY_partitioning           partitioning
    #define UNITY_outputtopology         outputtopology
    #define UNITY_patchconstantfunc      patchconstantfunc
    #define UNITY_outputcontrolpoints    outputcontrolpoints
#endif

struct VertexSOutput {
    float3 worldPos : TEXCOORD1;       // Posición en mundo del vértice
    float4 color : COLOR;              // Color del vértice
    float3 normal : NORMAL;            // Normal del vértice
    float4 vertex : SV_POSITION;       // Posición en clip space
    float2 uv : TEXCOORD0;             // Coordenadas UV
    float4 screenPos : TEXCOORD2;      // Posición en pantalla para efectos
    float3 viewDir : TEXCOORD3;        // Dirección hacia la cámara desde el vértice
};

float _Tess;
float _MaxTessDistance;

struct TessellationFactors {
    float edge[3] : SV_TessFactor;         // Teselación por borde
    float inside  : SV_InsideTessFactor;   // Teselación interior
};

struct Attributes {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 uv     : TEXCOORD0;
    float4 color  : COLOR;
};

struct ControlPoint {
    float4 vertex : INTERNALTESSPOS;
    float2 uv     : TEXCOORD0;
    float4 color  : COLOR;
    float3 normal : NORMAL;
};

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}

float ColorCalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess, float4 color) {
    float3 worldPosition = mul(unity_ObjectToWorld, vertex).xyz;
    float dist = distance(worldPosition, _WorldSpaceCameraPos.xyz);
    float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0);

    // Si el canal rojo es muy bajo, fuerza mínima teselación
    if (color.r < 0.1) {
        f = 0.01;
    }

    return f * tess;
}

uniform float3 _Position;
uniform float _OrthographicCamSize;
uniform sampler2D _GlobalEffectRT;
uniform sampler2D _Mask;
uniform float _SnowHeight;
uniform float _SnowDepth;

TessellationFactors patchConstantFunction(InputPatch<ControlPoint, 3> patch) {
    float minDist = 5.0;
    float maxDist = _MaxTessDistance;

    TessellationFactors f;

    float edge0 = ColorCalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess, patch[0].color);
    float edge1 = ColorCalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess, patch[1].color);
    float edge2 = ColorCalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess, patch[2].color);

    // Promedio entre bordes para suavizar el nivel de subdivisión
    f.edge[0] = (edge1 + edge2) * 0.5;
    f.edge[1] = (edge2 + edge0) * 0.5;
    f.edge[2] = (edge0 + edge1) * 0.5;

    f.inside  = (edge0 + edge1 + edge2) / 3.0;

    return f;
}

VertexSOutput vert(Attributes input)
{
    VertexSOutput output;

    float3 worldPosition = mul(unity_ObjectToWorld, input.vertex).xyz;

    // Mapea posición en mundo a UV relativas a una cámara ortográfica
    float2 uv = (worldPosition.xz - _Position.xz) / (_OrthographicCamSize * 2.0) + 0.5;

    // Obtiene máscara y efecto desde texturas globales
    float mask = tex2Dlod(_Mask, float4(uv, 0, 0)).a;
    float4 RTEffect = tex2Dlod(_GlobalEffectRT, float4(uv, 0, 0)) * mask;

    // Calcula dirección de vista
    output.viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPosition);

    // Eleva el terreno según la normal y la cantidad de nieve (basada en color.r)
    input.vertex.xyz += normalize(input.normal) *
        saturate((input.color.r * _SnowHeight) + (input.color.r));

    // Baja el terreno según la intensidad del canal verde del efecto y el color.r
    input.vertex.xyz -= normalize(input.normal) *
        saturate(RTEffect.g * saturate(input.color.r)) * _SnowDepth;

    // Transforma posición final a clip space
    output.vertex = UnityObjectToClipPos(input.vertex);
    output.worldPos = worldPosition;

    // Calcula coordenadas de pantalla
    float4 clipvertex = output.vertex / output.vertex.w;
    output.screenPos = ComputeScreenPos(clipvertex);

    output.color = input.color;

    // Modifica la normal para efectos visuales (sobreelevación por nieve)
    output.normal = saturate(input.normal);
    output.normal.y += RTEffect.g * input.color.r * 0.4;

    output.uv = input.uv;

    return output;
}

[UNITY_domain("tri")]
VertexSOutput domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
    Attributes v;

    // Interpolación manual de todos los campos
    #define Tesselationing(fieldName) \
    v.fieldName = \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;

    Tesselationing(vertex)
    Tesselationing(uv)
    Tesselationing(color)
    Tesselationing(normal)

    return vert(v);
}
