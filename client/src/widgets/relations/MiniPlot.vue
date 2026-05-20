<script setup lang="ts">
import { computed } from 'vue';
import type { IPairDetail } from '../../common';

const props = defineProps<{ detail: IPairDetail }>();

const VB_W = 400;
const VB_H = 140;
const ML = 38;
const MT = 10;
const MR = 8;
const MB = 30;
const PW = VB_W - ML - MR;
const PH = VB_H - MT - MB;

function fmtNum(v: number): string {
    if (typeof v !== 'number' || !isFinite(v)) return '—';
    if (Math.abs(v) >= 1000) return v.toFixed(0);
    if (Math.abs(v) >= 100) return v.toFixed(1);
    if (Math.abs(v) >= 10) return v.toFixed(1);
    return v.toFixed(2);
}

function truncLabel(s: string, max = 16): string {
    return s.length > max ? s.slice(0, max - 1) + '…' : s;
}

function linspace(min: number, max: number, n: number): number[] {
    if (n === 1) return [min];
    return Array.from(
        { length: n },
        (_, i) => min + (i / (n - 1)) * (max - min)
    );
}

const scatterSvg = computed(() => {
    if (props.detail.type !== 'scatter') return null;
    const { points, xLabel, yLabel } = props.detail;
    if (!points.length) return null;

    const xs = points.map((p) => p.x);
    const ys = points.map((p) => p.y);
    const xMin = Math.min(...xs);
    const xMax = Math.max(...xs);
    const yMin = Math.min(...ys);
    const yMax = Math.max(...ys);
    const xRange = xMax - xMin || 1;
    const yRange = yMax - yMin || 1;
    const xPad = xRange * 0.04;
    const yPad = yRange * 0.04;

    const x0 = xMin - xPad;
    const x1 = xMax + xPad;
    const y0 = yMin - yPad;
    const y1 = yMax + yPad;

    const toX = (x: number) => ML + ((x - x0) / (x1 - x0)) * PW;
    const toY = (y: number) => MT + PH - ((y - y0) / (y1 - y0)) * PH;

    const n = points.length;
    const meanX = xs.reduce((a, b) => a + b, 0) / n;
    const meanY = ys.reduce((a, b) => a + b, 0) / n;
    const denom = xs.reduce((s, x) => s + (x - meanX) ** 2, 0);
    const slope = denom
        ? xs.reduce((s, x, i) => s + (x - meanX) * ((ys[i] ?? 0) - meanY), 0) /
          denom
        : 0;
    const intercept = meanY - slope * meanX;

    const xTicks = linspace(xMin, xMax, 4).map((v) => ({
        label: fmtNum(v),
        x: toX(v),
    }));
    const yTicks = linspace(yMin, yMax, 4).map((v) => ({
        label: fmtNum(v),
        y: toY(v),
    }));

    return {
        svgPoints: points.map((p) => ({ x: toX(p.x), y: toY(p.y) })),
        trend: {
            x1: toX(x0),
            y1: toY(intercept + slope * x0),
            x2: toX(x1),
            y2: toY(intercept + slope * x1),
        },
        xTicks,
        yTicks,
        xLabel,
        yLabel,
    };
});

const barsData = computed(() => {
    if (props.detail.type !== 'bars') return null;
    const { groups, contLabel, catLabel } = props.detail;
    if (!groups.length) return null;
    const maxMean = Math.max(...groups.map((g) => g.mean), 0);
    return { groups, contLabel, catLabel, maxMean };
});

const COLORS = [
    '#3e6e96',
    '#c28a4a',
    '#6b9f6b',
    '#9b59b6',
    '#c0392b',
    '#2980b9',
    '#d68910',
    '#717d7e',
];

const mosaicData = computed(() => {
    if (props.detail.type !== 'mosaic') return null;
    const { rows, cols, counts } = props.detail;
    if (!rows.length || !cols.length) return null;

    let globalMax = 1;
    for (let ri = 0; ri < rows.length; ri++) {
        for (let ci = 0; ci < cols.length; ci++) {
            globalMax = Math.max(globalMax, counts[ri]?.[ci] ?? 0);
        }
    }

    const rowData = rows.map((row, ri) => {
        const rowCounts = counts[ri] ?? [];
        const bars = cols.map((col, ci) => {
            const count = rowCounts[ci] ?? 0;
            return { col, color: COLORS[ci % COLORS.length], count, pct: (count / globalMax) * 100 };
        });
        return { row, bars };
    });

    return { rowData };
});
</script>

