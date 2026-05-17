<script setup lang="ts">
import { computed } from 'vue';
import type { IContinuousSummary } from '../../common';

const props = defineProps<{
    variable: IContinuousSummary;
}>();

const HW = 360;
const HH = 110;
const PAD_Y_TOP = 8;
const PAD_Y_BOT = 18;

const baselineY = HH - PAD_Y_BOT;
const tickEndY = baselineY + 5;
const tickMedianEndY = baselineY + 8;

const bars = computed(() => {
    const counts = props.variable.histogram.counts;
    if (counts.length === 0) return [];
    const maxC = Math.max(...counts, 1);
    const usableW = HW;
    const usableH = HH - PAD_Y_TOP - PAD_Y_BOT;
    const barW = usableW / counts.length;
    return counts.map((c, i) => ({
        x: i * barW + 0.5,
        y: HH - PAD_Y_BOT - (c / maxC) * usableH,
        w: Math.max(1, barW - 1),
        h: Math.max(1, (c / maxC) * usableH),
    }));
});

function xForValue(v: number): number {
    const lo = props.variable.min;
    const hi = props.variable.max;
    if (hi === lo) return HW / 2;
    return ((v - lo) / (hi - lo)) * HW;
}

function isBimodalHint(counts: number[]): boolean {
    if (counts.length < 5) return false;
    const peaks: number[] = [];
    for (let i = 1; i < counts.length - 1; i++) {
        const c = counts[i] ?? 0;
        const prev = counts[i - 1] ?? 0;
        const next = counts[i + 1] ?? 0;
        if (c > prev && c >= next && c > 0) peaks.push(i);
    }
    if (peaks.length < 2) return false;
    peaks.sort((a, b) => (counts[b] ?? 0) - (counts[a] ?? 0));
    const p1 = peaks[0]!,
        p2 = peaks[1]!;
    const lo = Math.min(p1, p2),
        hi = Math.max(p1, p2);
    if (hi - lo < 2) return false;
    let valley = Infinity;
    for (let i = lo + 1; i < hi; i++) {
        const c = counts[i] ?? Infinity;
        if (c < valley) valley = c;
    }
    const smallerPeak = Math.min(counts[p1] ?? 0, counts[p2] ?? 0);
    return valley < smallerPeak * 0.5;
}

const headline = computed<string | null>(() => {
    const v = props.variable;
    if (v.n === 0) return null;
    const parts: string[] = [];

    if (v.n < 5) {
        parts.push(`only ${v.n} observation${v.n === 1 ? '' : 's'}`);
    } else if (v.sd === 0 || v.min === v.max) {
        parts.push(`constant at ${fmt(v.mean)}`);
    } else if (
        v.integer &&
        v.nUnique != null &&
        v.nUnique <= 7 &&
        v.min >= 0 &&
        v.max <= 10
    ) {
        parts.push(
            `Likert-like (${fmt(v.min)}–${fmt(v.max)}, ${v.nUnique} unique)`
        );
    } else if (isBimodalHint(v.histogram.counts)) {
        parts.push('bimodal-suggesting');
    } else {
        const skew = (3 * (v.mean - v.median)) / v.sd;
        if (skew > 0.5) parts.push('right-skewed');
        else if (skew < -0.5) parts.push('left-skewed');
        else parts.push('approximately symmetric');
        if (v.integer) parts.push('integer-valued');
    }

    if (v.sd > 0 && v.min !== v.max) {
        parts.push(`range ${fmt(v.min)}–${fmt(v.max)}`);
    }

    if (v.nMissing === 0) {
        parts.push('no missing');
    } else {
        const totalN = v.n + v.nMissing;
        const pct = ((v.nMissing / totalN) * 100).toFixed(1);
        parts.push(`${pct}% missing`);
    }

    return parts.join(' · ');
});

function fmt(v: number): string {
    if (v === 0) return '0';
    const abs = Math.abs(v);
    if (abs >= 1000) return v.toFixed(0);
    if (abs >= 100) return v.toFixed(1);
    if (abs >= 10) return v.toFixed(2);
    return v.toFixed(3);
}

const missingPct = computed(() => {
    const total = props.variable.n + props.variable.nMissing;
    if (total === 0) return '0%';
    return ((props.variable.nMissing / total) * 100).toFixed(1) + '%';
});
</script>

