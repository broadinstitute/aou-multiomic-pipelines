FROM mambaorg/micromamba:2.0.2
COPY --chown=$MAMBA_USER:$MAMBA_USER env.yml /tmp/env.yaml
RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes
