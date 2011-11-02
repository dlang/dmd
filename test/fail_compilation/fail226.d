struct Struct { 
        char* chptr; 
}

void main()
{
        immutable Struct iStruct;
        Struct y = iStruct;
}

