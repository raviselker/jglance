<script setup lang="ts">
import { computed } from 'vue';
import type { IIdSummary } from '../../common';

const props = defineProps<{
    variable: IIdSummary;
}>();

const missingPct = computed(() => {
    const total = props.variable.n + props.variable.nMissing;
    if (total === 0) return '0%';
    return ((props.variable.nMissing / total) * 100).toFixed(1) + '%';
});

const samplesShown = computed(() => props.variable.samples.slice(0, 6));
const moreSamples = computed(() =>
    Math.max(0, props.variable.samples.length - 6)
);
</script>

<template>
    <div class="id">
        <p v-if="variable.description" class="id__desc">
            {{ variable.description }}
        </p>

        <p class="id__headline">
            Identifier column · {{ variable.nUnique }} unique value{{
                variable.nUnique === 1 ? '' : 's'
            }}
            <template v-if="variable.nMissing > 0">
                · {{ missingPct }} missing</template
            >
        </p>

        <div class="id__samples" v-if="samplesShown.length > 0">
            <p class="id__samples-label">Examples</p>
            <ul class="id__samples-list">
                <li v-for="s in samplesShown" :key="s">{{ s }}</li>
                <li v-if="moreSamples > 0" class="id__samples-more">
                    + {{ moreSamples }} more
                </li>
            </ul>
        </div>

        <dl class="id__stats">
            <div class="id__stat">
                <dt>Unique</dt>
                <dd>{{ variable.nUnique }}</dd>
            </div>
            <div class="id__stat">
                <dt>Observed</dt>
                <dd>{{ variable.n }}</dd>
            </div>
            <div class="id__stat">
                <dt>Missing</dt>
                <dd>{{ missingPct }}</dd>
            </div>
        </dl>
    </div>
</template>

<style scoped>
.id {
    display: flex;
    flex-direction: column;
    gap: var(--space-12);
}

.id__desc {
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

.id__headline {
    margin: 0;
    font-size: var(--type-body);
    font-style: italic;
    color: var(--ink-2);
    line-height: 1.4;
}

.id__samples {
    background: var(--surface);
    border: 1px solid var(--rule-soft);
    border-radius: 2px;
    padding: var(--space-12) var(--space-16);
}

.id__samples-label {
    margin: 0 0 6px;
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--ink-3);
    font-weight: 500;
}

.id__samples-list {
    margin: 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-wrap: wrap;
    gap: 6px 10px;
    font-size: var(--type-body);
    color: var(--ink);
    font-variant-numeric: tabular-nums;
}
.id__samples-list li {
    padding: 1px 6px;
    background: var(--surface-sunk);
    border-radius: 2px;
    border: 1px solid var(--rule-soft);
    font-size: 12px;
}
.id__samples-more {
    background: transparent !important;
    border: none !important;
    color: var(--ink-3);
    font-style: italic;
}

.id__stats {
    margin: 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-12) var(--space-16);
    padding-top: var(--space-12);
    border-top: 1px solid var(--rule-soft);
}
.id__stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
}
.id__stat dt {
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--ink-3);
    font-weight: 500;
}
.id__stat dd {
    margin: 0;
    font-size: 17px;
    font-weight: 500;
    color: var(--ink);
    font-variant-numeric: tabular-nums;
    line-height: 1.1;
}
</style>
