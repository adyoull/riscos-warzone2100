/*
 * riscos_output.c - link this into a program that prints (SDL_Log goes to
 * stderr) and runs in the desktop: printing from a Wimp task opens a
 * command window. Before main() runs, if the variable named by OUTPUT_VAR
 * is set, stdout and stderr go to that file instead; if it isn't, they are
 * discarded (/dev/null). No change to the program's own sources is needed.
 *
 * Build with -DOUTPUT_VAR='"App$Output"'; the !Run file sets it, e.g.
 *   Set App$Output /|<App$Dir>/Output
 *
 * From riscos-mesa (MIT licence, see LICENCES.txt); changed for Warzone
 * 2100: without the variable the output goes to OUTPUT_DEFAULT (if
 * defined), and if a file can't be opened, it's discarded (/dev/null)
 * rather than left to open a command window.
 */
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

#ifndef OUTPUT_VAR
#define OUTPUT_VAR "Program$Output"
#endif

/* Priority 101: before any library constructor that might print. */
__attribute__((constructor(101)))
static void riscos_redirect_output(void)
{
    const char *o = getenv(OUTPUT_VAR);
    FILE *f;
    if (!o || !*o)
#ifdef OUTPUT_DEFAULT
        o = OUTPUT_DEFAULT;
#else
        o = "/dev/null";
#endif
    /* RISC OS lets a file be open for writing only once, so it can't be
       opened for both streams: a second freopen() failed and left stderr
       closed, so everything written to stderr (errors, crash backtraces)
       was lost and the log stayed empty. Open it once, for stderr, and
       make stdout share it with dup2() (as the Freeciv port does). */
    if ((f = freopen(o, "w", stderr)) == NULL)
        f = freopen("/dev/null", "w", stderr);
    if (f != NULL) {
        setvbuf(stderr, NULL, _IONBF, 0);
        fflush(stdout);
        if (dup2(fileno(stderr), fileno(stdout)) >= 0)
            setvbuf(stdout, NULL, _IOLBF, 0);
    }
}
