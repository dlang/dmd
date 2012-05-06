#
# Copyright (c) 2012 by Digital Mars
# All Rights Reserved
# written by David Held
# http://www.digitalmars.com
# License for redistribution is by either the Artistic License
# in artistic.txt, or the GNU General Public License in gnu.txt.
# See the included readme.txt for details.
#
# Note: this makefile has been created for special use inside the DMD compiler.
# It is not suitable for general use with the DMC toolset.
#
# Required imports:
#
# CC        - DMC compiler
# LIB       - DMC librarian
# TFLAGS    - CFLAGS customized for STLPort and CPPUnit
# BFLAGS    - librarian flags

# CPPUnit root
ROOTDIR=..\..
# Compiler flags
CFLAGS=$(TFLAGS) -I$(ROOTDIR)\include
# Librarian flags
BFLAGS=$(BFLAGS) -p64

# Build target
TARGET=$(ROOTDIR)\lib\cppunit.lib

# Library objects
OBJS= AdditionalMessage.obj Asserter.obj BeOsDynamicLibraryManager.obj \
    BriefTestProgressListener.obj CompilerOutputter.obj DefaultProtector.obj \
    DllMain.obj DynamicLibraryManager.obj DynamicLibraryManagerException.obj \
    Exception.obj Message.obj PlugInManager.obj PlugInParameters.obj \
    Protector.obj ProtectorChain.obj RepeatedTest.obj \
    ShlDynamicLibraryManager.obj SourceLine.obj StringTools.obj \
    SynchronizedObject.obj Test.obj TestAssert.obj TestCase.obj \
    TestCaseDecorator.obj TestComposite.obj TestDecorator.obj \
    TestFactoryRegistry.obj TestFailure.obj TestLeaf.obj TestNamer.obj \
    TestPath.obj TestPlugInDefaultImpl.obj TestResult.obj \
    TestResultCollector.obj TestRunner.obj TestSetUp.obj \
    TestSuccessListener.obj TestSuite.obj TestSuiteBuilderContext.obj \
    TextOutputter.obj TextTestProgressListener.obj TextTestResult.obj \
    TextTestRunner.obj TypeInfoHelper.obj UnixDynamicLibraryManager.obj \
    Win32DynamicLibraryManager.obj XmlDocument.obj XmlElement.obj \
    XmlOutputter.obj XmlOutputterHook.obj

# Default target
$(TARGET): $(OBJS)
    lib -c -p64 $(TARGET) $(OBJS)

# Maintenance targets
clean:
    del $(TARGET)
    del $(OBJS)

# Default rule
.cpp.obj:
    $(CC) -c $(CFLAGS) $<
