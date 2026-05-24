import { ref } from 'vue';
import type { Ref } from 'vue';
import type { IRelationsData, IPlotStateStore } from '../common';
import { useJamoviOption } from './useJamoviOption';

export type RelationsTypeFilter = 'all' | 'continuous' | 'categorical';
export type RelationsSortMode = 'strength' | 'name' | 'type' | 'original';
export type RelationsViewMode = 'list' | 'matrix';

const VALID_TYPE_FILTERS: RelationsTypeFilter[] = [
    'all',
    'continuous',
    'categorical',
];
const VALID_SORT_MODES: RelationsSortMode[] = [
    'strength',
    'name',
    'type',
    'original',
];
const VALID_VIEW_MODES: RelationsViewMode[] = ['list', 'matrix'];

export interface RelationsState {
    selectedTarget: Ref<string>;
    viewMode: Ref<RelationsViewMode>;
    typeFilter: Ref<RelationsTypeFilter>;
    sortMode: Ref<RelationsSortMode>;
    expandedVars: Ref<Set<string>>;
}

export function useRelationsState(
    data: IRelationsData,
    _state: IPlotStateStore
): RelationsState {
    const firstVar = data.variables.length > 0 ? data.variables[0]!.name : '';

    const seedTarget = data.selectedTarget || firstVar;
    const seedViewMode: RelationsViewMode =
        data.viewMode && (VALID_VIEW_MODES as string[]).includes(data.viewMode)
            ? (data.viewMode as RelationsViewMode)
            : 'list';
    const seedTypeFilter: RelationsTypeFilter =
        data.typeFilter &&
        (VALID_TYPE_FILTERS as string[]).includes(data.typeFilter)
            ? (data.typeFilter as RelationsTypeFilter)
            : 'all';
    const seedSortMode: RelationsSortMode =
        data.sortMode && (VALID_SORT_MODES as string[]).includes(data.sortMode)
            ? (data.sortMode as RelationsSortMode)
            : 'strength';

    const selectedTarget = useJamoviOption<string>(
        'selectedTarget',
        seedTarget
    );
    const viewMode = useJamoviOption<RelationsViewMode>(
        'viewMode',
        seedViewMode
    );
    const typeFilter = useJamoviOption<RelationsTypeFilter>(
        'typeFilter',
        seedTypeFilter
    );
    const sortMode = useJamoviOption<RelationsSortMode>(
        'sortMode',
        seedSortMode
    );

    const expandedVars = ref<Set<string>>(new Set());

    return { selectedTarget, viewMode, typeFilter, sortMode, expandedVars };
}
