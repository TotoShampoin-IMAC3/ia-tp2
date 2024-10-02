// Credit
// ===================================================================================================================
// Raymarching shader. The shader uses code from two sources. One articles by iq https://www.iquilezles.org/www/articles/terrainmarching/terrainmarching.htm
// Another source is for the PBR lighting, the lighting is abit of an over kills, https://github.com/Nadrin/PBR/blob/master/data/shaders/hlsl/pbr.hlsl
// ===================================================================================================================

Shader "Unlit/Mandelbuld"
{
    Properties
    {
        // Color property for material inspector, default to white
        _Color1("Color 1", Color) = (0,0,0,1)
        _Color2("Color 2", Color) = (1,1,1,1)
        _Power("Power", Range(1, 10)) = 3
        _RaymarchIter("RaymarchIter", Range(1, 500)) = 300
        _MandelIter("MandelIter", Range(1, 50)) = 20
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
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
                int iter;
                float distance;
                float3 position;
                float3 normal;
            };

            bool IsInCube(float3 p, float3 size) {
                if(p.x < -size.x || p.x > size.x) return false;
                if(p.y < -size.y || p.y > size.y) return false;
                if(p.z < -size.z || p.z > size.z) return false;
                return true;
            }

            float _Power;
            float _RaymarchIter;
            float _MandelIter;
            #define SIZE .4

            // https://www.shadertoy.com/view/wstcDN
            float SdfMandelbulb(float3 position) {
                float Power = _Power;
                int steps = 0;
                float3 pos = position;
                pos = pos / SIZE;
                float3 z = pos;
                float dr = 2.0 / SIZE;
                float r = 0.0;
                for (int i = 0; i < _MandelIter; i++) { 
                    r = length(z);
                    steps = i;
                    if (r > 4.0) break;
                    
                    // convert to polar coordinates
                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, Power - 1.0) * Power * dr + 1.0;
                    
                    // scale and rotate the point
                    float zr = pow(r, Power);
                    theta = theta * Power;
                    phi = phi * Power;
                    
                    // convert back to cartesian coordinates
                    z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
                    z += pos;
                }
            
                return 0.5*log(r)*r/dr;
            }

            float SdfMandelbulbWithNormal(float3 position, inout float3 normal) {
                float distance = SdfMandelbulb(position);

                float epsilon = 0.001;
                float3 dx = float3(epsilon, 0.0, 0.0);
                float3 dy = float3(0.0, epsilon, 0.0);
                float3 dz = float3(0.0, 0.0, epsilon);
            
                float distanceX = SdfMandelbulb(position + dx);
                float distanceY = SdfMandelbulb(position + dy);
                float distanceZ = SdfMandelbulb(position + dz);
            
                normal = normalize(float3(distanceX - distance, distanceY - distance, distanceZ - distance));
            
                return distance;
            }
            
            RayHit Raymarch(Ray ray) {
                bool hit = false;
                float distance = 0.0;
                float3 p = ray.origin;
                float3 normal = float3(0, 0, 0);
                int i = 0;
                for (; i < _RaymarchIter; i++) {
                    p = ray.origin + ray.direction * distance;
                    float d = SdfMandelbulb(p);
                    // float d = SdfMandelbulbWithNormal(p, normal);
                    distance += d;
                    if (d < 0.001) {
                        hit = true;
                        break;
                    }
                }
                RayHit hitInfo;
                hitInfo.hit = hit;
                hitInfo.iter = i;
                hitInfo.distance = distance;
                hitInfo.position = p;
                // hitInfo.normal = normal;
                hitInfo.normal = normalize(p);
                return hitInfo;
            }

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float4 objectWorldPos : TEXCOORD1;
            };

            v2f vert (float4 vertex : POSITION)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.objectWorldPos = mul(UNITY_MATRIX_M, float4(0, 0, 0, 1));
                return o;
            }

            fixed4 _Color1;
            fixed4 _Color2;

            fixed4 frag (v2f i) : SV_Target
            {
                float near = _ProjectionParams.y;
                float far = _ProjectionParams.z;    

                float2 uv = i.screenPos.xy / (i.screenPos.w) * 2 - 1;

                float4 color = float4(0., 0., 0., 0.);

                float4x4 invMV = mul(unity_WorldToObject, UNITY_MATRIX_I_V);
                float4x4 invMVP = mul(unity_WorldToObject, mul(UNITY_MATRIX_I_V, unity_CameraInvProjection));

                // float4 light_dir = unity_LightPosition[0];
                float4 light_dir = _WorldSpaceLightPos0;
                light_dir = mul(UNITY_MATRIX_V, light_dir);
                light_dir = normalize(light_dir);

                Ray ray;
                ray.origin = mul(invMVP, float4(uv, -1, 1) * near).xyz;
                ray.direction = mul(invMVP, float4(uv * (far - near), far + near, far - near)).xyz;
                ray.direction = normalize(ray.direction);

                RayHit hit = Raymarch(ray);
                float3 normal = hit.normal;
                normal = mul(UNITY_MATRIX_IT_MV, normal);
                normal = normalize(normal);


                if(hit.hit) {
                    float t = hit.iter / 300.;
                    float lambertian = dot(normal, light_dir.xyz) * 0.5 + 0.5;
                    color.rgb = lerp(_Color1, _Color2, pow(t, 1/2.2)) * lambertian;
                    // color.rgb = dot(normal, light_dir) * _Color1.rgb;
                    // color.rgb = hit.normal;
                    color.a = 1.;
                } else {
                    color = 0.;
                }

                return color;
            }
            ENDCG
        }

		// Pass to render object as a shadow caster
		Pass 
		{
			Name "CastShadow"
			Tags { "LightMode" = "ShadowCaster" }
	
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"
	
			struct v2f 
			{ 
				V2F_SHADOW_CASTER;
                float4 screenPos : TEXCOORD0;
			};
	
			v2f vert( appdata_base v )
			{
				v2f o;
				TRANSFER_SHADOW_CASTER(o)
				return o;
			}
	
			float4 frag( v2f i ) : COLOR
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
    }
}