-- StudyHub MultiJogos: carregamento autorizado pelo servidor.
assert(type(readfile)=="function" and type(writefile)=="function", "Executor sem arquivos locais")
if type(makefolder)=="function" then pcall(makefolder,"AriseStudyHub") end
local source=[=====[
-- Study Hub licensed loader. No Discord/GitHub/admin secrets belong in this file.
local resume = ...
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end
local env = getgenv()
local BASE = "https://key-server-9pry.onrender.com"
local Policy = (function()
local Policy = {}
function Policy.accept(reply, startedAt, now)
    if type(reply) ~= "table" or reply.ok ~= true or type(reply.sessao) ~= "string"
        or #reply.sessao < 16 or #reply.sessao > 100 then return nil end
    local remaining = reply.sessaoRestanteMs
    if type(remaining) ~= "number" or remaining ~= remaining or remaining <= 0 or remaining > 180000 then return nil end
    local license = reply.licencaRestanteMs
    if license ~= nil then
        if type(license) ~= "number" or license ~= license or license <= 0 or license == math.huge then return nil end
        remaining = math.min(remaining, license)
    end
    -- Count from request dispatch, conservatively accounting for time spent in transit.
    local deadline = startedAt + remaining / 1000
    if deadline <= now then return nil end
    return {token = reply.sessao, deadline = deadline,
        licenseDeadline = license and (startedAt + license / 1000) or nil,
        licensePermanent = license == nil,
        renewAt = math.min(now + 60, deadline - 1)}
end
function Policy.classify(status, reply)
    local code = type(reply) == "table" and reply.erro or nil
    if code == "SESSAO_INVALIDA" then return "reauth" end
    if code == "KEY_INVALIDA" or code == "KEY_EXPIRADA" or code == "KEY_REVOGADA"
        or code == "DISPOSITIVO_INVALIDO" then return "stop" end
    if status == 200 then return "success" end
    if status == 0 or status == 429 or status >= 500 then return "retry" end
    return "stop"
end
return Policy

end)()
local bootstrap = [====[
local userId, resume, originGameId = ...
if not game:IsLoaded() then game.Loaded:Wait() end
local player = game:GetService("Players").LocalPlayer
while not player do task.wait() player = game:GetService("Players").LocalPlayer end
if player.UserId ~= userId then return nil end
originGameId = tostring(originGameId or game.GameId)
local env = getgenv()
local function enabled()
    local path = originGameId == "7074860883" and ("AriseStudyHub/" .. userId .. ".json")
        or ("AriseStudyHub/Profiles/" .. originGameId .. "_" .. userId .. ".json")
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" or data.userId ~= userId then return false end
    local h = data.houses
    local guildReturn = originGameId == "7074860883" and type(data.guild) == "table" and type(data.guild.journey) == "table"
        and data.guild.journey.phase == "return" and type(data.guild.journey.nextWorld) == "number"
        and data.guild.journey.nextWorld >= 1 and data.guild.journey.nextWorld <= 3
    return data.autoExecute == true or guildReturn or (originGameId == "7074860883" and type(h) == "table"
        and h.enabled == true and type(h.route) == "table" and type(h.route.nextWorld) == "number"
        and h.route.nextWorld >= 1 and h.route.nextWorld <= 3)
end
if not enabled() then return nil end
local old = env.__AriseAutoSession
if old and old.version == "multi-1" and old.originGameId == originGameId then return old end
if old and old.connection then old.connection:Disconnect() end
local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
if type(queue) ~= "function" then return nil end
local session = {version = "multi-1", originGameId = originGameId, queued = false}
env.__AriseAutoSession = session
function session.arm()
    if session.queued or not enabled() then return end
    local auth = env.__StudyHubLicense
    if auth and not auth:isValid() then return end
    local source = string.format('assert(loadstring(readfile("AriseStudyHub/AutoExecute.luau")))(%s, true, %q)', tostring(userId), originGameId)
    local ok, problem = pcall(queue, source)
    session.queued, session.problem = ok, not ok and tostring(problem) or nil
end
session.arm()
session.connection = player.OnTeleport:Connect(function(status)
    if status == Enum.TeleportState.Failed then session.queued = false session.arm() return end
    if status == Enum.TeleportState.Started then
        if session.beforeTeleport then session.beforeTeleport() end
        session.arm()
    end
end)
if resume and env.__StudyHubResumeJob ~= game.JobId then
    env.__StudyHubResumeJob = game.JobId
    local ok, problem = pcall(function()
        assert(loadstring(readfile("AriseStudyHub/Loader.luau")))(true)
    end)
    if not ok then warn("[StudyHub] Nao foi possivel abrir o loader: " .. tostring(problem)) end
end
return session
]====]
local requestHttp = request or http_request or (syn and syn.request) or (http and http.request)
local function readJson(path)
    local ok, value = pcall(function() return Http:JSONDecode(readfile(path)) end)
    return ok and type(value) == "table" and value or nil
end
local function validDevice(s)
    return type(s) == "string" and #s >= 32 and #s <= 128 and not s:find("[^%w_-]")
end
local function getDevice()
    local path = "AriseStudyHub/device.txt"
    local ok, value = pcall(readfile, path)
    if ok and validDevice(value) then return value end
    -- Do not silently replace an existing invalid identifier: that would trigger a new binding.
    if ok then error("Arquivo de dispositivo invalido. Restaure o arquivo ou use /resethwid.") end
    local valueNew = (Http:GenerateGUID(false) .. Http:GenerateGUID(false)):gsub("-", "")
    assert(validDevice(valueNew), "Falha ao gerar identificador")
    writefile(path, valueNew)
    assert(readfile(path) == valueNew, "Nao foi possivel salvar o dispositivo")
    return valueNew
end
local old = env.__StudyHubLicense
if old and type(old.stop) == "function" then old:stop(nil, true) end
local previousOther = env.__StudyHubRuntime
if previousOther and type(previousOther.destroy) == "function" then pcall(previousOther.destroy) end
local previous = env.__AriseStudyHub
if previous and type(previous.destroy) == "function" then pcall(previous.destroy) end
local previousAuto = env.__AriseAutoSession
if previousAuto and previousAuto.connection then previousAuto.connection:Disconnect() end
env.__AriseAutoSession = nil
local oldUI = env.__StudyHubKeyGui
if oldUI then pcall(function() oldUI:Destroy() end) end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "StudyHubKey", false, 11000
gui.Parent = (gethui and gethui()) or player:WaitForChild("PlayerGui")
env.__StudyHubKeyGui = gui
local panel = Instance.new("Frame")
panel.Size, panel.Position, panel.AnchorPoint = UDim2.fromOffset(370, 240), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
panel.BackgroundColor3, panel.BorderSizePixel, panel.Parent = Color3.fromRGB(8, 20, 31), 0, gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local scale = Instance.new("UIScale", panel)
local function fit()
    local camera = workspace.CurrentCamera
    if camera then scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 370, (camera.ViewportSize.Y - 24) / 240) end
end
fit()
local function text(class, y, height, value)
    local item = Instance.new(class)
    item.Size, item.Position = UDim2.new(1, -32, 0, height), UDim2.fromOffset(16, y)
    item.BackgroundTransparency, item.TextColor3 = 1, Color3.fromRGB(230, 240, 246)
    item.Font, item.TextSize, item.Text, item.Parent = Enum.Font.Gotham, 14, value, panel
    return item
end
local title = text("TextLabel", 14, 30, "STUDY HUB  |  ACESSO")
title.Font = Enum.Font.GothamBold
local input = text("TextBox", 57, 42, "")
input.PlaceholderText, input.ClearTextOnFocus, input.BackgroundTransparency = "Cole sua key", false, 0
input.BackgroundColor3 = Color3.fromRGB(15, 35, 50)
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 7)
local button = text("TextButton", 111, 40, "VALIDAR KEY")
button.BackgroundTransparency, button.BackgroundColor3 = 0, Color3.fromRGB(0, 173, 184)
button.Font = Enum.Font.GothamBold
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
local status = text("TextLabel", 159, 61, "O prazo comeca no primeiro uso. Reset de dispositivo pelo Discord.")
status.TextWrapped, status.TextSize = true, 12
local function show(message)
    if not gui.Parent then return end
    gui.Enabled = true
    status.Text = message
    button.Text, button.Active = "VALIDAR KEY", true
