<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { IPairDetail, VariableType } from '../../common';
import MiniPlot from './MiniPlot.vue';

interface Variable {
    name: string;
    type: VariableType;
}

const props = defineProps<{
    variables: Variable[];
    associations: Record<string, Record<string, number>>;
    allPairDetails?: Record<string, Record<string, IPairDetail>>;
}>();

const wrapRef = ref<HTMLElement | null>(null);
const containerWidth = ref(460);

let ro: ResizeObserver | null = null;
onMounted(() => {
    if (!wrapRef.value) return;
    containerWidth.value = wrapRef.value.clientWidth;
    ro = new ResizeObserver((entries) => {
        containerWidth.value = entries[0]?.contentRect.width ?? 460;
    });
    ro.observe(wrapRef.value);
});
onUnmounted(() => ro?.disconnect());

const n = computed(() => props.variables.length);
const LABEL_W = 88;

const cellSize = computed(() => {
    const count = n.value;
    if (count === 0) return 0;
    // Each cell carries its own left border (1px), so subtract count px for borders
    // plus 2px for the outer matrix border.
    const available = containerWidth.value - LABEL_W - count - 2;
    const ideal = Math.floor(available / count);
    return Math.max(18, Math.min(48, ideal));
});

const showValues = computed(() => cellSize.value >= 32);

const gridStyle = computed(() => ({
    gridTemplateColumns: `${LABEL_W}px repeat(${n.value}, ${cellSize.value}px)`,
}));

function getAssoc(i: number, j: number): number {
    if (i === j) return 1;
    const a = props.variables[i]!;
    const b = props.variables[j]!;
    return props.associations[a.name]?.[b.name] ?? 0;
}

const TYPE_RGB: Record<VariableType, [number, number, number]> = {
    continuous: [62, 110, 150],
    nominal: [194, 138, 74],
    ordinal: [107, 159, 107],
    id: [160, 160, 160],
};

function cellBg(v: number, isDiag: boolean, type: VariableType): string {
    if (isDiag) {
        const [r, g, b] = TYPE_RGB[type];
        return `rgb(${r},${g},${b})`;
    }
    const r = Math.round(240 + (62 - 240) * v);
    const g = Math.round(246 + (110 - 246) * v);
    const b = Math.round(251 + (150 - 251) * v);
    return `rgb(${r},${g},${b})`;
}

function cellFg(v: number, isDiag: boolean): string {
    if (isDiag) return 'rgba(255,255,255,0.75)';
    return v > 0.5 ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.5)';
}

const TYPE_DOT_COLOR: Record<VariableType, string> = {
    continuous: 'var(--type-cont)',
    nominal: 'var(--type-nom)',
    ordinal: 'var(--type-ord)',
    id: 'var(--type-id)',
};

function trunc(s: string, max: number): string {
    return s.length > max ? s.slice(0, max - 1) + '…' : s;
}

const selectedCell = ref<{ i: number; j: number } | null>(null);
const hoveredCell = ref<{ i: number; j: number } | null>(null);

function isRowHighlighted(idx: number): boolean {
    const cur = hoveredCell.value ?? selectedCell.value;
    return cur?.i === idx;
}

function isColHighlighted(idx: number): boolean {
    const cur = hoveredCell.value ?? selectedCell.value;
    return cur?.j === idx;
}

function isSelected(i: number, j: number): boolean {
    const cur = selectedCell.value;
    if (!cur) return false;
    return (cur.i === i && cur.j === j) || (cur.i === j && cur.j === i);
}

function onCellClick(i: number, j: number) {
    if (i === j) return;
    const cur = selectedCell.value;
    const isMirror =
        cur && ((cur.i === i && cur.j === j) || (cur.i === j && cur.j === i));
    selectedCell.value = isMirror ? null : { i, j };
}

function getMetric(typeA: VariableType, typeB: VariableType): string {
    const isCont = (t: VariableType) => t === 'continuous';
    if (isCont(typeA) && isCont(typeB)) return 'R²';
    if (!isCont(typeA) && !isCont(typeB)) return "Cramér's V";
    return 'Eta²';
}

const pairInfo = computed(() => {
    const cur = selectedCell.value;
    if (!cur) return null;
    const a = props.variables[cur.i]!;
    const b = props.variables[cur.j]!;
    return {
        a,
        b,
        v: getAssoc(cur.i, cur.j),
        metric: getMetric(a.type, b.type),
    };
});

// Look up mini-plot data: allPairDetails[rowVar][colVar] — row is treated as
// the "target" axis (y / rows), column as the "predictor" axis (x / cols).
const activePairDetail = computed((): IPairDetail | null => {
    const cur = selectedCell.value;
    if (!cur || !props.allPairDetails) return null;
    const a = props.variables[cur.i]!;
    const b = props.variables[cur.j]!;
    return props.allPairDetails[a.name]?.[b.name] ?? null;
});

