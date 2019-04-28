<script>
  import { Router, Route } from 'svero';
  import Index from './pages/Index.svelte';
  import Region from './pages/Region.svelte';
  import Snapshot from './pages/Snapshot.svelte';
  import Player from './pages/Player.svelte';
  import NotFound from './pages/NotFound.svelte';
</script>

<Router>
  <Route path="*" component={Index} />
  <Route path="/:region" component={Region} />
  <Route path="/:region/snapshot/:date" component={Snapshot} />
  <Route path="/:region/player/:player" component={Player} />
</Router>
