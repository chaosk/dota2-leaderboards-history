<script>
  import { onMount } from 'svelte';
  import { Link } from 'svero';

  export let router = {};

  let { region, date } = router.params;

  let items = [];
  let loading = true;
  let next_cursor = null;

  async function getSnapshot() {
    loading = true;
    next_cursor = next_cursor || "";
    const res = await fetch(`https://us-central1-dota-2-leaderboards-history.cloudfunctions.net/snapshot_records?region=${region}&date=${date}&cursor=${next_cursor}&limit=300`);
    const response = await res.json();
    items = items.concat(response.items);
    next_cursor = response.next_cursor;
    loading = false;
  }

  onMount(async () => {
    await getSnapshot();
  });
</script>

<h1>Snapshot from {date} for <Link href="/{region}" className="btn">{region}</Link></h1>

{#if items}
<ul>
  {#each items as { rank, name }, i}
  <li>{rank}. <Link href="/{region}/player/{name}">{name}</Link></li>
  {/each}
</ul>
{/if}
{#if loading}
  <p>...</p>
{:else}
{#if next_cursor}<button on:click={getSnapshot}>Load more</button>{/if}
{/if}
