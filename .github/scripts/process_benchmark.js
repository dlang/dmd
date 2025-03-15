// This script processes benchmark data and generates a consistent JSON format
// for historical tracking of performance metrics

const fs = require('fs');

// Read benchmark results from the input file
const benchmarkFile = process.argv[2];
const prNumber = process.argv[3];
const prTitle = process.argv[4];
const prUrl = process.argv[5];
const commitSha = process.argv[6];

// Check if file exists
if (!fs.existsSync(benchmarkFile)) {
  console.error(`Benchmark file not found: ${benchmarkFile}`);
  process.exit(1);
}

// Read and parse benchmark results
const benchmarkResults = JSON.parse(fs.readFileSync(benchmarkFile, 'utf8'));

// Extract key metrics
try {
  const prResults = benchmarkResults.results[0];
  const masterResults = benchmarkResults.results[1];

  // Calculate averages
  const prTimeAvg = prResults.mean.toFixed(3);
  const masterTimeAvg = masterResults.mean.toFixed(3);
  const prMemAvg = (prResults.max_rss ? (prResults.max_rss.reduce((a, b) => a + b, 0) / prResults.max_rss.length / 1024).toFixed(1) : 'N/A');
  const masterMemAvg = (masterResults.max_rss ? (masterResults.max_rss.reduce((a, b) => a + b, 0) / masterResults.max_rss.length / 1024).toFixed(1) : 'N/A');

  // Calculate time difference
  const timeDiff = (prResults.mean - masterResults.mean).toFixed(3);
  const timePct = ((prResults.mean / masterResults.mean - 1) * 100).toFixed(2) + '%';

  // Create result object
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

  // Output the result as JSON
  console.log(JSON.stringify(result, null, 2));

  // Write to output file if specified
  if (process.argv[7]) {
    fs.writeFileSync(process.argv[7], JSON.stringify(result, null, 2));
    console.log(`Results written to ${process.argv[7]}`);
  }

} catch (error) {
  console.error('Error processing benchmark results:', error);
  process.exit(1);
}
