<script>
  import { Link } from 'svero';

  export let router = {};

  let region = router.params.region;

  let promise = getSnapshots();

  async function getSnapshots() {
    const res = await fetch(`https://us-central1-dota-2-leaderboards-history.cloudfunctions.net/snapshot_list?region=${region}`);
    const response = await res.json();
    return response;
  }
</script>

<h1>Snapshots for {region}</h1>

{#await promise}
  <p>...</p>
{:then data}
{#if data.items}
<ul>
  {#each data.items as { date }, i}
  <li><Link href="/{region}/snapshot/{date}" className="btn">{date}</Link></li>
  {/each}
</ul>
{/if}
{:catch error}
  <p style="color: red">{error.message}</p>
{/await}
