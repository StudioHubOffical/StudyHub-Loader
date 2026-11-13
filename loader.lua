-- StudyHub MultiJogos: carregamento autorizado pelo servidor.
assert(type(readfile)=="function" and type(writefile)=="function", "Executor sem arquivos locais")
if type(makefolder)=="function" then pcall(makefolder,"AriseStudyHub") end
local source=[=====[
-- Vykron Hub licensed loader. No Discord/GitHub/admin secrets belong in this file.
local resume = ...
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end
local env = getgenv()
local BASE = "https://api.vykronhub.com"
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
function Policy.savedKey(cache, gameId)
    if type(cache) ~= "table" then return nil end
    local candidates = {}
    local function add(value) if type(value) == "string" then table.insert(candidates, value) end end
    if type(cache.byGame) == "table" then add(cache.byGame[tostring(gameId)]) end
    if tostring(gameId) == "7074860883" then add(cache.key) end
    add(cache.lastKey) add(cache.key)
    for _, value in ipairs(candidates) do
        local key = value:gsub("%s", ""):upper()
        if key:match("^%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x$") then return key end
    end
    return nil
end
function Policy.silentStartup(cache, gameId)
    local key = Policy.savedKey(cache, gameId)
    return key ~= nil and type(cache.confirmedByGame) == "table"
        and cache.confirmedByGame[tostring(gameId)] == key
end
function Policy.bindingEpoch(cache, gameId, key)
    local bindings = type(cache) == "table" and cache.bindingsByGame
    local binding = type(bindings) == "table" and bindings[tostring(gameId)]
    local epoch = type(binding) == "table" and binding.key == key and binding.epoch
    if type(epoch) == "number" and epoch == math.floor(epoch) and epoch >= 1 and epoch < math.huge then return epoch end
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

-- LOADER SILENT-1
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "StudyHubKey", false, 11000
-- Decide whether to show before parenting: saved-key checks must not flash on screen.
gui.Enabled = false
gui.Parent = (gethui and gethui()) or player:WaitForChild("PlayerGui")
env.__StudyHubKeyGui = gui
local cyan = Color3.fromRGB(0, 213, 222)
local muted = Color3.fromRGB(140, 164, 183)
local function create(class, parent, props)
    local object = Instance.new(class)
    for k, v in pairs(props) do object[k] = v end
    object.Parent = parent
    return object
end
local function round(object, radius)
    create("UICorner", object, {CornerRadius = UDim.new(0, radius)})
end
local function artwork(parent, name, asset, x, y, width, height)
    return create("ImageLabel", parent, {Name = name, Image = "rbxassetid://" .. asset,
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 1, Active = false, Visible = true, ScaleType = Enum.ScaleType.Fit})
end
local function hideFallbackWhenLoaded(image, fallback)
    local function update() fallback.Visible = not image.IsLoaded end
    image:GetPropertyChangedSignal("IsLoaded"):Connect(update)
    update()
end
local panel = create("Frame", gui, {Size = UDim2.fromOffset(460, 460),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(7, 20, 33), BorderSizePixel = 0})
round(panel, 18)
create("UIStroke", panel, {Color = Color3.fromRGB(25, 98, 117), Thickness = 1, Transparency = 0.2})
local scale = create("UIScale", panel, {Scale = 1})
local function fit()
    local camera = workspace.CurrentCamera
    if camera then scale.Scale = math.max(0.1, math.min(1, (camera.ViewportSize.X - 24) / 460, (camera.ViewportSize.Y - 24) / 460)) end
end
fit()
local fitConnection = RunService.Heartbeat:Connect(fit)
gui.Destroying:Connect(function() fitConnection:Disconnect() end)
local function label(parent, value, x, y, width, height, size, color, bold)
    return create("TextLabel", parent, {Text = value, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height), BackgroundTransparency = 1,
        TextColor3 = color or Color3.fromRGB(232, 243, 249), TextSize = size,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham})
end
local logo = create("Frame", panel, {Position = UDim2.fromOffset(24, 23), Size = UDim2.fromOffset(44, 44),
    BackgroundColor3 = Color3.fromRGB(11, 43, 59), BorderSizePixel = 0})
round(logo, 10)
local logoFallback = label(logo, "S", 0, 0, 44, 44, 31, cyan, true)
local logoArt = artwork(logo, "StudyHubLogo", "128145399327530", 0, 0, 44, 44)
hideFallbackWhenLoaded(logoArt, logoFallback)
local title = label(panel, "VYKRON HUB", 82, 23, 210, 25, 21, nil, true)
title.TextXAlignment = Enum.TextXAlignment.Left
local subtitle = label(panel, "A C E S S O", 83, 49, 200, 15, 10, muted)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
local close = create("TextButton", panel, {Position = UDim2.fromOffset(403, 25), Size = UDim2.fromOffset(32, 32),
    Text = "×", TextSize = 25, Font = Enum.Font.Gotham, TextColor3 = muted,
    BackgroundColor3 = Color3.fromRGB(12, 34, 50), BorderSizePixel = 0})
round(close, 8)
close.Activated:Connect(function() gui:Destroy() end)
create("Frame", panel, {Position = UDim2.fromOffset(24, 83), Size = UDim2.fromOffset(412, 1),
    BackgroundColor3 = Color3.fromRGB(28, 58, 76), BorderSizePixel = 0})
local gameBadge = label(panel, game.GameId == 7074860883 and "ARISE CROSSOVER" or "VYKRON HUB · MULTIJOGOS", 130, 101, 200, 24, 11, cyan, true)
gameBadge.BackgroundTransparency = 0
gameBadge.BackgroundColor3 = Color3.fromRGB(10, 39, 52)
round(gameBadge, 6)
label(panel, "Bem-vindo à Vykron Hub", 24, 141, 412, 30, 23, nil, true)
label(panel, "Valide sua key para acessar a hub.", 24, 179, 412, 22, 13, muted)
local inputBox = create("Frame", panel, {Position = UDim2.fromOffset(24, 222), Size = UDim2.fromOffset(412, 52),
    BackgroundColor3 = Color3.fromRGB(12, 34, 51), BorderSizePixel = 0})
round(inputBox, 9)
create("UIStroke", inputBox, {Color = Color3.fromRGB(34, 73, 93), Thickness = 1})
local keyFallback = label(inputBox, "KEY", 10, 0, 38, 52, 10, cyan, true)
local keyArt = artwork(inputBox, "LicenseKeyIcon", "100690696575933", 14, 11, 30, 30)
hideFallbackWhenLoaded(keyArt, keyFallback)
local input = create("TextBox", inputBox, {Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -104, 1, 0),
    Text = "", PlaceholderText = "Cole sua key", ClearTextOnFocus = false,
    BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(232, 243, 249),
    PlaceholderColor3 = muted, TextSize = 14, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left})
