# syntax=docker/dockerfile:1
FROM ubuntu:18.04
WORKDIR /app
COPY . .
RUN apt update -y && \
    apt install git -y && \
    apt install lua5.1 -y && \
    apt install luarocks -y && \
    apt install libssl-dev -y && \
    apt install m4 -y && \
    apt install liblua5.1-bitop0 -y && \
    apt install zlib1g-dev -y && \
    luarocks install http && \
    luarocks install lua-zlib
ENV LUA_PATH="/app/runtime/lua/?.lua;/app/runtime/lua/?/init.lua;;"
WORKDIR /app/src
CMD ["lua", "Server.lua"]
EXPOSE 8080/tcp