<template>
    <div class="cd">
        <p v-if="variable.description" class="cd__desc">
            {{ variable.description }}
        </p>

        <p v-if="headline" class="cd__headline">{{ headline }}</p>

        <div class="cd__hist">
            <svg
                :viewBox="`0 0 ${HW} ${HH + 12}`"
                preserveAspectRatio="none"
                class="cd__svg"
                aria-hidden="true"
            >
                <line
                    :x1="0"
                    :x2="HW"
                    :y1="baselineY"
                    :y2="baselineY"
                    class="cd__baseline"
                />
                <rect
                    v-for="(b, i) in bars"
                    :key="i"
                    :x="b.x"
                    :y="b.y"
                    :width="b.w"
                    :height="b.h"
                    class="cd__bar"
                />

                <!-- quartile ticks below baseline -->
                <g
                    v-if="
                        variable.q1 !== undefined && variable.q3 !== undefined
                    "
                    class="cd__quart"
                >
                    <line
                        :x1="xForValue(variable.q1)"
                        :x2="xForValue(variable.q1)"
                        :y1="baselineY"
                        :y2="tickEndY"
                        class="cd__quart-tick"
                    />
                    <line
                        :x1="xForValue(variable.median)"
                        :x2="xForValue(variable.median)"
                        :y1="baselineY"
                        :y2="tickMedianEndY"
                        class="cd__quart-median"
                    />
                    <line
                        :x1="xForValue(variable.q3)"
                        :x2="xForValue(variable.q3)"
                        :y1="baselineY"
                        :y2="tickEndY"
                        class="cd__quart-tick"
                    />
                </g>
            </svg>
            <div class="cd__axis">
                <span>{{ fmt(variable.min) }}</span>
                <span class="cd__axis-name">{{ variable.name }}</span>
                <span>{{ fmt(variable.max) }}</span>
            </div>
        </div>

        <dl class="cd__stats">
            <div class="cd__stat">
                <dt>Mean</dt>
                <dd>{{ fmt(variable.mean) }}</dd>
            </div>
            <div class="cd__stat">
                <dt>SD</dt>
                <dd>{{ fmt(variable.sd) }}</dd>
            </div>
            <div class="cd__stat">
                <dt>Median</dt>
                <dd>{{ fmt(variable.median) }}</dd>
            </div>
            <div class="cd__stat">
                <dt>Min</dt>
                <dd>{{ fmt(variable.min) }}</dd>
            </div>
            <div class="cd__stat">
                <dt>Max</dt>
                <dd>{{ fmt(variable.max) }}</dd>
            </div>
            <div class="cd__stat">
                <dt>Missing</dt>
                <dd>{{ missingPct }}</dd>
            </div>
        </dl>
    </div>
</template>

<style scoped>
.cd {
    display: flex;
    flex-direction: column;
    gap: var(--space-12);
}

.cd__desc {
    margin: 0;
    padding: var(--space-8) var(--space-12);
    font-size: var(--type-body);
    font-style: italic;
    color: var(--ink);
    line-height: 1.45;
    background: var(--surface-accent);
    border-left: 3px solid var(--accent);
    border-radius: 0 2px 2px 0;
}

.cd__headline {
    margin: 0;
    font-size: var(--type-body);
    font-style: italic;
    color: var(--ink-2);
    line-height: 1.4;
}

.cd__hist {
    background: var(--surface);
    border: 1px solid var(--rule-soft);
    border-radius: 2px;
    padding: var(--space-8) var(--space-8) 0;
}

.cd__svg {
    width: 100%;
    height: 110px;
    display: block;
}

.cd__baseline {
    stroke: var(--ink-3);
    stroke-width: 1;
    shape-rendering: crispEdges;
    vector-effect: non-scaling-stroke;
}
.cd__bar {
    fill: var(--accent);
}

/* quartile tick marks */
.cd__quart-tick {
    stroke: var(--ink-3);
    stroke-width: 1;
    vector-effect: non-scaling-stroke;
    shape-rendering: crispEdges;
}
.cd__quart-median {
    stroke: var(--ink);
    stroke-width: 1.5;
    vector-effect: non-scaling-stroke;
    shape-rendering: crispEdges;
}

.cd__axis {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    padding: 4px 4px 6px;
    font-size: var(--type-helper);
    color: var(--ink-3);
    font-variant-numeric: tabular-nums;
}
.cd__axis-name {
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-weight: 500;
    color: var(--ink-3);
    font-variant-numeric: normal;
}

.cd__stats {
    margin: 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-12) var(--space-16);
}
.cd__stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
}
.cd__stat dt {
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--ink-3);
    font-weight: 500;
}
.cd__stat dd {
    margin: 0;
    font-size: 17px;
    font-weight: 500;
    color: var(--ink);
    font-variant-numeric: tabular-nums;
    line-height: 1.1;
}
</style>