end
local busy = false
local Controller = {}
Controller.__index = Controller
function Controller:isValid()
    return self.active and env.__StudyHubLicense == self and os.clock() < self.deadline
end
function Controller:attach(callback)
    assert(self:isValid(), "Licenca sem sessao valida")
    self.destroyHub = callback
end
function Controller:hubClosed()
    self:stop(nil, true)
end
function Controller:stop(message, silent)
    if not self.active then return end
    self.active = false
    busy = false
    if self.watch then self.watch:Disconnect() end
    local session = env.__AriseAutoSession
    if session and session.connection then session.connection:Disconnect() end
    env.__AriseAutoSession = nil
    if self.launchThread and self.launchThread ~= coroutine.running() then pcall(task.cancel, self.launchThread) end
    local callback = self.destroyHub
    self.destroyHub = nil
    if callback then pcall(callback) end
    if env.__StudyHubLicense == self then env.__StudyHubLicense = nil end
    -- Keep profile settings unchanged; expire only the current execution.
    if not silent then show(message or "Sessao encerrada. Valide a key novamente.") end
end
function Controller:accept(reply, startedAt)
    if not self.active or env.__StudyHubLicense ~= self then return false end
    local timing = Policy.accept(reply, startedAt, os.clock())
    if not timing then return false end
    self.token, self.deadline, self.renewAt = timing.token, timing.deadline, timing.renewAt
    self.licenseDeadline, self.licensePermanent = timing.licenseDeadline, timing.licensePermanent
    return true
