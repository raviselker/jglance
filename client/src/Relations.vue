<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import type {
    IRelationsData,
    IPairDetail,
    IPlotStateStore,
    VariableType,
} from './common';
import MiniPlot from './widgets/relations/MiniPlot.vue';
import MatrixView from './widgets/relations/MatrixView.vue';
import { useRelationsState } from './composables/useRelationsState';
import type {
    RelationsSortMode,
    RelationsTypeFilter,
} from './composables/useRelationsState';

const props = defineProps<{
    data: IRelationsData;
    state: IPlotStateStore;
}>();

const { selectedTarget, viewMode, typeFilter, sortMode, expandedVars } =
    useRelationsState(props.data, props.state);
const showDropdown = ref(false);

type SortMode = RelationsSortMode;
const sortOptions: { id: SortMode; label: string }[] = [
    { id: 'strength', label: 'Effect strength' },
    { id: 'name', label: 'Name' },
    { id: 'type', label: 'Type' },
    { id: 'original', label: 'Original order' },
];

type TypeFilter = RelationsTypeFilter;
const typeOptions: { id: TypeFilter; label: string }[] = [
    { id: 'all', label: 'All' },
    { id: 'continuous', label: 'Continuous' },
    { id: 'categorical', label: 'Categorical' },
];
const dropdownSearch = ref('');
const searchInputRef = ref<HTMLInputElement | null>(null);

watch(selectedTarget, () => {
    expandedVars.value = new Set();
});

function handleDocClick() {
    showDropdown.value = false;
}
onMounted(() => document.addEventListener('click', handleDocClick));
onUnmounted(() => document.removeEventListener('click', handleDocClick));

async function openDropdown(e: Event) {
    e.stopPropagation();
    if (showDropdown.value) {
        showDropdown.value = false;
        return;
    }
    showDropdown.value = true;
    dropdownSearch.value = '';
    await nextTick();
    searchInputRef.value?.focus();
}

function closeDropdown() {
    showDropdown.value = false;
}

function setFocus(varName: string) {
    selectedTarget.value = varName;
    showDropdown.value = false;
    expandedVars.value = new Set();
}

function toggleExpand(varName: string) {
    if (!pairDetail(varName)) return;
    const next = new Set(expandedVars.value);
    if (next.has(varName)) next.delete(varName);
    else next.add(varName);
    expandedVars.value = next;
}

const anyExpanded = computed(() => expandedVars.value.size > 0);

function expandAll() {
    expandedVars.value = new Set(
        predictors.value.filter((p) => !!pairDetail(p.name)).map((p) => p.name)
    );
}

function collapseAll() {
    expandedVars.value = new Set();
}

const targetVar = computed(() =>
    props.data.variables.find((v) => v.name === selectedTarget.value)
);

const filteredDropdownVars = computed(() => {
    const q = dropdownSearch.value.toLowerCase().trim();
    if (!q) return props.data.variables;
    return props.data.variables.filter(
        (v) =>
            v.name.toLowerCase().includes(q) ||
            (v.description && v.description.toLowerCase().includes(q))
    );
});

const TYPE_ORDER: Record<VariableType, number> = {
    continuous: 0,
    nominal: 1,
    ordinal: 2,
    id: 3,
};

const predictors = computed(() => {
    if (!selectedTarget.value) return [];
    const assocs = (props.data.associations ?? {})[selectedTarget.value] ?? {};
    let vars = props.data.variables
        .filter((v) => v.name !== selectedTarget.value)
        .map((v) => ({ ...v, association: assocs[v.name] ?? 0 }));
    if (typeFilter.value === 'continuous') {
        vars = vars.filter((v) => v.type === 'continuous');
    } else if (typeFilter.value === 'categorical') {
        vars = vars.filter((v) => v.type !== 'continuous');
    }
    switch (sortMode.value) {
        case 'name':
            return [...vars].sort((a, b) => a.name.localeCompare(b.name));
        case 'type':
            return [...vars].sort(
                (a, b) =>
                    TYPE_ORDER[a.type] - TYPE_ORDER[b.type] ||
                    b.association - a.association
            );
        case 'original':
            return vars;
        default:
            return [...vars].sort((a, b) => b.association - a.association);
    }
});

