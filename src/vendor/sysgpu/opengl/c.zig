/// OpenGL C bindings wrapper for Zig 0.16+
/// Note: In Zig 0.16, `usingnamespace` was removed. We now export the C namespace directly.
const c = @cImport({
    @cInclude("windows.h");
    @cInclude("GL/glcorearb.h");
    @cInclude("GL/glext.h");
    @cInclude("GL/wglext.h");
});

// Re-export all C declarations
pub const gl = c;

// Common OpenGL type aliases for convenience
pub const GLenum = c.GLenum;
pub const GLboolean = c.GLboolean;
pub const GLbitfield = c.GLbitfield;
pub const GLvoid = c.GLvoid;
pub const GLbyte = c.GLbyte;
pub const GLshort = c.GLshort;
pub const GLint = c.GLint;
pub const GLubyte = c.GLubyte;
pub const GLushort = c.GLushort;
pub const GLuint = c.GLuint;
pub const GLsizei = c.GLsizei;
pub const GLfloat = c.GLfloat;
pub const GLclampf = c.GLclampf;
pub const GLdouble = c.GLdouble;
pub const GLclampd = c.GLclampd;
pub const GLchar = c.GLchar;
pub const GLsizeiptr = c.GLsizeiptr;
pub const GLintptr = c.GLintptr;

// WGL types
pub const HGLRC = c.HGLRC;
pub const HDC = c.HDC;
pub const PIXELFORMATDESCRIPTOR = c.PIXELFORMATDESCRIPTOR;
