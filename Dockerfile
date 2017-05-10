FROM shadow-standalone
# Get the shadow-standalone container by running:
# wget https://security.cs.georgetown.edu/shadow-docker-images/shadow-standalone.tar.gz.
# gunzip -c shadow-standalone.tar.gz | docker load
# More instructions at https://github.com/shadow/shadow/wiki/1-Installation-and-Setup#pre-built-images

MAINTAINER Andrew Fasano version: 0.1

RUN dnf -y install libstdc++ libstdc++-devel clang clang-devel llvm llvm-devel glib2 glib2-devel git wget tar autoconf automake openssl which cmake

USER shadow
ENV USER "shadow"

RUN cd ~ && git clone https://github.com/shadow/shadow-plugin-bitcoin.git
RUN mkdir ~/shadow-plugin-bitcoin/build

# BOOST
RUN cd ~ && wget http://downloads.sourceforge.net/project/boost/boost/1.50.0/boost_1_50_0.tar.gz
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
RUN cd ~/shadow-plugin-bitcoin/build && wget https://www.openssl.org/source/openssl-1.0.1h.tar.gz && tar xaf openssl-1.0.1h.tar.gz
RUN cd ~/shadow-plugin-bitcoin/build/openssl-1.0.1h && ./config --prefix=/home/${USER}/.shadow shared threads enable-ec_nistp_64_gcc_128 -fPIC
RUN cd ~/shadow-plugin-bitcoin/build/openssl-1.0.1h && make depend && make && make install_sw

# BITCOIN
RUN cd ~/shadow-plugin-bitcoin/build && git clone https://github.com/amiller/bitcoin.git -b 0.9.2-netmine
RUN cd ~/shadow-plugin-bitcoin/build/bitcoin && ./autogen.sh && LD_LIBRARY_PATH=`pwd`/../boost_1_50_0/stage/lib PKG_CONFIG_PATH=/home/${USER}/.shadow/lib/pkgconfig LDFLAGS=-L/home/${USER}/.shadow/lib CFLAGS=-I/home/${USER}/.shadow/include CXXFLAGS=-I`pwd`/../boost_1_50_0 ./configure --prefix=/home/${USER}/.shadow --without-miniupnpc --without-gui --disable-wallet --disable-tests --with-boost-libdir=`pwd`/../boost_1_50_0/stage/lib

# GNU PTH
RUN cd ~/shadow-plugin-bitcoin/build && git clone https://github.com/amiller/gnu-pth.git -b shadow
RUN cd ~/shadow-plugin-bitcoin/build/gnu-pth && ./configure --enable-epoll

# build shadow plugin
RUN cd ~/shadow-plugin-bitcoin/build && mkdir shadow-plugin-bitcoin
RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && mkdir shadow-plugin-bitcoin
RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && CC=`which clang` CXX=`which clang++` LD_LIBRARY_PATH=`pwd`/../boost_1_50_0/stage/lib PKG_CONFIG_PATH=/home/${USER}/.shadow/lib/pkgconfig LDFLAGS=-L/home/${USER}/.shadow/lib CFLAGS=-I/home/${USER}/.shadow/include CXXFLAGS=-I`pwd`/../boost_1_50_0 cmake ../..
RUN cd ~/shadow-plugin-bitcoin/build/shadow-plugin-bitcoin && make -j2 && make install

# Update LD_LIBRARY_PATH - TODO - why doesn't this work
#ENV LD_LIBRARY_PATH /usr/local/lib:/usr/lib:/lib:/home/shadow/.shadow/lib
#RUN ldconfig
#RUN ldd /home/shadow/.shadow/lib/libshadow-preload-bitcoind.so - Should have no errors

# Tempory fix for LD_LIBRARY_PATH
RUN cp /home/shadow/.shadow/lib/*.so /lib/
RUN ldconfig

# RUN
RUN cd ~/shadow-plugin-bitcoin &&  mkdir run
RUN cd ~/shadow-plugin-bitcoin/run && ../src/bitcoind/shadow-bitcoind -y -i ../resource/shadow.config.xml -r -t | grep -e "received: getaddr" -e "received: verack"

# Set up dev environment
RUN dnf -y remove vim-minimal

# We need to install sudo as root or it breaks
USER root
RUN dnf -y install vim sudo tmux

USER shadow
RUN mkdir ~/host
Add . ~/host

#RUN wget https://cs.umd.edu/%7Eamiller/dotbitcoin_backing_120k.tar.gz
#mkdir initdata
#cd initdata
#mkdir pristine # will hold the single copy of the blockchain datasets
#cp -R /storage/dotbitcoin_backing_120k pristine/.
#mkdir dotbitcoin_template_120k
#cd dotbitcoin_template_120k
