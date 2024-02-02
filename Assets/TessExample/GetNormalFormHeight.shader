Shader "Hidden/TraceImageShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        
        Pass // pass 0
        {
            Name "BlurDepth"
            
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            // Texture2D _MainTex;
            // SamplerState sampler_LinearClamp;
            // float4 _MainTex_TexelSize;
            //
            // float4 SampleTex_Linear(Texture2D texName, float2 uv)
            // {
            //     return texName.Sample(sampler_LinearClamp, uv);
            // }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float4 frag (v2f input) : SV_Target
            {
                float4 height = tex2D(_MainTex, input.uv);
                float offset = _MainTex_TexelSize.x;
                float4 h = height;
                h += tex2D(_MainTex, input.uv + float2(0, offset));
                h += tex2D(_MainTex, input.uv + float2(offset, offset));
                h += tex2D(_MainTex, input.uv + float2(offset, 0));
                h += tex2D(_MainTex, input.uv + float2(offset, -offset));
                h += tex2D(_MainTex, input.uv + float2(0, -offset));
                h += tex2D(_MainTex, input.uv + float2(-offset, -offset));
                h += tex2D(_MainTex, input.uv + float2(-offset, 0));
                h += tex2D(_MainTex, input.uv + float2(-offset, offset));
                
                return h / 9;
            }
            ENDCG
        }

        Pass // pass 1
        {
            Name "CombineNoise"
            
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            float4 frag (v2f i) : SV_Target
            {
                float height = tex2D(_MainTex, float2(1 - i.uv.x, i.uv.y)).r;

                return float4(height, height, height, height);
            }
            ENDCG
        }
    }
}
