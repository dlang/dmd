// infinite loop on DMD0.080

void main()
{
   char[] bug = "Crash";
   foreach(char ; bug){}
}