function fmt(v: number): string {
    if (typeof v !== 'number' || !isFinite(v)) return '—';
    return v >= 0.995 ? '1.00' : v.toFixed(2);
}
</script>

<template>
    <div ref="wrapRef" class="matrix-scroll">
        <div class="matrix-wrap">
            <template v-if="n > 0">
                <div class="matrix" :style="gridStyle">
                    <!-- Corner -->
                    <div class="matrix__corner"></div>

                    <!-- Column headers (rotated labels) -->
                    <!-- z-index decreases left→right so earlier labels paint over later backgrounds -->
                    <div
                        v-for="(v, j) in variables"
                        :key="`col-${j}`"
                        class="matrix__col-label"
                        :class="{ 'is-cross': isColHighlighted(j) }"
                        :style="{ zIndex: variables.length - j }"
                        :title="v.name"
                    >
                        <span class="matrix__col-label-text">{{
                            trunc(v.name, 8)
                        }}</span>
                    </div>

                    <!-- Data rows -->
                    <template v-for="(varA, i) in variables" :key="`row-${i}`">
                        <div
                            class="matrix__row-label"
                            :class="{ 'is-cross': isRowHighlighted(i) }"
                            :title="varA.name"
                        >
                            <span
                                class="matrix__type-dot"
                                :style="`background: ${TYPE_DOT_COLOR[varA.type]}`"
                            ></span>
                            <span class="matrix__row-label-text">{{
                                trunc(varA.name, 11)
                            }}</span>
                        </div>
                        <div
                            v-for="(varB, j) in variables"
                            :key="`cell-${i}-${j}`"
                            class="matrix__cell"
                            :class="{
                                'is-diag': i === j,
                                'is-selected': isSelected(i, j),
                            }"
                            :style="{
                                background: cellBg(
                                    getAssoc(i, j),
                                    i === j,
                                    varA.type
                                ),
                                color: cellFg(getAssoc(i, j), i === j),
                                height: `${cellSize}px`,
                            }"
                            :title="
                                i === j
                                    ? varA.name
                                    : `${varA.name} × ${varB.name}: ${getMetric(varA.type, varB.type)} = ${fmt(getAssoc(i, j))}`
                            "
                            :role="i !== j ? 'button' : undefined"
                            :tabindex="i !== j ? 0 : undefined"
                            @mouseenter="
                                hoveredCell = i !== j ? { i, j } : null
                            "
                            @mouseleave="hoveredCell = null"
                            @click="onCellClick(i, j)"
                            @keydown.enter="onCellClick(i, j)"
                            @keydown.space.prevent="onCellClick(i, j)"
                        >
                            <span
                                v-if="showValues && i !== j"
                                class="matrix__cell-val"
                                >{{ fmt(getAssoc(i, j)) }}</span
                            >
                        </div>
                    </template>
                </div>

                <!-- Colour scale legend -->
                <div class="matrix__legend">
                    <span class="legend__label">0</span>
                    <div class="legend__ramp"></div>
                    <span class="legend__label">1</span>
                    <span class="legend__hint">Association strength</span>
                </div>

                <!-- Selected pair detail panel -->
                <Transition name="detail">
                    <div v-if="pairInfo" class="matrix__detail">
                        <div class="matrix__pair-strip">
                            <span
                                class="pair-dot"
                                :style="`background: ${TYPE_DOT_COLOR[pairInfo.a.type]}`"
                            ></span>
                            <span class="pair-name">{{ pairInfo.a.name }}</span>
                            <span class="pair-sep">×</span>
                            <span
                                class="pair-dot"
                                :style="`background: ${TYPE_DOT_COLOR[pairInfo.b.type]}`"
                            ></span>
                            <span class="pair-name">{{ pairInfo.b.name }}</span>
                            <span class="pair-metric">{{
                                pairInfo.metric
                            }}</span>
                            <span class="pair-value">{{
                                fmt(pairInfo.v)
                            }}</span>
                        </div>
                        <MiniPlot
                            v-if="activePairDetail"
                            :detail="activePairDetail"
                        />
                    </div>
                </Transition>
            </template>

            <p v-else class="matrix-empty">No variables to display.</p>
        </div>
    </div>
</template>

<style scoped>
.matrix-scroll {
    overflow-x: auto;
}

.matrix-wrap {
    padding-bottom: var(--space-8);
}

.matrix {
    display: grid;
    gap: 0;
    overflow: visible;
    width: fit-content;
}

/* Corner (top-left blank cell) */
.matrix__corner {
    height: 70px;
    background: transparent;
}

