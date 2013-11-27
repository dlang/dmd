/*
TEST_OUTPUT:
---
0500-classes.tex(2484): Error: function fail343.TimedApp.run cannot override final function I.fail343.Timer.run
0500-classes.tex(2484): Error: function fail343.TimedApp.run cannot override final function Application.fail343.Application.run
---
*/

#line 2471 "0500-classes.tex"
interface Timer
{
   final void run() { }
}

interface I : Timer { }
interface Application
{
   final void run() { }
}
class TimedApp : I, Application
{
   // cannot define run()
   void run() { }
}
