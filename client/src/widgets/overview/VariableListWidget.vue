<script setup lang="ts">
import { computed, inject, ref } from 'vue';
import type { IVariableSummary } from '../../common';
import {
    OVERVIEW_STATE_KEY,
    type OverviewState,
} from '../../composables/useOverviewState';

import Sparkline from './Sparkline.vue';
import ContinuousDetail from './ContinuousDetail.vue';
import CategoricalDetail from './CategoricalDetail.vue';
import IdDetail from './IdDetail.vue';

const props = defineProps<{
    variables: IVariableSummary[];
    nRows: number;
}>();

const state = inject<OverviewState>(OVERVIEW_STATE_KEY)!;

type Item =
    | { kind: 'header'; key: string; label: string; count: number }
    | { kind: 'row'; key: string; variable: IVariableSummary };

function typeGroupLabel(t: string): string {
    if (t === 'continuous') return 'Continuous';
    if (t === 'nominal') return 'Nominal';
    if (t === 'ordinal') return 'Ordinal';
    if (t === 'id') return 'Identifier';
    return t;
}

const itemsWithHeaders = computed<Item[]>(() => {
    const vars = props.variables;
    if (state.sortMode.value !== 'type' || vars.length === 0) {
        return vars.map((v) => ({
            kind: 'row' as const,
            key: v.name,
            variable: v,
        }));
    }

    const result: Item[] = [];
    let currentType: string | null = null;
    let groupCount = 0;
    let headerIndex = -1;

    for (const v of vars) {
        if (v.type !== currentType) {
            if (headerIndex >= 0) {
                (
                    result[headerIndex] as { kind: 'header'; count: number }
                ).count = groupCount;
            }
            currentType = v.type;
            groupCount = 0;
            result.push({
                kind: 'header',
                key: `header-${v.type}`,
                label: typeGroupLabel(v.type),
                count: 0,
            });
            headerIndex = result.length - 1;
        }
        result.push({ kind: 'row', key: v.name, variable: v });
        groupCount++;
    }
    if (headerIndex >= 0) {
        (result[headerIndex] as { kind: 'header'; count: number }).count =
            groupCount;
    }
    return result;
});

const listRef = ref<HTMLUListElement | null>(null);

function onRowKey(event: KeyboardEvent) {
    const btn = event.currentTarget as HTMLButtonElement;
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        const buttons =
            listRef.value?.querySelectorAll<HTMLButtonElement>('.row');
        if (!buttons) return;
        const arr = Array.from(buttons);
        const idx = arr.indexOf(btn);
        if (idx < 0) return;
        const dir = event.key === 'ArrowDown' ? 1 : -1;
        const target = arr[Math.max(0, Math.min(arr.length - 1, idx + dir))];
        target?.focus();
    } else if (event.key === 'Escape') {
        state.collapseAll();
        (event.currentTarget as HTMLButtonElement).blur();
    }
}

function typeLabel(t: IVariableSummary['type']): string {
    return t === 'continuous'
        ? 'continuous'
        : t === 'ordinal'
          ? 'ordinal'
          : t === 'id'
            ? 'id'
            : 'nominal';
}

function missingPct(v: IVariableSummary): number {
    return props.nRows > 0 ? (v.nMissing / props.nRows) * 100 : 0;
}

function isContinuous(
    v: IVariableSummary
): v is import('../../common').IContinuousSummary {
    return v.type === 'continuous';
}

function isId(v: IVariableSummary): v is import('../../common').IIdSummary {
    return v.type === 'id';
}

function fmt(x: number): string {
    const abs = Math.abs(x);
    if (abs >= 100) return x.toFixed(1);
    if (abs >= 10) return x.toFixed(2);
    return x.toFixed(2);
}

function previewStat(v: IVariableSummary): string {
    if (v.type === 'continuous') {
        if (v.min === v.max) return `constant ${fmt(v.mean)}`;
        return `mean ${fmt(v.mean)} · range ${fmt(v.min)}–${fmt(v.max)}`;
    }
    if (v.type === 'id') {
        return `identifier · ${v.nUnique} unique`;
    }
    if (v.levels.length === 0)
        return `${v.nLevels} level${v.nLevels === 1 ? '' : 's'}`;
    const top = v.levels.reduce(
        (best, l) => (l.count > best.count ? l : best),
        v.levels[0]!
    );
    return `${v.nLevels} level${v.nLevels === 1 ? '' : 's'} · top: ${top.name}`;
}
</script>

