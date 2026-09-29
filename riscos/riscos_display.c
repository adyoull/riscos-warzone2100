/*
 * riscos_display.c - the game's display settings from !Run, passed to SDL
 * for this program only.
 *
 * - Warzone2100$RenderSize (e.g. 640x480 or 800x600): the game renders at
 *   that size and the picture is stretched to the window or the screen.
 *   Software OpenGL costs about the same per pixel, so fewer pixels means
 *   a faster game. Sizes under 640x480 (the game's minimum) are ignored.
 *   When the overlay is used and this isn't set, the game renders at
 *   800x600 on screens bigger than 1024x768 (where its window starts at
 *   1024x768), else 640x480: the overlay stretches it for free. "off" (or
 *   0) renders at the window's own size.
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
#include <string.h>
#include <kernel.h>
#include <swis.h>

/* The screen's size in pixels (current mode), or 0. */
static void screen_size(int *w, int *h)
{
    int x = -1, y = -1;
    if (_swix(OS_ReadModeVariable, _INR(0,1) | _OUT(2), -1, 11, &x)
        || _swix(OS_ReadModeVariable, _INR(0,1) | _OUT(2), -1, 12, &y))
        x = y = -1;
    *w = x + 1;
    *h = y + 1;
}

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
    int use_overlay;

    unsetenv("SDL_RISCOS_GL_RENDER_SIZE");
    unsetenv("SDL_RISCOS_GL_OVERLAY");

    if (overlay && (*overlay == '1' || *overlay == '0') && overlay[1] == '\0')
        use_overlay = *overlay == '1';
    else
        use_overlay = have_videooverlay();
    if (use_overlay)
        setenv("SDL_RISCOS_GL_OVERLAY", "1", 1);
    else if (overlay && *overlay == '0')
        setenv("SDL_RISCOS_GL_OVERLAY", "0", 1);

    if (size && (strcmp(size, "off") == 0 || strcmp(size, "0") == 0))
        return;                     /* render at the window's size */
    if (size && *size) {
        if (sscanf(size, "%dx%d%c", &w, &h, &c) == 2 && w >= 640 && h >= 480
            && w <= 4096 && h <= 4096) {
            char buf[32];
            snprintf(buf, sizeof buf, "%dx%d", w, h);
            setenv("SDL_RISCOS_GL_RENDER_SIZE", buf, 1);
            return;
        }
        fprintf(stderr, "Warzone2100$RenderSize \"%s\" ignored: "
                "use WxH, at least 640x480, or off\n", size);
    }
    if (use_overlay) {
        int sw, sh;
        screen_size(&sw, &sh);
        setenv("SDL_RISCOS_GL_RENDER_SIZE",
               sw > 1024 && sh > 768 ? "800x600" : "640x480", 1);
    }
}
