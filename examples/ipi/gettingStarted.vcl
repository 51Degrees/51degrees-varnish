/**
@example ipi/gettingStarted.vcl

Shows how to look up IP Intelligence properties for an IP address.

This example is available in full on [GitHub](https://github.com/51Degrees/51degrees-varnish/blob/main/examples/ipi/gettingStarted.vcl).

The example uses the ASN data file, which has the properties `AsnName` and
`Asn`. The Lite and Enterprise data files have more. The example also asks for
`Country`, `Latitude` and `Longitude`, which only the Enterprise data file has.
On a free data file each reads N/A, and the x-enterprise header says where to
ask for a copy of the Enterprise data file. From the repository folder,
`sh cxx/data/get-data-files.sh 51Degrees-IPIV4AsnIpiV41.ipi` downloads the ASN
file to `cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi`. The path to the
data file needs to be updated before running the example.

On a local machine the address of the client is a loopback address, which has no
useful IP Intelligence, so the second match reads an address from a request
header. In production the second argument can be left out, as in the first
match, so that the address of the client is used.

In a Linux environment, the following command:
```
$ curl localhost:8080 -I -H "X-Real-IP: 212.58.224.22"
```
Expected output:
```
HTTP/1.1 200 OK
...
x-asn: <the name of the network the client address belongs to>
x-asn-real: \"BBC\":1
x-location-real: N/A,N/A,N/A
x-enterprise: Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-ipi-gettingstarted-vcl&utm_term=enterprise-data-file
...
```
Values take the form `"value":weight`, where the weight shows the confidence in
the value, with the double quotes escaped so they can be used in a header.
*/
vcl 4.0;

import fiftyonedegrees_ipi;

backend default {
	.host = "127.0.0.1";
	.port = "80";
}

sub vcl_recv {
	set req.http.x-asn = fiftyonedegrees_ipi.match("AsnName");
	set req.http.x-asn-real = fiftyonedegrees_ipi.match("AsnName", req.http.X-Real-IP);
	// Country, Latitude and Longitude are only in the Enterprise data file,
	// and read N/A on a free one.
	set req.http.x-location-real = fiftyonedegrees_ipi.match("Country,Latitude,Longitude", req.http.X-Real-IP);
}

sub vcl_deliver {
	set resp.http.x-asn = req.http.x-asn;
	set resp.http.x-asn-real = req.http.x-asn-real;
	set resp.http.x-location-real = req.http.x-location-real;
	// On a free data file, say where to ask for the Enterprise data file.
	if (req.http.x-location-real ~ "N/A") {
		set resp.http.x-enterprise = "Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-ipi-gettingstarted-vcl&utm_term=enterprise-data-file";
	}
}

sub vcl_init {
	fiftyonedegrees_ipi.set_properties("AsnName,Asn,Country,Latitude,Longitude");
	fiftyonedegrees_ipi.start("/etc/varnish/51Degrees-IPIV4AsnIpiV41.ipi");
}

/**
Find out more

The engine this example uses:
https://github.com/51Degrees/51degrees-cxx
The Varnish modules:
https://github.com/51Degrees/51degrees-varnish

IP Intelligence: https://51degrees.com/ip-intelligence?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-ipi-gettingstarted-vcl&utm_term=ip-intelligence
Data files and pricing: https://51degrees.com/pricing?utm_source=github&utm_medium=example&utm_campaign=51degrees-varnish&utm_content=examples-ipi-gettingstarted-vcl&utm_term=pricing
*/
