using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class cam : MonoBehaviour
{
    public Transform target;

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        // Vector2 input = new Vector2(Input.GetAxis("Horizontal"), Input.GetAxis("Vertical"));
        Vector3 move = GetInput();
        move = transform.rotation * move;

        transform.position += 15 * Time.deltaTime * move;
        transform.LookAt(target);
    }

    Vector3 GetInput()
    {
        Vector3 input = new();
        if (Input.GetKey(KeyCode.W))
        {
            input.y += 1;
        }
        if (Input.GetKey(KeyCode.S))
        {
            input.y -= 1;
        }
        if (Input.GetKey(KeyCode.A))
        {
            input.x -= 1;
        }
        if (Input.GetKey(KeyCode.D))
        {
            input.x += 1;
        }
        if (Input.GetKey(KeyCode.LeftShift))
        {
            input.z += 1;
        }
        if (Input.GetKey(KeyCode.LeftControl))
        {
            input.z -= 1;
        }
        if (input.magnitude > 1)
        {
            input.Normalize();
        }
        return input;
    }
}
