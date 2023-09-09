function widget:GetInfo()
	return {
		name = "Ignore List API", --version 4.1.2
		desc = "Adds privacy functions which allow players to restrict incoming communication during the game.\n/ignoreplayer <name>\n/unignoreplayer <name>\n/ignorelist\n/dnd <off, on, delay>\n/dndpings <true, false>\n/dndpostgame <true, false>\n/dndwhitelist <add,remove, clear, leave blank to view list> <player names (full or partial)>",
		author = "Bluestone (DND edit by Soybeen)", -- options suite by Citrine
		date = "created June 2014 (edited September 2023)",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, --enabled by default
		handler = true, --can use widgetHandler:x()
	}
end

--[[
NOTE: This widget will block map draw commands from ignored players.
      It is up to the chat console widget to check WG.ignoredPlayers[playerName] and block chat
]]


local pID_table = {}
local ignoredPlayers = {}
local dndWhitelist = {}

local myName = select(1,Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false))
local isSpec = Spring.GetSpectatingState()

local specColStr = "\255\255\255\1"
local whiteStr = "\255\255\255\1"

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

local game_progress = 0 -- 0 preload, 1 start, 2 over
local game_started = false -- true once the first frame is processed by the :GameFrame() callin

local config = {
	doNotDisturb = "off", -- < off, on, delay > off: disable DND mode | on: block all incoming communication | delay: DND disabled during pregame setup, enabled after :GameStart()
	allowPings = false, -- only affects map draw commands if doNotDisturb is enabled, pings from directly ignored players will still always be hidden
	allowPostGame = false,
	dndwhitelist = {},
--	showSelf = true,
}

local DND_PREFERENCE = {"off","on","delay"}



-- DND Functions -- Soybeen was here

function CheckAllowPings()
	return config.allowPings
end

function CheckLocalGameOver()
	return isSpec or game_progress >= 2
end

function CheckAllowPostGame()
	return config.allowPostGame and CheckLocalGameOver()
end

function CheckShowSelf()
	return config.showSelf
end

function CheckDND()
	return config.doNotDisturb
end

function AddDNDWhitelist(pID)
	dndWhitelist[pID] = true
end

function RemoveDNDWhitelist(pID)
	dndWhitelist[pID] = nil
end

function EchoDNDWhitelist(pID)
	local str = "DND Whitelist:\n"
	for pID,_ in pairs(dndWhitelist) do
		str = str..pID.."  "
	end
	Spring.Echo(str)
end

function DNDShouldApply()
	local dnd = CheckDND()
	if dnd == "on" then
		return true
	elseif dnd == "delay" then
		return game_started
	elseif dnd == "off" then
		return false
	end
end

-- PID & Color Setup --
 
function CheckPIDs()
	local playerList = Spring.GetPlayerList()
	for _, pID in ipairs(playerList) do
		pID_table[select(1, Spring.GetPlayerInfo(pID, false))] = pID
	end
end

function colourPlayer(playerName)
	local playerID = pID_table[playerName]
	if not playerID then
		return whiteStr
	end

	local _, _, spec, teamID = Spring.GetPlayerInfo(playerID, false)
	if spec then
		return specColStr
	end
	local nameColourR, nameColourG, nameColourB, _ = Spring.GetTeamColor(teamID)
	if (not isSpec) and anonymousMode ~= "disabled" then
		nameColourR, nameColourG, nameColourB = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end
	local R255 = math.floor(nameColourR * 255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
	local G255 = math.floor(nameColourG * 255)
	local B255 = math.floor(nameColourB * 255)
	if R255 % 10 == 0 then
		R255 = R255 + 1
	end
	if G255 % 10 == 0 then
		G255 = G255 + 1
	end
	if B255 % 10 == 0 then
		B255 = B255 + 1
	end
	return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255) --works thanks to zwzsg
end

--Ignore Functions--

