struct Struct { 
        char* chptr; 
}

void main()
{
        char ch = 'd';
        invariant Struct iStruct = {&ch};
}


