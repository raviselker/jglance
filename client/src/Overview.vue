<script setup lang="ts">
import { computed, provide, ref } from 'vue';
import type { IOverviewData, IPlotStateStore } from './common';
import {
    useOverviewState,
    OVERVIEW_STATE_KEY,
} from './composables/useOverviewState';

import OverviewHeader from './widgets/overview/OverviewHeader.vue';
import VariableListWidget from './widgets/overview/VariableListWidget.vue';

const props = defineProps<{
    data: IOverviewData;
    state: IPlotStateStore;
}>();

const overviewState = useOverviewState(props.state, props.data);
provide(OVERVIEW_STATE_KEY, overviewState);

/* Search is intentionally local — not persisted across re-renders */
const searchQuery = ref('');

const filteredVars = computed(() => {
    const tf = overviewState.typeFilter.value;
    const q = searchQuery.value.toLowerCase().trim();
    return props.data.variables.filter((v) => {
        if (tf === 'continuous' && v.type !== 'continuous') return false;
        /* 'categorical' chip groups nominal + ordinal + id together */
        if (tf === 'categorical' && v.type === 'continuous') return false;
        if (q) {
            const inName = v.name.toLowerCase().includes(q);
            const inDesc =
                !!v.description && v.description.toLowerCase().includes(q);
            if (!inName && !inDesc) return false;
        }
        return true;
    });
});

const sortedVars = computed(() => {
    const arr = [...filteredVars.value];
    const mode = overviewState.sortMode.value;
    if (mode === 'name') arr.sort((a, b) => a.name.localeCompare(b.name));
    else if (mode === 'type')
        arr.sort(
            (a, b) =>
                a.type.localeCompare(b.type) || a.name.localeCompare(b.name)
        );
    else if (mode === 'missing-desc')
        arr.sort((a, b) => b.nMissing - a.nMissing);
    return arr;
});

/* ---------- dataset-level summary stats for the header ---------- */
const summaryStats = computed(() => {
    const all = props.data.variables;
    let nContinuous = 0,
        nNominal = 0,
        nOrdinal = 0,
        nId = 0;
    let totalMissing = 0;
    for (const v of all) {
        switch (v.type) {
            case 'continuous':
                nContinuous++;
                break;
            case 'nominal':
                nNominal++;
                break;
            case 'ordinal':
                nOrdinal++;
                break;
            case 'id':
                nId++;
                break;
        }
        totalMissing += v.nMissing;
    }
    return {
        nContinuous,
        nNominal,
        nOrdinal,
        nId,
        totalCells: props.data.nRows * all.length,
        totalMissing,
    };
});

/* ---------- issue detection logic (duplicated from IssuesPanel) ---------- */
const hasIssues = computed(() => {
    const nRows = props.data.nRows;
    const vars = props.data.variables;
    const MISSING_THRESHOLD = 0.2;

    const isHighMissing = (v: any) =>
        nRows > 0 && v.nMissing / nRows > MISSING_THRESHOLD;
    const isSingleLevel = (v: any) =>
        (v.type === 'nominal' || v.type === 'ordinal') && v.nLevels <= 1;
    const isConstantContinuous = (v: any) =>
        v.type === 'continuous' && v.n >= 2 && v.sd === 0;
    const isIdLike = (v: any) => {
        if (v.type !== 'nominal' && v.type !== 'ordinal') return false;
        return nRows >= 10 && v.nLevels >= nRows * 0.95;
    };

    return vars.some(
        (v) =>
            isHighMissing(v) ||
            isSingleLevel(v) ||
            isConstantContinuous(v) ||
            isIdLike(v)
    );
});
</script>

<template>
    <article class="jglance jglance--overview">
        <OverviewHeader
            v-model:search="searchQuery"
            :data="data"
            :n-rows="data.nRows"
            :n-vars-total="data.variables.length"
            :n-vars-shown="sortedVars.length"
            :n-continuous="summaryStats.nContinuous"
            :n-nominal="summaryStats.nNominal"
            :n-ordinal="summaryStats.nOrdinal"
            :n-id="summaryStats.nId"
            :total-cells="summaryStats.totalCells"
            :total-missing="summaryStats.totalMissing"
            :visible-names="sortedVars.map((v) => v.name)"
            :has-issues="hasIssues"
        />

        <div v-if="data.variables.length === 0" class="jglance__empty">
            <p>Nothing to show yet.</p>
            <p class="jglance__empty-hint">
                Drop variables into the supplier on the left to see an overview.
            </p>
        </div>

        <VariableListWidget
            v-else
            :variables="sortedVars"
            :n-rows="data.nRows"
        />
    </article>
</template>

<style scoped>
.jglance--overview {
    container-type: inline-size;
    container-name: overview;

    background: var(--surface);
    color: var(--ink);
    padding: var(--space-16) var(--space-20) var(--space-16);
    font-family: var(--font-sans);
    font-size: var(--type-body);
    line-height: 1.5;
}

.jglance__empty {
    padding: var(--space-32) var(--space-16);
    text-align: center;
    color: var(--ink-2);
    font-size: var(--type-body);
}
.jglance__empty p {
    margin: 4px 0;
}
.jglance__empty-hint {
    font-size: var(--type-helper);
    color: var(--ink-3);
}
</style>
