Shader "Unlit/Sand"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BumpTex ("Bump", 2D) = "bump" {}
		//_TraceTex ("Trace", 2D) = "black" {}
        _TraceStrength ("Trace Strength", Float) = 8
 		_BumpScale ("BumpScale", Range(0,5)) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "SimpleLit" "IgnoreProjector" = "True" "ShaderModel"="4.5"}
        LOD 300

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _SHOW_TRACE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 texcoord   : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1; // xyz: posWS
                half4 normalWS    : TEXCOORD2; // xyz: normal, w: viewDir.x
                half4 tangentWS   : TEXCOORD3; // xyz: tangent, w: viewDir.y
                half4 bitangentWS : TEXCOORD4; // xyz: bitangent, w: viewDir.z
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpTex);
            SAMPLER(sampler_BumpTex);
            TEXTURE2D(_TraceTex);
            SAMPLER(sampler_TraceTex);
            float4 _MainTex_ST;
            float4 _PlayerPos;
            float _BumpScale;
            float _TraceStrength;
            float _InvRange;

            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
                output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
                output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
                output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);

                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.positionWS.xyz = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;
                
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                
                half4 normalTex = SAMPLE_TEXTURE2D(_BumpTex, sampler_BumpTex, input.uv);
                half3 localNormal = UnpackNormalScale(normalTex, _BumpScale);

                #if defined(_SHOW_TRACE)
                float2 traceUV = (input.positionWS.xz - _PlayerPos.xz) * _InvRange;
                if(length(traceUV) < 0.5)
                {
                    half4 traceTex = SAMPLE_TEXTURE2D(_TraceTex, sampler_TraceTex, traceUV + 0.5);
                    half lerpValue = traceTex.a;
                    half3 traceNormal = traceTex.rgb * 2 - 1;
                    traceNormal.xy *= _TraceStrength;
                    localNormal = lerp(localNormal, traceNormal, lerpValue);
                }
                #endif
                
                localNormal.xy *= _BumpScale;

                half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                half3 normalWS = TransformTangentToWorld(localNormal, tangentToWorld);
                normalWS = normalize(normalWS);

                float3 lightDir = normalize(_MainLightPosition.xyz);
				float nl = dot(normalWS, lightDir);
				float3 diff = pow(saturate(nl), 2.2);
				diff = lerp(lerp(float3(0.25,0.4,1), float3(0.7,0.3,0.05), diff.r), 1, diff.r);
				baseColor.rgb *= diff;

                return baseColor;
            }
            ENDHLSL
        }
    }
}
