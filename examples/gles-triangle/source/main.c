// SPDX-License-Identifier: MIT
//
// Draws a turning triangle with OpenGL ES 3 through EGL. Press + to exit.
//
// The program uses the default NWindow, as on Switch 1.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include <switch.h>

#include <EGL/egl.h>
#include <GLES3/gl3.h>

typedef struct {
    EGLDisplay display;
    EGLContext context;
    EGLSurface surface;
} Window;

static const char *const vertex_source =
    "#version 300 es\n"
    "layout(location = 0) in vec2 position;\n"
    "layout(location = 1) in vec3 color;\n"
    "uniform float angle;\n"
    "out vec3 vertex_color;\n"
    "void main() {\n"
    "    mat2 rotation = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));\n"
    "    gl_Position = vec4(rotation * position, 0.0, 1.0);\n"
    "    vertex_color = color;\n"
    "}\n";

static const char *const fragment_source =
    "#version 300 es\n"
    "precision mediump float;\n"
    "in vec3 vertex_color;\n"
    "out vec4 fragment_color;\n"
    "void main() {\n"
    "    fragment_color = vec4(vertex_color, 1.0);\n"
    "}\n";

// Position (x, y) and color (r, g, b) of each corner.
static const float vertices[] = {
    0.0f,  0.6f,  1.0f, 0.2f, 0.2f,
    -0.6f, -0.5f, 0.2f, 1.0f, 0.2f,
    0.6f,  -0.5f, 0.2f, 0.2f, 1.0f,
};

static void fail(const char *what)
{
    printf("%s failed (EGL error 0x%x)\n", what, eglGetError());
    exit(1);
}

static void create_window(Window *w)
{
    w->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (!eglInitialize(w->display, NULL, NULL))
        fail("eglInitialize");
    eglBindAPI(EGL_OPENGL_ES_API);

    const EGLint config_attributes[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_NONE,
    };
    EGLConfig config;
    EGLint config_count;
    if (!eglChooseConfig(w->display, config_attributes, &config, 1,
                         &config_count) || config_count == 0)
        fail("eglChooseConfig");

    w->surface = eglCreateWindowSurface(w->display, config,
                                        nwindowGetDefault(), NULL);
    if (w->surface == EGL_NO_SURFACE)
        fail("eglCreateWindowSurface");

    const EGLint context_attributes[] = {EGL_CONTEXT_MAJOR_VERSION, 3,
                                         EGL_NONE};
    w->context = eglCreateContext(w->display, config, EGL_NO_CONTEXT,
                                  context_attributes);
    if (w->context == EGL_NO_CONTEXT)
        fail("eglCreateContext");
    eglMakeCurrent(w->display, w->surface, w->surface, w->context);
}

static void destroy_window(Window *w)
{
    eglMakeCurrent(w->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(w->display, w->context);
    eglDestroySurface(w->display, w->surface);
    eglTerminate(w->display);
}

static GLuint compile_shader(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        char log[512];
        glGetShaderInfoLog(shader, sizeof(log), NULL, log);
        printf("Shader compile error: %s\n", log);
        exit(1);
    }
    return shader;
}

static GLuint create_program(void)
{
    GLuint vertex = compile_shader(GL_VERTEX_SHADER, vertex_source);
    GLuint fragment = compile_shader(GL_FRAGMENT_SHADER, fragment_source);
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);
    glDeleteShader(vertex);
    glDeleteShader(fragment);
    return program;
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    // Write the messages to a file on the SD card.
    freopen("sdmc:/gles-triangle.log", "w", stdout);
    setvbuf(stdout, NULL, _IOLBF, 0);

    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    PadState pad;
    padInitializeDefault(&pad);

    Window window;
    create_window(&window);
    printf("GL_RENDERER: %s\n", glGetString(GL_RENDERER));
    printf("GL_VERSION: %s\n", glGetString(GL_VERSION));

    GLuint program = create_program();
    GLint angle_location = glGetUniformLocation(program, "angle");

    GLuint vertex_array, buffer;
    glGenVertexArrays(1, &vertex_array);
    glBindVertexArray(vertex_array);
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float),
                          (void *)0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float),
                          (void *)(2 * sizeof(float)));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);

    for (unsigned frame = 0; appletMainLoop(); frame++) {
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus)
            break;

        glClearColor(0.1f, 0.1f, 0.15f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(program);
        glUniform1f(angle_location, (float)frame / 60.0f);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        eglSwapBuffers(window.display, window.surface);
    }

    glDeleteBuffers(1, &buffer);
    glDeleteVertexArrays(1, &vertex_array);
    glDeleteProgram(program);
    destroy_window(&window);
    return 0;
}
