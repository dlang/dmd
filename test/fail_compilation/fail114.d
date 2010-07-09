// 371

void funcA( typeof(&funcB) p) { }

void funcB( typeof(&funcA) p) { }
