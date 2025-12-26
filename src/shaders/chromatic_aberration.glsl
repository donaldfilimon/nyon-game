#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// Aberration parameters
const float offset = 0.005;

void main()
{
    float r = texture(texture0, fragTexCoord + vec2(offset, 0.0)).r;
    float g = texture(texture0, fragTexCoord).g;
    float b = texture(texture0, fragTexCoord - vec2(offset, 0.0)).b;
    float a = texture(texture0, fragTexCoord).a;
    
    finalColor = vec4(r, g, b, a);
}
