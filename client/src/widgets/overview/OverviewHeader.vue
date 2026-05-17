<script setup lang="ts">
import { computed, inject } from 'vue';
import {
    OVERVIEW_STATE_KEY,
    type OverviewState,
    type OverviewTypeFilter,
    type OverviewSortMode,
} from '../../composables/useOverviewState';
import type { IOverviewData } from '../../common';

import IssuesPanel from './IssuesPanel.vue';

const props = defineProps<{
    data: IOverviewData;
    nRows: number;
    nVarsTotal: number;
    nVarsShown: number;
    nContinuous: number;
    nNominal: number;
    nOrdinal: number;
    nId: number;
    totalCells: number;
    totalMissing: number;
    search: string;
    visibleNames: string[];
    hasIssues: boolean;
}>();

const emit = defineEmits<{
    'update:search': [value: string];
    'show-issues': [];
}>();

const state = inject<OverviewState>(OVERVIEW_STATE_KEY)!;
const { typeFilter, sortMode, expanded, issuesDismissed } = state;

const anyExpanded = computed(() => expanded.value.length > 0);

function toggleExpandAll() {
    if (anyExpanded.value) state.collapseAll();
    else state.expandAll(props.visibleNames);
}

const typeOptions: { id: OverviewTypeFilter; label: string }[] = [
    { id: 'all', label: 'All' },
    { id: 'continuous', label: 'Continuous' },
    { id: 'categorical', label: 'Categorical' },
];

const sortOptions: { id: OverviewSortMode; label: string }[] = [
    { id: 'original', label: 'Original order' },
    { id: 'name', label: 'Name' },
    { id: 'type', label: 'Type' },
    { id: 'missing-desc', label: 'Missing %' },
];

const completePct = computed(() => {
    if (props.totalCells === 0) return 100;
    return 100 - (props.totalMissing / props.totalCells) * 100;
});

const completeLabel = computed(() => {
    const pct = completePct.value;
    if (pct === 100) return '100%';
    if (pct >= 99.95) return '> 99.9%';
    return pct.toFixed(1) + '%';
});

const varsBreakdown = computed(() => {
    const parts: string[] = [];
    if (props.nContinuous > 0) parts.push(`${props.nContinuous} continuous`);
    if (props.nNominal > 0) parts.push(`${props.nNominal} nominal`);
    if (props.nOrdinal > 0) parts.push(`${props.nOrdinal} ordinal`);
    if (props.nId > 0) parts.push(`${props.nId} id`);
    return parts.join(' · ');
});
</script>

