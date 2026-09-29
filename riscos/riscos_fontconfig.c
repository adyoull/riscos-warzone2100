/*
 * riscos_fontconfig.c - which fontconfig setup the game uses, for this
 * program only.
 *
 * - With PackMan's fontconfig installed (UnixFC, which sets UnixFC$Dir and
 *   has fonts/fonts.conf), the game uses that setup, like other fontconfig
 *   programs: the system's fonts, font mapping and cache. The game links
 *   fontconfig 2.14.1, the version PackMan has, so it reads the same
 *   config and cache format (2.3.9-6 tried this with 2.12.6, which can't
 *   read the 2.14 config). The game's own DejaVu fonts are added on top as
 *   application fonts (RISCOS_APPFONTS, read by the patched QuesoGLC), so
 *   its text still shows if the system has no DejaVu.
 * - Without it, the game uses its own fonts/fonts.conf and nothing else.
 *
 * FONTCONFIG_PATH is where fontconfig looks for files that a config
 * includes by a relative name (conf.d), so it's set to UnixFC's folder too.
 *
 * Nothing global is set. 2.3.9-1 to -4 set FONTCONFIG_FILE with *Set in
 * !Run: a global variable, which UnixLib copies into every program's
 * environment, so other fontconfig programs used Warzone's setup. setenv()
 * of a name without '$' only changes this program's environment.
 *
 * Priority 102: QuesoGLC initialises fontconfig in its own constructor
 * (default priority), so this has to run first. riscos_output.c
 * (priority 101) runs before this.
 *
 * Paths are UnixLib paths, /<Var$Dir>/..., expanded when a file is opened.
 */
#include <stdlib.h>
#include <unistd.h>

#define UNIXFC_CONF "/<UnixFC$Dir>/fonts/fonts.conf"

__attribute__((constructor(102)))
static void riscos_fontconfig_env(void)
{
    /* getenv() of a name with a '$' reads the RISC OS variable. */
    const char *unixfc = getenv("UnixFC$Dir");

    if (unixfc && *unixfc && access(UNIXFC_CONF, R_OK) == 0) {
        setenv("FONTCONFIG_FILE", UNIXFC_CONF, 1);
        setenv("FONTCONFIG_PATH", "/<UnixFC$Dir>/fonts", 1);
        setenv("RISCOS_APPFONTS", "/<Warzone2100$Dir>/fonts", 1);
    } else {
        setenv("FONTCONFIG_FILE", "/<Warzone2100$Dir>/fonts/fonts.conf", 1);
        unsetenv("FONTCONFIG_PATH");
        unsetenv("RISCOS_APPFONTS");
    }
    /* Another program's global settings mustn't redirect ours. */
    unsetenv("FONTCONFIG_SYSROOT");
}