function typeGroupLabel(t: VariableType): string {
    const labels: Record<VariableType, string> = {
        continuous: 'Continuous',
        nominal: 'Nominal',
        ordinal: 'Ordinal',
        id: 'Identifier',
    };
    return labels[t];
}

type PredictorItem =
    | { kind: 'colheader'; key: string }
    | { kind: 'header'; key: string; label: string; count: number }
    | {
          kind: 'row';
          key: string;
          name: string;
          description: string | null;
          type: VariableType;
          association: number;
      };

const predictorItems = computed((): PredictorItem[] => {
    const sorted = predictors.value;
    if (sortMode.value !== 'type') {
        const rows = sorted.map((p) => ({
            kind: 'row' as const,
            key: p.name,
            ...p,
        }));
        return [{ kind: 'colheader', key: 'colheader' }, ...rows];
    }
    const items: PredictorItem[] = [];
    let lastType: VariableType | null = null;
    for (const p of sorted) {
        if (p.type !== lastType) {
            const count = sorted.filter((x) => x.type === p.type).length;
            items.push({
                kind: 'header',
                key: `header-${p.type}`,
                label: typeGroupLabel(p.type),
                count,
            });
            lastType = p.type;
        }
        items.push({ kind: 'row', key: p.name, ...p });
    }
    return items;
});

const associationBreakdown = computed(() => {
    if (!selectedTarget.value) return '';
    const vars = props.data.variables.filter(
        (v) => v.name !== selectedTarget.value
    );
    let nCont = 0,
        nCat = 0;
    for (const v of vars) {
        if (v.type === 'continuous') nCont++;
        else nCat++;
    }
    const parts: string[] = [];
    if (nCont > 0) parts.push(`${nCont} continuous`);
    if (nCat > 0) parts.push(`${nCat} categorical`);
    return `${vars.length} associations · ${parts.join(' · ')}`;
});

const matrixVars = computed(() => {
    let vars = props.data.variables;
    if (typeFilter.value === 'continuous') {
        vars = vars.filter((v) => v.type === 'continuous');
    } else if (typeFilter.value === 'categorical') {
        vars = vars.filter((v) => v.type !== 'continuous');
    }
    return vars;
});

function pairDetail(varName: string): IPairDetail | null {
    return props.data.pairDetails?.[varName] ?? null;
}

function statLabel(targetType: VariableType, varType: VariableType): string {
    const isCont = (t: VariableType) => t === 'continuous';
    if (isCont(targetType) && isCont(varType)) return 'R²';
    if (!isCont(targetType) && !isCont(varType)) return 'V';
    return 'Eta²';
}

function typeLabel(t: VariableType): string {
    if (t === 'id') return 'id';
    return t;
}

function typeColor(t: VariableType): string {
    const map: Record<VariableType, string> = {
        continuous: 'var(--type-cont)',
        nominal: 'var(--type-nom)',
        ordinal: 'var(--type-ord)',
        id: 'var(--type-id)',
    };
    return map[t];
}

function fmt(v: number): string {
    if (typeof v !== 'number' || !isFinite(v)) return '—';
    if (v >= 0.995) return '1.00';
    return v.toFixed(2);
}
</script>

