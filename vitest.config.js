// Prints every event of the watcher under vitest ("WATCH <event> <file>"), so that a run shows
// whether the replaced link reached vitest as an event. It changes nothing else.
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [{
    name: 'log-watcher-events',
    configureServer(server) {
      server.watcher.on('all', (event, file) => console.log('WATCH', event, file.replace(process.cwd() + '/', '')));
    },
  }],
});
