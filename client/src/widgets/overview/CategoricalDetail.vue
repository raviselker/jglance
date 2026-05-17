<script setup lang="ts">
import { computed } from 'vue';
import type { ICategoricalSummary } from '../../common';

const props = defineProps<{
    variable: ICategoricalSummary;
}>();

const maxCount = computed(() =>
    Math.max(...props.variable.levels.map((l) => l.count), 1)
);

const modeLevel = computed(() => {
    if (props.variable.levels.length === 0) return null;
    return props.variable.levels.reduce(
        (best, l) => (l.count > best.count ? l : best),
        props.variable.levels[0]!
    );
});

const modeLabel = computed(() => modeLevel.value?.name ?? '—');

const missingPct = computed(() => {
    const total = props.variable.n + props.variable.nMissing;
    if (total === 0) return '0%';
    return ((props.variable.nMissing / total) * 100).toFixed(1) + '%';
});

const headline = computed<string | null>(() => {
    const v = props.variable;
    if (v.nLevels === 0) return null;
    const parts: string[] = [];

    if (v.nLevels === 1) {
        parts.push(`single level: ${v.levels[0]?.name ?? '—'}`);
    } else {
        parts.push(`${v.nLevels} level${v.nLevels === 1 ? '' : 's'}`);
        const mode = modeLevel.value;
        if (mode && v.n > 0) {
            const pct = Math.round((mode.count / v.n) * 100);
            parts.push(`dominant: ${mode.name} (${pct}%)`);
        }
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
</script>

<template>
    <div class="cat">
        <p v-if="variable.description" class="cat__desc">
            {{ variable.description }}
        </p>

        <p v-if="headline" class="cat__headline">{{ headline }}</p>

        <ul class="cat__levels">
            <li
                v-for="lvl in variable.levels"
                :key="lvl.name"
                class="cat__level"
            >
                <span class="cat__level-name">{{ lvl.name }}</span>
                <div class="cat__bar-track">
                    <div
                        class="cat__bar"
                        :style="`width: ${(lvl.count / maxCount) * 100}%`"
                    ></div>
                </div>
                <span class="cat__level-count">{{ lvl.count }}</span>
            </li>
        </ul>

        <p v-if="variable.nTruncated > 0" class="cat__more">
            + {{ variable.nTruncated }} more level{{
                variable.nTruncated === 1 ? '' : 's'
            }}
            not shown
        </p>

        <dl class="cat__stats">
            <div class="cat__stat">
                <dt>Levels</dt>
                <dd>{{ variable.nLevels }}</dd>
            </div>
            <div class="cat__stat">
                <dt>Mode</dt>
                <dd class="cat__stat-text">{{ modeLabel }}</dd>
            </div>
            <div class="cat__stat">
                <dt>Missing</dt>
                <dd>{{ missingPct }}</dd>
            </div>
        </dl>
    </div>
</template>

<style scoped>
.cat {
    display: flex;
    flex-direction: column;
    gap: var(--space-12);
}

.cat__desc {
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

.cat__headline {
    margin: 0;
    font-size: var(--type-body);
    font-style: italic;
    color: var(--ink-2);
    line-height: 1.4;
}

.cat__levels {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 5px;
}

.cat__level {
    display: grid;
    grid-template-columns: minmax(0, 110px) 1fr 40px;
    gap: var(--space-12);
    align-items: center;
    font-size: var(--type-body);
}

.cat__level-name {
    color: var(--ink-2);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.cat__bar-track {
    height: 14px;
    background: var(--rule-soft);
    border-radius: 2px;
    overflow: hidden;
}
.cat__bar {
    height: 100%;
    background: var(--accent);
    transition: width 320ms var(--ease-snap);
}

.cat__level-count {
    color: var(--ink-2);
    font-variant-numeric: tabular-nums;
    font-size: var(--type-helper);
    text-align: right;
}

.cat__more {
    margin: 0;
    padding: 0 4px;
    font-size: var(--type-helper);
    color: var(--ink-3);
    font-style: italic;
}

.cat__stats {
    margin: 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-12) var(--space-16);
    padding-top: var(--space-12);
    border-top: 1px solid var(--rule-soft);
}
.cat__stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
}
.cat__stat dt {
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--ink-3);
    font-weight: 500;
}
.cat__stat dd {
    margin: 0;
    font-size: 17px;
    font-weight: 500;
    color: var(--ink);
    font-variant-numeric: tabular-nums;
    line-height: 1.1;
}
.cat__stat-text {
    font-variant-numeric: normal;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
</style>
