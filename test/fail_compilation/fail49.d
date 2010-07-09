private import std.string;

void main()
{
    char[] hold;
    switch((hold = toString('i')))
    {
	case "":
	case toString(cast(char)255):
	    hold = toString('i');
	    break;
    }
}

