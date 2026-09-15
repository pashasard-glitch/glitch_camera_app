#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;        // размер экрана
uniform float uTime;       // время
uniform float uIntensity;  // интенсивность эффекта
uniform sampler2D uTexture;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;

    // Сдвиг каналов (RGB split)
    float shift = 0.01 * uIntensity;
    float r = texture(uTexture, uv + vec2(shift, 0.0)).r;
    float g = texture(uTexture, uv).g;
    float b = texture(uTexture, uv - vec2(shift, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // Шум
    float noise = rand(uv + uTime) * 0.15 * uIntensity;
    color += noise;

    // VHS-полосы
    float scanline = sin(uv.y * 800.0 + uTime * 10.0) * 0.05 * uIntensity;
    color -= scanline;

    // Случайный сдвиг строк
    float blockShift = step(0.98, rand(vec2(floor(uv.y * 50.0), floor(uTime * 10.0))));
    uv.x += blockShift * 0.05 * uIntensity;

    fragColor = vec4(color, 1.0);
}
