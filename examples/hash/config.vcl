/**
@example hash/config.vcl

This example shows how to configure the available settings for 51Degrees'
on-premise device detection in Varnish. This example is available in full 
on [GitHub](https://github.com/51Degrees/51degrees-varnish/blob/main/examples/hash/config.vcl).

@include{doc} example-require-datafile.txt

The path to the data need to be updated before running the example.

In a Linux environment, the following commands:
```
$ curl localhost:8080 -I -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.97 Safari/537.36"
```
Expected output:
```
HTTP/1.1 200 OK
...
X-Metadata: False:55:0:0:PREDICTIVE:__zilla/5.0 (Windows____10.0; Win6_______________________________________________Chrome/7_.0.3904__7 Safari/5_____:23:15364-38914-97847-18092
```
The example also asks for HardwareVendor, HardwareName and DeviceType, which
only the Enterprise data file has. On the free Lite data file each reads N/A,
and the X-Enterprise header says where to ask for a copy of the Enterprise
data file:
```
X-Hardware: N/A:N/A:N/A
X-Enterprise: Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-config-vcl&utm_term=enterprise-data-file
X-Find-Out-More: This module is at https://github.com/51Degrees/51degrees-varnish and the engine it uses at https://github.com/51Degrees/51degrees-cxx. Read about device detection at https://51degrees.com/device-detection?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-config-vcl&utm_term=device-detection and about data files and pricing at https://51degrees.com/pricing?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-config-vcl&utm_term=pricing
```
With the Enterprise data file X-Hardware holds their values and there is no
X-Enterprise header.

*/
vcl 4.0;

import fiftyonedegrees;

backend default {
	.host = "127.0.0.1";
	.port = "80";
}

sub vcl_deliver {
	set resp.http.X-Metadata = fiftyonedegrees.match_all("IsMobile,Iterations,Drift,Difference,Method,UserAgents,MatchedNodes,DeviceId");
	// HardwareVendor, HardwareName and DeviceType are only in the Enterprise
	// data file, and read N/A on a free one. Then X-Enterprise says where to
	// ask for a copy.
	set resp.http.X-Hardware = fiftyonedegrees.match_all("HardwareVendor,HardwareName,DeviceType");
	if (resp.http.X-Hardware ~ "N/A") {
		set resp.http.X-Enterprise = "Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-config-vcl&utm_term=enterprise-data-file";
	}
	// Say where to find out more, after the other headers.
	set resp.http.X-Find-Out-More = "This module is at https://github.com/51Degrees/51degrees-varnish and the engine it uses at https://github.com/51Degrees/51degrees-cxx. Read about device detection at https://51degrees.com/device-detection?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-config-vcl&utm_term=device-detection and about data files and pricing at https://51degrees.com/pricing?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-config-vcl&utm_term=pricing";
}

sub vcl_init {
	fiftyonedegrees.set_delimiter(":");
	fiftyonedegrees.set_drift(10);
	fiftyonedegrees.set_difference(8);
	fiftyonedegrees.set_max_concurrency(5);
	fiftyonedegrees.set_allow_unmatched("YES");
	fiftyonedegrees.set_use_performance_graph("NO");
	fiftyonedegrees.set_use_predictive_graph("YES");
	fiftyonedegrees.start("/etc/varnish/51Degrees-LiteV4.1.hash");
}
