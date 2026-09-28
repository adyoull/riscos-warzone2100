/*
 * riscos_fontconfig.c - which fontconfig setup the game uses, for this
 * program only.
 *
 * - With PackMan's fontconfig installed (UnixFC, which sets UnixFC$Dir),
 *   the game uses its fonts.conf, like other fontconfig programs such as
 *   Iris: the system's fonts, font mapping and cache (UnixFC:cache). The
 *   game's own DejaVu fonts are added on top as application fonts
 *   (RISCOS_APPFONTS, read by the patched QuesoGLC), so its text still
 *   shows if the system has no DejaVu.
 * - Without it, the game uses its own fonts/fonts.conf.
 *
 * Nothing global is set. 2.3.9-1 to -4 set FONTCONFIG_FILE with *Set in
 * !Run: a global variable, which UnixLib copies into every program's
 * environment, so other fontconfig programs used Warzone's setup. setenv()
 * of a name without '$' only changes this program's environment.
 *
 * Priority 102: QuesoGLC initialises fontconfig in its own constructor
 * (default priority), so this has to run first. 2.3.9-5 didn't, and
 * fontconfig reported "Cannot load default config file".
 * riscos_output.c (priority 101) runs before this.
 *
 * Paths are given as UnixLib paths, /<Var$Dir>/..., the form !Run always
 * used (UnixLib expands the variable when the file is opened), so a
 * path's full stops and slashes aren't mixed up.
 */
#include <stdlib.h>

__attribute__((constructor(102)))
static void riscos_fontconfig_env(void)
{
    /* getenv() of a name with a '$' reads the RISC OS variable. */
    const char *unixfc = getenv("UnixFC$Dir");

    if (unixfc && *unixfc) {
        setenv("FONTCONFIG_FILE", "/<UnixFC$Dir>/fonts/fonts.conf", 1);
        setenv("RISCOS_APPFONTS", "/<Warzone2100$Dir>/fonts", 1);
    } else {
        setenv("FONTCONFIG_FILE", "/<Warzone2100$Dir>/fonts/fonts.conf", 1);
        unsetenv("RISCOS_APPFONTS");
    }
    /* Another program's global settings mustn't redirect ours. */
    unsetenv("FONTCONFIG_PATH");
    unsetenv("FONTCONFIG_SYSROOT");
}
