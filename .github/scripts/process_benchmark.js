const fs = require('fs');
const benchmarkFile = process.argv[2];
const prNumber = process.argv[3];
const prTitle = process.argv[4];
const prUrl = process.argv[5];
const commitSha = process.argv[6];
const path = require('path');
const outputPath = path.resolve(process.argv[7]);

if (!fs.existsSync(benchmarkFile)) {
  process.exit(1);
}

const benchmarkResults = JSON.parse(fs.readFileSync(benchmarkFile, 'utf8'));
let result; // Declare result outside try block

try {
  const prResults = benchmarkResults.results[0];
  const masterResults = benchmarkResults.results[1];

  const prTimeAvg = prResults.mean.toFixed(3);
  const masterTimeAvg = masterResults.mean.toFixed(3);

  const prMemAvg = prResults.max_rss
    ? (prResults.max_rss.reduce((a, b) => a + b, 0) / prResults.max_rss.length / 1024).toFixed(1)
    : 'N/A';

  const masterMemAvg = masterResults.max_rss
    ? (masterResults.max_rss.reduce((a, b) => a + b, 0) / masterResults.max_rss.length / 1024).toFixed(1)
    : 'N/A';

  const timeDiff = (prResults.mean - masterResults.mean).toFixed(3);
  const timePct = ((prResults.mean / masterResults.mean - 1) * 100).toFixed(2) + '%';

  result = {
    timestamp: new Date().toISOString(),
    pr: {
      number: parseInt(prNumber),
      title: prTitle,
      url: prUrl,
      commit: commitSha
    },
    metrics: {
        pr_time: parseFloat(prTimeAvg),
        master_time: parseFloat(masterTimeAvg),
        pr_memory: prMemAvg === 'N/A' ? null : parseFloat(prMemAvg),
        master_memory: masterMemAvg === 'N/A' ? null : parseFloat(masterMemAvg),
        time_diff: parseFloat(timeDiff),
        time_pct: timePct
    }
  }; // Removed extra closing parenthesis and semicolon here

} catch (error) {
  process.exit(1);
}

if (outputPath) {
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
}