function ignoreList ()
	if next(ignoredPlayers) then
		Spring.Echo("Ignored players:")
		for playerName, _ in pairs(ignoredPlayers) do
			Spring.Echo(colourPlayer(playerName) .. playerName)
		end
	else
		Spring.Echo("No ignored players")
	end
end

function UpdateGlobalIgnoreList()
	local list
	if DNDShouldApply() then
		if CheckAllowPostGame() then
			list = ignoredPlayers
		else
			pID_table_filtered = {}
			for playerName,_ in pairs(pID_table) do
				if (playerName ~= myName) and not dndWhitelist[playerName] then
					pID_table_filtered[playerName] = true
				end
			end
			list = pID_table_filtered
		end
	else
		list = ignoredPlayers
	end

	WG['ignoredPlayers'] = list
end

function IgnorePlayer (playerName)
	if playerName == myName then
		Spring.Echo("You cannot ignore yourself")
		return
	end

	ignoredPlayers[playerName] = true
	UpdateGlobalIgnoreList()
	Spring.Echo("Ignored " .. colourPlayer(playerName) .. playerName)
end

function UnignorePlayer (playerName)
	ignoredPlayers[playerName] = nil
	UpdateGlobalIgnoreList()
	Spring.Echo("Un-ignored " .. colourPlayer(playerName) .. playerName)
end

function UnignoreAll()
	if next(ignoredPlayers) then
		local text = "Un-ignored "
		for playerName, _ in pairs(ignoredPlayers) do
			text = text .. colourPlayer(playerName) .. playerName .. ", "
		end
		text = string.sub(text, 1, string.len(text) - 2) --remove final ", "
		Spring.Echo(text)
	else
		Spring.Echo("No players to unignore")
	end

	ignoredPlayers = {}
	UpdateGlobalIgnoreList()
end


function widget:PlayerChanged()
	isSpec = Spring.GetSpectatingState()
	CheckPIDs()
	UpdateGlobalIgnoreList()
end

-- Options Suite -- Soybeen was here, options suite by Citrine

local OPTION_SPECS = {
	{
		configVariable = "doNotDisturb",
		name = "Do Not Disturb",
		description = "Disables incoming chats, pings, and map drawings from other players.\noff: DND disabled\non: DND enabled\ndelay: DND temporarily disabled until the game starts",
		type = "select",
		options = DND_PREFERENCE
	},

	{
		configVariable = "allowPings",
		name = "Allow Mapmarks in DND",
		description = "Allow pings and drawings from other players while DND is enabled",
		type = "bool",
	},

	{
		configVariable = "allowPostGame",
		name = "Allow Post Game Chat in DND",
		description = "Temporarily allows communication after :GameOver() and when becoming a spectator, even if DND is enabled.",
		type = "bool",
	},

	-- {
	-- 	configVariable = "dndWhitelist",
	-- 	name = "DND Whitelist",
	-- 	description = "Allow whitelisted players to bypass your DND preferences. View and edit your whitelist with this command:\n/dndwhitelist <'add','remove', or leave blank to view> <player name(s)>"",
	-- 	type = "bool",
	-- },

	-- {
	-- 	configVariable = "showSelf",
	-- 	name = "Hide Your Own Communication",
	-- 	description = "Hides your own chat messages and mapmarks from yourself while DND is enabled.\n(please note that your chat and mapmarks will still be seen by other players regardless of your DND status)",
	-- 	type = "bool",
	-- },
	-- {
	--   configVariable = "hidePlayerNames",
	--   name = "Hide Player Names",
	--   description = "Hides player names from commanders and several UI elements",
	--   type = "bool",
	-- },

}

local function getOptionId(optionSpec)
	return "ignore_list_api__" .. optionSpec.configVariable
end

local function getWidgetName()
	return "Ignore List API"
end

local function getOptionSpecByName(str)
	for k,optionSpec in ipairs(OPTION_SPECS) do
		if optionSpec['name'] == str then
			return OPTION_SPECS[k]
		end
	end
