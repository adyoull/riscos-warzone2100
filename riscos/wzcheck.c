/*
 * wzcheck.c - start-up checker for !Warzone2100 (run by !Warzone2100.Check).
 *
 * Goes through what the game does before its window opens, one step at a
 * time, printing each step BEFORE doing it. If something kills the
 * program, the last line printed says where. Every line also goes to
 * <Wimp$ScrapDir>.WZCheck, so the report can be sent even if the window
 * closes.
 *
 * Steps:
 *   1. RISC OS version, and the modules the game uses (versions from
 *      their help strings).
 *   2. The variables the game and its libraries read (the FONTCONFIG ones
 *      as the game sets them for itself, riscos_fontconfig.c).
 *   3. Reserve (and remove) a dynamic area the size of the game's heap.
 *   4. fontconfig, set up exactly as the game does (riscos_fontconfig.c,
 *      the same patched fontconfig and FreeType): load the config, list
 *      the fonts, and find "DejaVu Sans".
 *   5. FreeType: open the matched font file.
 *   6. PhysicsFS: open the game's data (base.wz, mp.wz).
 *   7. Stack test: read() into fresh, untouched stack pages at increasing
 *      depths, as fontconfig did before 2.3.9-8. If the machine has the
 *      problem, this step stops with "EMT trap". It's last on purpose.
 *
 * Licence: GPL v2 or later, as the rest of the RISC OS port.
 */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <kernel.h>
#include <swis.h>
#include <fontconfig/fontconfig.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <physfs.h>

static FILE *report;

static void say(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    fflush(stdout);
    if (report) {
        va_start(ap, fmt);
        vfprintf(report, fmt, ap);
        va_end(ap);
        fflush(report);
    }
}

static void step(const char *what)
{
    say("\n== %s\n", what);
}

/* The version part of a module's help string ("Name <tabs> 1.23 (date)"). */
static void module(const char *name)
{
    _kernel_oserror *e;
    int base = 0;
    const char *help;

    e = _swix(OS_Module, _INR(0,1) | _OUT(3), 18, name, &base);
    if (e || !base) {
        say("  %-20s not loaded\n", name);
        return;
    }
    help = (const char *) (base + *(const int *) (base + 0x14));
    say("  %-20s ", name);
    while (*help && *help != '\t')
        help++;
    while (*help == '\t' || *help == ' ')
        help++;
    while (*help >= ' ')
        say("%c", *help++);
    say("\n");
}

static void var(const char *name)
{
    const char *v = getenv(name);
    say("  %-24s %s\n", name, v ? v : "(not set)");
}

/* Stack test. Each level of stack_down() has a frame under 1KB and touches
 * its lowest byte, so the stack grows a page at a time with no gaps. Then
 * stack_leaf() has read() - a SWI - fill a buffer that nothing has touched
 * yet, often in a page that has never been used. Different depths put the
 * buffer at different places relative to the page boundaries. */
static int __attribute__((noinline)) stack_leaf(const char *file)
{
    char buf[3000];
    int fd, n;

    fd = open(file, O_RDONLY);
    if (fd < 0)
        return -1;
    n = read(fd, buf, sizeof buf);
    close(fd);
    return n > 0 ? (unsigned char) buf[0] : n;
}

static int __attribute__((noinline)) stack_down(const char *file, int depth)
{
    volatile char pad[900];

    pad[0] = 0;
    if (depth > 0)
        return stack_down(file, depth - 1) + pad[0];
    return stack_leaf(file) + pad[0];
}

