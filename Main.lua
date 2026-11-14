--[[
  Notatki - wlasne notatki na mapie swiata.
  Alt + klik na mapie albo /notatka <tekst> w miejscu, gdzie stoisz.
]]
local _, ns = ...
local C, T = ns.CONFIG, ns.T

local ICON = "Interface\\Icons\\INV_Misc_Note_01"
local COLOR = { 1.0, 0.93, 0.68 }

local function AddNote(mapID, x, y, text)
	local db = ns.db
	db.notes[mapID] = db.notes[mapID] or {}
	table.insert(db.notes[mapID], {
		x = ns.Round(x), y = ns.Round(y), text = text,
		created = time(), char = ns.charKey,
	})
	ns.Print(T("note_added", text, ns.MapName(mapID), x * 100, y * 100))
	ns.RefreshMap()
end

local function AddNoteHere(text)
	text = strtrim(text or "")
	if text == "" then ns.Print(T("note_usage")) return end
	local mapID, x, y = ns.PlayerPos()
	if not mapID then ns.Print(T("no_position")) return end
	AddNote(mapID, x, y, text)
end

------------------------------------------------------------------------
-- Okienko do wpisania notatki (Alt + klik na mapie)
------------------------------------------------------------------------

local dialog

local function CreateDialog()
	local f = CreateFrame("Frame", "NotatkiInputDialog", UIParent, "BackdropTemplate")
	f:SetSize(360, 124)
	f:SetPoint("CENTER", 0, 140)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})

	f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.Title:SetPoint("TOP", 0, -20)

	local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	eb:SetSize(300, 24)
	eb:SetPoint("TOP", 0, -46)
	eb:SetAutoFocus(true)
	eb:SetMaxLetters(200)
	f.EditBox = eb

	local function Save()
		local text = strtrim(eb:GetText() or "")
		if text ~= "" and f.mapID then AddNote(f.mapID, f.x, f.y, text) end
		f:Hide()
	end
	eb:SetScript("OnEnterPressed", Save)
	eb:SetScript("OnEscapePressed", function() f:Hide() end)

	f.SaveButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.SaveButton:SetSize(110, 22)
	f.SaveButton:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
	f.SaveButton:SetScript("OnClick", Save)

	f.CancelButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.CancelButton:SetSize(110, 22)
	f.CancelButton:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)
	f.CancelButton:SetScript("OnClick", function() f:Hide() end)

	f:Hide()
	return f
end

local function OpenDialog(mapID, x, y)
	dialog = dialog or CreateDialog()
	dialog.mapID, dialog.x, dialog.y = mapID, x, y
	dialog.Title:SetText(T("note_prompt") .. " - " .. ns.MapName(mapID))
	dialog.SaveButton:SetText(T("save"))
	dialog.CancelButton:SetText(T("cancel"))
	dialog.EditBox:SetText("")
	dialog:Show()
	dialog.EditBox:SetFocus()
end

------------------------------------------------------------------------
-- Mapa
------------------------------------------------------------------------

NotatkiPinMixin = ns.NewPinMixin({
	icon = function() return ICON end,
	color = function() return COLOR end,
	name = function(n) return n.text end,
	tooltip = function(n, srcMapID)
		GameTooltip:AddLine(n.text, 1, 1, 1, true)
		GameTooltip:AddLine(ns.MapName(srcMapID), 0.7, 0.7, 0.7)
		local who = n.char and (n.char:match("^[^-]+") or n.char) or "?"
		GameTooltip:AddLine(T("tt_added", who, ns.Ago(n.created)), 0.6, 0.6, 0.6)
	end,
})

ns.EnableMap({
	templates = { "NotatkiPinTemplate" },
	refresh = function(map, uiMapID)
		ns.EachOnMap(ns.db.notes, uiMapID, function(n, src, x, y, size)
			map:AcquirePin("NotatkiPinTemplate", n, src, x, y, size)
		end)
	end,
	onAttach = function(worldMap)
		if not worldMap.AddCanvasClickHandler then return end
		worldMap:AddCanvasClickHandler(function(canvas, button, cursorX, cursorY)
			if button == "LeftButton" and IsAltKeyDown() then
				local mapID = canvas:GetMapID()
				if mapID and cursorX and cursorY then
					OpenDialog(mapID, cursorX, cursorY)
					return true
				end
			end
			return false
		end)
	end,
})

------------------------------------------------------------------------
-- Komendy
------------------------------------------------------------------------

local function ListNotes()
	local mapID = ns.PlayerPos()
	if not mapID then ns.Print(T("no_position")) return end
	local list = ns.db.notes[mapID]
	if not list or #list == 0 then ns.Print(T("list_none", ns.MapName(mapID))) return end
	ns.Print(T("list_header", ns.MapName(mapID)))
	for _, n in ipairs(list) do
		DEFAULT_CHAT_FRAME:AddMessage(T("list_line", n.x * 100, n.y * 100, n.text))
	end
end

C.onCommand = function(cmd, arg)
	if cmd == "list" then
		ListNotes()
		return true
	elseif cmd == "add" then
		AddNoteHere(arg)
		return true
	end
end

C.onUnknown = AddNoteHere

C.stats = function()
	local notes, maps = 0, 0
	for _, list in pairs(ns.db.notes) do
		maps = maps + 1
		notes = notes + #list
	end
	ns.Print(T("stats", notes, maps))
end

C.clearLabel = function()
	local mapID = ns.PlayerPos()
	return mapID and ns.MapName(mapID) or "?"
end
C.clear = function()
	local mapID = ns.PlayerPos()
	if mapID then ns.db.notes[mapID] = nil end
end
C.reset = function() ns.db.notes = {} end

-- /notatka <tekst> - zawsze dodaje notatke
SLASH_NOTATKA1 = "/notatka"
SLASH_NOTATKA2 = "/note"
SlashCmdList.NOTATKA = function(msg)
	if ns.db then AddNoteHere(msg) end
end