-- Display-only mask: authentication always reads the unchanged TextBox.Text.
local mask = label(inputBox, "", 52, 0, 300, 52, 14)
mask.Size = input.Size
mask.TextXAlignment = Enum.TextXAlignment.Left
mask.Active, mask.ZIndex = false, input.ZIndex + 1
local eye = create("TextButton", inputBox, {Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 36),
    Text = "", BackgroundTransparency = 1})
local eyeOval = create("Frame", eye, {Position = UDim2.fromOffset(7, 11), Size = UDim2.fromOffset(22, 14),
    BackgroundTransparency = 1, BorderSizePixel = 0})
round(eyeOval, 12)
create("UIStroke", eyeOval, {Color = muted, Thickness = 1.5})
local pupil = create("Frame", eyeOval, {Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = muted, BorderSizePixel = 0})
round(pupil, 8)
local slash = create("Frame", eye, {Position = UDim2.fromOffset(4, 17), Size = UDim2.fromOffset(28, 2),
    Rotation = -40, BackgroundColor3 = cyan, BorderSizePixel = 0})
local preferences = readJson("AriseStudyHub/loader-ui.json") or {}
local hideKey = preferences.hideKey ~= false
local eyeOpenArt = artwork(eye, "ShowKeyIcon", "123741328806608", 2, 2, 32, 32)
local eyeHiddenArt = artwork(eye, "HideKeyIcon", "121852765919539", 2, 2, 32, 32)
local function updateKeyMask()
    input.TextTransparency = hideKey and 1 or 0
    mask.Visible = hideKey and #input.Text > 0
    mask.Text = string.rep("•", math.min(#input.Text, 24))
    eyeOpenArt.Visible, eyeHiddenArt.Visible = not hideKey, hideKey
    local loaded = (hideKey and eyeHiddenArt or eyeOpenArt).IsLoaded
    eyeOval.Visible = not loaded
    slash.Visible = hideKey and not loaded
end
input:GetPropertyChangedSignal("Text"):Connect(updateKeyMask)
eyeOpenArt:GetPropertyChangedSignal("IsLoaded"):Connect(updateKeyMask)
eyeHiddenArt:GetPropertyChangedSignal("IsLoaded"):Connect(updateKeyMask)
updateKeyMask()
local button = create("TextButton", panel, {Position = UDim2.fromOffset(24, 289), Size = UDim2.fromOffset(412, 48),
    Text = "VALIDAR E ENTRAR", Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = Color3.fromRGB(1, 24, 35), BackgroundColor3 = cyan, BorderSizePixel = 0})
round(button, 9)
local status = label(panel, "O prazo começa no primeiro uso da key.", 24, 347, 412, 37, 11, muted)
status.TextWrapped = true
eye.Activated:Connect(function()
    hideKey = not hideKey
    updateKeyMask()
    local saved = pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, "AriseStudyHub") end
        writefile("AriseStudyHub/loader-ui.json", Http:JSONEncode({hideKey = hideKey}))
    end)
    if not saved then status.Text = "Preferência aplicada nesta sessão; não foi possível salvar." end
end)
local discord = create("TextButton", panel, {Position = UDim2.fromOffset(156, 391), Size = UDim2.fromOffset(148, 28),
    Text = "", BackgroundTransparency = 1})
