/**
@example curl/default.vcl

The VCL the Docker image in this folder runs. It sets each value on a response
header, so it can be seen with cURL. See the README in this folder.
*/
vcl 4.0;

import fiftyonedegrees;
import fiftyonedegrees_ipi;

backend default {
	.host = "127.0.0.1";
	.port = "80";
}

sub vcl_recv {
	return (synth(200));
}

sub vcl_synth {
	set resp.http.x-device-type = fiftyonedegrees.match_all("DeviceType");
	set resp.http.x-platform-name = fiftyonedegrees.match_all("PlatformName");
	set resp.http.x-platform-version = fiftyonedegrees.match_all("PlatformVersion");
	set resp.http.x-browser-name = fiftyonedegrees.match_all("BrowserName");
	set resp.http.x-browser-version = fiftyonedegrees.match_all("BrowserVersion");
	set resp.http.x-asn = fiftyonedegrees_ipi.match("AsnName", req.http.X-Real-IP);
	// DeviceType is only in the Enterprise data file, and reads N/A on the
	// Lite one. Then x-enterprise says where to ask for a copy.
	if (resp.http.x-device-type ~ "N/A") {
		set resp.http.x-enterprise = "Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-curl-default-vcl&utm_term=enterprise-data-file";
	}
	// Say where to find out more, after the other headers.
	set resp.http.x-find-out-more = "These modules are at https://github.com/51Degrees/51degrees-varnish and the engine they use at https://github.com/51Degrees/51degrees-cxx. Read about device detection at https://51degrees.com/device-detection?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-curl-default-vcl&utm_term=device-detection, about IP intelligence at https://51degrees.com/ip-intelligence?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-curl-default-vcl&utm_term=ip-intelligence and about data files and pricing at https://51degrees.com/pricing?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-curl-default-vcl&utm_term=pricing";
	return (deliver);
}

sub vcl_init {
	fiftyonedegrees.start("/app/cxx/data/device-detection/51Degrees-LiteV4.1.hash");
	fiftyonedegrees_ipi.start("/app/cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi");
}
