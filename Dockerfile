# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage
############## build stage ##############

# package versions
ARG ARGTABLE_VER="2.13"
ARG XMLTV_VER="v1.0.0"

# environment settings
ARG TZ="Etc/UTC"
ARG TVHEADEND_COMMIT
ENV HOME="/config"

# copy patches
COPY patches/ /tmp/patches/

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
    autoconf \
    automake \
    bsd-compat-headers \
    build-base \
    cmake \
    ffmpeg4-dev \
    file \
    findutils \
    gettext-dev \
    git \
    gnu-libiconv-dev \
    libgcrypt-dev \
    libhdhomerun-dev \
    libtool \
    libva-dev \
    libvpx-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    openssl-dev \
    opus-dev \
    patch \
    pcre2-dev \
    pkgconf \
    pngquant \
    python3 \
    sdl2-dev \
    uriparser-dev \
    x264-dev \
    x265-dev \
    zlib-dev

RUN \
  echo "**** remove musl iconv.h and replace with gnu-iconv.h ****" && \
  rm -rf /usr/include/iconv.h && \
  cp /usr/include/gnu-libiconv/iconv.h /usr/include/iconv.h

 RUN \
 echo "***** compile libdvbcsa sse2 ****" && \
 git clone https://github.com/glenvt18/libdvbcsa /tmp/libdvbcsa && \
 cd /tmp/libdvbcsa && \
 autoreconf -i && \
 ./configure \
	--enable-sse2 && \
 make -j 2 && \
 make  install

RUN \
  echo "**** compile tvheadend ****" && \
  if [ -z ${TVHEADEND_COMMIT+x} ]; then \
    TVHEADEND_COMMIT=$(curl -sX GET https://api.github.com/repos/tvheadend/tvheadend/commits/master \
    | jq -r '. | .sha'); \
  fi && \
  mkdir -p \
    /tmp/tvheadend && \
  git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
  cd /tmp/tvheadend && \
  git checkout ${TVHEADEND_COMMIT} && \
  ./configure \
    `#Encoding` \
    --disable-ffmpeg_static \
    --disable-libfdkaac_static \
    --disable-libtheora_static \
    --disable-libopus_static \
    --disable-libvorbis_static \
    --disable-libvpx_static \
    --disable-libx264_static \
    --disable-libx265_static \
    --disable-libfdkaac \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    \
    `#Options` \
    --disable-avahi \
    --disable-dbus_1 \
    --disable-bintray_cache \
    --disable-execinfo \
    --disable-hdhomerun_static \
    --enable-hdhomerun_client \
    --enable-libav \
    --enable-pngquant \
    --enable-trace \
    --enable-vaapi \
    --infodir=/usr/share/info \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --prefix=/usr \
    --python=python3 \
    --sysconfdir=/config && \
  make -j 2 && \
  make DESTDIR=/tmp/tvheadend-build install


############## runtime stage ##############
FROM ghcr.io/linuxserver/baseimage-alpine:3.17

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="saarg"

# environment settings
ENV HOME="/config"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    bsd-compat-headers \
    ffmpeg \
    ffmpeg4-libs \
    gnu-libiconv \
    libhdhomerun-libs \
    libva \
    libva-intel-driver \
    intel-media-driver \
    mesa \
    libvpx \
    libxml2 \
    libxslt \
    linux-headers \
    opus \
    pcre2 \
    py3-requests \
    python3 \
    uriparser \
    x264 \
    x265 \
    zlib

# copy local files and buildstage artifacts
COPY --from=buildstage /tmp/tvheadend-build/usr/ /usr/
COPY --from=buildstage /usr/local/lib/libdvbcsa* /usr/local/lib/
COPY root/ /

# ports and volumes
EXPOSE 9981 9982
VOLUME /config
