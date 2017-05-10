FROM shadow-standalone
# Get the shadow-standalone container by running:
# wget https://security.cs.georgetown.edu/shadow-docker-images/shadow-standalone.tar.gz.
# gunzip -c shadow-standalone.tar.gz | docker load
# More instructions at https://github.com/shadow/shadow/wiki/1-Installation-and-Setup#pre-built-images

MAINTAINER Andrew Fasano version: 0.1

USER shadow
ENV USER "shadow"

# Download files
RUN dnf -y install libstdc++ libstdc++-devel clang clang-devel llvm llvm-devel glib2 glib2-devel git wget tar autoconf automake openssl which cmake jansson jansson-devel libevent libevent-devel
RUN cd ~ && git clone https://github.com/shadow/shadow-plugin-bitcoin.git -b attacks-features
RUN cd ~ && wget http://downloads.sourceforge.net/project/boost/boost/1.50.0/boost_1_50_0.tar.gz
RUN cd ~/shadow-plugin-bitcoin/build && wget https://www.openssl.org/source/openssl-1.0.1h.tar.gz && tar xaf openssl-1.0.1h.tar.gz
RUN cd ~/shadow-plugin-bitcoin/build && git clone https://github.com/amiller/bitcoin.git -b 0.9.2-netmine
RUN cd ~/shadow-plugin-bitcoin/build && git clone https://github.com/amiller/gnu-pth.git -b shadow
RUN cd ~/shadow-plugin-bitcoin/build && git clone https://github.com/amiller/picocoin.git
RUN cd ~/shadow-plugin-bitcoin/build && wget http://pkgs.fedoraproject.org/lookaside/pkgs/libev/libev-4.15.tar.gz/3a73f247e790e2590c01f3492136ed31/libev-4.15.tar.gz
RUN cd ~ && wget https://cs.umd.edu/%7Eamiller/dotbitcoin_backing_120k.tar.gz

# BOOST
RUN cd ~ && tar xaf boost_1_50_0.tar.gz

# BOOST - patch - there's probably a better way
RUN head -n 42 ~/boost_1_50_0/boost/cstdint.hpp > ~/patched.hpp
RUN echo '#if defined(BOOST_HAS_STDINT_H)                           \' >> ~/patched.hpp
RUN echo '  && (!defined(__GLIBC__)                                 \' >> ~/patched.hpp
RUN echo '      || defined(__GLIBC_HAVE_LONG_LONG)                  \' >> ~/patched.hpp
RUN echo '      || (defined(__GLIBC__) && ((__GLIBC__ > 2) || ((__GLIBC__ == 2) && (__GLIBC_MINOR__ >= 17)))))' >> ~/patched.hpp
RUN awk 'NR >= 45' ~/boost_1_50_0/boost/cstdint.hpp >> ~/patched.hpp
RUN mv ~/patched.hpp ~/boost_1_50_0/boost/cstdint.hpp

# BOOST - finish
RUN cd ~/boost_1_50_0 && ./bootstrap.sh --with-libraries=filesystem,system,thread,program_options
RUN cd ~/boost_1_50_0 && ./b2
RUN mv ~/boost_1_50_0 ~/shadow-plugin-bitcoin/build

# OPENSSL
RUN cd ~/shadow-plugin-bitcoin/build/openssl-1.0.1h && ./config --prefix=/home/${USER}/.shadow shared threads enable-ec_nistp_64_gcc_128 -fPIC
RUN cd ~/shadow-plugin-bitcoin/build/openssl-1.0.1h && make depend && make && make install_sw

# BITCOIN
RUN cd ~/shadow-plugin-bitcoin/build/bitcoin && ./autogen.sh && LD_LIBRARY_PATH=`pwd`/../boost_1_50_0/stage/lib PKG_CONFIG_PATH=/home/${USER}/.shadow/lib/pkgconfig LDFLAGS=-L/home/${USER}/.shadow/lib CFLAGS=-I/home/${USER}/.shadow/include CXXFLAGS=-I`pwd`/../boost_1_50_0 ./configure --prefix=/home/${USER}/.shadow --without-miniupnpc --without-gui --disable-wallet --disable-tests --with-boost-libdir=`pwd`/../boost_1_50_0/stage/lib

