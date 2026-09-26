/* LD_PRELOAD helper for profiling a Linux build of the game on Mesa's xlib
 * software renderer (see README.md):
 * - the xlib libGL doesn't export two stencil extension functions that
 *   GLee links directly; forward them through glXGetProcAddress;
 * - print the frame rate every 5 seconds from SDL_GL_SwapWindow. */
#define _GNU_SOURCE
#include <GL/glx.h>
#include <dlfcn.h>
#include <stdio.h>
#include <time.h>

typedef void (*F1)(GLenum);
typedef void (*F4)(GLenum, GLenum, GLenum, GLenum);

void glActiveStencilFaceEXT(GLenum face)
{
	static F1 f;
	if (!f) f = (F1)glXGetProcAddress((const GLubyte *)"glActiveStencilFaceEXT");
	f(face);
}

void glStencilOpSeparateATI(GLenum a, GLenum b, GLenum c, GLenum d)
{
	static F4 f;
	if (!f) f = (F4)glXGetProcAddress((const GLubyte *)"glStencilOpSeparateATI");
	f(a, b, c, d);
}

void SDL_GL_SwapWindow(void *window)
{
	static void (*real)(void *);
	static int frames;
	static double t0;
	struct timespec ts;
	double t;

	if (!real) real = (void (*)(void *))dlsym(RTLD_NEXT, "SDL_GL_SwapWindow");
	real(window);
	frames++;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	t = ts.tv_sec + ts.tv_nsec * 1e-9;
	if (t0 == 0) t0 = t;
	if (t - t0 >= 5)
	{
		fprintf(stderr, "FPS %.2f (%.1f ms/frame)\n", frames / (t - t0), 1000 * (t - t0) / frames);
		frames = 0;
		t0 = t;
	}
}
