// Shared types + a sessionStorage-backed state store, modeled on
// jamovi/besoplots' PlotStateStore. Widgets share state via this store
// so selections survive jamovi re-renders.

export type VariableType = 'continuous' | 'nominal' | 'ordinal' | 'id';

export interface IVariableBase {
    name: string;
    description?: string | null;
    type: VariableType;
    n: number;
    nMissing: number;
}

export interface IContinuousSummary extends IVariableBase {
    type: 'continuous';
    min: number;
    max: number;
    mean: number;
    sd: number;
    median: number;
    q1?: number;
    q3?: number;
    integer?: boolean;
    nUnique?: number;
    histogram: { edges: number[]; counts: number[] };
}

export interface ICategoricalSummary extends IVariableBase {
    type: 'nominal' | 'ordinal';
    nLevels: number;
    nTruncated: number;
    levels: { name: string; count: number }[];
}

export interface IIdSummary extends IVariableBase {
    type: 'id';
    nUnique: number;
    samples: string[];
}

export type IVariableSummary =
    | IContinuousSummary
    | ICategoricalSummary
    | IIdSummary;

export interface IOverviewData {
    nRows: number;
    variables: IVariableSummary[];
    /** Persisted UI state, read from jamovi options on the R side and threaded
     *  through to the client for hydration. Survives .omv save/reopen. */
    sortMode?: string;
    typeFilter?: string;
    issuesDismissed?: boolean;
}

export interface IScatterPoint {
    x: number;
    y: number;
}

export interface IBarGroup {
    label: string;
    mean: number;
    n: number;
}

export type IPairDetail =
    | {
          type: 'scatter';
          points: IScatterPoint[];
          xLabel: string;
          yLabel: string;
      }
    | {
          type: 'bars';
          groups: IBarGroup[];
          contLabel: string;
          catLabel: string;
      }
    | {
          type: 'mosaic';
          rows: string[];
          cols: string[];
          counts: number[][];
      };

export interface IRelationsData {
    variables: {
        name: string;
        description: string | null;
        type: VariableType;
    }[];
    associations?: Record<string, Record<string, number>>;
    selectedTarget?: string;
    viewMode?: string;
    typeFilter?: string;
    sortMode?: string;
    pairDetails?: Record<string, IPairDetail> | null;
    allPairDetails?: Record<string, Record<string, IPairDetail>>;
    error?: string;
}

/* ===================== JSON state store ===================== */

type JSONPrimitive = string | number | boolean | null;
type JSONObject = { [key: string]: JSONValue };
type JSONArray = JSONValue[];
export type JSONValue = JSONPrimitive | JSONObject | JSONArray;

export interface IPlotStateStore {
    set(values: { [key: string]: JSONValue }): void;
    get<T extends JSONValue = JSONValue>(key: string): T | null;
}

export class PlotStateStore implements IPlotStateStore {
    private readonly storageKey: string;
    private readonly storage: Storage;

    constructor(
        storageKey: string = 'jglanceState',
        persistent: boolean = true
    ) {
        this.storageKey = storageKey;
        /* localStorage survives jamovi sessions; sessionStorage only the tab. */
        this.storage = persistent
            ? safeStorage('local')
            : safeStorage('session');
    }

    private read(): JSONObject {
        try {
            const stored = this.storage.getItem(this.storageKey);
            return stored ? (JSON.parse(stored) as JSONObject) : {};
        } catch {
            return {};
        }
    }

    private write(val: JSONObject): void {
        try {
            this.storage.setItem(this.storageKey, JSON.stringify(val));
        } catch {
            /* quota or disabled — silently drop */
        }
    }

    set(values: { [key: string]: JSONValue }): void {
        const current = this.read();
        for (const [k, v] of Object.entries(values)) current[k] = v;
        this.write(current);
    }

    get<T extends JSONValue = JSONValue>(key: string): T | null {
        const current = this.read();
        return (current[key] ?? null) as T | null;
    }
}

/* in-memory fallback if a real Storage isn't available */
function safeStorage(kind: 'local' | 'session'): Storage {
    try {
        const s =
            kind === 'local' ? window.localStorage : window.sessionStorage;
        const probe = '__jglance_probe__';
        s.setItem(probe, '1');
        s.removeItem(probe);
        return s;
    } catch {
        const mem = new Map<string, string>();
        return {
            get length() {
                return mem.size;
            },
            clear: () => mem.clear(),
            getItem: (k) => mem.get(k) ?? null,
            key: (i) => Array.from(mem.keys())[i] ?? null,
            removeItem: (k) => {
                mem.delete(k);
            },
            setItem: (k, v) => {
                mem.set(k, v);
            },
        } as Storage;
    }
}