<template>
    <!-- ── SCATTER: SVG ── -->
    <svg
        v-if="detail.type === 'scatter'"
        :viewBox="`0 0 ${VB_W} ${VB_H}`"
        width="100%"
        :height="VB_H"
        style="display: block; overflow: visible"
    >
        <!-- ── SCATTER ── -->
        <g v-if="scatterSvg">
            <!-- axes -->
            <line :x1="ML" :y1="MT" :x2="ML" :y2="MT + PH" style="stroke: var(--rule)" stroke-width="1" />
            <line :x1="ML" :y1="MT + PH" :x2="ML + PW" :y2="MT + PH" style="stroke: var(--rule)" stroke-width="1" />
            <!-- y ticks + gridlines -->
            <g v-for="t in scatterSvg.yTicks" :key="t.y">
                <line :x1="ML - 3" :y1="t.y" :x2="ML" :y2="t.y" style="stroke: var(--rule)" stroke-width="1" />
                <text :x="ML - 5" :y="t.y + 3.5" text-anchor="end" font-size="9" style="fill: var(--ink-4)">{{ t.label }}</text>
                <line :x1="ML" :y1="t.y" :x2="ML + PW" :y2="t.y" style="stroke: var(--rule-soft)" stroke-width="0.5" stroke-dasharray="2,3" />
            </g>
            <!-- x ticks -->
            <g v-for="t in scatterSvg.xTicks" :key="t.x">
                <line :x1="t.x" :y1="MT + PH" :x2="t.x" :y2="MT + PH + 3" style="stroke: var(--rule)" stroke-width="1" />
                <text :x="t.x" :y="MT + PH + 12" text-anchor="middle" font-size="9" style="fill: var(--ink-4)">{{ t.label }}</text>
            </g>
            <!-- axis labels -->
            <text :x="ML + PW / 2" :y="VB_H - 1" text-anchor="middle" font-size="9" style="fill: var(--ink-3)">
                {{ truncLabel(scatterSvg.xLabel) }}
            </text>
            <text :x="10" :y="MT + PH / 2" text-anchor="middle" font-size="9" style="fill: var(--ink-3)" :transform="`rotate(-90, 10, ${MT + PH / 2})`">
                {{ truncLabel(scatterSvg.yLabel) }}
            </text>
            <!-- trend line — dashed to distinguish from points -->
            <line
                :x1="scatterSvg.trend.x1" :y1="scatterSvg.trend.y1"
                :x2="scatterSvg.trend.x2" :y2="scatterSvg.trend.y2"
                style="stroke: var(--accent)"
                stroke-width="1.5"
                stroke-dasharray="5,3"
                stroke-linecap="round"
                opacity="0.6"
            />
            <!-- points — rendered after trend line so they sit on top -->
            <circle
                v-for="(p, i) in scatterSvg.svgPoints"
                :key="i"
                :cx="p.x" :cy="p.y"
                r="2.5"
                style="fill: var(--accent)"
                stroke="white"
                stroke-width="0.5"
                opacity="0.7"
            />
        </g>

    </svg>

    <!-- ── BARS: HTML (matches Overview's CategoricalDetail style) ── -->
    <div v-else-if="barsData" class="bars-mini">
        <p class="bars-mini__meta">
            Mean {{ barsData.contLabel }} by {{ barsData.catLabel }}
        </p>
        <ul class="bars-mini__list">
            <li
                v-for="g in barsData.groups"
                :key="g.label"
                class="bars-mini__row"
            >
                <span class="bars-mini__name">{{ g.label }}</span>
                <div class="bars-mini__track">
                    <div
                        class="bars-mini__fill"
                        :style="`width: ${barsData.maxMean ? (g.mean / barsData.maxMean) * 100 : 0}%`"
                    ></div>
                </div>
                <span class="bars-mini__value">{{ fmtNum(g.mean) }}</span>
            </li>
        </ul>
    </div>

    <!-- ── MOSAIC: grouped horizontal bars, one per col within each row ── -->
    <div v-else-if="mosaicData" class="mosaic-mini">
        <div
            v-for="r in mosaicData.rowData"
            :key="r.row"
            class="mosaic-group"
        >
            <p class="mosaic-group__label">{{ r.row }}</p>
            <ul class="bars-mini__list">
                <li
                    v-for="b in r.bars"
                    :key="b.col"
                    class="bars-mini__row"
                >
                    <span class="bars-mini__name">{{ b.col }}</span>
                    <div class="bars-mini__track">
                        <div
                            class="bars-mini__fill"
                            :style="`width: ${b.pct}%; background: ${b.color};`"
                        ></div>
                    </div>
                    <span class="bars-mini__value">{{ b.count }}</span>
                </li>
            </ul>
        </div>
    </div>
</template>

<style scoped>
/* ── Bars: horizontal HTML bars matching Overview ── */
.bars-mini {
    display: flex;
    flex-direction: column;
    gap: var(--space-8);
    padding: var(--space-4) 0;
}

.bars-mini__meta {
    margin: 0;
    font-size: var(--type-helper);
    color: var(--ink-3);
    font-style: italic;
}

.bars-mini__list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 5px;
}

.bars-mini__row {
    display: grid;
    grid-template-columns: minmax(0, 110px) 1fr 44px;
    gap: var(--space-12);
    align-items: center;
    font-size: var(--type-body);
}

.bars-mini__name {
    color: var(--ink-2);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.bars-mini__track {
    height: 14px;
    background: var(--rule-soft);
    border-radius: 2px;
    overflow: hidden;
}

.bars-mini__fill {
    height: 100%;
    background: var(--accent);
    border-radius: 2px;
    transition: width 320ms var(--ease-snap);
}

.bars-mini__value {
    color: var(--ink-2);
    font-variant-numeric: tabular-nums;
    font-weight: 600;
    font-size: var(--type-helper);
    text-align: right;
}

/* ── Mosaic: grouped horizontal bars ── */
.mosaic-mini {
    display: flex;
    flex-direction: column;
    gap: var(--space-8);
    padding: var(--space-4) 0;
}

.mosaic-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
}

.mosaic-group + .mosaic-group {
    margin-top: var(--space-4);
    padding-top: var(--space-8);
    border-top: 1px solid var(--rule-soft);
}

.mosaic-group__label {
    margin: 0;
    font-size: var(--type-helper);
    font-weight: 600;
    color: var(--ink-3);
    text-transform: uppercase;
    letter-spacing: 0.06em;
}
</style>
