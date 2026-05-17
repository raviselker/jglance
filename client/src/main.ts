import { createApp } from 'vue';

import './tokens.css';

import Overview from './Overview.vue';
import { PlotStateStore } from './common';
import type { IOverviewData, IPlotStateStore } from './common';

function createOverview(
    selector: string,
    data: IOverviewData,
    state: IPlotStateStore = new PlotStateStore('jglance:overview', false)
) {
    /* sessionStorage-only state — only used for ephemeral within-session things
     * like which rows are expanded. Persistent state (sort, filter, dismissed
     * issues) round-trips through jamovi options inside useOverviewState. */
    const app = createApp(Overview, { data, state });
    app.mount(selector);
    return app;
}

export { createOverview, PlotStateStore };

if (typeof window !== 'undefined') {
    (
        window as unknown as {
            Jglance: {
                createOverview: typeof createOverview;
                PlotStateStore: typeof PlotStateStore;
            };
        }
    ).Jglance = {
        createOverview,
        PlotStateStore,
    };
}
