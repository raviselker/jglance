<script setup lang="ts">
import { computed } from 'vue';
import type { IVariableSummary } from '../../common';

const props = defineProps<{
    variable: IVariableSummary;
    width?: number;
    height?: number;
    selected?: boolean;
}>();

const W = computed(() => props.width ?? 72);
const H = computed(() => props.height ?? 20);

const counts = computed<number[]>(() => {
    if (props.variable.type === 'continuous')
        return props.variable.histogram.counts;
    if (props.variable.type === 'id')
        return []; /* nothing meaningful to plot for IDs */
    return props.variable.levels.map((l) => l.count);
});

const isId = computed(() => props.variable.type === 'id');

const maxCount = computed(() => Math.max(...counts.value, 1));

const barW = computed(() => {
    const n = counts.value.length;
    if (n === 0) return 0;
    const gap = n > 8 ? 0.5 : 1;
    return Math.max(1, (W.value - gap * (n - 1)) / n);
});

function barX(i: number): number {
    return i * (barW.value + (counts.value.length > 8 ? 0.5 : 1));
}

function barY(c: number): number {
    return H.value - Math.max(1, (c / maxCount.value) * H.value);
}

function barH(c: number): number {
    return Math.max(1, (c / maxCount.value) * H.value);
}
</script>

<template>
    <svg
        :width="W"
        :height="H"
        :viewBox="`0 0 ${W} ${H}`"
        class="sparkline"
        :class="{ 'is-selected': selected, 'is-id': isId }"
        aria-hidden="true"
    >
        <line
            v-if="isId"
            :x1="2"
            :x2="W - 2"
            :y1="H - 2"
            :y2="H - 2"
            class="sparkline__id-bar"
        />
        <rect
            v-else
            v-for="(c, i) in counts"
            :key="i"
            :x="barX(i)"
            :y="barY(c)"
            :width="barW"
            :height="barH(c)"
            class="sparkline__bar"
        />
    </svg>
</template>

<style scoped>
.sparkline {
    display: block;
    shape-rendering: crispEdges;
}
.sparkline__bar {
    fill: var(--ink-4);
    transition: fill var(--dur-fast) var(--ease-snap);
}
.sparkline:hover .sparkline__bar {
    fill: var(--ink-3);
}
.sparkline.is-selected .sparkline__bar {
    fill: var(--accent);
}

/* ID variables: a single neutral baseline indicating "identifier" */
.sparkline__id-bar {
    stroke: var(--ink-4);
    stroke-width: 2;
    stroke-linecap: round;
}
.sparkline.is-selected .sparkline__id-bar {
    stroke: var(--accent);
}
</style>
