using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class TraceGenerator : MonoBehaviour
{
    public Texture TraceTexture;
    public float TraceRange = 10;
    public float TraceWidth = 1f;
    public float FadeSpeed = 1f;
    [Range(0, 1)] public float EdgeFade = 0.6f;

    private RenderTexture m_TraceRT1;
    private RenderTexture m_TraceRT2;
    private Material m_TraceMaterial;
    private Vector3 m_LastFramePos;

    private void OnEnable()
    {
        Shader shader = Shader.Find("Hidden/TraceGenerator");
        if (shader == null)
        {
            Debug.LogWarning("missing shader: Hidden/TraceGenerator");
            enabled = false;
            return;
        }
        
        if (TraceTexture == null)
        {
            Debug.LogWarning("dont set trace texture");
            enabled = false;
            return;
        }
        
        m_TraceRT1 = RenderTexture.GetTemporary(1024, 1024, 0, GraphicsFormat.R16G16B16A16_UNorm);
        m_TraceRT1.wrapMode = TextureWrapMode.Clamp;
        m_TraceRT1.name = "TraceRT_1";
        m_TraceRT2 = RenderTexture.GetTemporary(m_TraceRT1.descriptor);
        m_TraceRT2.wrapMode = TextureWrapMode.Clamp;
        m_TraceRT2.name = "TraceRT_2";
        
        m_TraceMaterial = new Material(shader);
        m_LastFramePos = transform.position;
        
        Graphics.Blit(null, m_TraceRT1, m_TraceMaterial, 1);
        
        Shader.EnableKeyword("_SHOW_TRACE");
    }

    private void OnDisable()
    {
        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(m_TraceRT1);
        RenderTexture.ReleaseTemporary(m_TraceRT2);
        
        Shader.DisableKeyword("_SHOW_TRACE");
    }

    private void SwapRT()
    {
        (m_TraceRT1, m_TraceRT2) = (m_TraceRT2, m_TraceRT1);
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 position = transform.position;
        Shader.SetGlobalVector("_PlayerPos", position);
        Shader.SetGlobalFloat("_Range", TraceRange);
        Shader.SetGlobalFloat("_InvRange", 1f / TraceRange);
        
        m_TraceMaterial.SetTexture("_StepBump", TraceTexture);
        m_TraceMaterial.SetFloat("_TraceWidth", 1f / TraceWidth);
        m_TraceMaterial.SetFloat("_FadeSpeed", FadeSpeed * 0.001f);
        m_TraceMaterial.SetFloat("_EdgeFade", EdgeFade / 2f);
        m_TraceMaterial.SetVector("_DeltaPos", position - m_LastFramePos);
        Graphics.Blit(m_TraceRT1, m_TraceRT2, m_TraceMaterial, 0);
        Shader.SetGlobalTexture("_TraceTex", m_TraceRT2);
        SwapRT();
        
        m_LastFramePos = position;
    }
}
