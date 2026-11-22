#!/bin/bash
# Times requests through Varnish, each making one detection, and writes the
# results to results.json in the current folder. Run it from the folder CMake
# built in.
#
# The figure is the clock time for every request, the same measure as the
# console performance examples. A run that failed says why and writes no
# results.
#
# The first argument is the engine, hash for device detection or ipi for IP
# Intelligence. The second is the folder holding the built modules.
#
# _51DEGREES_DD_PATH names the device detection data file and
# _51DEGREES_IPI_PATH the IP Intelligence one. _51DEGREES_EVIDENCE_YAML names
# the evidence records file for device detection. Each is the free file in
# cxx/data when it is not set. IP Intelligence sends the addresses of
# cxx/data/ip-intelligence/evidence.yml.
set -u

if [ "$#" -ne 2 ] || { [ "$1" != "hash" ] && [ "$1" != "ipi" ]; }; then
	echo "Usage: $0 hash|ipi /path/to/built/modules" >&2
	exit 2
fi
engine=$1
modules=$2

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DATA="$HERE/../../../cxx/data"
HOST=127.0.0.1:3000
WORKERS=$(nproc)
PASSES=$((20000 * WORKERS))
VCL="$PWD/perf.vcl"
WORK="$PWD/varnish-work"

rm -f results.json

if [ "$engine" == "ipi" ]; then
	FILE=${_51DEGREES_IPI_PATH:-$DATA/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi}
	# A record of the IP Intelligence evidence file holds one IP address,
	# which is not a header. The address is sent as the User-Agent header,
	# where the VCL reads it, so that each request carries a different
	# address.
	SOURCE=(-E "$PWD/evidence.ipi.yml")
	sed 's/^server\.client-ip: /header.User-Agent: /' \
		"$DATA/ip-intelligence/evidence.yml" > "${SOURCE[1]}"
	IMPORT="import fiftyonedegrees_ipi;"
	INIT='fiftyonedegrees_ipi.set_performance_profile("IN_MEMORY");
	fiftyonedegrees_ipi.start("'"$FILE"'");'
	LOOKUP='set req.http.x-result = fiftyonedegrees_ipi.match("AsnName", req.http.user-agent);'
else
	FILE=${_51DEGREES_DD_PATH:-$DATA/device-detection/51Degrees-LiteV4.1.hash}
	SOURCE=(-E "${_51DEGREES_EVIDENCE_YAML:-$DATA/device-detection/20000 Evidence Records.yml}")
	IMPORT="import fiftyonedegrees;"
	INIT='fiftyonedegrees.set_performance_profile("IN_MEMORY");
	fiftyonedegrees.set_properties("IsMobile");
	fiftyonedegrees.start("'"$FILE"'");'
	LOOKUP='set req.http.x-result = fiftyonedegrees.match_all("IsMobile");'
fi
if [ ! -s "${SOURCE[1]}" ]; then
	echo "The evidence file ${SOURCE[1]} is missing or empty"
	exit 1
fi

cat > "$VCL" <<EOF
vcl 4.0;
$IMPORT
backend default { .host = "127.0.0.1"; .port = "9"; }
sub vcl_init {
	$INIT
}
sub vcl_recv {
	$LOOKUP
	return (synth(200));
}
EOF

rm -rf "$WORK"
varnishd -F -n "$WORK" -a "$HOST" -f "$VCL" \
	-p "vmod_path=$modules/src/dd/.libs:$modules/src/ipi/.libs" \
	-s malloc,64m > varnishd.out 2>&1 &
VARNISH_PID=$!

tries=0
until [ "$(curl -o /dev/null -s -w '%{http_code}' "http://$HOST/")" == "200" ]; do
	tries=$((tries + 1))
	if [ "$tries" -gt 120 ] || ! kill -0 "$VARNISH_PID" 2>/dev/null; then
		echo "Varnish did not start"
		cat varnishd.out
		kill "$VARNISH_PID" 2>/dev/null
		exit 1
	fi
	sleep 1
done

./ApacheBench-prefix/src/ApacheBench-build/bin/ab "${SOURCE[@]}" -q -c "$WORKERS" -n "$PASSES" "http://$HOST/" > process.out

kill "$VARNISH_PID"
wait "$VARNISH_PID" 2>/dev/null

FAILED=$(sed -En 's/Failed requests: *([0-9]+)/\1/p' process.out)
NON200=$(sed -En 's/Non-2xx responses: *([0-9]+)/\1/p' process.out)
TAKEN=$(sed -En 's/Time taken for tests: *([0-9.]+) seconds/\1/p' process.out)
if [ "${FAILED:-1}" != "0" ] || [ -n "$NON200" ] ||
	! awk -v taken="${TAKEN:-0}" 'BEGIN { exit !(taken > 0) }'; then
	echo "No results: ${TAKEN:-unknown} seconds," \
		"${FAILED:-unknown} failed requests, ${NON200:-0} non-2xx responses"
	exit 1
fi

awk -v taken="$TAKEN" -v requests="$PASSES" -v concurrency="$WORKERS" 'BEGIN {
	seconds = taken / requests
	printf "{\n"
	printf "  \"HigherIsBetter\": { \"DetectionsPerSecond\": %.2f },\n", 1 / seconds
	printf "  \"LowerIsBetter\": { \"AvgMillisecsPerDetection\": %.6f },\n", seconds * 1000
	printf "  \"Seconds\": %s,\n", taken
	printf "  \"Requests\": %d,\n", requests
	printf "  \"Concurrency\": %d\n", concurrency
	printf "}\n"
}' > results.json
cat results.json
