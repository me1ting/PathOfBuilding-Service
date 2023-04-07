# syntax=docker/dockerfile:1
FROM ubuntu:18.04
WORKDIR /app
COPY src/ ./src
COPY runtime/ ./runtime
RUN apt-get update -y && \
    apt-get install git -y && \
    apt-get install lua5.1 -y && \
    apt-get install luarocks -y && \
    apt-get install libssl-dev -y && \
    apt-get install m4 -y && \
    apt-get install liblua5.1-bitop0 -y && \
    apt-get install zlib1g-dev -y && \
    luarocks install http && \
    luarocks install lua-zlib
ENV LUA_PATH="/app/runtime/lua/?.lua;/app/runtime/lua/?/init.lua;;"
WORKDIR /app/src
CMD ["lua", "Server.lua"]
EXPOSE 8080/tcp