local discordArt = artwork(discord, "DiscordIcon", "134120255785711", 2, 0, 32, 28)
-- The uploaded asset has a public thumbnail even when raw image delivery is restricted.
discordArt.Image = "rbxthumb://type=Asset&id=134120255785711&w=150&h=150"
local discordCaption = label(discord, "Discord · Obter key", 0, 0, 148, 28, 13, cyan, true)
local function refreshDiscordIcon()
    local loaded = discordArt.IsLoaded == true
    discordArt.Visible = loaded
    discordCaption.Text = loaded and "Obter key" or "Discord · Obter key"
    discordCaption.Position = UDim2.fromOffset(loaded and 37 or 0, 0)
    discordCaption.Size = UDim2.fromOffset(loaded and 105 or 148, 28)
end
discordArt:GetPropertyChangedSignal("IsLoaded"):Connect(refreshDiscordIcon)
refreshDiscordIcon()
local DISCORD_INVITE = "https://discord.gg/g8bEFs2Pee"
discord.Activated:Connect(function()
    local opened = pcall(function() game:GetService("GuiService"):OpenBrowserWindow(DISCORD_INVITE) end)
    if opened then status.Text = "Convite do Discord aberto."
    elseif type(setclipboard) == "function" and pcall(setclipboard, DISCORD_INVITE) then
        status.Text = "Convite copiado. Cole no navegador ou no Discord."
    else status.Text = DISCORD_INVITE end
end)
label(panel, "Sua key salva será validada automaticamente.", 24, 426, 412, 16, 10, muted)
local function show(message)
    if not gui.Parent then return end
    gui.Enabled = true
    status.Text = message
    button.Text, button.Active = "VALIDAR E ENTRAR", true
end

local busy = false
local Controller = {}
Controller.__index = Controller
function Controller:isValid()
    return self.active and env.__StudyHubLicense == self and os.clock() < self.deadline
