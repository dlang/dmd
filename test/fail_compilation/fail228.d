int ToTypeString (T:int) ()
{
    return 1;
}

int ToTypeString (T:string) ()
{
    return 2;
}

void main ()
{
    printf("%d\n", ToTypeString!(typeof(localVariable))());
}

