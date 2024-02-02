Shader "Snow"
{
    Properties
    {
        _Color("Color(RGB)",Color) = (1,1,1,1)
        _TopTex("Top Map",2D) = "white"{}
        _BottomTex("Bottom Map", 2D) = "gray"{}
        _NormalMap("Normal Map", 2D) = "bump"{}
        _NoiseMap("Snow Noise Map", 2D) = "black"{}
        _NoiseStrength("Noise Strength", Float) = 1
        
        [Header(Tessellation)]
        _Tess("Tessellation", Range(1, 32)) = 20
        _MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
        
        //[Header(Trail)]
        //_Trail("Trail", 2D) = "black"{}
        //_TrailFactor("Center", Vector) = (0,0,1,1)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry+0"
        }
        
        Pass
        {
            Name "Pass"
            Tags 
            { 
                "LightMode"="UniversalForward"
            }
            
            // Render State
            Blend One Zero, One Zero
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM

            #pragma require tessellation
            #pragma require geometry
            
            #pragma vertex BeforeTessVertProgram
            #pragma hull HullProgram
            #pragma domain DomainProgram
            #pragma fragment FragmentProgram

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.6

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal@12.1.7/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            float _NoiseStrength;
            float _Tess;
            float _MaxTessDistance;
            float _MinTessDistance;
            CBUFFER_END
            
			TEXTURE2D(_TopTex);          SAMPLER(sampler_TopTex);
            TEXTURE2D(_BottomTex);        SAMPLER(sampler_BottomTex);
            TEXTURE2D(_NormalMap);        SAMPLER(sampler_NormalMap);
            TEXTURE2D(_NoiseMap);         SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_SnowTraceTexture); SAMPLER(sampler_SnowTraceTexture);

            float4 _TopTex_ST;
            float4 _SnowTraceTexture_TexelSize;
            float _SnowThickness;

            // 顶点着色器的输入
            struct Attributes
            {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
                float4 color   : COLOR;
            };

            // 片段着色器的输入
            struct Varyings
            {
                float4 vertex      : SV_POSITION;
                float4 color       : COLOR;
                float2 uv          : TEXCOORD0;
                float3 posWS       : TEXCOORD1;
                float4 normalWS    : TEXCOORD2;
                float4 tangentWS   : TEXCOORD3;
                float4 bitangentWS : TEXCOORD4;
            };

            // 为了确定如何细分三角形，GPU使用了四个细分因子。三角形面片的每个边缘都有一个因数。
            // 三角形的内部也有一个因素。三个边缘向量必须作为具有SV_TessFactor语义的float数组传递。
            // 内部因素使用SV_InsideTessFactor语义
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside  : SV_InsideTessFactor;
            };

            // 该结构的其余部分与Attributes相同，只是使用INTERNALTESSPOS代替POSITION语意，否则编译器会报位置语义的重用
            struct ControlPoint
            {
                float4 vertex  : INTERNALTESSPOS;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
                float4 color   : COLOR;
            };

            // 顶点着色器，此时只是将Attributes里的数据递交给曲面细分阶段
            ControlPoint BeforeTessVertProgram(Attributes v)
            {
                ControlPoint p;
        
                p.vertex = v.vertex;
                p.uv = v.uv;
                p.normal = v.normal;
                p.tangent = v.tangent;
                p.color = v.color;
        
                return p;
            }

            // 随着距相机的距离减少细分数
            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPosition = TransformObjectToWorld(vertex.xyz);
                float dist = distance(worldPosition,  GetCameraPositionWS());
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return (f);
            }
            
            // Patch Constant Function决定Patch的属性是如何细分的。这意味着它每个Patch仅被调用一次，
            // 而不是每个控制点被调用一次。这就是为什么它被称为常量函数，在整个Patch中都是常量的原因。
            // 实际上，此功能是与HullProgram并行运行的子阶段。
            // 三角形面片的细分方式由其细分因子控制。我们在MyPatchConstantFunction中确定这些因素。
            // 当前，我们根据其距离相机的位置来设置细分因子
            TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;
            
                TessellationFactors f;
            
                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);
            
                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            //细分阶段非常灵活，可以处理三角形，四边形或等值线。我们必须告诉它必须使用什么表面并提供必要的数据。
            //这是 hull 程序的工作。Hull 程序在曲面patch上运行，该曲面patch作为参数传递给它。
            //我们必须添加一个InputPatch参数才能实现这一点。Patch是网格顶点的集合。必须指定顶点的数据格式。
            //现在，我们将使用ControlPoint结构。在处理三角形时，每个patch将包含三个顶点。此数量必须指定为InputPatch的第二个模板参数
            //Hull程序的工作是将所需的顶点数据传递到细分阶段。尽管向其提供了整个patch，
            //但该函数一次仅应输出一个顶点。patch中的每个顶点都会调用一次它，并带有一个附加参数，
            //该参数指定应该使用哪个控制点（顶点）。该参数是具有SV_OutputControlPointID语义的无符号整数。
            [domain("tri")]//明确地告诉编译器正在处理三角形，其他选项：
            [outputcontrolpoints(3)]//明确地告诉编译器每个patch输出三个控制点
            [outputtopology("triangle_cw")]//当GPU创建新三角形时，它需要知道我们是否要按顺时针或逆时针定义它们
            [partitioning("fractional_odd")]//告知GPU应该如何分割patch，现在，仅使用整数模式
            [patchconstantfunc("MyPatchConstantFunction")]//GPU还必须知道应将patch切成多少部分。这不是一个恒定值，每个patch可能有所不同。必须提供一个评估此值的函数，称为patch常数函数（Patch Constant Functions）
            ControlPoint HullProgram(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

			Varyings AfterTessVertProgram (Attributes v)
			{
				Varyings o;

                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS.y += _SnowThickness;
                float4 traceTex = SAMPLE_TEXTURE2D_LOD(_SnowTraceTexture, sampler_SnowTraceTexture, v.uv, 0);
                o.posWS.y -= traceTex.a;
                
				o.vertex = TransformWorldToHClip(o.posWS.xyz);
                
				o.uv = TRANSFORM_TEX(v.uv, _TopTex);

                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);
                half3 viewDirWS = GetWorldSpaceViewDir(o.posWS);
                o.normalWS = half4(normalInput.normalWS, viewDirWS.x);
                o.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
                o.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);

                o.color = 0;

                return o;
			}

            //HUll着色器只是使曲面细分工作所需的一部分。一旦细分阶段确定了应如何细分patch，
            //则由Domain着色器来评估结果并生成最终三角形的顶点。
            //Domain程序将获得使用的细分因子以及原始patch的信息，原始patch在这种情况下为OutputPatch类型。
            //细分阶段确定patch的细分方式时，不会产生任何新的顶点。相反，它会为这些顶点提供重心坐标。
            //使用这些坐标来导出最终顶点取决于域着色器。为了使之成为可能，每个顶点都会调用一次域函数，并为其提供重心坐标。
            //它们具有SV_DomainLocation语义。
            //在Demain函数里面，我们必须生成最终的顶点数据。
            [domain("tri")] //Hull着色器和Domain着色器都作用于相同的域，即三角形。我们通过domain属性再次发出信号
            Varyings DomainProgram(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes v;

                //为了找到该顶点的位置，我们必须使用重心坐标在原始三角形范围内进行插值。
                //X，Y和Z坐标确定第一，第二和第三控制点的权重。
                //以相同的方式插值所有顶点数据。让我们为此定义一个方便的宏，该宏可用于所有矢量大小。
                #define DomainInterpolate(fieldName) v.fieldName = \
                        patch[0].fieldName * barycentricCoordinates.x + \
                        patch[1].fieldName * barycentricCoordinates.y + \
                        patch[2].fieldName * barycentricCoordinates.z;

                //对位置、颜色、UV、法线等进行插值
                DomainInterpolate(vertex)
                DomainInterpolate(uv)
                DomainInterpolate(color)
                DomainInterpolate(normal)
                DomainInterpolate(tangent)

                //现在，我们有了一个新的顶点，该顶点将在此阶段之后发送到几何程序或插值器。
                //但是这些程序需要Varyings数据，而不是Attributes。为了解决这个问题，
                //我们让域着色器接管了原始顶点程序的职责。
                //这是通过调用其中的AfterTessVertProgram（与其他任何函数一样）并返回其结果来完成的。
                return AfterTessVertProgram(v);
            }

            #define planeWidth 20

            float3 FindNormal(float2 uv)
            {
                float u = _SnowTraceTexture_TexelSize.x * 1;
                
                float2 offsets[4];
                offsets[0] = uv + float2(u, 0);
                offsets[1] = uv + float2(-u, 0);
                offsets[2] = uv + float2(0, u);
                offsets[3] = uv + float2(0, -u);

                float hts[4];
                for (int j = 0; j < 4; j++)
                {
                    hts[j] = SAMPLE_TEXTURE2D(_SnowTraceTexture, sampler_SnowTraceTexture, float2(offsets[j].x, offsets[j].y)).a;
                }

                float3 x = float3(u * planeWidth, (hts[0] - hts[1]), 0);
                float3 y = float3(0, (hts[2] - hts[3]), u * planeWidth);
                return normalize(cross(y, x));

                // float3 n;
                // n.x = -(hts[0] - hts[1]);
                // n.z = (hts[2] - hts[3]);
                // n.y = 0.5;
                // return normalize(n);
            }

            // 片段着色器
            half4 FragmentProgram(Varyings i) : SV_TARGET
            {
                half3 topColor = SAMPLE_TEXTURE2D(_TopTex, sampler_TopTex, i.uv).rgb;
                half3 bottomColor = SAMPLE_TEXTURE2D(_BottomTex, sampler_BottomTex, i.uv).rgb;
                bottomColor = 0.5;

                float lerpVal = smoothstep(0, _SnowThickness * 0.1, i.posWS.y);
                half3 albedo = lerp(_Color.rgb, topColor, lerpVal);

                float4 normalTex = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv);
                float3 normalTS = UnpackNormalScale(normalTex, 1);
                float3x3 tangentToWorld = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
                float3 localNormalWS = TransformTangentToWorld(normalTS, tangentToWorld);

                float3 traceNormalWS = FindNormal(i.uv);

                float4 traceTex = SAMPLE_TEXTURE2D(_SnowTraceTexture, sampler_SnowTraceTexture, i.uv);

                float3 normalWS = traceTex.a == 0 ? localNormalWS : traceNormalWS;

                Light light = GetMainLight();
                half3 attenuatedLightColor = half3(1,1,1) * 0.2 + light.distanceAttenuation;
                half3 lightColor = LightingLambert(attenuatedLightColor, light.direction, normalWS);
                lightColor *= albedo;
                
                return half4(lightColor, 1.0);
            }

            ENDHLSL
        }
    }
}