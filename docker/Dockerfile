FROM rocker/r-ver:latest

## copy the renv.lock into the image
COPY renv.lock /renv.lock

## install renv
RUN Rscript -e 'install.packages(c("renv"))'

## set the renv path var to the renv lib
ENV RENV_PATHS_LIBRARY renv/library

## restore packages from renv.lock
RUN Rscript -e 'renv::restore(lockfile="/renv.lock", repos=NULL)'

## copy in built R package
COPY neuro2_0.1.7.tar.gz /neuro2_0.1.7.tar.gz

## run script to install built R package from source
RUN Rscript -e 'install.packages("/neuro2_0.1.7.tar.gz", type="source", repos=NULL)'
