import { ref, watch } from 'vue';
import type { Ref } from 'vue';

/**
 * Calls jamovi's window.setOption() if available. Silently no-ops in the
 * dev harness. Triggers an analysis re-run and persists the value to .omv.
 */
export function pushOptionToJamovi(name: string, value: unknown): void {
    const fn = (
        window as unknown as { setOption?: (n: string, v: unknown) => void }
    ).setOption;
    if (typeof fn === 'function') {
        try {
            fn(name, value);
        } catch {
            /* ignore */
        }
    }
}

/**
 * Seeds a Vue ref from a jamovi-persisted value and watches it back to jamovi.
 * Use for any state that must survive .omv save/reopen.
 * Seed must come from the R-threaded payload (not a hardcoded default) to avoid
 * overwriting the persisted value on first mutation.
 * Must be called inside a Vue component setup or composable (needs effect scope).
 */
export function useJamoviOption<T>(name: string, seed: T): Ref<T> {
    const value = ref(seed) as Ref<T>;
    watch(value, (v) => pushOptionToJamovi(name, v), { flush: 'post' });
    return value;
}