end
function Controller:attach(callback)
    assert(self:isValid(), "Licenca sem sessao valida")
    assert(type(callback) == "function", "Runtime sem encerramento valido")
    self.destroyHub = callback
    -- A runtime may keep running after registering its UI and cleanup handle.
    -- Readiness is independent from the return of the downloaded main function.
    if not self.ready then
        -- Only a runtime that actually registered may enable quiet future starts.
        -- This local preference never grants a license; every start still calls the server.
        pcall(function()
            local cache = readJson("AriseStudyHub/license.json")
            if type(cache) ~= "table" or Policy.savedKey(cache, game.GameId) ~= self.key then return end
            cache.confirmedByGame = type(cache.confirmedByGame) == "table" and cache.confirmedByGame or {}
            cache.confirmedByGame[tostring(game.GameId)] = self.key
            writefile("AriseStudyHub/license.json", Http:JSONEncode(cache))
        end)
    end
    self.ready = true
    gui.Enabled = false
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
    if type(reply.recuperacao) == "string" and #reply.recuperacao >= 64 and #reply.recuperacao <= 2048
        and reply.recuperacao:match("^R1%.") then self.recoveryProof = reply.recuperacao end
    if type(reply.vinculo) == "number" and reply.vinculo >= 1 and reply.vinculo < math.huge
        and reply.vinculo == math.floor(reply.vinculo) then self.bindingEpoch = reply.vinculo end
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
-- LOADER TRANSPORT: bounded waits, discarded late replies, no credentials in diagnostics.
local function loaderPresent()
    return gui.Parent ~= nil and env.__StudyHubKeyGui == gui
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
local function post(route, body, canContinue)
    local startedAt = os.clock()
    local done, abandoned, ok, response = false, false, nil, nil
    local worker = task.spawn(function()
        local success, value = pcall(requestHttp, {Url = BASE .. route, Method = "POST",
            Headers = {["Content-Type"] = "application/json", Accept = "application/json, text/plain"},
            Body = Http:JSONEncode(body)})
        if not abandoned then ok, response, done = success, value, true end
    end)
    while not done and os.clock() - startedAt < 40 and loaderPresent() and (not canContinue or canContinue()) do task.wait(0.1) end
    if not done then
        abandoned = true
        pcall(task.cancel, worker)
        return 0, {erro = "REDE_TIMEOUT"}, nil, startedAt
    end
    if not ok or type(response) ~= "table" then return 0, nil, nil, startedAt end
    local code = tonumber(response.StatusCode or response.Status) or 0
    local raw = response.Body
    local decoded
    if type(raw) == "string" then
        local parsed, value = pcall(function() return Http:JSONDecode(raw) end)
        if parsed and type(value) == "table" then decoded = value end
    end
    if code == 200 and route ~= "/v1/script" and type(decoded) ~= "table" then
        return 0, {erro = "RESPOSTA_INVALIDA"}, nil, startedAt
    end
    local headers = response.Headers or {}
    local retryAfter = tonumber(headers["Retry-After"] or headers["retry-after"])
    return code, decoded, raw, startedAt, retryAfter
end
-- END LOADER TRANSPORT
local messages = {
    KEY_INVALIDA = "Key invalida.", KEY_REVOGADA = "Key revogada.", KEY_EXPIRADA = "Sua key expirou.",
    DISPOSITIVO_INVALIDO = "Dispositivo ou vinculo alterado. Valide manualmente; para trocar de aparelho, use /resethwid no Discord.",
    SESSAO_INVALIDA = "Sessao invalidada ou servidor reiniciado. Valide a key novamente.",
    MUITAS_TENTATIVAS = "Muitas tentativas. Aguarde um minuto.",
    JOGO_NAO_SUPORTADO = "Este jogo ainda nao tem uma hub cadastrada e ativa.",
    HUB_SEM_ACESSO = "Sua key nao inclui acesso a esta hub. Consulte a equipe no Discord.",
    FALHA_AO_SALVAR = "O servidor nao conseguiu salvar. Tente novamente em instantes.",
    REDE_TIMEOUT = "O servidor demorou para responder. Tente validar novamente.",
    RESPOSTA_INVALIDA = "Resposta temporariamente invalida do servidor. Tente novamente.",
    RECUPERACAO_INVALIDA = "A confirmacao da sessao venceu ou mudou. Valide manualmente para continuar.",
    VALIDACAO_MANUAL = "Clique em Validar e entrar uma vez para confirmar o vinculo deste loader atualizado.",
}
local function problem(reply, fallback)
    return type(reply) == "table" and messages[reply.erro] or fallback
