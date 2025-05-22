using UnityEngine;

[ExecuteInEditMode]
public class SetRenderTexture : MonoBehaviour
{
    [SerializeField] RenderTexture renderTexture;
    
    void Awake()
    {
        Shader.SetGlobalTexture("_GlobalEffectRT", renderTexture);
        Shader.SetGlobalFloat("_OrthographicCamSize", GetComponent<Camera>().orthographicSize);
    }
 
    private void Update()
    {
        Shader.SetGlobalVector("_Position", transform.position);
    }
}
