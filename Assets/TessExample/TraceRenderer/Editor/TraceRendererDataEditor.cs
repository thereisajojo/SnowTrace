using UnityEditor;
using UnityEditor.Rendering.Universal;

[CustomEditor(typeof(TraceRendererData), true)]
public class TraceRendererDataEditor : ScriptableRendererDataEditor
{
    SerializedProperty m_OpaqueLayerMask;
    
    private void OnEnable()
    {
        m_OpaqueLayerMask = serializedObject.FindProperty("m_OpaqueLayerMask");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();
        EditorGUILayout.PropertyField(m_OpaqueLayerMask);
        serializedObject.ApplyModifiedProperties();
        base.OnInspectorGUI();
    }
}
