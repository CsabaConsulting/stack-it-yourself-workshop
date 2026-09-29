# syntax=docker/dockerfile:1
# A CPU-only Ollama image: the official Ollama binary and its CPU backends, without the
# ~4.7 GB of CUDA, MLX-CUDA and Vulkan runtimes a GPU-free workshop never uses.
#
#   official ollama/ollama:0.34.4  ~3.75 GB download (amd64), ~9.3 GB on disk
#   this image                     a few tens of MB
#
# Ollama is MIT-licensed; its licence files are kept in /usr/lib/ollama.
ARG OLLAMA_VERSION=0.34.4

FROM ollama/ollama:${OLLAMA_VERSION} AS upstream
RUN rm -rf /usr/lib/ollama/cuda_* /usr/lib/ollama/mlx_* /usr/lib/ollama/rocm* /usr/lib/ollama/vulkan

FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=upstream /usr/bin/ollama /usr/bin/ollama
COPY --from=upstream /usr/lib/ollama /usr/lib/ollama
ENV OLLAMA_HOST=0.0.0.0:11434
EXPOSE 11434
ENTRYPOINT ["/usr/bin/ollama"]
CMD ["serve"]
