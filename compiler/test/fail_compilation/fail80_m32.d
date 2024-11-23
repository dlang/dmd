// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/fail80_m32.d(32): Error: cannot implicitly convert expression `"progress_rem"` of type `string` to `uint`
        images["progress_rem"]  = ResourceManager.getImage("progress_rem.gif"); // delete_obj_dis
               ^
fail_compilation/fail80_m32.d(33): Error: cannot implicitly convert expression `"redo"` of type `string` to `uint`
        images["redo"]          = ResourceManager.getImage("redo.gif");
               ^
---
*/

module paintshop;

class Image{}

class ResourceManager
{
    Image getImage(char[] name) { return null; }
}

class Test
{



    static Image[] images;

    static void initIcons()
    {
        images["progress_rem"]  = ResourceManager.getImage("progress_rem.gif"); // delete_obj_dis
        images["redo"]          = ResourceManager.getImage("redo.gif");
    }
}
