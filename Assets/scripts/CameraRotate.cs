using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraRotate : MonoBehaviour
{
    public float speed = 2;
    void Update()
    {
        if (Input.GetMouseButton(1))
        {
            gameObject.transform.RotateAround(Vector3.zero, Vector3.up, Input.GetAxis("Mouse X") * speed);
            gameObject.transform.RotateAround(Vector3.zero, -gameObject.transform.right, Input.GetAxis("Mouse Y") * speed);
        }
        
    }
}
