import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [vue()],
    build: {
        outDir: '../inst',
        emptyOutDir: false,
        lib: {
            entry: './src/main.ts',
            name: 'Jglance',
            fileName: (format) => `jglance.${format}.js`,
            formats: ['umd'],
        },
        rollupOptions: {
            external: [],
            output: { globals: {} },
        },
    },
    define: {
        'process.env.NODE_ENV': JSON.stringify('production'),
    },
});
