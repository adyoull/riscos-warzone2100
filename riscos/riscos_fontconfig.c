/*
 * riscos_fontconfig.c - point the statically linked fontconfig at the
 * game's own fonts.conf, for this program only.
 *
 * 2.3.9-1 to -4 did this with "Set FONTCONFIG_FILE" in !Run. That is a
 * global RISC OS variable, and UnixLib copies global variables without a
 * '$' into every program's environment, so other fontconfig programs
 * (Iris, anything from PackMan) started afterwards used Warzone's
 * fonts.conf and cache directory. setenv() of a name without '$' only
 * changes this program's own environment.
 *
 * Constructors run after UnixLib has built the environment (__unixinit,
 * then _init, in sys/_syslib.s), so the value set here isn't overwritten.
 */
#include <stdlib.h>

__attribute__((constructor))
static void riscos_fontconfig_env(void)
{
    /* UnixLib expands <Warzone2100$Dir> when fontconfig opens the file. */
    setenv("FONTCONFIG_FILE", "/<Warzone2100$Dir>/fonts/fonts.conf", 1);
    /* Another program's global settings mustn't redirect ours. */
    unsetenv("FONTCONFIG_PATH");
    unsetenv("FONTCONFIG_SYSROOT");
}
