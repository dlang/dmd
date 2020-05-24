module protection.subpkg.explicit;

package(protection) void commonAncestorFoo() @system;
package(protection.subpkg) void samePkgFoo() @system;