/* Column header cells */
.matrix__col-label {
    position: relative;
    height: 70px;
    background: transparent;
    overflow: visible;
    transition: background var(--dur-fast) var(--ease-snap);
}
.matrix__col-label.is-cross {
    background: var(--surface-sunk);
}

.matrix__col-label-text {
    position: absolute;
    bottom: 6px;
    left: 50%; /* pivot at column centre */
    transform: rotate(-45deg);
    transform-origin: 0% 100%; /* rotate from bottom-left = column centre */
    white-space: nowrap;
    font-size: 10px;
    color: var(--ink-3);
    display: block;
    pointer-events: none;
}

/* Row label cells */
.matrix__row-label {
    display: flex;
    align-items: center;
    gap: var(--space-6);
    background: transparent;
    padding: 0 var(--space-8) 0 var(--space-6);
    overflow: hidden;
    transition: background var(--dur-fast) var(--ease-snap);
}
.matrix__row-label.is-cross {
    background: var(--surface-sunk);
}

.matrix__type-dot {
    width: 6px;
    height: 6px;
    border-radius: 1.5px;
    flex: 0 0 auto;
}

.matrix__row-label-text {
    font-size: 11px;
    color: var(--ink-2);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
}

/* Data cells — border-left/top creates the grid lines between cells and also
   the single separator between the label areas and the data grid. */
.matrix__cell {
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: filter var(--dur-fast) var(--ease-snap);
    position: relative;
    border-left: 1px solid var(--rule-soft);
    border-top: 1px solid var(--rule-soft);
}
.matrix__cell.is-diag {
    cursor: default;
}
.matrix__cell:not(.is-diag):hover {
    filter: brightness(0.85);
}
.matrix__cell:not(.is-diag):focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: -2px;
    z-index: 1;
}
.matrix__cell.is-selected {
    box-shadow:
        inset 0 0 0 2px rgba(255, 255, 255, 0.85),
        inset 0 0 0 3.5px rgba(0, 0, 0, 0.4);
    z-index: 1;
}

.matrix__cell-val {
    font-size: 9px;
    font-variant-numeric: tabular-nums;
    font-weight: 600;
    letter-spacing: 0.01em;
    pointer-events: none;
    line-height: 1;
}

/* ── Selected pair detail ── */
.matrix__detail {
    margin-top: var(--space-8);
    border: 1px solid var(--rule);
    border-radius: 3px;
    overflow: hidden;
    background: var(--surface-sunk);
}

.matrix__pair-strip {
    display: flex;
    align-items: center;
    gap: var(--space-6);
    padding: var(--space-8) var(--space-12);
    font-size: var(--type-helper);
    border-bottom: 1px solid var(--rule-soft);
}

.pair-dot {
    width: 7px;
    height: 7px;
    border-radius: 2px;
    flex: 0 0 auto;
}

.pair-name {
    font-weight: 500;
    color: var(--ink);
}

.pair-sep {
    color: var(--ink-4);
    margin: 0 1px;
}

.pair-metric {
    margin-left: auto;
    color: var(--ink-3);
    font-variant-numeric: tabular-nums;
}

.pair-value {
    font-weight: 700;
    color: var(--accent);
    font-variant-numeric: tabular-nums;
    font-size: var(--type-body);
}

/* When a MiniPlot follows, give it padding inside the detail card */
.matrix__detail :deep(.bars-mini),
.matrix__detail :deep(.mosaic-mini),
.matrix__detail :deep(svg) {
    padding-left: var(--space-12);
    padding-right: var(--space-12);
    padding-bottom: var(--space-12);
}

.detail-enter-active,
.detail-leave-active {
    transition:
        opacity var(--dur-fast) var(--ease-snap),
        transform var(--dur-fast) var(--ease-snap);
    transform-origin: top;
}
.detail-enter-from,
.detail-leave-to {
    opacity: 0;
    transform: scaleY(0.97);
}

/* ── Colour scale legend ── */
.matrix__legend {
    display: flex;
    align-items: center;
    gap: var(--space-6);
    margin-top: var(--space-12);
    padding: 0 2px;
}

.legend__label {
    font-size: 10px;
    color: var(--ink-4);
    font-variant-numeric: tabular-nums;
    flex: 0 0 auto;
    width: 10px;
    text-align: center;
}

.legend__ramp {
    width: 80px;
    height: 8px;
    border-radius: 2px;
    background: linear-gradient(
        to right,
        rgb(240, 246, 251),
        rgb(62, 110, 150)
    );
    border: 1px solid var(--rule-soft);
    flex: 0 0 auto;
}

.legend__hint {
    font-size: 10px;
    color: var(--ink-4);
    margin-left: var(--space-8);
}

.matrix-empty {
    color: var(--ink-4);
    font-size: var(--type-helper);
    padding: var(--space-12) 0;
    font-style: italic;
    margin: 0;
}
</style>