int main(int argc, char **argv)
{
    const char *scrap = getenv("Wimp$ScrapDir");
    char path[512];

    (void) argc;
    if (scrap && *scrap) {
        snprintf(path, sizeof path, "%s.WZCheck", scrap);
        report = fopen(path, "w");
    }
    say("Warzone 2100 start-up check (%s)\n", __DATE__);
    if (report)
        say("A copy of this report is in <Wimp$ScrapDir>.WZCheck\n");

    step("1. RISC OS and modules");
    {
        char osver[256] = "";
        _kernel_oserror *e = _swix(OS_Byte, _INR(0,1), 0, 0);
        if (e)
            snprintf(osver, sizeof osver, "%s", e->errmess);
        say("  %s\n", osver);
    }
    module("UtilityModule");
    module("SharedUnixLibrary");
    module("ARMEABISupport");
    module("PThreadTicker");
    module("VFPSupport");
    module("SharedSound");
    module("StreamManager");
    module("SharedSoundBuffer");
    module("VideoOverlay");

    step("2. Variables");
    var("Warzone2100$Dir");
    var("Wimp$ScrapDir");
    var("Choices$Write");
    var("FONTCONFIG_FILE");
    var("FONTCONFIG_PATH");
    var("FONTCONFIG_SYSROOT");
    var("RISCOS_APPFONTS");
    var("FC_DEBUG");
    var("UnixFC$Dir");
    var("Warzone2100$RenderSize");
    var("Warzone2100$Overlay");
    var("SDL_RISCOS_GL_RENDER_SIZE");
    var("SDL_RISCOS_GL_OVERLAY");
    var("HOME");
    var("LANG");
    var("UnixEnv$wzcheck$sfix");

    step("3. Reserve a 512MB dynamic area for the heap (then remove it)");
    {
        int area = -1;
        _kernel_oserror *e = _swix(OS_DynamicArea, _INR(0,8) | _OUTR(1,1),
                                   0, -1, 0, -1, 0x80, 512 * 1024 * 1024, 0, -1,
                                   "Warzone2100 check", &area);
        if (e)
            say("  FAILED: %s\n", e->errmess);
        else {
            say("  OK (area %d)\n", area);
            _swix(OS_DynamicArea, _INR(0,1), 1, area);
        }
    }

    step("4. fontconfig, set up as the game does");
    say("  fontconfig %d (linked in)\n", FcGetVersion());
    say("  setup: %s\n", getenv("RISCOS_APPFONTS")
        ? "PackMan's (UnixFC), plus the game's fonts"
        : "the game's own fonts.conf");
    say("  FONTCONFIG_FILE for this program: %s\n",
        getenv("FONTCONFIG_FILE") ? getenv("FONTCONFIG_FILE") : "(not set)");
    say("  loading the config and scanning the fonts...\n");
    {
        FcConfig *config = FcInitLoadConfigAndFonts();
        FcFontSet *set;
        FcPattern *pat, *match;
        FcResult result;
        FcChar8 *file = NULL;

        if (!config) {
            say("  FAILED: no configuration\n");
            goto physfs;
        }
        set = FcConfigGetFonts(config, FcSetSystem);
        say("  config loaded; %d font(s) found\n", set ? set->nfont : 0);
        {
            FcStrList *l = FcConfigGetCacheDirs(config);
            FcChar8 *d;
            while (l && (d = FcStrListNext(l)))
                say("  cache folder: %s\n", d);
            if (l)
                FcStrListDone(l);
        }
        if (getenv("RISCOS_APPFONTS")) {
            /* As the game's QuesoGLC does. */
            const char *app = getenv("RISCOS_APPFONTS");
            say("  adding the game's fonts (%s)...\n", app);
            say("  %s\n", FcConfigAppFontAddDir(config, (const FcChar8 *) app)
                               ? "OK" : "FAILED");
            set = FcConfigGetFonts(config, FcSetApplication);
            say("  %d application font(s)\n", set ? set->nfont : 0);
            set = FcConfigGetFonts(config, FcSetSystem);
        }
        if (set)
            for (int i = 0; i < set->nfont && i < 10; i++) {
                FcChar8 *f;
                if (FcPatternGetString(set->fonts[i], FC_FILE, 0, &f) == FcResultMatch)
                    say("    %s\n", f);
            }
        say("  looking for \"DejaVu Sans\"...\n");
        pat = FcNameParse((const FcChar8 *) "DejaVu Sans");
        FcConfigSubstitute(config, pat, FcMatchPattern);
        FcDefaultSubstitute(pat);
        match = FcFontMatch(config, pat, &result);
        if (match && FcPatternGetString(match, FC_FILE, 0, &file) == FcResultMatch)
            say("  matched %s\n", file);
        else
            say("  FAILED: no match\n");

        step("5. FreeType: open that font");
        if (file) {
            FT_Library lib;
            FT_Face face;
            if (FT_Init_FreeType(&lib))
                say("  FAILED: FT_Init_FreeType\n");
            else if (FT_New_Face(lib, (const char *) file, 0, &face))
                say("  FAILED: can't open %s\n", file);
            else {
                say("  OK: %s %s, %ld glyphs\n", face->family_name,
                    face->style_name, face->num_glyphs);
                FT_Done_Face(face);
                FT_Done_FreeType(lib);
            }
        } else
            say("  skipped (no font)\n");
        if (match)
            FcPatternDestroy(match);
        FcPatternDestroy(pat);
    }

physfs:
    step("6. PhysicsFS: the game's data");
    if (!PHYSFS_init(argv[0]))
        say("  FAILED: PHYSFS_init: %s\n", PHYSFS_getLastError());
    else {
        static const char *const pak[] = { "base.wz", "mp.wz" };
        for (int i = 0; i < 2; i++) {
            snprintf(path, sizeof path, "/<Warzone2100$Dir>/data/%s", pak[i]);
            if (PHYSFS_addToSearchPath(path, 1))
                say("  OK: %s\n", pak[i]);
            else
                say("  FAILED: %s: %s\n", pak[i], PHYSFS_getLastError());
        }
        say("  names.txt %s\n", PHYSFS_exists("messages/strings/names.txt")
                                   ? "found" : "not found (may be normal)");
        PHYSFS_deinit();
    }

    step("7. Stack test: read() into untouched stack pages");
    say("  (if the check stops here with \"EMT trap\", this machine has the\n"
        "   stack problem that 2.3.9-8 works around in fontconfig)\n");
    snprintf(path, sizeof path, "/<Warzone2100$Dir>/fonts/fonts.conf");
    for (int depth = 0; depth <= 40; depth++) {
        say("  depth %2d... ", depth);
        int r = stack_down(path, depth);
        say(r < 0 ? "can't open fonts.conf\n" : "OK\n");
    }

    step("Done: everything above passed unless it says FAILED");
    if (report)
        fclose(report);
    return 0;
}
