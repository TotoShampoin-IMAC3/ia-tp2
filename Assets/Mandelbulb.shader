// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Credit
// ===================================================================================================================
// Raymarching shader. The shader uses code from two sources. One articles by iq https://www.iquilezles.org/www/articles/terrainmarching/terrainmarching.htm
// Another source is for the PBR lighting, the lighting is abit of an over kills, https://github.com/Nadrin/PBR/blob/master/data/shaders/hlsl/pbr.hlsl
// ===================================================================================================================


// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/Mandelbuld"
{
    Properties
    {
        // Color property for material inspector, default to white
        _Color ("Main Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
	      	#include "UnityCG.cginc"

            struct Ray {
                float3 origin;
                float3 direction;
            };
            struct RayHit {
                bool hit;
                float distance;
                float3 position;
                float3 normal;
            };

            struct Object {
                float3 position;
                float size;
            };
            float SdfSphere(Object s, float3 position) {
                return length(position - s.position) - s.size;
            }

            RayHit Raymarch(Ray ray, Object obj) {
                bool hit = false;
                float distance = 0.0;
                float3 p = ray.origin;
                float3 normal = float3(0, 0, 0);
                for (int i = 0; i < 100; i++) {
                    p = ray.origin + ray.direction * distance;
                    float d = SdfSphere(obj, p);
                    distance += d;
                    if (d < 0.001) {
                        hit = true;
                        normal = normalize(p - obj.position);
                    }
                }
                RayHit hitInfo;
                hitInfo.hit = hit;
                hitInfo.distance = distance;
                hitInfo.position = p;
                hitInfo.normal = mul(UNITY_MATRIX_I_V, normal);
                return hitInfo;
            }

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float4 objectViewPos : TEXCOORD1;
                Ray ray : TEXCOORD2;
            };

            v2f vert (float4 vertex : POSITION)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.objectViewPos = mul(UNITY_MATRIX_MV, float4(0, 0, 0, 1));
                return o;
            }

            fixed4 _Color;

            fixed4 frag (v2f i) : SV_Target
            {
                float time = _Time.y;
                float4 res = _ScreenParams;
                float3 lightViewDir = _WorldSpaceLightPos0;
                float near = _ProjectionParams.y;
                float far = _ProjectionParams.z;    

                float2 uv = i.screenPos.xy / (i.screenPos.w) * 2 - 1;

                float4 color = float4(0., 0., 0., 0.);

                Object obj;
                obj.position = i.objectViewPos.xyz;
                obj.size = .5;

                Ray ray;
                ray.origin = mul(unity_CameraInvProjection, float4(uv, -1, 1) * near).xyz;
                ray.direction = mul(unity_CameraInvProjection, float4(uv * (far - near), far + near, far - near)).xyz;
                ray.direction = normalize(ray.direction);

                RayHit hit = Raymarch(ray, obj);

                if(hit.hit) {
                    color.rgb = dot(hit.normal, lightViewDir);
                    color.a += 1.;
                } else {
                    color = 0.;
                }

                return color;
            }
            ENDCG
        }
    }
}