<template>
    <article class="jglance jglance--relations">
        <!-- ── Empty state (fewer than 2 vars) ── -->
        <template v-if="data.error">
            <div class="relations__empty">
                <svg
                    class="relations__empty-icon"
                    width="48"
                    height="48"
                    viewBox="0 0 48 48"
                    fill="none"
                    aria-hidden="true"
                >
                    <line
                        x1="8"
                        y1="40"
                        x2="42"
                        y2="7"
                        stroke="currentColor"
                        stroke-width="1.5"
                        opacity="0.18"
                        stroke-linecap="round"
                    />
                    <circle
                        cx="10"
                        cy="38"
                        r="3"
                        fill="currentColor"
                        opacity="0.2"
                    />
                    <circle
                        cx="17"
                        cy="30"
                        r="3"
                        fill="currentColor"
                        opacity="0.3"
                    />
                    <circle
                        cx="24"
                        cy="23"
                        r="3"
                        fill="currentColor"
                        opacity="0.45"
                    />
                    <circle
                        cx="31"
                        cy="17"
                        r="3"
                        fill="currentColor"
                        opacity="0.3"
                    />
                    <circle
                        cx="39"
                        cy="10"
                        r="3"
                        fill="currentColor"
                        opacity="0.2"
                    />
                </svg>
                <p class="relations__empty-title">
                    {{
                        data.variables.length === 0
                            ? 'Nothing to show yet'
                            : 'One more variable needed'
                    }}
                </p>
                <p class="relations__empty-hint">{{ data.error }}</p>
            </div>
        </template>

        <div v-else class="relations">
            <!-- ── View mode toggle ── -->
            <div class="view-toggle" role="group" aria-label="View mode">
                <button
                    type="button"
                    class="view-toggle__btn"
                    :class="{ 'is-active': viewMode === 'list' }"
                    @click="viewMode = 'list'"
                >
                    <svg
                        width="13"
                        height="11"
                        viewBox="0 0 13 11"
                        aria-hidden="true"
                        fill="none"
                    >
                        <line
                            x1="0"
                            y1="1"
                            x2="13"
                            y2="1"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linecap="round"
                        />
                        <line
                            x1="0"
                            y1="5.5"
                            x2="13"
                            y2="5.5"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linecap="round"
                        />
                        <line
                            x1="0"
                            y1="10"
                            x2="13"
                            y2="10"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linecap="round"
                        />
                    </svg>
                    <span>List</span>
                </button>
                <button
                    type="button"
                    class="view-toggle__btn"
                    :class="{ 'is-active': viewMode === 'matrix' }"
                    @click="viewMode = 'matrix'"
                >
                    <svg
                        width="12"
                        height="12"
                        viewBox="0 0 12 12"
                        aria-hidden="true"
                    >
                        <rect
                            x="0"
                            y="0"
                            width="5"
                            height="5"
                            rx="1"
                            fill="currentColor"
                        />
                        <rect
                            x="7"
                            y="0"
                            width="5"
                            height="5"
                            rx="1"
                            fill="currentColor"
                        />
                        <rect
                            x="0"
                            y="7"
                            width="5"
                            height="5"
                            rx="1"
                            fill="currentColor"
                        />
                        <rect
                            x="7"
                            y="7"
                            width="5"
                            height="5"
                            rx="1"
                            fill="currentColor"
                        />
                    </svg>
                    <span>Matrix</span>
                </button>
            </div>

            <!-- ── Focus section ── -->
            <div
                v-if="viewMode === 'list'"
                class="focus-section"
                :class="{ 'is-open': showDropdown }"
                @click.stop
            >
                <!-- Trigger row -->
                <div
                    class="focus-trigger"
                    role="button"
                    tabindex="0"
                    :aria-expanded="showDropdown"
                    @click="openDropdown"
                    @keydown.enter.prevent="openDropdown"
                    @keydown.space.prevent="openDropdown"
                >
                    <div class="focus-trigger__body">
                        <span class="focus-trigger__eyebrow"
                            >Focus Variable</span
                        >
                        <div v-if="targetVar" class="focus-trigger__selected">
                            <span
                                class="type-dot"
                                :class="`is-${targetVar.type}`"
                                aria-hidden="true"
                            ></span>
                            <span class="focus-trigger__name">{{
                                targetVar.name
                            }}</span>
                            <svg
                                class="focus-trigger__chevron"
                                :class="{ 'is-open': showDropdown }"
                                width="10"
                                height="6"
                                viewBox="0 0 10 6"
                                aria-hidden="true"
                            >
                                <path
                                    d="M0.5 0.5L5 4.5L9.5 0.5"
                                    stroke="currentColor"
                                    stroke-width="1.3"
                                    fill="none"
                                    stroke-linecap="round"
                                />
                            </svg>
                        </div>
                        <span v-else class="focus-trigger__placeholder">
                            Select a variable to explore…
                        </span>
                        <span v-if="targetVar" class="focus-trigger__meta">
                            {{ typeLabel(targetVar.type) }} ·
                            {{ associationBreakdown }}
                        </span>
                    </div>
                </div>

                <!-- Dropdown panel -->
                <div
                    v-if="showDropdown"
                    class="focus-dropdown"
                    @click.stop
                    @keydown.escape="closeDropdown"
                >
                    <!-- Search input — matches Overview's search style -->
                    <label class="focus-search">
                        <svg
                            class="focus-search__icon"
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
                            ref="searchInputRef"
                            v-model="dropdownSearch"
                            type="text"
                            class="focus-search__input"
                            placeholder="Search variables…"
                            aria-label="Search variables"
                            @keydown.escape="closeDropdown"
                        />
                        <button
                            v-if="dropdownSearch"
                            type="button"
                            class="focus-search__clear"
                            @click.stop="dropdownSearch = ''"
                            aria-label="Clear search"
                        >
                            ×
                        </button>
                    </label>

                    <!-- Variable list -->
                    <ul class="focus-list" role="listbox">
                        <li
                            v-for="v in filteredDropdownVars"
                            :key="v.name"
                            role="option"
                            :aria-selected="v.name === selectedTarget"
                        >
                            <button
                                type="button"
                                class="focus-list__item"
                                :class="{
                                    'is-selected': v.name === selectedTarget,
                                }"
                                @click="setFocus(v.name)"
                            >
                                <span
                                    class="type-dot"
                                    :class="`is-${v.type}`"
                                    aria-hidden="true"
                                ></span>
                                <span class="focus-list__name">{{
                                    v.name
                                }}</span>
                                <span class="focus-list__type">{{
                                    typeLabel(v.type)
                                }}</span>
                            </button>
                        </li>
                        <li
                            v-if="filteredDropdownVars.length === 0"
                            class="focus-list__empty"
                        >
                            No variables match
                        </li>
                    </ul>
                </div>
            </div>

            <!-- ── Association list ── -->
            <div class="assoc-container">
                <div class="assoc-controls">
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
                    <label v-if="viewMode === 'list'" class="controls__sort">
                        <span class="controls__label">Sort:</span>
                        <span class="controls__select-wrap">
                            <span class="controls__select-value">{{
                                sortOptions.find((o) => o.id === sortMode)
                                    ?.label
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
                                aria-label="Sort associations by"
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
                        v-if="viewMode === 'list'"
                        type="button"
                        class="assoc-expand-btn"
                        :disabled="predictors.length === 0"
                        @click="anyExpanded ? collapseAll() : expandAll()"
                    >
                        {{ anyExpanded ? 'Collapse all' : 'Expand all' }}
                    </button>
                </div>
                <MatrixView
                    v-if="viewMode === 'matrix'"
                    :variables="matrixVars"
                    :associations="data.associations ?? {}"
                    :all-pair-details="data.allPairDetails"
                />
                <ul v-else class="assoc-list">
                    <template v-for="item in predictorItems" :key="item.key">
                        <!-- Column header (non-type sorts) -->
                        <li
                            v-if="item.kind === 'colheader'"
                            class="assoc-colheader"
                            aria-hidden="true"
                        >
                            <span class="assoc-colheader__var">Variable</span>
                            <span class="assoc-colheader__effect"
                                >Effect size</span
                            >
                        </li>

                        <!-- Type group heading -->
                        <li
                            v-else-if="item.kind === 'header'"
                            class="assoc-group"
                        >
                            <span class="assoc-group__label">{{
                                item.label
                            }}</span>
                            <span class="assoc-group__count"
                                >{{ item.count }}
                                {{ item.count === 1 ? 'var' : 'vars' }}</span
                            >
                            <span class="assoc-group__effect">Effect size</span>
                        </li>

                        <!-- Variable row -->
                        <li
                            v-else-if="item.kind === 'row'"
                            class="assoc-item"
                            :class="{
                                'is-expanded': expandedVars.has(item.name),
                            }"
                        >
                            <button
                                type="button"
                                class="assoc-row"
                                :class="{
                                    'is-selected': expandedVars.has(item.name),
                                }"
                                @click="toggleExpand(item.name)"
                                :aria-expanded="expandedVars.has(item.name)"
                            >
                                <!-- Main grid row -->
                                <span
                                    class="type-dot"
                                    :class="`is-${item.type}`"
                                    aria-hidden="true"
                                ></span>
                                <span class="assoc-row__name">{{
                                    item.name
                                }}</span>
                                <span class="assoc-row__type">{{
                                    typeLabel(item.type)
                                }}</span>
                                <div class="assoc-row__right">
                                    <span class="assoc-row__stat">{{
                                        statLabel(targetVar!.type, item.type)
                                    }}</span>
                                    <span class="assoc-row__value">{{
                                        fmt(item.association)
                                    }}</span>
                                </div>
                                <!-- Thin bar below the grid -->
                                <div class="assoc-row__bar-track">
                                    <div
                                        class="assoc-row__bar-fill"
                                        :style="{
                                            width: `${item.association * 100}%`,
                                            background: typeColor(item.type),
                                        }"
                                    ></div>
                                </div>
                            </button>

                            <Transition name="detail">
                                <div
                                    v-if="
                                        expandedVars.has(item.name) &&
                                        pairDetail(item.name)
                                    "
                                    class="assoc-detail"
                                >
                                    <p class="assoc-detail__title">
                                        {{ item.name }} × {{ selectedTarget }}
                                        <span class="assoc-detail__stat">
                                            ·
                                            {{
                                                statLabel(
                                                    targetVar!.type,
                                                    item.type
                                                )
                                            }}
                                            =
                                            {{ fmt(item.association) }}
                                        </span>
                                    </p>
                                    <MiniPlot
                                        :detail="pairDetail(item.name)!"
                                    />
                                </div>
                            </Transition>
                        </li>
                    </template>
                </ul>
            </div>
        </div>
    </article>