<template>
    <header class="header">
        <!-- ===== summary strip ===== -->
        <dl class="summary">
            <div class="summary__stat">
                <dt>Rows</dt>
                <dd>{{ nRows }}</dd>
            </div>
            <div class="summary__stat">
                <dt>Variables</dt>
                <dd>{{ nVarsTotal }}</dd>
                <p v-if="varsBreakdown" class="summary__sub">
                    {{ varsBreakdown }}
                </p>
            </div>
            <div class="summary__stat summary__stat--right">
                <dt>Complete</dt>
                <dd>{{ completeLabel }}</dd>
                <p v-if="totalMissing > 0" class="summary__sub">
                    {{ totalMissing }} cell{{ totalMissing === 1 ? '' : 's' }}
                    missing
                </p>
                <button
                    v-if="hasIssues && issuesDismissed"
                    type="button"
                    class="summary__restore-issues"
                    @click="issuesDismissed = false"
                >
                    Issues hidden (restore)
                </button>
            </div>
        </dl>

        <!-- ===== issues panel (shown above controls if not dismissed) ===== -->
        <IssuesPanel :data="data" />

        <!-- ===== controls (single flex row, wraps when narrow) ===== -->
        <div class="controls">
            <label class="controls__search">
                <svg
                    class="controls__search-icon"
                    width="13"
                    height="13"
                    viewBox="0 0 13 13"
                    aria-hidden="true"
                >
                    <circle
                        cx="5.5"
                        cy="5.5"
                        r="4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.4"
                    />
                    <line
                        x1="8.5"
                        y1="8.5"
                        x2="12"
                        y2="12"
                        stroke="currentColor"
                        stroke-width="1.4"
                        stroke-linecap="round"
                    />
                </svg>
                <input
                    type="text"
                    :value="search"
                    @input="
                        emit(
                            'update:search',
                            ($event.target as HTMLInputElement).value
                        )
                    "
                    placeholder="Search variables…"
                    class="controls__search-input"
                    aria-label="Search variables"
                />
                <button
                    v-if="search"
                    type="button"
                    class="controls__search-clear"
                    @click="emit('update:search', '')"
                    aria-label="Clear search"
                >
                    ×
                </button>
            </label>

            <div class="controls__group">
                <button
                    v-for="opt in typeOptions"
                    :key="opt.id"
                    type="button"
                    class="controls__chip"
                    :class="{ 'is-active': typeFilter === opt.id }"
                    @click="typeFilter = opt.id"
                >
                    {{ opt.label }}
                </button>
            </div>

            <label class="controls__sort">
                <span class="controls__label">Sort:</span>
                <span class="controls__select-wrap">
                    <span class="controls__select-value">{{
                        sortOptions.find((o) => o.id === sortMode)?.label
                    }}</span>
                    <svg
                        class="controls__chev"
                        width="9"
                        height="6"
                        viewBox="0 0 9 6"
                        aria-hidden="true"
                    >
                        <path
                            d="M0.5 0.5L4.5 4.5L8.5 0.5"
                            stroke="currentColor"
                            stroke-width="1.2"
                            fill="none"
                        />
                    </svg>
                    <select
                        v-model="sortMode"
                        class="controls__select"
                        aria-label="Sort variables by"
                    >
                        <option
                            v-for="opt in sortOptions"
                            :key="opt.id"
                            :value="opt.id"
                        >
                            {{ opt.label }}
                        </option>
                    </select>
                </span>
            </label>

            <button
                type="button"
                class="controls__expand"
                :disabled="visibleNames.length === 0"
                @click="toggleExpandAll"
            >
                {{ anyExpanded ? 'Collapse all' : 'Expand all' }}
            </button>

            <span v-if="nVarsShown !== nVarsTotal" class="controls__shown">
                showing {{ nVarsShown }} of {{ nVarsTotal }}
            </span>
        </div>
    </header>
</template>

<style scoped>
.header {
    display: flex;
    flex-direction: column;
    gap: var(--space-12);
    margin-bottom: var(--space-12);
}

/* ---------- summary strip ---------- */
.summary {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr) auto;
    gap: var(--space-24);
    margin: 0;
    padding-bottom: var(--space-16);
    border-bottom: 1px solid var(--rule);
}

.summary__stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
}
.summary__stat--right {
    align-items: flex-end;
    text-align: right;
}

.summary__stat dt {
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--ink-3);
    font-weight: 500;
}

.summary__stat dd {
    margin: 0;
    font-size: 26px;
    font-weight: 600;
    color: var(--ink);
    line-height: 1;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
}

.summary__sub {
    margin: 4px 0 0;
    font-size: var(--type-helper);
    color: var(--ink-3);
    line-height: 1.3;
}

.summary__restore-issues {
    appearance: none;
    background: transparent;
    border: none;
    color: var(--accent);
    font: inherit;
    font-size: var(--type-helper);
    padding: 0;
    margin-top: 6px;
    cursor: pointer;
    border-bottom: 1px dotted var(--accent-soft);
    transition:
        color var(--dur-fast) var(--ease-snap),
        border-color var(--dur-fast) var(--ease-snap);
}
.summary__restore-issues:hover {
    color: var(--bar-selected);
    border-bottom-color: var(--bar-selected);
}

/* ---------- controls (single wrap-row) ---------- */
.controls {
    display: flex;
    align-items: baseline;
    gap: var(--space-12) var(--space-16);
    flex-wrap: wrap;
}

