/**
@example mixed/gettingStarted.vcl

Shows how to load the device detection and IP Intelligence modules together, and
use both for the same request.

This example is available in full on [GitHub](https://github.com/51Degrees/51degrees-varnish/blob/main/examples/mixed/gettingStarted.vcl).

The example uses the Lite device detection data file and the ASN IP Intelligence
data file. From the repository folder,
`sh cxx/data/get-data-files.sh 51Degrees-LiteV4.1.hash 51Degrees-IPIV4AsnIpiV41.ipi`
downloads them to `cxx/data/device-detection/51Degrees-LiteV4.1.hash` and
`cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi`. The paths to the data
files need to be updated before running the example.

The example also asks for HardwareVendor, HardwareName and DeviceType, and for
Country, Latitude and Longitude, which only the Enterprise data files have. On
the free data files each reads N/A, and the x-enterprise header says where to
ask for a copy of the Enterprise data files.

In a Linux environment, the following command:
```
$ curl localhost:8080 -I -H "X-Real-IP: 212.58.224.22" -A "Mozilla/5.0 (iPhone; CPU iPhone OS 11_2 like Mac OS X) AppleWebKit/604.4.7 (KHTML, like Gecko) Mobile/15C114"
```
Expected output:
```
HTTP/1.1 200 OK
...
x-ismobile: True
x-asn: \"BBC\":1
x-hardware: N/A,N/A,N/A
x-location: N/A,N/A,N/A
x-enterprise: Some of these properties need the Enterprise data files. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-mixed-gettingstarted-vcl&utm_term=enterprise-data-file
...
```
*/
vcl 4.0;

import fiftyonedegrees;
import fiftyonedegrees_ipi;

backend default {
	.host = "127.0.0.1";
	.port = "80";
}

sub vcl_recv {
	set req.http.x-ismobile = fiftyonedegrees.match_all("IsMobile");
	set req.http.x-asn = fiftyonedegrees_ipi.match("AsnName", req.http.X-Real-IP);
	// The hardware and location properties are only in the Enterprise data
	// files, and read N/A on the free ones.
	set req.http.x-hardware = fiftyonedegrees.match_all("HardwareVendor,HardwareName,DeviceType");
	set req.http.x-location = fiftyonedegrees_ipi.match("Country,Latitude,Longitude", req.http.X-Real-IP);
}

sub vcl_deliver {
	set resp.http.x-ismobile = req.http.x-ismobile;
	set resp.http.x-asn = req.http.x-asn;
	set resp.http.x-hardware = req.http.x-hardware;
	set resp.http.x-location = req.http.x-location;
	// On a free data file, say where to ask for the Enterprise data files.
	if (req.http.x-hardware ~ "N/A" || req.http.x-location ~ "N/A") {
		set resp.http.x-enterprise = "Some of these properties need the Enterprise data files. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-mixed-gettingstarted-vcl&utm_term=enterprise-data-file";
	}
}

sub vcl_init {
	fiftyonedegrees.start("/etc/varnish/51Degrees-LiteV4.1.hash");
	fiftyonedegrees_ipi.start("/etc/varnish/51Degrees-IPIV4AsnIpiV41.ipi");
}

/**
Find out more

The engine this example uses:
https://github.com/51Degrees/51degrees-cxx
The Varnish modules:
https://github.com/51Degrees/51degrees-varnish

Device detection: https://51degrees.com/device-detection?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-mixed-gettingstarted-vcl&utm_term=device-detection
IP Intelligence: https://51degrees.com/ip-intelligence?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-mixed-gettingstarted-vcl&utm_term=ip-intelligence
Data files and pricing: https://51degrees.com/pricing?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-mixed-gettingstarted-vcl&utm_term=pricing
*/
