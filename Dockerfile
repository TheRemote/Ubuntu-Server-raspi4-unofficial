FROM ubuntu:bionic

RUN apt-get update && \
    apt-get install --yes \
        bc bison build-essential curl file flex git kpartx libgmp-dev libmpc-dev libmpfr-dev libssl-dev \
        module-init-tools qemu-user-static unzip

ARG binutils_version
ARG gcc_version
ARG make_jobs
ARG toolchain

RUN mkdir -p "$toolchain" && \
    cd "$toolchain" && \
    curl -fsSLO https://ftp.gnu.org/gnu/binutils/binutils-$binutils_version.tar.bz2 && \
    tar xf binutils-$binutils_version.tar.bz2 && \
    rm binutils-$binutils_version.tar.bz2 && \
    mkdir binutils-${binutils_version}-build && \
    cd binutils-${binutils_version}-build && \
    ../binutils-$binutils_version/configure --prefix="$toolchain" --target=aarch64-linux-gnu --disable-nls && \
    make --jobs="$make_jobs" && \
    make install realclean

RUN mkdir -p "$toolchain" && \
    cd "$toolchain" && \
    curl -fsSLO https://ftp.gnu.org/gnu/gcc/gcc-$gcc_version/gcc-$gcc_version.tar.gz && \
    tar xf gcc-$gcc_version.tar.gz && \
    rm gcc-$gcc_version.tar.gz && \
    mkdir gcc-${gcc_version}-build && \
    cd gcc-${gcc_version}-build && \
    ../gcc-$gcc_version/configure \
        --prefix="$toolchain" --target=aarch64-linux-gnu --with-newlib --without-headers --disable-nls \
        --disable-shared --disable-threads --disable-libssp --disable-decimal-float --disable-libquadmath \
        --disable-libvtv --disable-libgomp --disable-libatomic --enable-languages=c && \
    make --jobs="$make_jobs" all-gcc && \
    make install-gcc realclean

ENV PATH="$toolchain/bin:$PATH"
ENV MAKE_JOBS="$make_jobs"

WORKDIR /app
COPY . ./

RUN apt-get install --yes sudo && \
    adduser --disabled-password --gecos '' docker && \
    adduser docker sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir /build && chown docker:docker /build
VOLUME /build
USER docker