</template>

<style scoped>
.jglance--relations {
    padding: var(--space-16) var(--space-20);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: var(--type-body);
    line-height: 1.5;
}

/* ── View mode toggle ── */
.view-toggle {
    display: inline-flex;
    align-items: center;
    border: 1px solid var(--rule);
    border-radius: 3px;
    overflow: hidden;
    margin-bottom: var(--space-12);
}

.view-toggle__btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-6);
    padding: 4px 10px;
    background: var(--surface);
    border: none;
    border-right: 1px solid var(--rule);
    color: var(--ink-3);
    font: inherit;
    font-size: var(--type-helper);
    cursor: pointer;
    transition:
        background var(--dur-fast) var(--ease-snap),
        color var(--dur-fast) var(--ease-snap);
    line-height: 1.4;
}
.view-toggle__btn:last-child {
    border-right: none;
}
.view-toggle__btn:hover:not(.is-active) {
    background: var(--surface-sunk);
    color: var(--ink-2);
}
.view-toggle__btn.is-active {
    background: var(--accent);
    color: white;
}

/* ── Empty state ── */
.relations__empty {
    padding: var(--space-32) var(--space-16);
    text-align: center;
    color: var(--ink-3);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-8);
}

.relations__empty-icon {
    color: var(--accent);
    margin-bottom: var(--space-4);
}

