/*
 * riscos_display.c - the game's display settings from !Run, passed to SDL
 * for this program only.
 *
 * - Warzone2100$RenderSize (e.g. 640x480 or 800x600): the game renders at
 *   that size and the picture is stretched to the window or the screen.
 *   Software OpenGL costs about the same per pixel, so fewer pixels means
 *   a faster game. Sizes under 640x480 (the game's minimum) are ignored.
 * - The hardware overlay (VideoOverlay, on the Raspberry Pi) shows the
 *   frames instead of plotting them whenever the module is loaded (!Run
 *   loads it from !System if it's there). Warzone2100$Overlay 0 turns it
 *   off, 1 asks for it even if the module isn't loaded yet. Without the
 *   module SDL keeps its usual path, so other machines are unaffected.
 *
 * riscos-mesa's SDL (20.3.5-10) reads its hints SDL_RISCOS_GL_RENDER_SIZE
 * and SDL_RISCOS_GL_OVERLAY from the environment when they aren't set by
 * SDL_SetHint. setenv() of a name without '$' only changes this program's
 * environment, so other SDL programs aren't affected (a *Set of the SDL
 * name itself in !Run would reach every UnixLib program).
 *
 * Priority 103: after riscos_output.c (101) and riscos_fontconfig.c (102),
 * long before SDL starts.
 */
#include <stdio.h>
#include <stdlib.h>
#include <kernel.h>
#include <swis.h>

/* Is the VideoOverlay module loaded? */
static int have_videooverlay(void)
{
    return _swix(OS_Module, _INR(0,1), 18, "VideoOverlay") == NULL;
}

__attribute__((constructor(103)))
static void riscos_display_env(void)
{
    /* getenv() of a name with a '$' reads the RISC OS variable. */
    const char *size = getenv("Warzone2100$RenderSize");
    const char *overlay = getenv("Warzone2100$Overlay");
    int w, h;
    char c;

    unsetenv("SDL_RISCOS_GL_RENDER_SIZE");
    unsetenv("SDL_RISCOS_GL_OVERLAY");
    if (size && *size) {
        if (sscanf(size, "%dx%d%c", &w, &h, &c) == 2 && w >= 640 && h >= 480
            && w <= 4096 && h <= 4096) {
            char buf[32];
            snprintf(buf, sizeof buf, "%dx%d", w, h);
            setenv("SDL_RISCOS_GL_RENDER_SIZE", buf, 1);
        } else {
            fprintf(stderr, "Warzone2100$RenderSize \"%s\" ignored: "
                    "use WxH, at least 640x480\n", size);
        }
    }
    if (overlay && (*overlay == '1' || *overlay == '0') && overlay[1] == '\0')
        setenv("SDL_RISCOS_GL_OVERLAY", overlay, 1);
    else if (have_videooverlay())
        setenv("SDL_RISCOS_GL_OVERLAY", "1", 1);
}
