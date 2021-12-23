using UnityEditor;

public class HLSLFile
{
    static readonly string hlslTemplateGUID = "1bfccf0cc4095e44b9d4197eaeee013e";
    static readonly string defaultNewHLSLName = "NewHLSL.hlsl";

    [MenuItem("Assets/Create/Shader/HLSL")]
    static void Create()
    {
        string templatePath = AssetDatabase.GUIDToAssetPath(hlslTemplateGUID);
        ProjectWindowUtil.CreateScriptAssetFromTemplateFile(templatePath, defaultNewHLSLName);
    }
}
