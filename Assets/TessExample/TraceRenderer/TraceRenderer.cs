using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TraceRenderer : ScriptableRenderer
{
    private TraceDepthPass m_TraceDepthPass;
    private GetNormalPass m_GetNormalPass;
    private Material m_DepthMaterial;
    private Material m_NormalMaterial;

    private static readonly string traceShaderName = "Trace/TraceDepth";
    private static readonly string normalShaderName = "Hidden/TraceImageShader";
    
    public TraceRenderer(TraceRendererData data) : base(data)
    {
        var traceShader = Shader.Find(traceShaderName);
        if (traceShader == null)
        {
            Debug.LogWarning($"dont find shader: {traceShaderName}");
            return;
        }

        var normalShader = Shader.Find(normalShaderName);
        if (normalShader == null)
        {
            Debug.LogWarning($"dont find shader: {normalShaderName}");
            return;
        }
        
        m_DepthMaterial = new Material(traceShader);
        m_TraceDepthPass = new TraceDepthPass(data.opaqueLayerMask, m_DepthMaterial);
        m_NormalMaterial = new Material(normalShader);
        m_GetNormalPass = new GetNormalPass(m_NormalMaterial);
    }

    public override void Setup(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        Camera camera = renderingData.cameraData.camera;
        ref CameraData cameraData = ref renderingData.cameraData;
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;

        EnqueuePass(m_TraceDepthPass);
        EnqueuePass(m_GetNormalPass);

        for (int i = 0; i < rendererFeatures.Count; ++i)
        {
            if (rendererFeatures[i].isActive)
                rendererFeatures[i].AddRenderPasses(this, ref renderingData);
        }
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(m_DepthMaterial);
        CoreUtils.Destroy(m_NormalMaterial);
    }
}

public class TraceDepthPass : ScriptableRenderPass
{
    private Material overrideMat;
    private FilteringSettings filtering;

    private static ShaderTagId shaderTagId = new ShaderTagId("UniversalForward");
    
    public TraceDepthPass(LayerMask layerMask, Material mat)
    {
        overrideMat = mat;
        filtering = new FilteringSettings(RenderQueueRange.opaque, layerMask);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        DrawingSettings draw = CreateDrawingSettings(shaderTagId, ref renderingData, SortingCriteria.CommonOpaque);
        draw.overrideMaterial = overrideMat;
        draw.overrideMaterialPassIndex = 0;
        context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
    }
}

public class GetNormalPass : ScriptableRenderPass
{
    private Material NormalMat;
    private static int m_SnowTraceTextureId = Shader.PropertyToID("_SnowTraceTexture");
    private static int m_TempTextureId = Shader.PropertyToID("_SnowTempTexture");

    public GetNormalPass(Material mat)
    {
        NormalMat = mat;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var des = renderingData.cameraData.cameraTargetDescriptor;
        int width = des.width;
        int height = des.height;
        cmd.GetTemporaryRT(m_SnowTraceTextureId, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGBFloat);
        cmd.GetTemporaryRT(m_TempTextureId, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGBFloat);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var target = renderingData.cameraData.targetTexture;
        var cmd = CommandBufferPool.Get("Get Normal");
        cmd.Blit(target, m_TempTextureId, NormalMat, 1);
        cmd.Blit(m_TempTextureId, m_SnowTraceTextureId, NormalMat, 0);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(m_SnowTraceTextureId);
        cmd.ReleaseTemporaryRT(m_TempTextureId);
    }
}
