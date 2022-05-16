using UnityEngine;
using System.Collections;
using System;

[ExecuteInEditMode]
public class ShaderSetup : MonoBehaviour
{
    private Material material;

    [Header("sphere marching")]
    [Range(1, 400)]
    public float maxDst = 200;
    [Range(0.01f, 0.0001f)]
    public float epsilon = 0.003f;

    [Header("mandelbulb")]
    [Range(0f, 8f)]
    public float MandelbulbPower = 8;
    [Range(2, 100)]
    public int MandelbulbIterations = 50;

    [Header("colors")]
    [Range(0f, 1f)]
    public float Hue = 0.72f;
    public bool NormalsAsColor = false;

    [Header("lighting and shadows")]
    public Transform lightdirection;
    public Texture SkyboxTexture;

    [Space(20)]

    public bool SoftShadows = true;
    [Range(0.1f, 1f)]
    public float ShadowAccuracy = 1.0f;
    [Range(128, 1024)]
    public float ShadowSharpness = 512;

    [Space(20)]

    public bool AmbientOcclusion = true;

    [Space(20)]

    public bool Reflections = true;
    [Range(0.0f, 1f)]
    public float reflectiveness = 0.5f;

    private bool UpdatePowerOverTime = false;
    float UpdatedValue = 2;
    bool GoingUp = true;


    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            maxDst = 200;
            epsilon = 0.003f;

            MandelbulbPower = 8;
            MandelbulbIterations = 50;

            Hue = 0.72f;
            NormalsAsColor = false;

            SoftShadows = true;
            ShadowAccuracy = 1.0f;
            ShadowSharpness = 512;
            AmbientOcclusion = true;
            Reflections = true;
            reflectiveness = 0.5f;

            UpdatePowerOverTime = false;
        }

        if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            maxDst = 400;
            epsilon = 0.001f;

            MandelbulbPower = 3;
            MandelbulbIterations = 50;

            Hue = 0.4f;
            NormalsAsColor = true;

            SoftShadows = false;
            ShadowAccuracy = 1.0f;
            ShadowSharpness = 512;
            AmbientOcclusion = true;
            Reflections = false;
            reflectiveness = 0.5f;

            UpdatePowerOverTime = false;
        }

        if (Input.GetKeyDown(KeyCode.Alpha3))
        {
            maxDst = 400;
            epsilon = 0.0001f;

            MandelbulbPower = 2;
            MandelbulbIterations = 50;

            Hue = 0.25f;
            NormalsAsColor = false;

            SoftShadows = false;
            ShadowAccuracy = 1.0f;
            ShadowSharpness = 512;
            AmbientOcclusion = true;
            Reflections = false;
            reflectiveness = 0.5f;

            UpdatePowerOverTime = true;
        }

        if (UpdatedValue >= 8)
        {
            GoingUp = false;
        }
        if (UpdatedValue <= 2)
        {
            GoingUp = true;
        }

        if (GoingUp)
        {
            UpdatedValue += 0.5f * Time.deltaTime;
        }
        if (!GoingUp)
        {
            UpdatedValue -= 0.5f * Time.deltaTime;
        }

        if (UpdatePowerOverTime)
        {
            MandelbulbPower = UpdatedValue;
        }
        else
        {
            UpdatedValue = 2;
        }
    }

    void Awake()
    {
        material = new Material(Shader.Find("Hidden/RayMarchingShader"));
    }

    void SetParameters()
    {
        if (lightdirection == null)
        {
            lightdirection = GameObject.FindGameObjectWithTag("MainLight").transform;
        }

        material.SetTexture("_SkyboxTexture", SkyboxTexture);
        material.SetMatrix("_CTW", Camera.main.cameraToWorldMatrix);
        material.SetMatrix("_PMI", Camera.main.projectionMatrix.inverse);
        material.SetFloat("maxDst", maxDst);
        material.SetFloat("epsilon", epsilon);
        material.SetFloat("MandelbulbPower", MandelbulbPower);
        material.SetInt("MandelbulbIterations", MandelbulbIterations);
        material.SetInt("NormalsAsColor", Convert.ToInt32(NormalsAsColor));
        material.SetVector("rgb", new Vector3(Color.HSVToRGB(Hue, 0.2f, 1).g, Color.HSVToRGB(Hue, 0.2f, 1).r, Color.HSVToRGB(Hue, 0.2f, 1).b));
        material.SetFloat("skyboxBrightness", 1);
        material.SetVector("lightdirection", Quaternion.Euler(lightdirection.rotation.eulerAngles) * Vector3.back);
        material.SetFloat("shadowbias", epsilon / ShadowAccuracy);
        material.SetFloat("k", ShadowSharpness);
        material.SetInt("SoftShadows", Convert.ToInt32(SoftShadows));
        material.SetInt("HardShadows", 0);
        material.SetInt("AmbientOcclusion", Convert.ToInt32(AmbientOcclusion));
        material.SetInt("Reflections", Convert.ToInt32(Reflections));
        material.SetFloat("reflectiveness", reflectiveness);
    }

    // Postprocess the image
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        SetParameters();
        Graphics.Blit(source, destination, material);
    }
}
