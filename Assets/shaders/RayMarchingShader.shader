Shader "Hidden/RayMarchingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
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

            //variables
            float maxDst;
            float epsilon;
            float MandelbulbPower;
            int MandelbulbIterations;
            float3 rgb;
            int NormalsAsColor;
            float skyboxBrightness;
            float3 lightdirection;
            float shadowbias;
            float k;
            int SoftShadows;
            int HardShadows;
            int Reflections;
            int AmbientOcclusion;
            float reflectiveness;
            Texture2D<float4> _SkyboxTexture;
            SamplerState sampler_SkyboxTexture;
            static const float PI = 3.14159265f;
            float4x4 _CTW;
            float4x4 _PMI;


            // distance estimators and their normals

            float SphereDistance(float3 eye, float3 centre, float radius) 
            {
                return distance(eye, centre) - radius;
            }

            float RepeatedSphereDistance(float3 eye, float3 centre, float radius, float repetitionperiod)
            {
                float3 c = float3(repetitionperiod, repetitionperiod, repetitionperiod);
                float3 q = fmod(eye + 0.5 * c, c) - 0.5 * c;
                return SphereDistance(q, centre, radius);
            }

            float3 EstimateSphereNormal(float3 p)
            {
                float centerDistance = RepeatedSphereDistance(p, float3(0, 0, 0), 1, 3);
                float xDistance = RepeatedSphereDistance(p + float3(epsilon, 0, 0), float3(0, 0, 0), 1, 3);
                float yDistance = RepeatedSphereDistance(p + float3(0, epsilon, 0), float3(0, 0, 0), 1, 3);
                float zDistance = RepeatedSphereDistance(p + float3(0, 0, epsilon), float3(0, 0, 0), 1, 3);
                return (float3(xDistance, yDistance, zDistance) - centerDistance) / epsilon;
            }

            float MandelbulbDistance(float3 pos)
            {
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;
                for (int i = 0; i < MandelbulbIterations; i++) 
                {
                    r = length(z);
                    if (r > 2) 
                    {
                        break;
                    }

                    // convert to polar coordinates
                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, MandelbulbPower - 1.0) * MandelbulbPower * dr + 1.0;

                    // scale and rotate the point
                    float zr = pow(r, MandelbulbPower);
                    theta = theta * MandelbulbPower;
                    phi = phi * MandelbulbPower;

                    // convert back to cartesian coordinates
                    z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
                    z += pos;
                }
                return 0.5 * log(r) * r / dr;
            }

            float3 EstimateMandelbulbNormal(float3 p, float3 dir)
            {
                float3 xDir = float3(epsilon, 0, 0);
                float3 yDir = float3(0, epsilon, 0);
                float3 zDir = float3(0, 0, epsilon);

                return normalize(float3(
                    MandelbulbDistance(p + xDir) - MandelbulbDistance(p - xDir),
                    MandelbulbDistance(p + yDir) - MandelbulbDistance(p - yDir),
                    MandelbulbDistance(p + zDir) - MandelbulbDistance(p - zDir)
                    ));
            }


            // ray creation

            struct Ray
            {
                float3 origin;
                float3 direction;
            };

            Ray CreateRay(float3 origin, float3 direction) 
            {
                Ray ray;
                ray.origin = origin;
                ray.direction = direction;
                return ray;
            } 

            Ray CreateCameraRay(float2 uv) 
            {
                float3 origin = mul(_CTW, float4(0, 0, 0, 1)).xyz; // The CoP of the camera
                float3 fragPos = mul(_PMI, float4(uv * 2 - 1, 0, 1)).xyz; // Frag's camera coords
                float3 direction = normalize(mul(_CTW, float4(fragPos, 0)).xyz);
                return CreateRay(origin, direction);
            }


            // shader options

            float calcsoftshadow(float3 ro, float3 rd)
            {
                float res = 1;
                int iter = 1;
                float dst = shadowbias;
                float multiplier = 1;
                float ph = 1;
                ro += shadowbias * -rd;

                while (iter < maxDst)
                {
                    dst = MandelbulbDistance(ro);

                    if (dst < epsilon)
                    {
                        return 0.0;
                    }

                    float y = dst * dst / (2.0 * ph);
                    float d = sqrt(dst * dst - y * y);
                    res = min(res, k * dst / max(0.0, iter - y));
                    ph = dst;
                    ro += lightdirection * dst;
                    iter++;
                }
                return res * multiplier;
            }

            float calchardshadow(float3 ro, float3 rd)
            {
                int iter = 1;
                float dst = shadowbias;
                ro += shadowbias * -rd;

                while (iter < maxDst)
                {
                    dst = MandelbulbDistance(ro);

                    if (dst < epsilon)
                    {
                        return 0.0;
                    }

                    ro += lightdirection * dst;
                    iter++;
                }
                return 1.0;
            }

            float3 calcreflections(float3 ro, float3 rd, float3 normal)
            {
                rd = reflect(rd, normal);
                float theta = acos(rd.y) / -PI;
                float phi = atan2(rd.x, -rd.z) / -PI * 0.5f;
                return _SkyboxTexture.SampleLevel(sampler_SkyboxTexture, float2(phi, theta), 0);
            }


            // pixel shader

            fixed4 frag (v2f i) : SV_Target
            {
                uint width, height;
                Ray ray = CreateCameraRay(i.uv);
                int iter = 0;
                float3 startpos = ray.origin;
                float3 startdir = ray.direction;

                while (iter < maxDst)
                {
                    float dst = MandelbulbDistance(ray.origin);
                    //float dst = sphereSDF(ray.origin);
                    
                    if (dst <= epsilon)
                    {
                        // other
                        if (NormalsAsColor == 1)
                        {
                            float3 normal = EstimateMandelbulbNormal(ray.origin, ray.direction * epsilon);
                            rgb = (normal * 0.5 + 0.5);
                        }

                        // float
                        float effects = 1;
                        if (SoftShadows == 1)
                        {
                            float shadow = calcsoftshadow(ray.origin, ray.direction);
                            effects *= shadow;
                        }
                        if (HardShadows == 1)
                        {
                            float shadow = calchardshadow(ray.origin, ray.direction);
                            effects *= shadow;
                        }
                        if (AmbientOcclusion == 1)
                        {
                            float ao = 1 - (float)iter / (float)maxDst;
                            effects *= ao;
                        }

                        // float3
                        float3 effects3 = float3(1, 1, 1);
                        float3 reflection = float3(1, 1, 1);
                        if (Reflections == 1)
                        {
                            float3 normal = EstimateMandelbulbNormal(ray.origin, ray.direction * epsilon);
                            reflection = calcreflections(ray.origin, ray.direction, normal);
                            reflection = lerp(1, reflection, reflectiveness);
                            effects3 *= reflection;
                        }

                        
                        return float4(rgb * effects * effects3, 1);
                        break;
                    }
                    ray.origin += ray.direction * dst;
                    iter++;
                }

                // Sample the skybox and write it
                float theta = acos(ray.direction.y) / -PI;
                float phi = atan2(ray.direction.x, -ray.direction.z) / -PI * 0.5f;
                return _SkyboxTexture.SampleLevel(sampler_SkyboxTexture, float2(phi, theta), 0);
            }
            ENDCG
        }
    }
}
