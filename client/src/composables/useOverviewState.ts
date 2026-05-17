import { ref, watch } from 'vue'
import type { Ref } from 'vue'
import type { IOverviewData, IPlotStateStore } from '../common'

export type OverviewTypeFilter = 'all' | 'continuous' | 'categorical'
export type OverviewSortMode = 'original' | 'name' | 'type' | 'missing-desc'

const VALID_TYPES: OverviewTypeFilter[] = ['all', 'continuous', 'categorical']
const VALID_SORTS: OverviewSortMode[] = ['original', 'name', 'type', 'missing-desc']

export interface OverviewState {
    expanded: Ref<string[]>
    typeFilter: Ref<OverviewTypeFilter>
    sortMode: Ref<OverviewSortMode>
    issuesDismissed: Ref<boolean>
    toggle: (name: string) => void
    isExpanded: (name: string) => boolean
    expandAll: (names: string[]) => void
    collapseAll: () => void
}

export const OVERVIEW_STATE_KEY = Symbol('overview-state')

/**
 * Calls jamovi's `window.setOption` if it's available. This is exposed by the
 * jamovi results-html iframe and triggers an analysis re-run, but jamovi
 * persists the value to the .omv file — which is the *only* way to make state
 * survive save/reopen.
 *
 * Silently no-ops in the dev harness (which doesn't have window.setOption).
 */
function pushOptionToJamovi(name: string, value: unknown): void {
    const fn = (window as unknown as { setOption?: (n: string, v: unknown) => void }).setOption
    if (typeof fn === 'function') {
        try { fn(name, value) } catch { /* ignore */ }
    }
}

/**
 * Builds the shared state composable.
 *
 * Three of the refs (sortMode, typeFilter, issuesDismissed) are seeded from
 * jamovi-persisted options that R passes through `data`. When they change,
 * we round-trip via `setOption` so the new value is saved with the .omv.
 *
 * `expanded` stays in the local `IPlotStateStore` only — it survives within a
 * jamovi session but resets on .omv reopen (acceptable for per-row UI state).
 */
export function useOverviewState(store: IPlotStateStore, data: IOverviewData): OverviewState {
    /* ---- ephemeral (within-session only) ---- */
    const expanded = ref<string[]>([])
    const storedExpanded = store.get<string[]>('expandedVariables')
    if (Array.isArray(storedExpanded))
        expanded.value = storedExpanded.filter(n => typeof n === 'string')
    watch(expanded, (v) => store.set({ expandedVariables: v }), { deep: true })

    /* ---- persistent (round-tripped through jamovi options) ---- */
    const seedType: OverviewTypeFilter =
        (data.typeFilter && (VALID_TYPES as string[]).includes(data.typeFilter))
            ? data.typeFilter as OverviewTypeFilter
            : 'all'
    const seedSort: OverviewSortMode =
        (data.sortMode && (VALID_SORTS as string[]).includes(data.sortMode))
            ? data.sortMode as OverviewSortMode
            : 'original'
    const seedDismissed: boolean = data.issuesDismissed === true

    const typeFilter = ref<OverviewTypeFilter>(seedType)
    const sortMode = ref<OverviewSortMode>(seedSort)
    const issuesDismissed = ref<boolean>(seedDismissed)

    /* Push changes back to jamovi so they persist. `flush: 'post'` ensures the
     * setOption call happens after Vue's render pass, avoiding any chance of
     * setOption triggering a re-render while we're already rendering. */
    watch(sortMode, (v) => pushOptionToJamovi('sortMode', v), { flush: 'post' })
    watch(typeFilter, (v) => pushOptionToJamovi('typeFilter', v), { flush: 'post' })
    watch(issuesDismissed, (v) => pushOptionToJamovi('issuesDismissed', v), { flush: 'post' })

    function toggle(name: string) {
        const idx = expanded.value.indexOf(name)
        expanded.value = idx === -1
            ? [...expanded.value, name]
            : expanded.value.filter(n => n !== name)
    }

    function isExpanded(name: string): boolean {
        return expanded.value.includes(name)
    }

    function expandAll(names: string[]) {
        expanded.value = [...names]
    }

    function collapseAll() {
        expanded.value = []
    }

    return {
        expanded, typeFilter, sortMode, issuesDismissed,
        toggle, isExpanded, expandAll, collapseAll,
    }
}
