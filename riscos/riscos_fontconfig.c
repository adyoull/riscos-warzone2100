/*
 * riscos_fontconfig.c - point the fontconfig linked into the game at the
 * game's own fonts/fonts.conf, for this program only.
 *
 * - Not PackMan's fontconfig setup (UnixFC): its fonts.conf is written for
 *   fontconfig 2.14, and the 2.12.6 linked into the game can't load it
 *   ("Cannot load default config file"; 2.3.9-6 tried it, reported by
 *   Chris Gransden). The game's own setup has its DejaVu fonts and its own
 *   cache folder, so it doesn't touch UnixFC's.
 * - Nothing global. 2.3.9-1 to -4 set FONTCONFIG_FILE with *Set in !Run: a
 *   global variable, which UnixLib copies into every program's
 *   environment, so other fontconfig programs (Iris) used Warzone's setup.
 *   setenv() of a name without '$' only changes this program's
 *   environment.
 * - Priority 102: QuesoGLC initialises fontconfig in its own constructor
 *   (default priority), so this has to run first (2.3.9-5 didn't).
 *   riscos_output.c (priority 101) runs before this.
 * - The path is a UnixLib path, /<Var$Dir>/..., expanded when the file is
 *   opened, as !Run always wrote it.
 */
#include <stdlib.h>

__attribute__((constructor(102)))
static void riscos_fontconfig_env(void)
{
    setenv("FONTCONFIG_FILE", "/<Warzone2100$Dir>/fonts/fonts.conf", 1);
    /* Another program's global settings mustn't redirect ours. */
    unsetenv("FONTCONFIG_PATH");
    unsetenv("FONTCONFIG_SYSROOT");
    unsetenv("RISCOS_APPFONTS");
}