end
function Controller:getLicenseRemaining()
    if not self:isValid() then return 0, "expired" end
    if self.licensePermanent then return nil, "permanent" end
    if type(self.licenseDeadline) == "number" then
        return math.max(0, self.licenseDeadline - os.clock()), "timed"
    end
    return nil, "unknown"
end
function Controller:setAutoExecute(enabled)
    if self.hubId == "arise" then error("Use a opcao Misc da hub Arise") end
    assert(self:isValid(), "Sessao encerrada")
    assert(type(enabled) == "boolean", "Opcao invalida")
    if type(makefolder) == "function" then pcall(makefolder, "AriseStudyHub/Profiles") end
    local path = "AriseStudyHub/Profiles/" .. self.gameId .. "_" .. player.UserId .. ".json"
    local profile = readJson(path) or {}
    profile.userId, profile.autoExecute = player.UserId, enabled
    writefile(path, Http:JSONEncode(profile))
    if enabled then
        return assert(loadstring(readfile("AriseStudyHub/AutoExecute.luau")))(player.UserId, false, self.gameId)
    end
    local oldSession = env.__AriseAutoSession
    if oldSession and oldSession.connection then oldSession.connection:Disconnect() end
    env.__AriseAutoSession = nil
end
local function post(route, body)
    local startedAt = os.clock()
    local ok, response = pcall(requestHttp, {Url = BASE .. route, Method = "POST",
        Headers = {["Content-Type"] = "application/json", Accept = "application/json, text/plain"},
        Body = Http:JSONEncode(body)})
    if not ok or type(response) ~= "table" then return 0, nil, nil, startedAt end
    local code = tonumber(response.StatusCode or response.Status) or 0
    local raw = response.Body
    local decoded
    if type(raw) == "string" then
        local parsed, value = pcall(function() return Http:JSONDecode(raw) end)
        if parsed and type(value) == "table" then decoded = value end
    end
    return code, decoded, raw, startedAt
end
local messages = {
    KEY_INVALIDA = "Key invalida.", KEY_REVOGADA = "Key revogada.", KEY_EXPIRADA = "Sua key expirou.",
    DISPOSITIVO_INVALIDO = "Key vinculada a outro dispositivo. Use /resethwid no Discord.",
    SESSAO_INVALIDA = "Sessao invalidada ou servidor reiniciado. Valide a key novamente.",
    MUITAS_TENTATIVAS = "Muitas tentativas. Aguarde um minuto.",
    JOGO_NAO_SUPORTADO = "Este jogo ainda nao tem uma hub cadastrada e ativa.",
    HUB_SEM_ACESSO = "Sua key nao inclui acesso a esta hub. Consulte a equipe no Discord.",
    FALHA_AO_SALVAR = "O servidor nao conseguiu salvar. Tente novamente em instantes.",
}
local function problem(reply, fallback)
    return type(reply) == "table" and messages[reply.erro] or fallback
