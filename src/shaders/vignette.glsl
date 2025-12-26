#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// Vignette parameters
const float radius = 0.75;
const float soft = 0.45;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Distance from center
    vec2 pos = fragTexCoord - vec2(0.5);
    float dist = length(pos);
    
    // Vignette calculation
    float vignette = smoothstep(radius, radius - soft, dist);
    
    finalColor = vec4(texelColor.rgb * vignette, texelColor.a);
}
