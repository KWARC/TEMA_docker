FROM debian:stable

LABEL maintainer "Alexandru Hambasan, Mihnea Iancu" 

EXPOSE 8080 9090 9200 11005 9999 

## Disable apt cache
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache


## Basics
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y git subversion locales  && \
    apt-get clean
COPY locale.gen /etc/locale.gen
RUN locale-gen
RUN echo "export LC_CTYPE=en_US.UTF-8" >> ~/.bashrc
RUN echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc


## (1) Environment Setup 
# (1.1) MWS & Misc Deps 
RUN apt-get install -y g++ cmake make pkg-config && apt-get clean
RUN apt-get install -y libmicrohttpd-dev libxml2-dev libleveldb-dev libsnappy-dev libjson0-dev  && apt-get clean
RUN apt-get install -y libicu-dev libcurl4-gnutls-dev libhtmlcxx-dev && apt-get clean
# (1.2) TeMa Frontend Deps
RUN apt-get install -y curl php5 php5-curl elasticsearch && apt-get clean
# ADD SYMBOLIC LINK FOR ES
RUN ln -s /etc/elasticsearch/ /usr/share/elasticsearch/config
# ADD elasticsearch config. file to the container
COPY elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
# (1.3) Install TeMa Proxy deps
RUN apt-get install -y npm && apt-get clean
# (1.4) Install MMT deps
RUN apt-get install -y java-common 
## (2) Set up MWS & friends
WORKDIR /var/data/
COPY ./mws /var/data/mws/
COPY ./mws-frontend /var/data/mws-frontend/
COPY ./tema-proxy /var/data/tema-proxy/
WORKDIR /var/data/mws/
RUN make && make install 
## (3) Set up MMT
# (3.1) ADD MMT scripts
WORKDIR /var/data/
COPY ./deploy /var/data/MMT/deploy/
## (3.2) Set up MMT Library & OEIS-specific config
WORKDIR /var/data/
COPY ./mmtarch /var/data/mmtarch/
COPY serve.msl /var/data/mmtarch/serve.msl
## (4) Set up generated content 
# (4.1) Create havests
WORKDIR /var/data/
RUN mkdir harvest
RUN find mmtarch/export/oeis-pres/narration/ -name *.html | xargs -n 10 docs2harvest -c mmtarch/lib/tema-config.json -o harvest
# (4.2) Index 
RUN mkdir index && mws/bin/mws-index -I harvest -o index/
# (4.3) Generate elasticsearch json index, will out to `havest/` a .json file for every .harvest file
RUN harvests2json -H harvest/ -I index/
# (5) Add start-up script -- see adjacent `start-tema` file for details -- 
ADD start-tema /usr/bin/