end
local function launch(key)
    if busy then return end
    busy = true
    button.Text, button.Active = "VALIDANDO...", false
    status.Text = "Conectando ao servidor de licencas..."
    local setupOK, setup = pcall(function()
        assert(type(requestHttp) == "function", "Executor sem suporte a requisicoes POST.")
        assert(type(readfile) == "function" and type(writefile) == "function", "Executor sem arquivos locais.")
        if type(makefolder) == "function" then pcall(makefolder, "AriseStudyHub") end
        writefile("AriseStudyHub/AutoExecute.luau", bootstrap)
        local oldAuto = env.__AriseAutoSession
        if oldAuto and oldAuto.connection then oldAuto.connection:Disconnect() end
        env.__AriseAutoSession = nil
        return getDevice()
    end)
    if not setupOK then busy = false show(tostring(setup)) return end
    local device = setup
    local resolveCode, resolved = post("/v1/jogo", {gameId = tostring(game.GameId)})
    if resolveCode ~= 200 or type(resolved) ~= "table" or resolved.protocolo ~= 2 or type(resolved.hub) ~= "table" then
        busy = false
        show(problem(resolved, "Atualize o servidor para a versao MultiJogos ou tente novamente."))
        return
    end
    local code, reply, _, startedAt = post("/v1/ativar", {key = key, userId = tostring(player.UserId), dispositivo = device, gameId = tostring(game.GameId)})
    if not gui.Parent then busy = false return end
    local c = setmetatable({active = true, deadline = 0, renewAt = 0, device = device,
        gameId = tostring(game.GameId), hubId = resolved.hub.id}, Controller)
    env.__StudyHubLicense = c
    if code ~= 200 or type(reply) ~= "table" or reply.protocolo ~= 2 or type(reply.hub) ~= "table"
        or reply.hub.id ~= c.hubId or not c:accept(reply, startedAt) then
        c:stop(problem(reply, "Nao foi possivel validar. Verifique o servidor e tente novamente."))
        busy = false return
    end
    local function bindOriginal()
        local slot = c.hubId == "arise" and "__AriseStudyHub" or "__StudyHubRuntime"
        local hub = env[slot]
        if hub and type(hub.destroy) == "function" and not c.boundHub then
            c.boundHub, c.hubSlot = hub, slot
            c:attach(function() hub.destroy() end)
        end
    end
    c.watch = RunService.Heartbeat:Connect(function()
        if c.boundHub and env[c.hubSlot] ~= c.boundHub then c:stop(nil, true) return end
        if c:isValid() then bindOriginal() end
        if not c:isValid() then c:stop("Autorizacao vencida sem renovacao. Valide sua key novamente.") end
    end)
    -- Network renewal runs separately; a blocked request cannot block the deadline watchdog.
    task.spawn(function()
        while c.active do
            task.wait(0.25)
            if not c:isValid() then break end
            if os.clock() >= c.renewAt then
                local httpCode, data, _, began = post("/v1/renovar", {sessao = c.token, dispositivo = device})
                if not c:isValid() then break end
                local result = Policy.classify(httpCode, data)
                if result == "success" and c:accept(data, began) then
                    -- Updated only by a confirmed response.
                elseif result == "retry" then c.renewAt = os.clock() + (httpCode == 429 and 60 or 10)
                else c:stop(problem(data, "Falha na validacao da sessao. Valide sua key novamente.")) end
            end
        end
    end)
    status.Text = "Licenca validada. Carregando a hub..."
    local scriptCode, scriptReply, source = post("/v1/script", {sessao = c.token, dispositivo = device})
    if not c:isValid() then busy = false return end
    if scriptCode ~= 200 or type(source) ~= "string" or not source:find("-- STUDYHUB-LICENSED-1", 1, true) then
        c:stop(problem(scriptReply, "Publique o runtime licenciado no servidor. O codigo atual ainda nao e compativel."))
        busy = false return
    end
    local fn = loadstring(source, "StudyHubLicensed")
    if not fn then c:stop("O script recebido tem erro de compilacao.") busy = false return end
    local saved = pcall(function()
        local cache = readJson("AriseStudyHub/license.json") or {}
        cache.byGame = type(cache.byGame) == "table" and cache.byGame or {}
        cache.byGame[tostring(game.GameId)] = key
        cache.lastKey = key
        if c.hubId == "arise" then cache.key = key end
        writefile("AriseStudyHub/license.json", Http:JSONEncode(cache))
    end)
    if not saved then c:stop("Nao foi possivel salvar a key para continuidade por teleporte.") busy = false return end
    -- Only needed by the hub's existing capability check. Never store the downloaded runtime locally.
    writefile("AriseStudyHub/Hub.luau", '-- Runtime servido exclusivamente pelo loader.\nerror("Use StudyHub_Loader.luau")')
    c.launchThread = task.spawn(function()
        local ok = pcall(fn)
        if not c.active then return end
        if ok and c:isValid() then bindOriginal() end
        if not ok or not c.destroyHub then
            c:stop("A hub nao iniciou corretamente. Confira o runtime publicado.")
        elseif c:isValid() then gui.Enabled = false end
        busy = false
    end)
    task.delay(120, function()
        if c.active and gui.Enabled then c:stop("A inicializacao demorou demais. Tente novamente com o jogo carregado.") end
    end)
