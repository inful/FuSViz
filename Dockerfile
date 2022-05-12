FROM rocker/shiny:4.1 AS builder

LABEL maintainer="Sen ZHAO <t.cytotoxic@gmail.com>"

RUN apt-get update && apt-get install -y \
	build-essential \
	sudo \
	unzip \
	wget \
	curl \
	git \
	libbz2-dev \
	zlib1g-dev \
	libgsl0-dev \
	liblzma-dev \
	libglpk-dev \
	libncurses5-dev \
	libperl-dev \
	zlib1g-dev \
	libcurl4-openssl-dev \
	libxt-dev \
	libcairo2-dev \
	libsqlite3-dev \
	libpng-dev \
	libjpeg-dev \
	libxml2-dev \
	libssl-dev \
	libssh2-1-dev \
    && rm -rf /var/lib/apt/lists/*

ENV LIBRARY_PATH=$LIBRARY_PATH:/usr/local/lib/R/lib/
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/R/lib/

WORKDIR /tmp
ARG htsversion=1.13
RUN curl -L https://github.com/samtools/htslib/releases/download/${htsversion}/htslib-${htsversion}.tar.bz2 | tar xj && \
    (cd htslib-${htsversion} && ./configure --enable-plugins --with-plugin-path='$(libexecdir)/htslib:/usr/libexec/htslib' && make install) && \
    ldconfig && \
    curl -L https://github.com/samtools/samtools/releases/download/${htsversion}/samtools-${htsversion}.tar.bz2 | tar xj && \
    (cd samtools-${htsversion} && ./configure --with-htslib=system && make install) && \
    curl -L https://github.com/samtools/bcftools/releases/download/${htsversion}/bcftools-${htsversion}.tar.bz2 | tar xj && \
    (cd bcftools-${htsversion} && ./configure --enable-libgsl --enable-perl-filters --with-htslib=system && make install)

RUN install2.r -e remotes
RUN install2.r -e devtools
RUN installGithub.r "lchiffon/wordcloud2"
RUN installGithub.r "senzhaocode/FuSViz"
RUN wget https://cran.r-project.org/src/contrib/Archive/shinyWidgets/shinyWidgets_0.6.2.tar.gz && R CMD INSTALL shinyWidgets_0.6.2.tar.gz
RUN rm -rf /tmp/bcftools* && rm -rf /tmp/htslib-* && rm -rf /tmp/samtools-* && rm -rf /tmp/file* && rm -rf /tmp/shinyWidgets*

# Now build an image without all the dev cruft
FROM rocker/shiny:4.1 AS result

ENV LIBRARY_PATH=$LIBRARY_PATH:/usr/local/lib/R/lib/
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/R/lib/
RUN echo "local(options(shiny.port = 3838, shiny.host = '0.0.0.0'))" >> /usr/local/lib/R/etc/Rprofile.site

# Set Volume
RUN mkdir /data && chmod 777 /data
VOLUME /data

COPY --from=builder /usr/local/lib/R/lib /usr/local/lib/R/lib

# Set non-root user
RUN addgroup --system senzhao && adduser --system --ingroup senzhao senzhao

WORKDIR /home/senzhao

COPY inst/app/*.R .

RUN chown senzhao:senzhao -R /home/senzhao

USER senzhao

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/home/senzhao')"]
