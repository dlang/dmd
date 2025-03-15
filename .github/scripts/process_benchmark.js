const fs = require('fs');
const benchmarkFile = process.argv[2];
const prNumber = process.argv[3];
const prTitle = process.argv[4];
const prUrl = process.argv[5];
const commitSha = process.argv[6];

if (!fs.existsSync(benchmarkFile)) {
  process.exit(1);
}

const benchmarkResults = JSON.parse(fs.readFileSync(benchmarkFile, 'utf8'));

try {
  const prResults = benchmarkResults.results[0];
  const masterResults = benchmarkResults.results[1];

  const prTimeAvg = prResults.mean.toFixed(3);
  const masterTimeAvg = masterResults.mean.toFixed(3);
  const prMemAvg = (prResults.max_rss ? (prResults.max_rss.reduce((a, b) => a + b, 0) / prResults.max_rss.length / 1024).toFixed(1) : 'N/A');
  const masterMemAvg = (masterResults.max_rss ? (masterResults.max_rss.reduce((a, b) => a + b, 0) / masterResults.max_rss.length / 1024).toFixed(1) : 'N/A');
  const timeDiff = (prResults.mean - masterResults.mean).toFixed(3);
  const timePct = ((prResults.mean / masterResults.mean - 1) * 100).toFixed(2) + '%';

  const result = {
    timestamp: new Date().toISOString(),
    pr: {
      number: prNumber,
      title: prTitle,
      url: prUrl,
      commit: commitSha
    },
    metrics: {
      pr_time: prTimeAvg,
      master_time: masterTimeAvg,
      pr_memory: prMemAvg,
      master_memory: masterMemAvg,
      time_diff: timeDiff,
      time_pct: timePct
    }
  };

  // This line was missing or incomplete in your original script
  console.log(JSON.stringify(result, null, 2));

  if (process.argv[7]) {
    fs.writeFileSync(process.argv[7], JSON.stringify(result, null, 2));
  }
} catch (error) {
  console.error('Error processing benchmark results:', error);
  process.exit(1);
}