.relations__empty-title {
    margin: 0;
    font-size: var(--type-body);
    font-weight: 500;
    color: var(--ink-2);
}

.relations__empty-hint {
    margin: 0;
    font-size: var(--type-helper);
    color: var(--ink-3);
}

/* ── Shared type dot (matches Overview) ── */
.type-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 2px;
    background: var(--ink-4);
    flex: 0 0 auto;
}
.type-dot.is-continuous {
    background: var(--type-cont);
}
.type-dot.is-nominal {
    background: var(--type-nom);
}
.type-dot.is-ordinal {
    background: var(--type-ord);
}
.type-dot.is-id {
    background: var(--type-id);
}

/* ── Focus section ── */
.focus-section {
    position: relative;
    margin-bottom: var(--space-12);
    padding-bottom: var(--space-12);
    border-bottom: 1px solid var(--rule);
}

.focus-trigger {
    display: flex;
    flex-direction: column;
    gap: 2px;
    cursor: pointer;
    padding: var(--space-4) 0;
    transition: opacity var(--dur-fast) var(--ease-snap);
}
.focus-trigger:hover {
    opacity: 0.8;
}
.focus-trigger:focus-visible {
    outline: 2px solid var(--accent-soft);
    outline-offset: 2px;
    border-radius: 3px;
}

.focus-trigger__body {
    display: flex;
    flex-direction: column;
    gap: 2px;
}

.focus-trigger__eyebrow {
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--ink-3);
    font-weight: 500;
}

.focus-trigger__selected {
    display: flex;
    align-items: center;
    gap: var(--space-8);
}

.focus-trigger__name {
    font-size: 20px;
    font-weight: 600;
    color: var(--ink);
    letter-spacing: -0.02em;
    line-height: 1.2;
}

