using UnityEngine;

[ExecuteInEditMode]
public class CameraDepthEnable : MonoBehaviour
{

    private void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
    }
}