end
-- LOADER STARTUP: retry only transient failures, never expiry/revocation/device changes.
local function startupPost(route, body, canContinue)
    local began = os.clock()
    local stages = {["/v1/jogo"] = "Identificando o jogo", ["/v1/ativar"] = "Validando a key", ["/v1/script"] = "Carregando a hub"}
    local lastCode, lastReply, lastRaw, lastStart = 0, nil, nil, began
    local function allowed() return loaderPresent() and (not canContinue or canContinue()) end
    for attempt = 1, 3 do
        if not allowed() then break end
        env.__StudyHubLoaderStatus = {stage = route, attempt = attempt}
        status.Text = (stages[route] or "Conectando") .. " · tentativa " .. attempt .. "/3..."
        local code, reply, raw, started, retryAfter = post(route, body, allowed)
        lastCode, lastReply, lastRaw, lastStart = code, reply, raw, started
        if not allowed() then break end
        env.__StudyHubLoaderStatus.status = code
        if Policy.classify(code, reply) == "retry" then gui.Enabled = true end
        if Policy.classify(code, reply) ~= "retry" or attempt == 3 then return code, reply, raw, started end
        local pause = code == 429 and math.max(60, retryAfter or 60) or attempt * 3
        if os.clock() + pause - began >= 150 then break end
        local untilAt = os.clock() + pause
        while allowed() and os.clock() < untilAt do
            status.Text = "Conexao temporariamente indisponivel. Nova tentativa em " .. math.ceil(untilAt - os.clock()) .. " s..."
            task.wait(0.25)
        end
    end
    return lastCode, lastReply, lastRaw, lastStart
end
local function waitForGameReady()
    if game.GameId ~= 7074860883 then return true end
    local deadline = os.clock() + 90
    while loaderPresent() and os.clock() < deadline do
        local storage = game:GetService("ReplicatedStorage")
        local modules = storage:FindFirstChild("SharedModules")
        local indexer = storage:FindFirstChild("Indexer")
        local scripts = player:FindFirstChild("PlayerScripts")
        local ui = scripts and scripts:FindFirstChild("NewUI", true)
        local character = player.Character
        local enemies = modules and modules:FindFirstChild("Enemies")
        local ready = modules and modules:FindFirstChild("WeaponsModule") and modules:FindFirstChild("ClientData")
            and enemies and enemies:FindFirstChild("EnemyLocal") and storage:FindFirstChild("BridgeNet2")
            and indexer and indexer:FindFirstChild("StatsInfo") and indexer:FindFirstChild("BalanceInfo")
            and ui and ui:FindFirstChild("Screens") and character and character:FindFirstChild("HumanoidRootPart")
            and player:GetAttribute("Loaded") ~= false and not player.GameplayPaused
        if ready then return true end
        status.Text = "Aguardando o jogo e o personagem carregarem..."
        task.wait(0.5)
    end
    return false
end
-- END LOADER STARTUP
-- LOADER SESSION RECOVERY: never fall back to device-binding activation.
local function recoverSession(c)
    if type(c.recoveryProof) ~= "string" then
        c:stop("Atualize o servidor de keys e valide manualmente uma vez para habilitar a recuperacao automatica.")
        return false
    end
    for attempt = 1, 3 do
        if not c:isValid() then return false end
        local code, reply, _, began = post("/v1/recuperar", {key = c.key, userId = tostring(player.UserId),
            dispositivo = c.device, gameId = tostring(game.GameId), recuperacao = c.recoveryProof}, function() return c:isValid() end)
        if not c:isValid() then return false end
        if code == 200 and type(reply) == "table" and reply.protocolo == 2 and type(reply.hub) == "table"
            and reply.hub.id == (c.hubId or "arise") and c:accept(reply, began) then
            if c.ready then gui.Enabled = false end
            return true
        end
        if code == 404 then c:stop("Atualize o servidor de keys para habilitar a recuperacao automatica.") return false end
        if Policy.classify(code, reply) ~= "retry" then
            c:stop(problem(reply, "Nao foi possivel recuperar a sessao. Valide manualmente.")) return false
        end
        if attempt == 3 then break end
        local untilAt = os.clock() + (code == 429 and 60 or attempt * 3)
        while c:isValid() and os.clock() < untilAt do task.wait(0.25) end
    end
    if c:isValid() then c:stop("Nao foi possivel recuperar a sessao por falha de conexao. Tente novamente.") end
    return false