.controls__group {
    display: inline-flex;
    align-items: baseline;
    gap: var(--space-6);
    font-size: var(--type-body);
    color: var(--ink-2);
}

.controls__label {
    color: var(--ink-3);
    font-size: var(--type-helper);
}

.controls__chip {
    appearance: none;
    background: transparent;
    border: 1px solid var(--rule);
    color: var(--ink-2);
    font: inherit;
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 2px;
    cursor: pointer;
    transition:
        background var(--dur-fast) var(--ease-snap),
        color var(--dur-fast) var(--ease-snap),
        border-color var(--dur-fast) var(--ease-snap);
}
.controls__chip:hover {
    color: var(--ink);
    border-color: var(--ink-3);
}
.controls__chip.is-active {
    background: var(--accent);
    color: white;
    border-color: var(--accent);
}

.controls__sort {
    display: inline-flex;
    align-items: baseline;
    gap: var(--space-6);
    font-size: var(--type-body);
    color: var(--ink-2);
    margin-left: auto; /* push Sort + everything after it to the right */
}

.controls__select-wrap {
    position: relative;
    display: inline-flex;
    align-items: baseline;
    gap: 6px;
    color: var(--ink);
    cursor: pointer;
    padding: 2px 8px 2px 6px;
    border: 1px solid var(--rule);
    border-radius: 2px;
    background: var(--surface);
    transition: border-color var(--dur-fast) var(--ease-snap);
}
.controls__select-wrap:hover {
    border-color: var(--accent);
}
.controls__select-wrap:focus-within {
    border-color: var(--accent);
    outline: 2px solid var(--accent-soft);
    outline-offset: -1px;
}

.controls__select-value {
    font-weight: 500;
}

.controls__chev {
    color: var(--ink-3);
    transform: translateY(-1px);
}

.controls__select {
    position: absolute;
    inset: -2px -4px;
    width: calc(100% + 8px);
    opacity: 0;
    cursor: pointer;
    font-family: var(--font-sans);
}

.controls__expand {
    appearance: none;
    background: transparent;
    border: none;
    color: var(--ink-3);
    font: inherit;
    font-size: var(--type-helper);
    padding: 2px 0;
    cursor: pointer;
    border-bottom: 1px dotted var(--ink-4);
    transition:
        color var(--dur-fast) var(--ease-snap),
        border-color var(--dur-fast) var(--ease-snap);
}
.controls__expand:hover:not(:disabled) {
    color: var(--accent);
    border-bottom-color: var(--accent);
}
.controls__expand:disabled {
    opacity: 0.4;
    cursor: not-allowed;
}

.controls__shown {
    margin: 0;
    color: var(--ink-3);
    font-size: var(--type-helper);
    font-style: italic;
}

/* ---------- search (own row — forces remaining controls to wrap below) ---------- */
.controls__search {
    position: relative;
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 6px 4px 10px;
    border: 1px solid var(--rule);
    border-radius: 2px;
    background: var(--surface);
    transition: border-color var(--dur-fast) var(--ease-snap);
    flex: 0 0 100%;
    box-sizing: border-box;
}
.controls__search:hover {
    border-color: var(--ink-3);
}
.controls__search:focus-within {
    border-color: var(--accent);
    outline: 2px solid var(--accent-soft);
    outline-offset: -1px;
}

.controls__search-icon {
    color: var(--ink-3);
    flex: 0 0 auto;
}

.controls__search-input {
    appearance: none;
    border: none;
    background: transparent;
    outline: none;
    font: inherit;
    font-size: var(--type-body);
    color: var(--ink);
    padding: 0;
    flex: 1;
    min-width: 0;
}
.controls__search-input::placeholder {
    color: var(--ink-4);
}

.controls__search-clear {
    appearance: none;
    background: transparent;
    border: none;
    color: var(--ink-3);
    cursor: pointer;
    font-size: 16px;
    line-height: 1;
    padding: 0 4px;
    border-radius: 2px;
}
.controls__search-clear:hover {
    color: var(--ink);
}
</style>
