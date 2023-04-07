#@
-- This wrapper allows the program to run headless on any OS (in theory)
-- It can be run using a standard lua interpreter, although LuaJIT is preferable

local zlib = require "http.zlib"

-- Callbacks
local callbackTable = { }
local mainObject
function runCallback(name, ...)
        if callbackTable[name] then
                return callbackTable[name](...)
        elseif mainObject and mainObject[name] then
                return mainObject[name](mainObject, ...)
        end
end
function SetCallback(name, func)
        callbackTable[name] = func
end
function GetCallback(name)
        return callbackTable[name]
end
function SetMainObject(obj)
        mainObject = obj
end

-- Image Handles
local imageHandleClass = { }
imageHandleClass.__index = imageHandleClass
function NewImageHandle()
        return setmetatable({ }, imageHandleClass)
end
function imageHandleClass:Load(fileName, ...)
        self.valid = true
end
function imageHandleClass:Unload()
        self.valid = false
end
function imageHandleClass:IsValid()
        return self.valid
end
function imageHandleClass:SetLoadingPriority(pri) end
function imageHandleClass:ImageSize()
        return 1, 1
end

-- Rendering
function RenderInit() end
function GetScreenSize()
        return 1920, 1080
end
function SetClearColor(r, g, b, a) end
function SetDrawLayer(layer, subLayer) end
function SetViewport(x, y, width, height) end
function SetDrawColor(r, g, b, a) end
function DrawImage(imgHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom) end
function DrawImageQuad(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4) end
function DrawString(left, top, align, height, font, text) end
function DrawStringWidth(height, font, text)
        return 1
end
function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
        return 0
end
function StripEscapes(text)
        return text:gsub("%^%d",""):gsub("%^x%x%x%x%x%x%x","")
end
function GetAsyncCount()
        return 0
end

-- Search Handles
function NewFileSearch() end

-- General Functions
function SetWindowTitle(title) end
function GetCursorPos()
        return 0, 0
end
function SetCursorPos(x, y) end
function ShowCursor(doShow) end
function IsKeyDown(keyName) end
function Copy(text) end
function Paste() end
function Deflate(data)
        local deflater = zlib.deflate()
        return deflater(data, true)
end
function Inflate(data)
        local inflater = zlib.inflate()
        return inflater(data, true)
end
function GetTime()
        return 0
end
function GetScriptPath()
        return ""
end
function GetRuntimePath()
        return ""
end
function GetUserPath()
        return ""
end
function MakeDir(path) end
function RemoveDir(path) end
function SetWorkDir(path) end
function GetWorkDir()
        return ""
end
function LaunchSubScript(scriptText, funcList, subList, ...) end
function AbortSubScript(ssID) end
function IsSubScriptRunning(ssID) end
function LoadModule(fileName, ...)
        if not fileName:match("%.lua") then
                fileName = fileName .. ".lua"
        end
        local func, err = loadfile(fileName)
        if func then
                return func(...)
        else
                error("LoadModule() error loading '"..fileName.."': "..err)
        end
end
function PLoadModule(fileName, ...)
        if not fileName:match("%.lua") then
                fileName = fileName .. ".lua"
        end
        local func, err = loadfile(fileName)
        if func then
                return PCall(func, ...)
        else
                error("PLoadModule() error loading '"..fileName.."': "..err)
        end
end
function PCall(func, ...)
        local ret = { pcall(func, ...) }
        if ret[1] then
                table.remove(ret, 1)
                return nil, unpack(ret)
        else
                return ret[2]
        end
end
function ConPrintf(fmt, ...)
        -- Optional
        print(string.format(fmt, ...))
end
function ConPrintTable(tbl, noRecurse) end
function ConExecute(cmd) end
function ConClear() end
function SpawnProcess(cmdName, args) end
function OpenURL(url) end
function SetProfiling(isEnabled) end
function Restart() end
function Exit() end

local l_require = require
function require(name)
        -- Hack to stop it looking for lcurl, which we don't really need
        if name == "lcurl.safe" then
                return
        end
        return l_require(name)
end


dofile("Launch.lua")

-- Prevents loading of ModCache
-- Allows running mod parsing related tests without pushing ModCache
-- The CI env var will be true when run from github workflows but should be false for other tools using the headless wrapper 
mainObject.continuousIntegrationMode = os.getenv("CI") 

runCallback("OnInit")
runCallback("OnFrame") -- Need at least one frame for everything to initialise

if mainObject.promptMsg then
        -- Something went wrong during startup
        print(mainObject.promptMsg)
        io.read("*l")
        return
end

-- The build module; once a build is loaded, you can find all the good stuff in here
build = mainObject.main.modes["BUILD"]

-- Here's some helpful helper functions to help you get started
function newBuild()
        mainObject.main:SetMode("BUILD", false, "Help, I'm stuck in Path of Building!")
        runCallback("OnFrame")
end
function loadBuildFromXML(xmlText, name)
        mainObject.main:SetMode("BUILD", false, name or "", xmlText)
        runCallback("OnFrame")
end
function loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
        mainObject.main:SetMode("BUILD", false, "")
        runCallback("OnFrame")
        local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
        build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
        -- You now have a build without a correct main skill selected, or any configuration options set
        -- Good luck!
end

------------------ service
function jsonToXml(getItemsJSON, getPassiveSkillsJSON)
        loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
        return build:SaveDB("code")
end
------------------ http server
local port = 8080 -- 0 means pick one at random

local http_server = require "http.server"
local http_headers = require "http.headers"
local http_util = require "http.util"

local function reply(myserver, stream) -- luacheck: ignore 212
        -- Read in headers
        local req_headers = assert(stream:get_headers())
        local req_method = req_headers:get ":method"
        local req_path = req_headers:get(":path") or ""

        -- Log request to stdout
        assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"\n',
                os.date("%d/%b/%Y:%H:%M:%S %z"),
                req_method or "",
                req_path,
                stream.connection.version
        )))

        local res_headers = http_headers.new()

        -- Route request
        if req_method == "POST" then
                if req_path == "/jsonToXml" then
                        local body = stream:get_body_as_string(10)
                        local pairs = {}
                        for name,value in http_util.query_args(body) do
                                pairs[name] = value
                        end
                        local passiveSkills = pairs["passiveSkills"]
                        local items = pairs["items"]

                        passiveSkills = Inflate(common.base64.decode(passiveSkills:gsub("-","+"):gsub("_","/")))
                        items = Inflate(common.base64.decode(items:gsub("-","+"):gsub("_","/")))
                        local xmlText = jsonToXml(items, passiveSkills)
                        local xmlTextBase64 = common.base64.encode(Deflate(xmlText)):gsub("+","-"):gsub("/","_")

                        res_headers:append(":status","200")
                        assert(stream:write_headers(res_headers, false))
                        assert(stream:write_chunk(xmlTextBase64,true))
                        return
                end
        end

        res_headers:append(":status", "404")
        assert(stream:write_headers(res_headers, true))
end

local myserver = assert(http_server.listen {
        host = "0.0.0.0";
        port = port;
        onstream = reply;
        onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
                local msg = op .. " on " .. tostring(context) .. " failed"
                if err then
                        msg = msg .. ": " .. tostring(err)
                end
                assert(io.stderr:write(msg, "\n"))
        end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(myserver:listen())
do
        local bound_port = select(3, myserver:localname())
        assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end
-- Start the main server loop
assert(myserver:loop())