FROM ubuntu:24.04
WORKDIR /app

# Varnish Cache from its GitHub release, checked against the SHA256 GitHub shows
# for the file, as ci/setup-environment.ps1 does. A different version needs its
# own _51DEGREES_VARNISH_SHA256.
ARG _51DEGREES_VARNISH_VERSION=9.1.0
ARG _51DEGREES_VARNISH_SHA256=fe615fa024c801d12928e7eea0e822ba93ab625a585841143c36ae02d5bcc37a

RUN apt-get update && apt-get install --no-install-recommends -y git curl ca-certificates \
	build-essential automake autoconf libtool pkg-config cpio libedit-dev libncurses-dev \
	python3 python3-docutils libpcre2-dev libpcre3-dev libssl-dev

RUN curl -fLsS -o /tmp/varnish.tgz https://github.com/varnish/varnish/releases/download/varnish-${_51DEGREES_VARNISH_VERSION}/varnish-${_51DEGREES_VARNISH_VERSION}.tar.gz \
	&& echo "${_51DEGREES_VARNISH_SHA256}  /tmp/varnish.tgz" | sha256sum -c - \
	&& mkdir /tmp/varnish && tar xzf /tmp/varnish.tgz --strip-components=1 -C /tmp/varnish \
	&& cd /tmp/varnish && ./configure --without-jemalloc --with-sphinx-build=true && make -j4 && make install && ldconfig \
	&& rm -rf /tmp/varnish /tmp/varnish.tgz

# What to build, the head of main unless --build-arg names another
# _51DEGREES_BRANCH or one _51DEGREES_COMMIT, so a change can be checked before
# it reaches main. _51DEGREES_REPOSITORY is the address it is fetched from.
ARG _51DEGREES_REPOSITORY=https://github.com/51Degrees/51degrees-varnish
ARG _51DEGREES_BRANCH=main
ARG _51DEGREES_COMMIT=
RUN git init -q . && git remote add origin "${_51DEGREES_REPOSITORY}" \
	&& git fetch -q origin "${_51DEGREES_COMMIT:-$_51DEGREES_BRANCH}" && git checkout -q FETCH_HEAD \
	&& git submodule update --init --recursive

# The data submodule holds a link to each data file that default.vcl loads
# rather than the file. A copy put beside this Dockerfile before the build is
# used, read through a bind mount so that it is stored in the image once, and
# any other is downloaded. With _51DEGREES_DOWNLOAD_DATA_FILES=false a missing
# copy fails the build instead, which is how CI builds the image from the data
# files it has fetched.
ARG _51DEGREES_DOWNLOAD_DATA_FILES=true
RUN --mount=type=bind,target=/tmp/context \
	for file in device-detection/51Degrees-LiteV4.1.hash \
		ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi; do \
		name=$(basename "$file"); \
		if [ -f "/tmp/context/$name" ]; then \
			cp "/tmp/context/$name" "cxx/data/$file" || exit 1; \
		elif [ "$_51DEGREES_DOWNLOAD_DATA_FILES" = true ]; then \
			sh cxx/data/get-data-files.sh -s examples-51degrees-varnish "$name" || exit 1; \
		else \
			echo "$name is not beside the Dockerfile, and" \
				"_51DEGREES_DOWNLOAD_DATA_FILES is not true, so it is not downloaded" >&2; \
			exit 1; \
		fi; \
	done

RUN ./autogen.sh && ./configure && make -j4 && make install

COPY default.vcl /app/default.vcl

EXPOSE 8080

CMD ["varnishd", "-F", "-a", "0.0.0.0:8080", "-f", "/app/default.vcl"]