<template>
    <ul ref="listRef" class="list" v-if="variables.length > 0">
        <template v-for="item in itemsWithHeaders" :key="item.key">
            <li
                v-if="item.kind === 'header'"
                class="list__group"
                :aria-hidden="true"
            >
                <span class="list__group-label">{{ item.label }}</span>
                <span class="list__group-count"
                    >{{ item.count }}
                    {{ item.count === 1 ? 'var' : 'vars' }}</span
                >
            </li>
            <li
                v-else
                class="list__item"
                :class="{ 'is-expanded': state.isExpanded(item.variable.name) }"
                :data-var-name="item.variable.name"
            >
                <button
                    type="button"
                    class="row"
                    :class="{
                        'is-selected': state.isExpanded(item.variable.name),
                    }"
                    @click="state.toggle(item.variable.name)"
                    @keydown="onRowKey"
                    :aria-expanded="state.isExpanded(item.variable.name)"
                >
                    <span
                        class="row__type-dot"
                        :class="`is-${item.variable.type}`"
                        aria-hidden="true"
                    ></span>
                    <span class="row__name">{{ item.variable.name }}</span>
                    <span class="row__type">{{
                        typeLabel(item.variable.type)
                    }}</span>
                    <span class="row__spark">
                        <Sparkline
                            :variable="item.variable"
                            :selected="state.isExpanded(item.variable.name)"
                        />
                        <span class="row__preview" :aria-hidden="true">
                            <Sparkline
                                :variable="item.variable"
                                :width="220"
                                :height="60"
                            />
                            <span class="row__preview-stat">{{
                                previewStat(item.variable)
                            }}</span>
                        </span>
                    </span>
                    <span
                        class="row__missing"
                        :class="{ 'is-warn': item.variable.nMissing > 0 }"
                    >
                        <template v-if="item.variable.nMissing === 0"
                            >—</template
                        >
                        <template v-else
                            >{{
                                missingPct(item.variable).toFixed(0)
                            }}%</template
                        >
                    </span>
                </button>

                <Transition name="detail">
                    <div
                        v-if="state.isExpanded(item.variable.name)"
                        class="detail"
                    >
                        <ContinuousDetail
                            v-if="isContinuous(item.variable)"
                            :variable="item.variable"
                        />
                        <IdDetail
                            v-else-if="isId(item.variable)"
                            :variable="item.variable"
                        />
                        <CategoricalDetail v-else :variable="item.variable" />
                    </div>
                </Transition>
            </li>
        </template>
    </ul>

    <div v-else class="empty">
        <p>No variables match the current filter.</p>
    </div>
</template>

<style scoped>
.list {
    list-style: none;
    padding: 0;
    margin: 0;
    border-top: 1px solid var(--rule-soft);
}

.list__item {
    border-bottom: 1px solid var(--rule-soft);
    transition:
        margin var(--dur-base) var(--ease-snap),
        box-shadow var(--dur-base) var(--ease-snap);
}

/* Expanded items lift into card-like blocks so a stretch of expanded
   detail panels doesn't visually blend together. */
.list__item.is-expanded {
    border: 1px solid var(--rule);
    border-radius: 4px;
    margin: var(--space-8) 0;
    background: var(--surface);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
    overflow: hidden;
}
.list__item.is-expanded + .list__item.is-expanded {
    margin-top: 0; /* avoid double gap when stacked */
}

.list__group {
    display: flex;
    align-items: baseline;
    gap: var(--space-8);
    padding: var(--space-16) var(--space-12) var(--space-4);
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    font-weight: 600;
    color: var(--ink-3);
    background: var(--surface);
}
.list__group:first-child {
    padding-top: var(--space-6);
}
.list__group-label {
    color: var(--ink-2);
}
.list__group-count {
    color: var(--ink-4);
    font-weight: 500;
}

.row {
    width: 100%;
    background: transparent;
    border: none;
    padding: var(--space-8) var(--space-12);
    display: grid;
    grid-template-columns: 8px minmax(0, 1fr) auto 78px 44px;
    align-items: center;
    gap: var(--space-12);
    cursor: pointer;
    font: inherit;
    color: var(--ink);
    text-align: left;
    transition: background var(--dur-fast) var(--ease-snap);
}
.row:hover {
    background: var(--surface-sunk);
}
.row:focus-visible {
    outline: 2px solid var(--accent-soft);
    outline-offset: -2px;
}
.row.is-selected {
    background: var(--surface-accent);
}

.row__type-dot {
    width: 8px;
    height: 8px;
    border-radius: 2px;
    background: var(--ink-4);
    flex: 0 0 auto;
}
.row__type-dot.is-continuous {
    background: var(--accent);
}
.row__type-dot.is-nominal {
    background: #c28a4a;
}
.row__type-dot.is-ordinal {
    background: #6b9f6b;
}
.row__type-dot.is-id {
    background: var(--ink-4);
}

.row__name {
    font-weight: 500;
    color: var(--ink);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
}
.row.is-selected .row__name {
    color: var(--accent);
    font-weight: 600;
}

.row__type {
    color: var(--ink-3);
    font-size: var(--type-helper);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-weight: 500;
}

.row__spark {
    position: relative;
    display: inline-flex;
    align-items: center;
}

.row__preview {
    position: absolute;
    bottom: calc(100% + 8px);
    right: -8px;
    background: var(--surface);
    border: 1px solid var(--rule);
    border-radius: 3px;
    padding: 8px 10px 6px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    z-index: 20;
    pointer-events: none;
    white-space: nowrap;
    opacity: 0;
    visibility: hidden;
    transform: translateY(2px);
    transition:
        opacity var(--dur-fast) var(--ease-snap),
        transform var(--dur-fast) var(--ease-snap),
        visibility 0s linear var(--dur-fast);
    display: flex;
    flex-direction: column;
    gap: 4px;
}

.row__spark:hover .row__preview {
    opacity: 1;
    visibility: visible;
    transform: translateY(0);
    transition-delay: 80ms, 80ms, 0s;
}

.row__preview-stat {
    font-size: var(--type-helper);
    color: var(--ink-2);
    font-variant-numeric: tabular-nums;
    line-height: 1.3;
}

.row__missing {
    text-align: right;
    color: var(--ink-3);
    font-variant-numeric: tabular-nums;
    font-size: var(--type-helper);
}
.row__missing.is-warn {
    color: var(--ink-2);
    font-weight: 500;
}

/* ---------- detail panel below the selected row ---------- */
.detail {
    background: var(--surface-sunk);
    padding: var(--space-16) var(--space-20) var(--space-16);
    border-top: 1px solid var(--rule-soft);
    overflow: hidden;
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
    transform: scaleY(0.96);
}

/* ---------- empty ---------- */
.empty {
    padding: var(--space-32) var(--space-16);
    text-align: center;
    color: var(--ink-3);
    font-size: var(--type-helper);
    border-top: 1px solid var(--rule-soft);
}
</style>
