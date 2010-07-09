module paintshop;


class Image{}
class ResourceManager
{
	Image getImage(char[] name) { return null; }
}

class Test
{

import std.file;
import std.path;

static Image[] images;

static void initIcons() 
{

	images["progress_rem"] 	= ResourceManager.getImage("progress_rem.gif");	// delete_obj_dis
	images["redo"] 			= ResourceManager.getImage("redo.gif");
}

}
