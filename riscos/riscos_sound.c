/*
 * riscos_sound.c - OpenAL Soft's settings for this program only.
 *
 * The game's sound goes OpenAL Soft -> SDL -> SDL's RISC OS driver
 * (SharedSoundBuffer and StreamManager). OpenAL asks SDL for its period
 * size, 1024 samples by default: SDL's driver then keeps about 70 ms
 * queued, which runs dry whenever the game is busy for a moment
 * (scrolling, a big battle, loading), and the sound breaks up. With 4096
 * (as riscos-openttd and fheroes2 use) the driver keeps about 280 ms
 * queued, so the sound carries on through those moments; sound effects
 * start a little later, which a strategy game doesn't notice.
 *
 * OpenAL Soft reads that from the file named by ALSOFT_CONF. setenv() of a
 * name without '$' only changes this program's environment, so other
 * programs using OpenAL aren't affected. An ALSOFT_CONF already set is
 * left alone, so another file can still be used for testing. The file is
 * !Warzone2100.alsoft/conf (it can be edited: period_size 1024 to 8192).
 *
 * Priority 104: after riscos_output.c (101), riscos_fontconfig.c (102) and
 * riscos_display.c (103), long before OpenAL reads its configuration.
 */
#include <stdlib.h>

__attribute__((constructor(104)))
static void riscos_sound_env(void)
{
    const char *conf = getenv("ALSOFT_CONF");

    if (conf == NULL || *conf == '\0')
        setenv("ALSOFT_CONF", "/<Warzone2100$Dir>/alsoft.conf", 1);
}