end
local function submit()
    local key = input.Text:gsub("%s", ""):upper()
    if not key:match("^%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x$") then
        show("Cole a key completa no formato XXXX-XXXX-XXXX-XXXX.") return
    end
    local ok = pcall(launch, key)
    if not ok then
        busy = false
        local c = env.__StudyHubLicense
        if c then c:stop("Falha ao carregar. Confira os arquivos locais e o servidor.")
        else show("Falha ao carregar. Confira os arquivos locais e o servidor.") end
    end
end
button.Activated:Connect(submit)
input.FocusLost:Connect(function(enter) if enter then submit() end end)
gui.Destroying:Connect(function()
    local c = env.__StudyHubLicense
    if c then c:stop(nil, true) end
end)
local cached = readJson("AriseStudyHub/license.json")
local cachedKey = cached and type(cached.byGame) == "table" and cached.byGame[tostring(game.GameId)]
if not cachedKey and game.GameId == 7074860883 then cachedKey = cached and cached.key end
if not cachedKey then cachedKey = cached and (cached.lastKey or cached.key) end
if type(cachedKey) == "string" then input.Text = cachedKey end
if resume == true and type(cachedKey) == "string" then task.spawn(submit) end
]=====]
writefile("AriseStudyHub/Loader.luau",source)
writefile("AriseStudyHub/AutoExecute.luau",[====[
local userId, resume, originGameId = ...
if not game:IsLoaded() then game.Loaded:Wait() end
local player = game:GetService("Players").LocalPlayer
while not player do task.wait() player = game:GetService("Players").LocalPlayer end
if player.UserId ~= userId then return nil end
originGameId = tostring(originGameId or game.GameId)
local env = getgenv()
local function enabled()
    local path = originGameId == "7074860883" and ("AriseStudyHub/" .. userId .. ".json")
        or ("AriseStudyHub/Profiles/" .. originGameId .. "_" .. userId .. ".json")
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" or data.userId ~= userId then return false end
    local h = data.houses
    local guildReturn = originGameId == "7074860883" and type(data.guild) == "table" and type(data.guild.journey) == "table"
        and data.guild.journey.phase == "return" and type(data.guild.journey.nextWorld) == "number"
        and data.guild.journey.nextWorld >= 1 and data.guild.journey.nextWorld <= 3
    return data.autoExecute == true or guildReturn or (originGameId == "7074860883" and type(h) == "table"
        and h.enabled == true and type(h.route) == "table" and type(h.route.nextWorld) == "number"
        and h.route.nextWorld >= 1 and h.route.nextWorld <= 3)
end
if not enabled() then return nil end
local old = env.__AriseAutoSession
if old and old.version == "multi-1" and old.originGameId == originGameId then return old end
if old and old.connection then old.connection:Disconnect() end
local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
if type(queue) ~= "function" then return nil end
local session = {version = "multi-1", originGameId = originGameId, queued = false}
env.__AriseAutoSession = session
function session.arm()
    if session.queued or not enabled() then return end
    local auth = env.__StudyHubLicense
    if auth and not auth:isValid() then return end
    local source = string.format('assert(loadstring(readfile("AriseStudyHub/AutoExecute.luau")))(%s, true, %q)', tostring(userId), originGameId)
    local ok, problem = pcall(queue, source)
    session.queued, session.problem = ok, not ok and tostring(problem) or nil
end
session.arm()
session.connection = player.OnTeleport:Connect(function(status)
    if status == Enum.TeleportState.Failed then session.queued = false session.arm() return end
    if status == Enum.TeleportState.Started then
        if session.beforeTeleport then session.beforeTeleport() end
        session.arm()
    end
end)
if resume and env.__StudyHubResumeJob ~= game.JobId then
    env.__StudyHubResumeJob = game.JobId
    local ok, problem = pcall(function()
        assert(loadstring(readfile("AriseStudyHub/Loader.luau")))(true)
    end)
    if not ok then warn("[StudyHub] Nao foi possivel abrir o loader: " .. tostring(problem)) end
end
return session
]====])
assert(readfile("AriseStudyHub/Loader.luau")==source,"Falha ao salvar loader")
assert(loadstring(source))(false)
