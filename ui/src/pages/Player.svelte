<script>
  import Chart from 'chart.js';
  import { onMount } from 'svelte';
  import { Link } from 'svero';

  export let router = {};

  let { region, player } = router.params;

  let canvasElement;
  let chart = null;

  async function buildChart(ctx) {
    const res = await fetch(`https://us-central1-dota-2-leaderboards-history.cloudfunctions.net/player_records?name=${player}&region=${region}`);
    const response = await res.json();

    let labels = [];
    let data = [];
    response.items.forEach((item) => {
      labels.unshift(item.date);
      data.unshift(item.rank);
    })

    let chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: `Rank in ${region}`,
          data: [],
          fill: "start",
        }],
      },
      options: {
        scales: {
          yAxes: [{
            ticks: {
              reverse: true,
            }
          }]
        }
      }
    });

    chart.data.labels = labels;
    chart.data.datasets[0].data = data;
    chart.update();
  }

  onMount(async () => {
    const ctx = canvasElement.getContext('2d');
    await buildChart(ctx);
  });
</script>

<h1>{player} in <Link href="/{region}" className="btn">{region}</Link></h1>

<canvas bind:this={canvasElement}></canvas>
