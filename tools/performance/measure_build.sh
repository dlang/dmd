#!/bin/bash

runs=3
times=()

echo "Running $runs clean builds..."

for i in $(seq 1 $runs)
do
    echo "Run $i..."
    make clean > /dev/null 2>&1

    start=$(date +%s)
    ci/run.sh build > /dev/null 2>&1
    end=$(date +%s)

    duration=$((end - start))
    echo "Build $i: $duration seconds"

    times+=($duration)
done

# Sort times
sorted=($(printf '%s\n' "${times[@]}" | sort -n))
median=${sorted[1]}

echo "Median build time: $median seconds"

# Save to JSON
echo "{ \"median_build_time\": $median }" > build_result.json

echo "Saved result to build_result.json"
