Shader "Hidden/TraceGenerator"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_StepBump ("Step Bump", 2D) = "bump" {}
        //_FadeSpeed ("Fade Speed", Float) = 0.001
        //_EdgeFade ("Edge Fade", Float) = 0.3
    }
    
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "Trace"
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _StepBump;
            
            float _Range;
            float _InvRange; // 1 / _Range
            float _TraceWidth;
            float _FadeSpeed;
            float _EdgeFade;
            float3 _DeltaPos;

            half4 frag(v2f i) : SV_Target
            {
                half4 normal = half4(0.5, 0.5, 1, 0);

                float2 mianUV = i.uv + _DeltaPos.xz * _InvRange;
                half4 col = tex2D(_MainTex, mianUV);
                col = lerp(col, normal, _FadeSpeed);

                float2 uv = i.uv - 0.5;
                half4 stepCol1 = tex2D(_StepBump, uv * _Range * _TraceWidth * 1.5 + 0.5);
                half4 stepCol2 = tex2D(_StepBump, uv * _Range * _TraceWidth + 0.5);
                stepCol2.rg = 1 - stepCol2.rg;
                half4 stepCol = lerp(stepCol2, stepCol1, stepCol1.a);

                col = lerp(col, stepCol, saturate(stepCol.a - col.a));
                // float egde = step(abs(uv.x), 0.499) * step(abs(uv.y), 0.499);
                // col = lerp(normal, col, egde);

                // 移动时才计算边缘衰减
                if (_DeltaPos.x > 0.001 || _DeltaPos.z > 0.001)
                {
                    float len = length(uv);
                    float e = 1 - smoothstep(_EdgeFade, 0.5, len);
                    col = lerp(normal, col, e);
                }

                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Init"
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;

            half4 frag(v2f i) : SV_Target
            {
                return half4(0.5, 0.5, 1, 0);
            }
            ENDCG
        }
    }
}
