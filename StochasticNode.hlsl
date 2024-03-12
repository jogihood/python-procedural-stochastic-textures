// Hash function equivalent in HLSL
float2 Hash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// Triangle grid calculation in HLSL
void TriangleGrid(float2 uv, out float w1, out float w2, out float w3, out int2 vertex1, out int2 vertex2, out int2 vertex3)
{
    uv *= 3.464; // 2 * sqrt(3)
    float2 skewedCoord = mul(float2x2(1.0, 0.0, -0.57735027, 1.15470054), uv);
    int2 baseId = (int2)floor(skewedCoord);
    float3 temp = float3(frac(skewedCoord), 0);
    temp.z = 1.0 - temp.x - temp.y;
    if (temp.z > 0.0)
    {
        w1 = temp.z;
        w2 = temp.y;
        w3 = temp.x;
        vertex1 = baseId;
        vertex2 = baseId + int2(0, 1);
        vertex3 = baseId + int2(1, 0);
    }
    else
    {
        w1 = -temp.z;
        w2 = 1.0 - temp.y;
        w3 = 1.0 - temp.x;
        vertex1 = baseId + int2(1, 1);
        vertex2 = baseId + int2(1, 0);
        vertex3 = baseId + int2(0, 1);
    }
}

// Main function adaptation for HLSL and Unity
float3 ProceduralTilingAndBlending(
    UnityTexture2D tex,
    UnitySamplerState ss,
    float2 uv,
    float tile)
{
    uv *= tile;
    float w1, w2, w3;
    int2 vertex1, vertex2, vertex3;
    TriangleGrid(uv, w1, w2, w3, vertex1, vertex2, vertex3);

    float2 uv1 = uv + Hash(vertex1);
    float2 uv2 = uv + Hash(vertex2);
    float2 uv3 = uv + Hash(vertex3);

    float3 I1 = tex.SampleGrad(ss, uv1, ddx(uv), ddy(uv)).rgb;
    float3 I2 = tex.SampleGrad(ss, uv2, ddx(uv), ddy(uv)).rgb;
    float3 I3 = tex.SampleGrad(ss, uv3, ddx(uv), ddy(uv)).rgb;

    return w1 * I1 + w2 * I2 + w3 * I3;
}

void TriplanarProceduralTiling_float(
    float3 worldPos, 
    float3 normal, 
    UnityTexture2D tex, 
    UnitySamplerState ss, 
    float tile,
    float blend, 
    out float3 combinedColor)
{
    // Calculate blend weights based on the normal and sharpening parameter
    float3 weights = pow(abs(normal), blend);
    weights /= dot(weights, float3(1.0, 1.0, 1.0)); // Normalize the weights

    // Procedurally modify and sample the single texture for each axis
    float3 proceduralColorX = ProceduralTilingAndBlending(tex, ss, worldPos.yz, tile);
    float3 proceduralColorY = ProceduralTilingAndBlending(tex, ss, worldPos.xz, tile);
    float3 proceduralColorZ = ProceduralTilingAndBlending(tex, ss, worldPos.xy, tile);

    // Combine the textures based on weights
    combinedColor = proceduralColorX * weights.x + proceduralColorY * weights.y + proceduralColorZ * weights.z;
}
