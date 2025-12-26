#version 330

// Input vertex attributes
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord)*colDiffuse*fragColor;

    // Invert colors
    finalColor = vec4(1.0 - texelColor.rgb, texelColor.a);
}
