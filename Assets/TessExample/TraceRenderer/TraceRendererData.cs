using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
#endif

[Serializable]
public class TraceRendererData : ScriptableRendererData
{
#if UNITY_EDITOR
    [MenuItem("Assets/Create/Rendering/URP Trace Renderer", priority = CoreUtils.Sections.section3 + CoreUtils.Priorities.assetsCreateRenderingMenuPriority + 3)]
    static void CreateForwardRendererData()
    {
        ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateSightRendererAsset>(), "TraceRenderer.asset", null, null);
    }

    internal class CreateSightRendererAsset : EndNameEditAction
    {
        public override void Action(int instanceId, string pathName, string resourceFile)
        {
            var instance = CreateInstance<TraceRendererData>();
            AssetDatabase.CreateAsset(instance, pathName);
            ResourceReloader.ReloadAllNullIn(instance, UniversalRenderPipelineAsset.packagePath);
            Selection.activeObject = instance;
        }
    }
#endif
    
    [SerializeField] LayerMask m_OpaqueLayerMask = -1;
    
    public LayerMask opaqueLayerMask
    {
        get => m_OpaqueLayerMask;
        set
        {
            SetDirty();
            m_OpaqueLayerMask = value;
        }
    }
    
    protected override ScriptableRenderer Create()
    {
        return new TraceRenderer(this);
    }
}
