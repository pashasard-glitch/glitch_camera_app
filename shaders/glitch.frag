

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform int uEffectFlags;
uniform sampler2D uTexture;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    uv.y = 1.0 - uv.y;

    vec3 color = texture(uTexture, uv).rgb;

    // 1: RGB Split
    if ((uEffectFlags & 1) != 0) {
        float amt = 0.02 * uIntensity;
        color.r = texture(uTexture, uv + vec2(amt, 0.0)).r;
        color.b = texture(uTexture, uv - vec2(amt, 0.0)).b;
    }

    // 2: VHS / scanlines
    if ((uEffectFlags & 2) != 0) {
        float scan = sin(uv.y * 1200.0 + uTime * 25.0) * 0.1 * uIntensity;
        color -= scan;
        float shift = step(0.94, rand(vec2(floor(uv.y * 90.0), floor(uTime * 20.0))));
        vec3 shifted = texture(uTexture, uv + vec2(shift * 0.04 * uIntensity, 0.0)).rgb;
        color = mix(color, shifted, shift);
        color += vec3(0.1, 0.0, 0.15) * uIntensity;
    }

    // 4: DataMosh — блочный сдвиг
    if ((uEffectFlags & 4) != 0) {
        float row = floor(uv.y * 30.0);
        float col = floor(uv.x * 20.0);
        float block = rand(vec2(row, col + floor(uTime * 6.0)));
        vec2 offset = vec2(
            (block - 0.5) * 0.08 * uIntensity,
            (rand(vec2(col, row)) - 0.5) * 0.03 * uIntensity
        );
        color = mix(color, texture(uTexture, uv + offset).rgb, 0.8);
    }

    // 8: Noise
    if ((uEffectFlags & 8) != 0) {
        float n = rand(uv * uSize + uTime * 100.0);
        color += n * 0.4 * uIntensity;
    }

    // 16: Invert pulse
    if ((uEffectFlags & 16) != 0) {
        float pulse = step(0.96, rand(vec2(floor(uTime * 10.0))));
        color = mix(color, vec3(1.0) - color, pulse * uIntensity);
    }

    // 32: Кислотный оттенок (braincor vibes)
    if ((uEffectFlags & 32) != 0) {
        color *= vec3(1.2, 0.9, 1.3);
        color += vec3(0.05, 0.0, 0.1) * uIntensity;
    }

    fragColor = vec4(color, 1.0);
}
