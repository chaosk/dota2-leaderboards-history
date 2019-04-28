<script>
    export let region;
    export let name;

    import { onMount } from 'svelte';
    import Chart from 'chart.js';

    let canvasElement;
    let chart = null;

    async function buildChart(ctx) {
        let chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: `Rank in ${region} region`,
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

        const res = await fetch(`https://us-central1-dota-2-leaderboards-history.cloudfunctions.net/player_records_api?name=${name}&region=${region}`);
        const response = await res.json();

        if (!res.ok) {
            throw new Error(data);
        }


        let labels = [];
        let data = [];
        response.items.forEach((item) => {
            labels.unshift(item.date);
            data.unshift(item.rank);
        })
        chart.data.labels = labels;
        chart.data.datasets[0].data = data;
        chart.update();
    }

    onMount(async () => {
        const ctx = canvasElement.getContext('2d');
        await buildChart(ctx);
    });
</script>

<canvas bind:this={canvasElement}></canvas>
{#if chart}
    <p>
        yay!
    </p>
{:else}
    <p>...waiting</p>
{/if}
