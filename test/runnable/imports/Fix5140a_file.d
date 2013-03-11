module imports.Fix5140a;

string getCallingModule(string name = __MODULE__) { return name; }
string getTemplCallingModule(string name = __MODULE__)() { return name; }
string getCalleeModule() { return __MODULE__; }

string getCallingFunc(string name = __FUNCTION__) { return name; }
string getTemplCallingFunc(string name = __FUNCTION__)() { return name; }
string getCalleeFunc() { return __FUNCTION__; }

string getCallingPrettyFunc(string name = __PRETTY_FUNCTION__) { return name; }
string getTemplCallingPrettyFunc(string name = __PRETTY_FUNCTION__)() { return name; }
string getCalleePrettyFunc(int x, float y) { return __PRETTY_FUNCTION__; }
