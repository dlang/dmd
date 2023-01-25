// https://issues.dlang.org/show_bug.cgi?id=23595
// EXTRA_SOURCES: extra-files/test23595png.d
// EXTRA_FILES: imports/test23595types.d

struct AudioOutputThread
{
    alias Sample = AudioPcmOutThreadImplementation.Sample;
}

import imports.test23595types;

class AudioPcmOutThreadImplementation
{
    void[pthread_mutex_t.sizeof] _slock;
    struct Sample { }
}
