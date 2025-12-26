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

    // Apply sepia filter
    float r = dot(texelColor.rgb, vec3(0.393, 0.769, 0.189));
    float g = dot(texelColor.rgb, vec3(0.349, 0.686, 0.168));
    float b = dot(texelColor.rgb, vec3(0.272, 0.534, 0.131));
    
    finalColor = vec4(r, g, b, texelColor.a);
}
