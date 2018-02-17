import imports.pkg313.c313 : bug, imports.c314 : bug; // previously 2 import statements
import imports.pkg313.c313 : bug, imports.c314; // also allows qualified module w/o selective import
import imports.c314, imports.pkg313.c313 : bug; // unchanged
