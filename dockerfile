FROM redhat/ubi8:latest AS builder

RUN dnf install -y gcc make pcre-devel zlib-devel openssl-devel wget tar git which redhat-rpm-config

ARG NGINX_VERSION
ARG MODULE_NAME
ARG MODULE_REPO
ARG GITHUB_REPOS_TO_CLONE

WORKDIR /build
RUN wget -qO- http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xzf -

RUN <<`
set -eux
for repo in ${MODULE_REPO} ${GITHUB_REPOS_TO_CLONE}; do
  git clone https://github.com/$repo $(basename "$repo")
done
`

WORKDIR /build/nginx-${NGINX_VERSION}
RUN <<`
set -eux
CONFIGURE_ARGS=(
  --with-compat
)

for repo in ${GITHUB_REPOS_TO_CLONE}; do
  CONFIGURE_ARGS+=(--add-dynamic-module=../$(basename $repo))
done

./configure "${CONFIGURE_ARGS[@]}" --add-dynamic-module=../$(basename ${MODULE_REPO})
`

RUN make modules
RUN <<`
set -eux
mkdir -p /out
cp objs/${MODULE_NAME}.so /out/${MODULE_NAME}.so
tar -C /out -czf /out/${MODULE_NAME}.so.tgz ${MODULE_NAME}.so
`

FROM scratch
ARG MODULE_NAME
COPY --from=builder /out/${MODULE_NAME}.so /${MODULE_NAME}.so
COPY --from=builder /out/${MODULE_NAME}.so.tgz /${MODULE_NAME}.so.tgz
CMD ["sh"]
