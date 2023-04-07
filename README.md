# PathOfBuildingServer
Http server of [PathOfBuilding](https://github.com/PathOfBuildingCommunity/PathOfBuilding).

# Usage
## docker
[docker](https://docs.docker.com/engine/install/) is required:
```bash
cd ~
git clone https://github.com/me1ting/PathOfBuildingServer.git
cd ~/PathOfBuildingServer
sudo docker build -t pob-server .
sudo docker run -dp 8000:8080 pob-server
```
The container needs at least **300M** memory to run.

# Provide
**transform poe json data to pob xml data**

http `post` the `compressed encoded replaced` json data to `/jsonToXml` with raw format:
```js
//TODO: add code
```

**more feature**

Change `src/Server.lua` for your purpose.