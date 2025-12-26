#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// Bloom parameters
const float threshold = 0.5;
const float intensity = 1.2;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Bright pass
    vec3 bright = max(texelColor.rgb - vec3(threshold), vec3(0.0)) * (1.0 / (1.0 - threshold));
    
    // Simplified blur / bloom accumulation
    // In a real bloom we'd have a separate pass, but here we can do a small kernel
    vec3 bloom = bright;
    float offset = 0.002;
    bloom += max(texture(texture0, fragTexCoord + vec2(offset, 0.0)).rgb - vec3(threshold), 0.0);
    bloom += max(texture(texture0, fragTexCoord - vec2(offset, 0.0)).rgb - vec3(threshold), 0.0);
    bloom += max(texture(texture0, fragTexCoord + vec2(0.0, offset)).rgb - vec3(threshold), 0.0);
    bloom += max(texture(texture0, fragTexCoord - vec2(0.0, offset)).rgb - vec3(threshold), 0.0);
    
    bloom /= 5.0;
    
    finalColor = vec4(texelColor.rgb + bloom * intensity, texelColor.a);
}