.focus-trigger__placeholder {
    font-size: var(--type-body);
    color: var(--ink-4);
    font-style: italic;
    padding: 2px 0;
}

.focus-trigger__meta {
    font-size: var(--type-helper);
    color: var(--ink-3);
}

.focus-trigger__chevron {
    color: var(--ink-3);
    flex: 0 0 auto;
    transition: transform var(--dur-fast) var(--ease-snap);
    margin-left: 3px;
    align-self: center;
}
.focus-trigger__chevron.is-open {
    transform: rotate(180deg);
}

/* ── Dropdown ── */
.focus-dropdown {
    position: absolute;
    top: calc(100% + 4px);
    left: -20px;
    right: -20px;
    background: var(--surface);
    border: 1px solid var(--rule);
    border-radius: 3px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
    z-index: 20;
    overflow: hidden;
}

/* Search — exact match of Overview's .controls__search */
.focus-search {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 8px 6px 12px;
    border-bottom: 1px solid var(--rule-soft);
    background: var(--surface-sunk);
    transition: border-color var(--dur-fast) var(--ease-snap);
}
.focus-search:focus-within {
    border-bottom-color: var(--accent);
}

.focus-search__icon {
    color: var(--ink-3);
    flex: 0 0 auto;
}

.focus-search__input {
    flex: 1;
    min-width: 0;
    border: none;
    background: transparent;
    outline: none;
    font: inherit;
    font-size: var(--type-body);
    color: var(--ink);
    padding: 0;
}
.focus-search__input::placeholder {
    color: var(--ink-4);
}

