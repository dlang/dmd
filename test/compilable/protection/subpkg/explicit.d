module protection.subpkg.explicit;

package(protection) void commonAncestorFoo();
package(protection.subpkg) void samePkgFoo();
package(protection.subpkg2) void differentSubPkgFoo();
package(unknown) void unknownPkgFoo();
