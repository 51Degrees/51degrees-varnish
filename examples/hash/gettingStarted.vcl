/**
@example hash/gettingStarted.vcl

@include{doc} example-getting-started-hash.txt

This example is available in full on [GitHub](https://github.com/51Degrees/51degrees-varnish/blob/main/examples/hash/gettingStarted.vcl).

@include{doc} example-require-datafile.txt

The path to the data need to be updated before running the example.

In a Linux environment, the following commands:
```
$ curl localhost:8080 -I -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.97 Safari/537.36"
$ curl localhost:8080 -I -A "Mozilla/5.0 (iPhone; CPU iPhone OS 11_2 like Mac OS X) AppleWebKit/604.4.7 (KHTML, like Gecko) Mobile/15C114"
```
Expected output:
```
HTTP/1.1 200 OK
...
X-IsMobile: False
...

...
HTTP/1.1 200 OK
...
X-IsMobile: True
```
The example also asks for HardwareVendor, HardwareName and DeviceType, which
only the Enterprise data file has. On the free Lite data file each reads N/A,
and the X-Enterprise header says where to ask for a copy of the Enterprise
data file:
```
X-Hardware: N/A,N/A,N/A
X-Enterprise: Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-gettingstarted-vcl&utm_term=enterprise-data-file
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

sub vcl_recv {
	set req.http.X-IsMobile = fiftyonedegrees.match_single(req.http.user-agent, "IsMobile");
}

sub vcl_deliver {
	set resp.http.X-IsMobile = fiftyonedegrees.match_single(req.http.user-agent, "IsMobile");
	// HardwareVendor, HardwareName and DeviceType are only in the Enterprise
	// data file, and read N/A on a free one. Then X-Enterprise says where to
	// ask for a copy.
	set resp.http.X-Hardware = fiftyonedegrees.match_single(req.http.user-agent, "HardwareVendor,HardwareName,DeviceType");
	if (resp.http.X-Hardware ~ "N/A") {
		set resp.http.X-Enterprise = "Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-gettingstarted-vcl&utm_term=enterprise-data-file";
	}
}

sub vcl_init {
	fiftyonedegrees.start("/etc/varnish/51Degrees-LiteV4.1.hash");
}

/**
Find out more

The engine this example uses:
https://github.com/51Degrees/51degrees-cxx
The Varnish modules:
https://github.com/51Degrees/51degrees-varnish

Device detection: https://51degrees.com/device-detection?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-gettingstarted-vcl&utm_term=device-detection
Data files and pricing: https://51degrees.com/pricing?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-hash-gettingstarted-vcl&utm_term=pricing
*/