.focus-search__clear {
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
.focus-search__clear:hover {
    color: var(--ink);
}

/* Variable list inside dropdown */
.focus-list {
    list-style: none;
    padding: 0;
    margin: 0;
    max-height: 220px;
    overflow-y: auto;
}

.focus-list__item {
    display: flex;
    align-items: center;
    gap: var(--space-8);
    width: 100%;
    padding: 7px var(--space-16);
    background: none;
    border: none;
    border-bottom: 1px solid var(--rule-soft);
    cursor: pointer;
    font: inherit;
    font-size: var(--type-body);
    color: var(--ink);
    text-align: left;
    transition: background var(--dur-fast) var(--ease-snap);
}
.focus-list li:last-child .focus-list__item {
    border-bottom: none;
}
.focus-list__item:hover {
    background: var(--surface-sunk);
}
.focus-list__item.is-selected {
    background: var(--surface-accent);
}

.focus-list__name {
    flex: 1;
    font-weight: 500;
}

.focus-list__type {
    font-size: var(--type-helper);
    color: var(--ink-4);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-weight: 500;
}

.focus-list__empty {
    padding: var(--space-12) var(--space-16);
    font-size: var(--type-helper);
    color: var(--ink-4);
    font-style: italic;
    text-align: center;
}

/* ── Association list ── */
/* ── Association controls bar ── */
.assoc-controls {
    display: flex;
    align-items: baseline;
    gap: var(--space-12);
    margin-bottom: var(--space-12);
    padding: 0 var(--space-4);
}

.controls__group {
    display: inline-flex;
    align-items: baseline;
    gap: var(--space-6);
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

/* Sort control — copied from Overview's .controls__sort */
.controls__sort {
    display: inline-flex;
    align-items: baseline;
    gap: var(--space-6);
    font-size: var(--type-body);
    color: var(--ink-2);
    margin-left: auto;
}

.controls__label {
    color: var(--ink-3);
    font-size: var(--type-helper);
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

.assoc-expand-btn {
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
.assoc-expand-btn:hover:not(:disabled) {
    color: var(--accent);
    border-bottom-color: var(--accent);
}
.assoc-expand-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
}

.assoc-list {
    list-style: none;
    padding: 0;
    margin: 0;
    border-top: 1px solid var(--rule-soft);
}

.assoc-item {
    border-bottom: 1px solid var(--rule-soft);
    transition:
        margin var(--dur-base) var(--ease-snap),
        box-shadow var(--dur-base) var(--ease-snap);
}
.assoc-item:last-child {
    border-bottom: none;
}

/* Lift expanded items into a card — same as Overview */
.assoc-item.is-expanded {
    border: 1px solid var(--rule);
    border-radius: 4px;
    margin: var(--space-8) 0;
    background: var(--surface-sunk);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
    overflow: hidden;
}
.assoc-item.is-expanded + .assoc-item.is-expanded {
    margin-top: 0;
}

/* Row button */
.assoc-row {
    width: 100%;
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font: inherit;
    color: var(--ink);
    text-align: left;
    display: flex;
    flex-direction: column;
    transition: background var(--dur-fast) var(--ease-snap);
}
.assoc-row:hover {
    background: var(--surface-sunk);
}
.assoc-row:focus-visible {
    outline: 2px solid var(--accent-soft);
    outline-offset: -2px;
}
.assoc-row.is-selected {
    background: var(--surface-accent);
}

/* Main content row inside the button */
.assoc-row > .type-dot,
.assoc-row__name,
.assoc-row__type,
.assoc-row__right {
    /* these are the grid children — we use a grid on the button's inner "row" via a wrapper trick */
}

/* Use a grid via :not(.assoc-row__bar-track) children */
.assoc-row {
    display: grid;
    grid-template-columns: 8px minmax(0, 1fr) auto auto;
    grid-template-rows: auto;
    align-items: center;
    gap: 0 var(--space-12);
    padding: var(--space-8) var(--space-12);
    position: relative;
}

.assoc-row > .type-dot {
    grid-column: 1;
    grid-row: 1;
}
.assoc-row__name {
    grid-column: 2;
    grid-row: 1;
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.assoc-row__type {
    grid-column: 3;
    grid-row: 1;
    font-size: var(--type-helper);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-weight: 500;
    color: var(--ink-3);
}
.assoc-row__right {
    grid-column: 4;
    grid-row: 1;
    display: flex;
    align-items: baseline;
    gap: var(--space-4);
}
.assoc-row__bar-track {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 3px;
    background: var(--rule-soft);
}

.assoc-row__stat {
    font-size: var(--type-helper);
    color: var(--ink-4);
}
.assoc-row__value {
    font-size: var(--type-body);
    font-variant-numeric: tabular-nums;
    font-weight: 700;
    color: var(--ink-2);
    min-width: 30px;
    text-align: right;
}

.assoc-row.is-selected .assoc-row__name {
    color: var(--accent);
    font-weight: 600;
}

.assoc-row__bar-fill {
    height: 100%;
    border-radius: 1px;
}

/* ── Expanded detail ── */
.assoc-detail {
    padding: var(--space-12) var(--space-16) var(--space-16);
    border-top: 1px solid var(--rule-soft);
    background: var(--surface-sunk);
}

.assoc-detail__title {
    margin: 0 0 var(--space-8);
    font-size: var(--type-helper);
    font-weight: 600;
    color: var(--ink-3);
}

.assoc-detail__stat {
    font-weight: 400;
    color: var(--ink-4);
}

/* ── Column header (non-type sort) ── */
.assoc-colheader {
    display: grid;
    grid-template-columns: 8px minmax(0, 1fr) auto auto;
    align-items: baseline;
    gap: 0 var(--space-12);
    padding: var(--space-6) var(--space-12) var(--space-4);
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    font-weight: 600;
    color: var(--ink-3);
    list-style: none;
}

.assoc-colheader__var {
    grid-column: 1 / 4;
    color: var(--ink-2);
}

.assoc-colheader__effect {
    grid-column: 4;
    text-align: right;
    color: var(--ink-4);
    font-weight: 600;
    letter-spacing: 0.05em;
}

/* ── Type group headings (shown when sorted by type) ── */
.assoc-group {
    display: flex;
    align-items: baseline;
    gap: var(--space-8);
    padding: var(--space-16) var(--space-12) var(--space-4);
    font-size: var(--type-eyebrow);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    font-weight: 600;
    color: var(--ink-3);
    list-style: none;
}

.assoc-group:first-child {
    padding-top: var(--space-6);
}

.assoc-group__label {
    color: var(--ink-2);
}

.assoc-group__count {
    color: var(--ink-4);
    font-weight: 500;
}

.assoc-group__effect {
    margin-left: auto;
    font-size: var(--type-helper);
    color: var(--ink-4);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    font-weight: 600;
}

/* ── Expand/collapse animation ── */
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
</style>
