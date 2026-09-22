#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uEffectFlags;
uniform float uInt[11];
uniform sampler2D uTexture;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

bool flagOn(float flag) {
    return mod(floor(uEffectFlags / flag), 2.0) >= 1.0;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    uv.y = 1.0 - uv.y;

    vec3 color = texture(uTexture, uv).rgb;

    if (flagOn(1.0)) {
        float amt = 0.02 * uInt[0];
        color.r = texture(uTexture, uv + vec2(amt, 0.0)).r;
        color.b = texture(uTexture, uv - vec2(amt, 0.0)).b;
    }

    if (flagOn(2.0)) {
        float i = uInt[1];
        float scan = sin(uv.y * 1200.0 + uTime * 25.0) * 0.1 * i;
        color -= scan;
        float shift = step(0.94, rand(vec2(floor(uv.y * 90.0), floor(uTime * 20.0))));
        vec3 shifted = texture(uTexture, uv + vec2(shift * 0.04 * i, 0.0)).rgb;
        color = mix(color, shifted, shift);
        color += vec3(0.1, 0.0, 0.15) * i;
    }

    if (flagOn(4.0)) {
        float i = uInt[2];
        float row = floor(uv.y * 30.0);
        float col = floor(uv.x * 20.0);
        float block = rand(vec2(row, col + floor(uTime * 6.0)));
        vec2 offset = vec2(
            (block - 0.5) * 0.08 * i,
            (rand(vec2(col, row)) - 0.5) * 0.03 * i
        );
        color = mix(color, texture(uTexture, uv + offset).rgb, 0.8);
    }

    if (flagOn(8.0)) {
        float i = uInt[3];
        float n = rand(uv * uSize + uTime * 100.0);
        color += n * 0.4 * i;
    }

    if (flagOn(16.0)) {
        float i = uInt[4];
        float pulse = step(0.96, rand(vec2(floor(uTime * 10.0))));
        color = mix(color, vec3(1.0) - color, pulse * i);
    }

    if (flagOn(32.0)) {
        float i = uInt[5];
        color *= vec3(1.2, 0.9, 1.3);
        color += vec3(0.05, 0.0, 0.1) * i;
    }

    if (flagOn(64.0)) {
        float i = uInt[6];
        float levels = mix(8.0, 2.5, i);
        vec3 posterized = floor(color * levels) / levels;
        color = mix(color, posterized, min(i * 1.3, 1.0));

        float bandCount = 50.0;
        float bandY = floor(uv.y * bandCount);
        float streakChance = rand(vec2(bandY, floor(uTime * 4.0)));
        float streak = step(0.8, streakChance);
        float streakOffset = (rand(vec2(bandY, 77.0)) - 0.5) * 0.25 * i;
        vec3 streakColor = texture(uTexture, uv + vec2(streakOffset, 0.0)).rgb;
        vec3 streakPosterized = floor(streakColor * levels) / levels;
        color = mix(color, streakPosterized, streak * 0.85);
    }

    if (flagOn(128.0)) {
        float i = uInt[7];
        float line = sin(uv.y * uSize.y * 1.5) * 0.5 + 0.5;
        float darken = mix(1.0, line, 0.5 * i);
        color *= darken;
    }

    if (flagOn(256.0)) {
        float i = uInt[8];
        float scratchX = rand(vec2(floor(uTime * 8.0), 3.0));
        float dist = abs(uv.x - scratchX);
        float scratch = smoothstep(0.002, 0.0, dist) * step(0.5, rand(vec2(floor(uTime * 8.0), 9.0)));
        color += scratch * 0.6 * i;

        float speckle = step(0.995, rand(uv * uSize + uTime * 50.0));
        color += speckle * 0.8;
    }

    if (flagOn(512.0)) {
        float i = uInt[9];
        float gray = dot(color, vec3(0.299, 0.587, 0.114));
        vec3 sepia = vec3(gray * 1.2, gray * 1.0, gray * 0.75);
        color = mix(color, sepia, 0.6 * i);

        float dist = distance(uv, vec2(0.5));
        float vignette = smoothstep(0.9, 0.3, dist);
        color *= mix(1.0, vignette, 0.5 * i);

        color = mix(color, color * 0.85 + 0.05, 0.4 * i);
    }

    if (flagOn(1024.0)) {
        float i = uInt[10];

        // Крупные блоки "смазываются" в случайном направлении, как
        // при поломанном P-кадре в видео.
        float blockSize = mix(40.0, 10.0, i);
        vec2 block = floor(uv * uSize / blockSize);
        float rnd = rand(block + floor(uTime * 3.0));
        float angle = rnd * 6.2831853;
        vec2 dir = vec2(cos(angle), sin(angle));
        float smearAmt = mix(0.0, 0.05, i) * step(0.55, rnd);

        vec3 smeared = vec3(0.0);
        const int SAMPLES = 6;
        for (int s = 0; s < SAMPLES; s++) {
            float t = float(s) / float(SAMPLES - 1);
            smeared += texture(uTexture, uv + dir * smearAmt * t).rgb;
        }
        smeared /= float(SAMPLES);
        color = mix(color, smeared, min(i * 1.2, 1.0));

        // Резкие блочные скачки поверх смаза.
        float jumpChance = rand(block + floor(uTime * 10.0) + 5.0);
        if (jumpChance > 0.92) {
            vec2 jump = (vec2(rand(block), rand(block + 1.0)) - 0.5) * 0.1 * i;
            color = texture(uTexture, uv + jump).rgb;
        }

        // Фиолетово-тёмный оттенок, как при сильном пережатии видео.
        color = mix(color, color * vec3(0.75, 0.55, 0.95), 0.5 * i);
        color *= mix(1.0, 0.75, i * 0.5);
    }

    fragColor = vec4(color, 1.0);
}
