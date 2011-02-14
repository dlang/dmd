struct Struct { 
        char* chptr; 
}

void main()
{
        char ch = 'd';
        invariant Struct iStruct = {1, &ch};
}