end

local function getOptionValue(optionSpec)
	if optionSpec.type == "slider" then
		return config[optionSpec.configVariable]
	elseif optionSpec.type == "bool" then
		return config[optionSpec.configVariable]
	elseif optionSpec.type == "select" then
		-- we have text, we need index
		for i, v in ipairs(optionSpec.options) do
			if config[optionSpec.configVariable] == v then
				return i
			end
		end
	end
end

local function setOptionValue(optionSpec, value)
	local echoValue

	if optionSpec.type == "slider" then
		config[optionSpec.configVariable] = value
	elseif optionSpec.type == "bool" then
		config[optionSpec.configVariable] = value
	elseif optionSpec.type == "select" then
		-- we have index, we need text
		config[optionSpec.configVariable] = optionSpec.options[value]
		echoValue = optionSpec.options[value]
	end

	echoValue = echoValue or value
	Spring.Echo(optionSpec.name.." set to: "..tostring(echoValue))

--	resetOptions()
	UpdateGlobalIgnoreList()
end

local function createOnChange(optionSpec)
	return function(i, value, force)
		setOptionValue(optionSpec, value)
	end
end

local function addOptionFromSpec(optionSpec)
	local option = table.copy(optionSpec)
	option.configVariable = nil
	option.enabled = nil
	option.id = getOptionId(optionSpec)
	option.widgetname = getWidgetName()
	option.value = getOptionValue(optionSpec)
	option.onchange = createOnChange(optionSpec)
	WG['options'].addOption(option)
end


local function addAllOptions()
	for _, optionSpec in ipairs(OPTION_SPECS) do
		addOptionFromSpec(optionSpec)
	end
end

local function removeOptionFromSpec(optionSpec)
	local optionID = getOptionId(optionSpec)
	WG['options'].removeOption(optionID)
end

local function removeAllOptions()
	for _, optionSpec in pairs(OPTION_SPECS) do
		removeOptionFromSpec(optionSpec)
	end
end

function resetOptions()
	removeAllOptions()
	addAllOptions()
end

function widget:Initialize()
	addAllOptions()
	CheckPIDs()
	UpdateGlobalIgnoreList()
end

function widget:Shutdown()
	removeAllOptions()
end



-- Text Commands -- 

