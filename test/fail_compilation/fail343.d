#line 2471 "0500-classes.tex"
interface Timer {
   final void run() { }
   
}

interface I : Timer { }
interface Application {
   final void run() { }
   
}
class TimedApp : I, Application {
   // cannot define run()
   void run() { }
}
