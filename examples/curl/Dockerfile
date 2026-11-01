FROM ubuntu:24.04
WORKDIR /app

# Varnish Cache from its GitHub release, checked against the SHA256 GitHub shows
# for the file, as ci/setup-environment.ps1 does. A different version needs its
# own VARNISH_SHA256.
ARG VARNISH_VERSION=9.1.0
ARG VARNISH_SHA256=fe615fa024c801d12928e7eea0e822ba93ab625a585841143c36ae02d5bcc37a

RUN apt-get update && apt-get install --no-install-recommends -y git git-lfs curl ca-certificates \
	build-essential automake autoconf libtool pkg-config cpio libedit-dev libncurses-dev \
	python3 python3-docutils libpcre2-dev libpcre3-dev libssl-dev

RUN curl -fLsS -o /tmp/varnish.tgz https://github.com/varnish/varnish/releases/download/varnish-${VARNISH_VERSION}/varnish-${VARNISH_VERSION}.tar.gz \
	&& echo "${VARNISH_SHA256}  /tmp/varnish.tgz" | sha256sum -c - \
	&& mkdir /tmp/varnish && tar xzf /tmp/varnish.tgz --strip-components=1 -C /tmp/varnish \
	&& cd /tmp/varnish && ./configure --without-jemalloc --with-sphinx-build=true && make -j4 && make install && ldconfig \
	&& rm -rf /tmp/varnish /tmp/varnish.tgz

RUN git clone --recurse-submodules https://github.com/51Degrees/51degrees-varnish .

RUN ./autogen.sh && ./configure && make -j4 && make install

COPY default.vcl /app/default.vcl

EXPOSE 8080

CMD ["varnishd", "-F", "-a", "0.0.0.0:8080", "-f", "/app/default.vcl"]
