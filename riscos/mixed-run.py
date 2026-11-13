#!/usr/bin/env python3
"""Turn !Warzone2100's !Run into the mixed build's (build/package.sh, MIXED=1).

The mixed program is an ELF file (warzone2100,e1f) that loads OpenGL, EGL,
GLU, SDL 2 and OpenAL from !MesaLibs through !SharedLibs (ld-riscos/so/2),
so !Run boots both, checks for them, tells the loader where !MesaLibs is
(warzone2100$LD$Env, named after the program's leaf name) and gives the
program a slot big enough for its image (about 17 MB with its zero-filled
data; the heap is in dynamic areas as before).

   mixed-run.py PATH-TO-!Run,feb
"""
import sys

path = sys.argv[1]
text = open(path, encoding='latin-1').read()

def swap(old, new):
    global text
    if old not in text:
        sys.exit('mixed-run.py: !Run has no line ' + repr(old.splitlines()[0]))
    text = text.replace(old, new, 1)

swap('''| Built with GCCSDK GCC 10.2 (arm-riscos-gnueabihf), statically linked with
| riscos-mesa (software OpenGL) and its SDL2, and converted to an Absolute
| (AIF) file, so !SharedLibs isn't needed.''',
'''| The mixed build, made with GCCSDK GCC 10.2 (arm-riscos-gnueabihf): the
| program (warzone2100, an ELF file) has UnixLib and its other libraries
| linked in, and loads OpenGL, EGL, GLU, SDL 2 and OpenAL from !MesaLibs,
| through !SharedLibs. Both go in !Boot.Resources. riscos-mesa then draws
| with the GPU through RISC3D where there's a driver for it, else in
| software, as the ordinary (Absolute) build does.''')

swap('''| directly after it. All are removed when the game quits. The WimpSlot
| only has to hold the program itself (about 25MB).
WimpSlot -min 32768K -max 32768K''',
'''| directly after it. All are removed when the game quits. The WimpSlot
| only has to hold the program itself (about 17MB with its zero-filled
| data); the shared libraries are loaded elsewhere.
WimpSlot -min 20480K -max 20480K''')

swap('''Do Run <Warzone2100$Dir>.warzone2100 ''',
'''| The libraries: !SharedLibs (with ld-riscos/so/2, GCCSDK 8 or later, as
| in Iris) and !MesaLibs, both in !Boot.Resources. After installing a new
| !MesaLibs, restart the machine: until then the libraries already loaded
| stay in use.
If "<SharedLibs$Dir>" = "" Then IfThere Boot:Resources.!SharedLibs.!Boot Then Run Boot:Resources.!SharedLibs.!Boot
If "<MesaLibs$Dir>" = "" Then IfThere Boot:Resources.!MesaLibs.!Boot Then Run Boot:Resources.!MesaLibs.!Boot
Unset Warzone2100$SO2
IfThere SharedLibs:lib.ld-riscos-eabihf/so Then Set Warzone2100$SO2 1
If "<Warzone2100$SO2>" = "" Then Error Warzone 2100 (mixed) needs a !SharedLibs with ld-riscos/so/2 (GCCSDK 8 or later, as in Iris) in !Boot.Resources
If "<MesaLibs$Dir>" = "" Then Error Warzone 2100 (mixed) needs !MesaLibs in !Boot.Resources
Unset Warzone2100$SO2
Set warzone2100$LD$Env "LD_LIBRARY_PATH=/MesaLibs:"
Do Run <Warzone2100$Dir>.warzone2100 ''')

open(path, 'w', encoding='latin-1').write(text)