end
-- END LOADER SESSION RECOVERY

local function launch(key, automatic)
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
    if not waitForGameReady() then busy = false show("O jogo ainda nao terminou de carregar. Tente validar novamente.") return end
    local bindingEpoch = Policy.bindingEpoch(readJson("AriseStudyHub/license.json"), game.GameId, key)
    local resolveCode, resolved = startupPost("/v1/jogo", {gameId = tostring(game.GameId)})
    if resolveCode ~= 200 or type(resolved) ~= "table" or resolved.protocolo ~= 2 or type(resolved.hub) ~= "table" then
        busy = false
        show(problem(resolved, "Atualize o servidor para a versao MultiJogos ou tente novamente."))
        return
    end
    local code, reply, _, startedAt = startupPost("/v1/ativar", {key = key, userId = tostring(player.UserId), dispositivo = device, gameId = tostring(game.GameId), automatico = automatic == true, vinculoEsperado = bindingEpoch})
    if not gui.Parent then busy = false return end
    local c = setmetatable({active = true, deadline = 0, renewAt = 0, device = device,
        gameId = tostring(game.GameId), hubId = resolved.hub.id}, Controller)
    env.__StudyHubLicense = c
    c.key = key
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
                local httpCode, data, _, began = post("/v1/renovar", {sessao = c.token, dispositivo = device}, function() return c:isValid() end)
                if not c:isValid() then break end
                local result = Policy.classify(httpCode, data)
                if result == "success" and c:accept(data, began) then
                    -- Updated only by a confirmed response.
                elseif result == "retry" then c.renewAt = os.clock() + (httpCode == 429 and 60 or 10)
                elseif result == "reauth" then recoverSession(c)
                else c:stop(problem(data, "Falha na validacao da sessao. Valide sua key novamente.")) end
            end
        end
    end)
    status.Text = "Licenca validada. Carregando a hub..."
    local scriptCode, scriptReply, source = startupPost("/v1/script", {sessao = c.token, dispositivo = device}, function() return c:isValid() end)
    if c:isValid() and Policy.classify(scriptCode, scriptReply) == "reauth" and recoverSession(c) then
        scriptCode, scriptReply, source = startupPost("/v1/script", {sessao = c.token, dispositivo = device}, function() return c:isValid() end)
    end
    if not c:isValid() then busy = false return end
    if scriptCode ~= 200 then
        c:stop(problem(scriptReply, "Nao foi possivel baixar a hub. Verifique a conexao e tente novamente."))
        busy = false return
    end
    if type(source) ~= "string" or not source:find("-- STUDYHUB-LICENSED-1", 1, true) then
        c:stop("Publique o runtime licenciado no servidor. O codigo atual ainda nao e compativel.")
        busy = false return
    end
    -- Compile before executing. A failed download is retried, never executed partially.
    local fn, compileProblem
    for compileAttempt = 1, 3 do
        if not c:isValid() then busy = false return end
        local ok, result, diagnostic = pcall(loadstring, source, "StudyHubLicensed")
        if ok and type(result) == "function" then fn = result break end
        compileProblem = tostring(ok and diagnostic or result):sub(1, 1200)
        warn("[StudyHub] Runtime compile attempt " .. compileAttempt .. ": " .. compileProblem)
        pcall(function()
            writefile("AriseStudyHub/loader-error.json", Http:JSONEncode({stage = "compile", attempt = compileAttempt,
                placeId = game.PlaceId, gameId = game.GameId, utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                bytes = #source, message = compileProblem}))
        end)
        if compileAttempt >= 3 then break end
        local untilAt = os.clock() + compileAttempt * 5
        status.Text = "Falha ao compilar a hub. Baixando novamente · tentativa " .. (compileAttempt + 1) .. "/3…"
        while c:isValid() and os.clock() < untilAt do task.wait(0.25) end
        if not c:isValid() then busy = false return end
        scriptCode, scriptReply, source = startupPost("/v1/script", {sessao = c.token, dispositivo = device}, function() return c:isValid() end)
        if c:isValid() and Policy.classify(scriptCode, scriptReply) == "reauth" and recoverSession(c) then
            scriptCode, scriptReply, source = startupPost("/v1/script", {sessao = c.token, dispositivo = device}, function() return c:isValid() end)
        end
        if not c:isValid() then busy = false return end
        if scriptCode ~= 200 then c:stop(problem(scriptReply, "Falha ao baixar novamente a hub. Confira a conexao.")) busy = false return end
        if type(source) ~= "string" or not source:find("-- STUDYHUB-LICENSED-1", 1, true) then
            c:stop("Resposta recebida nao e um runtime licenciado. Confira a publicacao no servidor.") busy = false return
        end
    end
    if not fn then
        c:stop("A hub recebida continua com erro de compilacao apos 3 tentativas. Detalhes: AriseStudyHub/loader-error.json.")
        busy = false return
    end
    local saved = pcall(function()
        local cache = readJson("AriseStudyHub/license.json") or {}
        cache.byGame = type(cache.byGame) == "table" and cache.byGame or {}
        cache.byGame[tostring(game.GameId)] = key
        cache.lastKey = key
        if c.bindingEpoch then
            cache.bindingsByGame = type(cache.bindingsByGame) == "table" and cache.bindingsByGame or {}
            cache.bindingsByGame[tostring(game.GameId)] = {key = key, epoch = c.bindingEpoch}
        end
        if c.hubId == "arise" then cache.key = key end
        writefile("AriseStudyHub/license.json", Http:JSONEncode(cache))
    end)
    if not saved then c:stop("Nao foi possivel salvar a key para continuidade por teleporte.") busy = false return end
    -- Only needed by the hub's existing capability check. Never store the downloaded runtime locally.
    writefile("AriseStudyHub/Hub.luau", '-- Runtime servido exclusivamente pelo loader.\nerror("Use StudyHub_Loader.luau")')
    c.launchThread = task.spawn(function()
        local ok = pcall(fn)
        if not c.active then return end
        if c:isValid() then bindOriginal() end
        if not ok then
            c:stop("A hub nao iniciou corretamente. Confira o runtime publicado.")
        elseif c.ready and c:isValid() then gui.Enabled = false end
        if c.ready or not c.active then busy = false end
    end)
    task.delay(120, function()
        if c.active and not c.ready then c:stop("A inicializacao demorou demais. Tente novamente com o jogo carregado.") end
    end)
end
local function submit(automatic)
    local key = input.Text:gsub("%s", ""):upper()
    if not key:match("^%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x$") then
        show("Cole a key completa no formato XXXX-XXXX-XXXX-XXXX.") return
    end
    local ok = pcall(launch, key, automatic == true)
    if not ok then
        busy = false
        local c = env.__StudyHubLicense
        if c then c:stop("Falha ao carregar. Confira os arquivos locais e o servidor.")
        else show("Falha ao carregar. Confira os arquivos locais e o servidor.") end
    end
end
button.Activated:Connect(function() submit(false) end)
input.FocusLost:Connect(function(enter) if enter then submit() end end)
gui.Destroying:Connect(function()
    local c = env.__StudyHubLicense
    if c then c:stop(nil, true) end
end)
local cachedKey = Policy.savedKey(readJson("AriseStudyHub/license.json"), game.GameId)
gui.Enabled = not Policy.silentStartup(readJson("AriseStudyHub/license.json"), game.GameId)
if cachedKey then
    input.Text = cachedKey
    status.Text = "Key salva encontrada. Validando automaticamente..."
    task.defer(function() submit(true) end)
elseif resume == true then
    status.Text = "Nao foi possivel ler uma key salva. Cole a key para continuar."
end
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
