<script setup lang="ts">
import { computed, inject, nextTick } from 'vue'
import type { IOverviewData, IVariableSummary } from '../../common'
import { OVERVIEW_STATE_KEY, type OverviewState } from '../../composables/useOverviewState'

const props = defineProps<{
    data: IOverviewData
}>()

const state = inject<OverviewState>(OVERVIEW_STATE_KEY)!
const { issuesDismissed } = state

interface IIssue {
    id: string
    text: string
    vars: string[]
}

const MISSING_THRESHOLD = 0.2     /* > 20% missing flagged */

function isHighMissing(v: IVariableSummary, nRows: number): boolean {
    return nRows > 0 && v.nMissing / nRows > MISSING_THRESHOLD
}

function isSingleLevel(v: IVariableSummary): boolean {
    return (v.type === 'nominal' || v.type === 'ordinal') && v.nLevels <= 1
}

function isConstantContinuous(v: IVariableSummary): boolean {
    return v.type === 'continuous' && v.n >= 2 && v.sd === 0
}

function isIdLike(v: IVariableSummary, nRows: number): boolean {
    /* Only flag UNMARKED columns that resemble identifiers — columns the
     * user has already typed as ID don't need an "action" callout. */
    if (v.type !== 'nominal' && v.type !== 'ordinal') return false
    return nRows >= 10 && v.nLevels >= nRows * 0.95
}

const issues = computed<IIssue[]>(() => {
    const nRows = props.data.nRows
    const vars = props.data.variables
    const result: IIssue[] = []

    const highMissing = vars.filter(v => isHighMissing(v, nRows))
    if (highMissing.length > 0) {
        result.push({
            id: 'high-missing',
            text: `${highMissing.length} variable${highMissing.length === 1 ? ' has' : 's have'} more than ${MISSING_THRESHOLD * 100}% missing`,
            vars: highMissing.map(v => v.name),
        })
    }

    const singleLevel = vars.filter(isSingleLevel)
    if (singleLevel.length > 0) {
        result.push({
            id: 'single-level',
            text: `${singleLevel.length} categorical variable${singleLevel.length === 1 ? '' : 's'} ${singleLevel.length === 1 ? 'has' : 'have'} only one level`,
            vars: singleLevel.map(v => v.name),
        })
    }

    const constant = vars.filter(isConstantContinuous)
    if (constant.length > 0) {
        result.push({
            id: 'constant',
            text: `${constant.length} continuous variable${constant.length === 1 ? '' : 's'} ${constant.length === 1 ? 'is' : 'are'} constant`,
            vars: constant.map(v => v.name),
        })
    }

    const idLike = vars.filter(v => isIdLike(v, nRows))
    if (idLike.length > 0) {
        result.push({
            id: 'id-like',
            text: `${idLike.length} variable${idLike.length === 1 ? ' looks' : 's look'} like identifier${idLike.length === 1 ? '' : 's'} (near-unique values)`,
            vars: idLike.map(v => v.name),
        })
    }

    return result
})

function onVarClick(name: string) {
    /* Expand if not already; never collapse from this entry point */
    if (!state.isExpanded(name))
        state.toggle(name)
    nextTick(() => {
        const row = document.querySelector(`[data-var-name="${CSS.escape(name)}"]`)
        row?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    })
}
</script>

<template>
    <aside
        v-if="!issuesDismissed && issues.length > 0"
        class="issues"
        aria-label="Data quality notes"
    >
        <header class="issues__head">
            <p class="issues__label">Worth a look</p>
            <button
                type="button"
                class="issues__close"
                @click="issuesDismissed = true"
                aria-label="Dismiss notes"
                title="Dismiss"
            >×</button>
        </header>

        <ul class="issues__list">
            <li v-for="issue in issues" :key="issue.id" class="issues__item">
                <span class="issues__dot" aria-hidden="true"></span>
                <span class="issues__text">{{ issue.text }}</span>
                <span class="issues__vars">
                    <span class="issues__vars-sep">—</span>
                    <template v-for="(varName, i) in issue.vars.slice(0, 3)" :key="varName">
                        <button
                            type="button"
                            class="issues__var-link"
                            @click="onVarClick(varName)"
                        >{{ varName }}</button>
                        <span v-if="i < Math.min(2, issue.vars.length - 1)" class="issues__vars-comma">,</span>
                    </template>
                    <span v-if="issue.vars.length > 3" class="issues__vars-more">
                        + {{ issue.vars.length - 3 }} more
                    </span>
                </span>
            </li>
        </ul>
    </aside>
</template>

<style scoped>
.issues {
    background: color-mix(in srgb, var(--accent) 5%, var(--surface));
    border: 1px solid color-mix(in srgb, var(--accent) 25%, var(--rule));
    border-radius: 3px;
    padding: var(--space-12) var(--space-16);
    margin-bottom: var(--space-16);
}

.issues__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-8);
    margin-bottom: var(--space-8);
}

.issues__label {
    margin: 0;
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--accent);
    font-weight: 600;
}

.issues__close {
    appearance: none;
    background: transparent;
    border: none;
    color: var(--ink-3);
    cursor: pointer;
    font-size: 18px;
    line-height: 1;
    padding: 0 4px;
    border-radius: 2px;
    transition: color var(--dur-fast) var(--ease-snap),
                background var(--dur-fast) var(--ease-snap);
}
.issues__close:hover {
    color: var(--ink);
    background: color-mix(in srgb, var(--ink-3) 10%, transparent);
}

.issues__list {
    margin: 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 5px;
}

.issues__item {
    display: flex;
    align-items: baseline;
    gap: var(--space-8);
    font-size: var(--type-body);
    color: var(--ink-2);
    line-height: 1.4;
    flex-wrap: wrap;
}

.issues__dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--accent);
    flex: 0 0 auto;
    transform: translateY(-1px);
}

.issues__text {
    color: var(--ink);
}

.issues__vars {
    color: var(--ink-3);
    font-size: var(--type-helper);
    display: inline-flex;
    align-items: baseline;
    gap: 4px;
    flex-wrap: wrap;
}
.issues__vars-sep { color: var(--ink-4); }
.issues__vars-comma { color: var(--ink-3); margin-left: -3px; }
.issues__vars-more { color: var(--ink-3); font-style: italic; }

.issues__var-link {
    appearance: none;
    background: transparent;
    border: none;
    color: var(--ink-2);
    font: inherit;
    font-size: var(--type-helper);
    font-style: italic;
    cursor: pointer;
    padding: 0;
    border-bottom: 1px dotted var(--ink-4);
    transition: color var(--dur-fast) var(--ease-snap),
                border-color var(--dur-fast) var(--ease-snap);
}
.issues__var-link:hover {
    color: var(--accent);
    border-bottom-color: var(--accent);
}
.issues__var-link:focus-visible {
    outline: 2px solid var(--accent-soft);
    outline-offset: 2px;
    border-radius: 2px;
}
</style>
