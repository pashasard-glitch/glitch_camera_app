#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    uv.y = 1.0 - uv.y;

    // RGB split
    float shift = 0.012 * uIntensity;
    float r = texture(uTexture, uv + vec2(shift, 0.0)).r;
    float g = texture(uTexture, uv).g;
    float b = texture(uTexture, uv - vec2(shift, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // VHS-скан-линии
    float scanline = sin(uv.y * 900.0 + uTime * 12.0) * 0.08 * uIntensity;
    color -= scanline;

    // Шум
    float noise = rand(uv + uTime) * 0.15 * uIntensity;
    color += noise;

    // Блочный сдвиг строк (datamosh vibe)
    float blockRow = floor(uv.y * 60.0);
    float blockShift = step(0.97, rand(vec2(blockRow, floor(uTime * 6.0))));
    vec2 uvShift = uv + vec2(blockShift * 0.04 * uIntensity, 0.0);
    vec3 shifted = texture(uTexture, uvShift).rgb;
    color = mix(color, shifted, blockShift);

    fragColor = vec4(color, 1.0);
}
