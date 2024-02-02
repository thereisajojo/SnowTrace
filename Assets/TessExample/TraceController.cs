using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

public class TraceController : MonoBehaviour
{
    // public RenderTexture TraceRT;
    public Camera TraceCamera;
    public float SnowThickness;

    private RenderTexture TraceRT1;
    private RenderTexture TraceRT2;

    private void OnEnable()
    {
        TraceCamera.enabled = true;

        TraceRT1 = RenderTexture.GetTemporary(512, 512, 0, RenderTextureFormat.RFloat);
        TraceRT1.filterMode = FilterMode.Bilinear;
        TraceRT1.name = "TraceRT_1";
        // TraceRT1.useMipMap = true;
        TraceRT2 = RenderTexture.GetTemporary(TraceRT1.descriptor);
        TraceRT2.filterMode = FilterMode.Point;
        TraceRT2.name = "TraceRT_2";
        // TraceRT2.useMipMap = true;

        CommandBuffer cmd = CommandBufferPool.Get();
        cmd.SetRenderTarget(TraceRT1);
        cmd.ClearRenderTarget(RTClearFlags.All, Color.black, 1, 0);
        cmd.SetRenderTarget(TraceRT2);
        cmd.ClearRenderTarget(RTClearFlags.All, Color.black, 1, 0);
        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
        
        TraceCamera.targetTexture = TraceRT1;
        Shader.SetGlobalTexture("_LastTraceTex", TraceRT2);
    }

    private void OnDisable()
    {
        if (TraceCamera)
        {
            TraceCamera.targetTexture = null;
            TraceCamera.enabled = false;
        }
        
        RenderTexture.ReleaseTemporary(TraceRT1);
        RenderTexture.ReleaseTemporary(TraceRT2);
    }

    private void Update()
    {
        Graphics.CopyTexture(TraceRT1, 0, 0, TraceRT2, 0, 0);
        Shader.SetGlobalFloat("_SnowThickness", SnowThickness);
        /*
        CommandBuffer cmd = CommandBufferPool.Get("Copy Trace Depth");
        // cmd.Blit(TraceRT1, TraceRT2);
        cmd.CopyTexture(TraceRT1, TraceRT2);
        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
        */
    }
}