# GNU PTH
RUN cd ~/shadow-plugin-bitcoin/build/gnu-pth && ./configure --enable-epoll

# picocoin
RUN cd ~/shadow-plugin-bitcoin/build/picocoin && ./autogen.sh && LDFLAGS=-L/home/${USER}/.shadow/lib ./configure

# libev
RUN cd ~/shadow-plugin-bitcoin/build/ && tar -zxf libev-4.15.tar.gz
RUN cd ~/shadow-plugin-bitcoin/build/libev-4.15 && ./configure

# build shadow plugin
RUN cd ~/shadow-plugin-bitcoin/build && mkdir shadow-plugin-bitcoin
RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && mkdir shadow-plugin-bitcoin
#RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && git checkout attacks-features
#RUN cd ~/shadow-plugin-bitcoin/ && git checkout origin/master src/CMakeLists.txt
RUN sed -i ~/shadow-plugin-bitcoin/src/CMakeLists.txt -re '211,312d'
RUN sed -i ~/shadow-plugin-bitcoin/src/CMakeLists.txt -re '350d'
RUN sed -i '350s/#//' ~/shadow-plugin-bitcoin/src/CMakeLists.txt
#RUN cat ~/shadow-plugin-bitcoin/src/CMakeLists.txt && exit 1
RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && CC=`which clang` CXX=`which clang++` LD_LIBRARY_PATH=`pwd`/../boost_1_50_0/stage/lib PKG_CONFIG_PATH=/home/${USER}/.shadow/lib/pkgconfig LDFLAGS=-L/home/${USER}/.shadow/lib CFLAGS=-I/home/${USER}/.shadow/include CXXFLAGS=-I`pwd`/../boost_1_50_0 cmake ../..
RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && make && make install

# Update LD_LIBRARY_PATH - TODO - why doesn't this work
#ENV LD_LIBRARY_PATH /usr/local/lib:/usr/lib:/lib:/home/shadow/.shadow/lib
#RUN ldconfig
#RUN ldd /home/shadow/.shadow/lib/libshadow-preload-bitcoind.so - Should have no errors

# Tempory fix for LD_LIBRARY_PATH
RUN cp /home/shadow/.shadow/lib/*.so /lib/
RUN ldconfig

# RUN
RUN cd ~/shadow-plugin-bitcoin &&  mkdir run
RUN cd ~/shadow-plugin-bitcoin/run &&  mkdir bcdnode1
RUN cd ~/shadow-plugin-bitcoin/run &&  mkdir bcdnode2
#RUN cd ~/shadow-plugin-bitcoin/run && ../src/bitcoind/shadow-bitcoind -y -i ../resource/shadow.config.xml -r -t | grep -e "received: getaddr" -e "received: verack"

## Set up dev environment
#RUN dnf -y remove vim-minimal
#
## We need to install sudo as root or it breaks
#USER root
#RUN dnf -y install vim sudo tmux
#
#USER shadow
#RUN mkdir ~/host
#
## Extract backing data and create symlinks
#RUN dnf -y install bc
#RUN cd ~/shadow-plugin-bitcoin/run && mkdir -p initdata/pristine
#
#RUN cd ~ && tar xf ~/dotbitcoin_backing_120k.tar.gz
#RUN cp -R ~/dotbitcoin_backing_120k ~/shadow-plugin-bitcoin/run/initdata/pristine/.
#RUN mkdir ~/shadow-plugin-bitcoin/run/initdata/dotbitcoin_template_120k
#RUN cd ~/shadow-plugin-bitcoin/run/initdata/dotbitcoin_template_120k && ../../../tools/make_symlinks.sh ../pristine/dotbitcoin_backing_120k
