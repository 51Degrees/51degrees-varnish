#!/bin/bash
# Temporary. Times main's modules against the head's on one runner, with the
# head's performance harness and the same varnishd, alternating which goes
# first in each round.
set -u
root=$1
rounds=${2:-10}
cd "$root/head/tests/performance/build"
for round in $(seq 1 "$rounds"); do
	if [ $((round % 2)) -eq 1 ]; then order="main head"; else order="head main"; fi
	for engine in hash ipi; do
		for variant in $order; do
			if [ "$engine" = ipi ]; then
				data="$root/$variant/cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi"
				evidence="$root/$variant/cxx/data/ip-intelligence/evidence.csv"
			else
				data="$root/assets/TAC-HashV41.hash"
				evidence="$root/assets/20000 Evidence Records.yml"
			fi
			BUILD_PATH="$root/$variant" ENGINE=$engine DATA_FILE="$data" EVIDENCE="$evidence" ./runPerf.sh > run.out 2>&1
			ms=$(sed -n 's/.*"AvgMillisecsPerDetection": \([0-9.]*\).*/\1/p' results.json 2>/dev/null)
			echo "TIMING round=$round engine=$engine variant=$variant ms=$ms"
			if [ -z "$ms" ]; then
				tail -15 run.out | sed 's/^/TIMING /'
			fi
		done
	done
done
