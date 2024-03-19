ARG TORCH="torch==2.2.1"
ARG TORCH_GEO="pyg-lib==0.4.0 \
    torch-cluster==1.6.3 \
    torch-scatter==2.1.2 \
    torch-sparse==0.6.18 \
    torch-spline-conv==1.2.2 \
    torch-geometric==2.5.1"
ARG TORCH_GEO_URL="https://data.pyg.org/whl/torch-2.2.1"
ARG CUDA_VER=cu121


FROM continuumio/miniconda3 as build-py
WORKDIR /root
RUN printf "name: py\n\ndependencies:\n  - python=3.11\n  - pip\n" > environment.yml
RUN conda env create -f environment.yml && \
    conda install -c conda-forge conda-pack
RUN /opt/conda/envs/py/bin/pip3 install --no-cache-dir autopep8
RUN apt-get update && apt-get install -y --no-install-recommends gcc make cmake g++ && apt-get clean
ADD requirements.txt /tmp/requirements.txt
ADD requirements2.txt /tmp/requirements2.txt
RUN /opt/conda/envs/py/bin/pip3 install --no-cache-dir -r /tmp/requirements.txt


FROM build-py AS build-py-cpu
ARG TORCH
ARG TORCH_GEO
ARG TORCH_GEO_URL
RUN /opt/conda/envs/py/bin/pip3 install --no-cache-dir $TORCH+cpu --extra-index-url https://download.pytorch.org/whl/cpu && \
    /opt/conda/envs/py/bin/pip3 install --no-cache-dir $TORCH_GEO -f $TORCH_GEO_URL+cpu.html
RUN /opt/conda/envs/py/bin/pip3 install --no-cache-dir -r /tmp/requirements2.txt
RUN conda clean --all && \
    conda-pack -n py -o /tmp/env.tar && \
    mkdir /venv && cd /venv && \
    tar xf /tmp/env.tar


FROM build-py AS build-py-cuda
ARG TORCH
ARG CUDA_VER
ARG TORCH_GEO
ARG TORCH_GEO_URL
RUN /opt/conda/envs/py/bin/pip3 install --no-cache-dir $TORCH+$CUDA_VER --extra-index-url https://download.pytorch.org/whl/$CUDA_VER && \
    /opt/conda/envs/py/bin/pip3 install --no-cache-dir $TORCH_GEO -f $TORCH_GEO_URL+$CUDA_VER.html
RUN /opt/conda/envs/py/bin/pip3 install --no-cache-dir -r /tmp/requirements2.txt
RUN conda clean --all && \
    conda-pack -n py -o /tmp/env.tar && \
    mkdir /venv && cd /venv && \
    tar xf /tmp/env.tar


FROM nvidia/cuda:12.3.2-runtime-ubuntu22.04 AS cuda-python
ENV TZ=Etc/UTC
RUN apt-get update && apt-get install -y --no-install-recommends git && apt-get clean
COPY --from=build-py-cuda /venv /venv
RUN bash -c "source /venv/bin/activate && conda-unpack"
ENV PATH="$PATH:/venv/bin"
CMD [ "/bin/bash" ]


FROM ubuntu:22.04 AS python
ENV TZ=Etc/UTC
RUN apt-get update && apt-get install -y --no-install-recommends git && apt-get clean
COPY --from=build-py-cpu /venv /venv
RUN bash -c "source /venv/bin/activate && conda-unpack"
ENV PATH="$PATH:/venv/bin"
CMD [ "/bin/bash" ]