function widget:TextCommand(s)
	local token = {}
	local n = 0
	--for w in string.gmatch(s, "%a+") do
	for w in string.gmatch(s, "%S+") do
		n = n + 1
		token[n] = w
	end

	--for i = 1,n do Spring.Echo (token[i]) end

	if token[1] == "ignoreplayer" or token[1] == "ignoreplayers" then
		for i = 2, n do
			IgnorePlayer(token[i])
		end
	end

	if token[1] == "unignoreplayer" or token[1] == "unignoreplayers" then
		if n == 1 then
			UnignoreAll()
		else
			for i = 2, n do
				UnignorePlayer(token[i])
			end
		end
	end

	if token[1] == "toggleignore" and n >= 2 then
		for i = 2, n do
			local playerName = token[i]
			if ignoredPlayers[playerName] then
				UnignorePlayer(playerName)
			else
				IgnorePlayer(playerName)
			end
		end
	end

	if token[1] == "ignorelist" then
		ignoreList()
	end

	if ((token[1] == "dnd") or (token[1] == "doNotDisturb")) then
		local setting = token[2]
		if setting then
			for i,v in next,DND_PREFERENCE do
				if setting == v then
					local optionName = "Do Not Disturb"
					local optionSpec = getOptionSpecByName(optionName)
					setOptionValue(optionSpec,setting)
					break
				end
			end
		end
	end

	if token[1] == "dndpings" then
		local setting = token[2]
		if setting then
			local optionName = 	"Allow Mapmarks in DND"
			local optionSpec = 	getOptionSpecByName(optionName)
			local stringToBoolean = { ["true"] = true, ["false"] = false }
			local typed_setting = 	stringToBoolean[setting]
			if typed_setting then
				setOptionValue(optionSpec,typed_setting)
			end
		end
	end

	if token[1] == "dndwhitelist" then
		local action_functions = {
			['add'] = function(pID)
				AddDNDWhitelist(pID)
				Spring.Echo("added "..pID.." to DND whitelist")
			end,
			['remove'] = function(pID)
				RemoveDNDWhitelist(pID)
				Spring.Echo("removed "..pID.." from DND whitelist")
			end,
			["clear"] = function(pID)
				dndWhitelist = {}
				Spring.Echo("cleared DND Whitelist")
			end,
		}

		local action_string = token[2]

		if not action_string then
			EchoDNDWhitelist()
		else
			local ActionFunction = action_functions[action_string]
			if ActionFunction then
				if not token[3] then
					ActionFunction()
				else
					CheckPIDs()
					
					local actionable_pIDs = {}
					local pID_table_lower = {}
					for pID, _ in pairs(pID_table) do
						local pID_lower = string.lower(pID)
						pID_table_lower[pID_lower] = pID
					end

					for i = 3,#token,1 do
						local query_pID = string.lower(token[i])
						if pID_table_lower[query_pID] then -- a proper pID was explicitly given (caps notwithstanding)
							actionable_pIDs[pID_table_lower[query_pID]] = true
						else -- let's try to autocomplete for them
							for pID_lower,pID in pairs(pID_table_lower) do
								if pID_lower:sub(1,#query_pID) == query_pID then 
									actionable_pIDs[pID] = true -- add the pID if it starts with the same characters as the query_pID
								end
							end
						end
					end

					
					if ActionFunction then
						for pID,_ in next,actionable_pIDs do
							if pID ~= myName then
								ActionFunction(pID)
							else
								Spring.Echo("You can't whitelist yourself")
							end
						end
					end
				end
			end
		end
	end
end

-- Game State Callins --

function widget:GamePreload()
	game_progress = 0
	UpdateGlobalIgnoreList()
end

function widget:GameStart()
	game_progress = 1
	UpdateGlobalIgnoreList()
end

function widget:GameOver()
	game_progress = 2
	UpdateGlobalIgnoreList()
end

function widget:GameFrame(f)
	if f >= 1 then
		game_started = true
	end
end

-- Communication Callins --

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	local playerName = select(1,Spring.GetPlayerInfo(playerID, false))
	
	if myName == playerName then
		return nil -- allow all pings from the self
	end

	if ignoredPlayers[select(1, Spring.GetPlayerInfo(playerID, false))] then
		return true -- always refuse map draws from deliberately ignored players
	end


	if dndWhitelist[playerName] then
		return nil -- allow pings from whitelisted players
	end

	if DNDShouldApply() then

		if CheckAllowPostGame() then
			return nil
		end

		if CheckAllowPings() then
			return nil
		end

		return true
	end

	return nil
end

-- ConfigData Callins --

function widget:GetConfigData()
	local data = {}
	local options_readout = {}
	for _, option in ipairs(OPTION_SPECS) do
		options_readout[option.configVariable] = getOptionValue(option)
	end

	data["options_readout"] = options_readout
	data["ignoredPlayers"] = table.copy(ignoredPlayers)
	data["dndWhitelist"] = table.copy(dndWhitelist)
	
	return data
end

function widget:SetConfigData(data)
	local options_readout = data["options_readout"] or {}
	ignoredPlayers = data["ignoredPlayers"] or {}
	dndWhitelist = data["dndWhitelist"] or {}

	for _, option in ipairs(OPTION_SPECS) do
		local configVariable = option.configVariable
		if options_readout[configVariable] ~= nil then
			setOptionValue(option, options_readout[configVariable])
		end
	end
end