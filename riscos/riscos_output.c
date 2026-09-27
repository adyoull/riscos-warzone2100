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
 * 2100 to discard the output when the variable isn't set.
 */
#include <stdio.h>
#include <stdlib.h>

#ifndef OUTPUT_VAR
#define OUTPUT_VAR "Program$Output"
#endif

__attribute__((constructor))
static void riscos_redirect_output(void)
{
    const char *o = getenv(OUTPUT_VAR);
    FILE *f;
    if (!o || !*o)
        o = "/dev/null";
    /* Empty the file, then append from both streams: with stdout opened
       "w", its writes went over what stderr had already written. */
    if ((f = fopen(o, "w")) != NULL)
        fclose(f);
    if (freopen(o, "a", stdout) != NULL) {
        setvbuf(stdout, NULL, _IOLBF, 0);
        if (freopen(o, "a", stderr) != NULL)
            setvbuf(stderr, NULL, _IONBF, 0);
    }
}
