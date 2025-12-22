local addonName, addon = ...
Provisioner = addon
Provisioner.L = addon.L -- Alias for easy access

-- --- Slash Commands Registration (First to ensure they work) ---
SLASH_PROVISIONER1 = "/prov"
SLASH_PROVISIONER2 = "/provisioner"
SlashCmdList["PROVISIONER"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    if cmd == "reset" then
        ProvisionerDB = nil
        Provisioner:InitializeDB()
        Provisioner:UpdateUI()
        print("|cFF00FF00Provisioner|r database reset.")
    elseif cmd == "debug" then
        print("Provisioner Debug: DB Exists?", ProvisionerDB ~= nil)
        print("Items Tracked:", ProvisionerDB and ProvisionerDB.trackedItems and #ProvisionerDB.trackedItems or "N/A")
    else
        print("|cFF00FF00Provisioner|r Commands:")
        print("  |cFFFFD700/prov reset|r - Reset database")
        print("  |cFFFFD700Alt+RightClick|r item in bag to track.")
    end
end

-- Initialisation de la base de données
function Provisioner:InitializeDB()
    if not ProvisionerDB then
        ProvisionerDB = {
            trackedItems = {}, -- { [itemID] = { goal = 100 } }
            settings = {
                showFrame = true,
                locked = false,
            }
        }
    end
end

-- Event Handler principal
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            Provisioner:InitializeDB()
            Provisioner:SetupMinimizeButton()
            Provisioner:UpdateUI()
            print("|cFF00FF00Provisioner|r loaded. Alt+RightClick to track items.")
        end
    elseif event == "PLAYER_LOGIN" then
        Provisioner:UpdateUI()
    elseif event == "BAG_UPDATE" or event == "GET_ITEM_INFO_RECEIVED" then
        Provisioner:UpdateUI()
    end
end)

-- --- Custom Input Logic (Replaces StaticPopup) ---

function Provisioner:GetInputFrame()
    if Provisioner.inputFrame then return Provisioner.inputFrame end
    
    local f = CreateFrame("Frame", "ProvisionerInputFrame", UIParent, "BackdropTemplate")
    f:SetSize(220, 85) -- Taller to fit button
    f:SetFrameStrata("FULLSCREEN_DIALOG") 
    f:EnableMouse(true)
    
    -- Cleaner Backdrop with darker bg
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    
    -- Apply Theme (Safe check if function exists yet)
    if Provisioner.ApplyThemeToFrame then
        Provisioner:ApplyThemeToFrame(f, "Main")
    else
        f:SetBackdropColor(0.1, 0.1, 0.1, 1) -- Fallback
    end
    
    -- Label
    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOP", 0, -12)
    lbl:SetWidth(190)
    lbl:SetJustifyH("CENTER")
    lbl:SetText("Set Goal")
    f.label = lbl
    -- Apply Theme to Label
    if Provisioner.GetTheme then
        local theme = Provisioner:GetTheme()
        lbl:SetTextColor(unpack(theme.title))
    end

    -- EditBox
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetPoint("TOP", 0, -35)
    eb:SetSize(140, 24)
    eb:SetAutoFocus(true)
    eb:SetNumeric(true)
    
    -- Close Button (X) - NOW JUST CLOSES
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        eb:ClearFocus()
        f:Hide()
    end)
    closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cancel", 1, 1, 1)
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Untrack Button (Explicit)
    local untrackBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    untrackBtn:SetSize(100, 22)
    untrackBtn:SetPoint("BOTTOM", 0, 10)
    untrackBtn:SetText("Stop Tracking")
    untrackBtn:SetScript("OnClick", function()
        if f.itemID then
             Provisioner:ToggleItem(f.itemID)
             print("Provisioner: Item removed.")
        end
        eb:ClearFocus()
        f:Hide()
    end)
    
    eb:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        local itemID = f.itemID
        if itemID and val and ProvisionerDB.trackedItems[itemID] then
            ProvisionerDB.trackedItems[itemID].goal = val
            Provisioner:UpdateUI()
        end
        self:ClearFocus() 
        f:Hide()
    end)
    
    eb:SetScript("OnEscapePressed", function(self) 
        self:ClearFocus() 
        f:Hide() 
    end)
    
    f.editBox = eb
    Provisioner.inputFrame = f
    return f
end

-- --- Core Logic ---

function Provisioner:InitializeDB()
    if not ProvisionerDB then ProvisionerDB = {} end
    if not ProvisionerDB.trackedItems then ProvisionerDB.trackedItems = {} end
    if not ProvisionerDB.profiles then ProvisionerDB.profiles = {} end
    if not ProvisionerDB.settings then ProvisionerDB.settings = { collapsed = false } end
    
    -- Load Saved Locale if exists
    if ProvisionerDB.settings.locale then
        addon:LoadLocale(ProvisionerDB.settings.locale)
    end
end

function Provisioner:GetTrackedItems()
    if ProvisionerDB.settings.useProfile then
        local charKey = UnitName("player") .. " - " .. GetRealmName()
        if not ProvisionerDB.profiles[charKey] then
            ProvisionerDB.profiles[charKey] = { items = {} }
        end
        return ProvisionerDB.profiles[charKey].items
    else
        return ProvisionerDB.trackedItems
    end
end

function Provisioner:SetupMinimizeButton()
    if ProvisionerMainFrame.minimizeBtn then return end
    
    local btn = CreateFrame("Button", nil, ProvisionerMainFrame)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPRIGHT", -8, -8)
    btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    
    btn:SetScript("OnClick", function(self)
        ProvisionerDB.settings.collapsed = not ProvisionerDB.settings.collapsed
        Provisioner:UpdateUI()
    end)
    
    ProvisionerMainFrame.minimizeBtn = btn
end

function Provisioner:ToggleItem(itemID)
    if not itemID then return end
    
    local items = Provisioner:GetTrackedItems()
    
    if items[itemID] then
        items[itemID] = nil
        print(string.format(Provisioner.L["STOP_TRACKING"], (GetItemInfo(itemID) or itemID)))
    else
        items[itemID] = { goal = 0 } -- 0 means infinite/no cap
        print(string.format(Provisioner.L["START_TRACKING"], (GetItemInfo(itemID) or itemID)))
    end
    Provisioner:UpdateUI()
end

-- --- UI Logic ---
local itemRows = {}
local ROW_HEIGHT = 20
local ROW_SPACING = 2

function Provisioner:GetItemRow(index)
    if not itemRows[index] then
        local row = CreateFrame("Button", nil, ProvisionerMainFrame, "BackdropTemplate") -- Changed to Button for click handling
        row:SetSize(ProvisionerMainFrame:GetWidth() - 20, ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        
        -- Initial Backdrop (will be colored by theme later)
        row:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        row:SetBackdropColor(0, 0, 0, 0) -- Default transparent until theme applied
        row:SetBackdropBorderColor(0, 0, 0, 0)
        
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ROW_HEIGHT, ROW_HEIGHT)
        row.icon:SetPoint("LEFT", 0, 0)
        
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.text:SetPoint("RIGHT", 0, 0)
        row.text:SetJustifyH("LEFT")
        
        row:SetScript("OnClick", function(self)
             if self.itemID then
                 local name = GetItemInfo(self.itemID) or "Unknown Item"
                 -- Open Custom Input Frame
                 local f = Provisioner:GetInputFrame()
                 f:SetParent(ProvisionerMainFrame) -- Ensure parent is correct
                 f:SetFrameStrata("DIALOG")
                 f:ClearAllPoints()
                 f:SetPoint("LEFT", self, "RIGHT", 5, 0) -- Show next to row
                 f:Show()
                 
                 f.itemID = self.itemID
                 f.label:SetText("Goal for " .. name)
                 
                 local currentGoal = ProvisionerDB.trackedItems[self.itemID].goal or 0
                 f.editBox:SetText(tostring(currentGoal))
                 f.editBox:HighlightText()
                 f.editBox:SetFocus()
             end
        end)
        
        -- Add Tooltip on Hover
        row:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        itemRows[index] = row
    end
    return itemRows[index]
end

function Provisioner:UpdateUI()
    if not ProvisionerMainFrame then return end
    
    -- Setup Main Frame Backdrop (One Time)
    if not Provisioner.mainFrameSetup then
        if not ProvisionerMainFrame.SetBackdrop then
            Mixin(ProvisionerMainFrame, BackdropTemplateMixin)
        end
        ProvisionerMainFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        Provisioner.mainFrameSetup = true
    end

    -- Setup Title Click (One Time)
    if not Provisioner.titleClickSetup then
        local titleRegion = _G["ProvisionerMainFrameTitle"]
        if titleRegion then
            local btn = CreateFrame("Button", nil, ProvisionerMainFrame)
            btn:SetAllPoints(titleRegion)
            btn:SetScript("OnEnter", function(self) 
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Click to Open Manager", 1, 1, 0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:SetScript("OnClick", function()
                Provisioner:CreateManagerWindow()
                if Provisioner.managerFrame:IsShown() then
                    Provisioner.managerFrame:Hide()
                else
                    Provisioner.managerFrame:Show()
                    Provisioner:UpdateManagerList()
                end
            end)
            Provisioner.titleClickSetup = true
        end
    end

    -- Handle Minimize Button Texture
    if ProvisionerMainFrame.minimizeBtn then
        if ProvisionerDB.settings.collapsed then
             ProvisionerMainFrame.minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
        else
             ProvisionerMainFrame.minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
        end
    end
    
    -- Apply Theme to Main Window
    if not ProvisionerMainFrame.title then
        ProvisionerMainFrame.title = _G["ProvisionerMainFrameTitle"]
    end
    if Provisioner.ApplyThemeToFrame then
        Provisioner:ApplyThemeToFrame(ProvisionerMainFrame, "Main")
    end
    
    -- Apply Global Scale
    local scale = ProvisionerDB.settings.scale or 1.0
    ProvisionerMainFrame:SetScale(scale)
    if Provisioner.managerFrame then
        Provisioner.managerFrame:SetScale(scale)
    end

    -- Use Theme Colors
    local theme = Provisioner:GetTheme()

    local index = 1
    
    -- If NOT collapsed, show items
    if not ProvisionerDB.settings.collapsed then
        local itemsList = Provisioner:GetTrackedItems()
        for itemID, data in pairs(itemsList) do
            local row = self:GetItemRow(index)
            row:Show()
            row:SetPoint("TOPLEFT", 10, -30 - ((index-1) * (ROW_HEIGHT + ROW_SPACING)))
            row.itemID = itemID
            
            -- Apply Theme to Row
            if Provisioner.ApplyThemeToFrame then
                Provisioner:ApplyThemeToFrame(row, "Row")
            end
            
            -- Count only in bags (not bank)
            local count = C_Item.GetItemCount(itemID) 
            local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(itemID)
            
            if name then
                row.icon:SetTexture(texture)
                if data.goal and data.goal > 0 then
                    row.text:SetText(string.format("%s: %d/%d", name, count, data.goal))
                    if count >= data.goal then
                         row.text:SetTextColor(unpack(theme.good)) -- Theme Success Color
                         
                         -- Alert Logic
                         if not data.completed then
                             PlaySound(618) -- SOUNDKIT.UI_QUEST_COMPLETE (ID 618)
                             -- Visual Flash Removed on user request
                             data.completed = true
                         end
                    else
                         row.text:SetTextColor(unpack(theme.text))
                         if data.completed then
                             data.completed = nil -- Reset if count drops
                         end
                    end
                else
                    row.text:SetText(string.format("%s: %d", name, count))
                    row.text:SetTextColor(unpack(theme.text))
                end
            else
                -- Item info might not be loaded yet
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.text:SetText(string.format(Provisioner.L["LOADING"], itemID))
            end
            
            index = index + 1
        end
    end
    
    -- Hide unused rows
    for i = index, #itemRows do
        itemRows[i]:Hide()
    end
    
    -- Adjust frame height & width dynamic
    local totalHeight = 40 + ((index-1) * (ROW_HEIGHT + ROW_SPACING))
    if ProvisionerDB.settings.collapsed then
        totalHeight = 35 -- Header only
        ProvisionerMainFrame:SetWidth(140) -- Minified Width
    else
        if totalHeight < 60 then 
            totalHeight = 60 
        end
        ProvisionerMainFrame:SetWidth(220) -- Standard Width
    end
    ProvisionerMainFrame:SetHeight(totalHeight)
    
    -- Sync Manager if open
    if Provisioner.managerFrame and Provisioner.managerFrame:IsShown() then
        Provisioner:UpdateManagerList()
    end
end

-- Hooking Container Frame Clicks

-- --- Accessibility / Themes ---

Provisioner.Themes = {
    Default = {
        name = "Default",
        bg = {0, 0, 0, 0}, -- Transparent
        border = {0, 0, 0, 0}, -- Transparent
        managerBg = {0.05, 0.05, 0.05, 1}, -- Solid Manager Window
        managerBorder = {1, 1, 1, 1},
        title = {1, 0.82, 0, 1}, -- Gold
        text = {1, 1, 1, 1}, -- White
        dropBg = {0.05, 0.2, 0.05, 0.4}, -- Green Tint
        dropBorder = {0.2, 0.6, 0.2, 0.5},
        good = {0, 1, 0, 1}, -- Green text
        listBg = {0, 0, 0, 0}, -- Transparent List Bg too? User said "on Provisioner list", context implies main frame.
        listBorder = {0, 0, 0, 0},
    },
    HighContrast = {
        name = "High Contrast",
        bg = {0, 0, 0, 1},
        border = {1, 1, 1, 1},
        title = {1, 1, 1, 1}, -- White
        text = {1, 1, 1, 1},
        dropBg = {0.2, 0.2, 0.2, 1}, -- Dark Grey
        dropBorder = {1, 1, 1, 1}, -- White
        good = {0, 1, 1, 1}, -- Cyan (Distinct)
        listBg = {0.1, 0.1, 0.1, 1},
        listBorder = {1, 1, 1, 1},
    },
    Protanopia = { -- Red-Weak (Avoid Red/Green confusion)
        name = "Protanopia",
        bg = {0.1, 0.1, 0.15, 1}, -- Bluish tint
        border = {0.6, 0.6, 0.8, 1},
        title = {1, 0.9, 0.4, 1},
        text = {0.9, 0.9, 1, 1},
        dropBg = {0.1, 0.2, 0.4, 0.5}, -- Blue tint
        dropBorder = {0.4, 0.6, 1, 0.8},
        good = {0.2, 0.6, 1, 1}, -- Blue for Success (instead of Green)
        listBg = {0.2, 0.2, 0.25, 0.8},
        listBorder = {0.5, 0.5, 0.7, 0.5},
    },
    Deuteranopia = { -- Green-Weak (Similar needs to Protanopia)
        name = "Deuteranopia",
        bg = {0.1, 0.1, 0.1, 1},
        border = {0.7, 0.7, 0.7, 1},
        title = {1, 0.8, 0.2, 1},
        text = {1, 1, 1, 1},
        dropBg = {0.2, 0.2, 0.4, 0.5}, -- Blueish
        dropBorder = {0.5, 0.5, 1, 0.8},
        good = {0.2, 0.6, 1, 1}, -- Blue for Success
        listBg = {0.2, 0.2, 0.2, 0.8},
        listBorder = {0.6, 0.6, 0.6, 0.5},
    },
    Tritanopia = { -- Blue-Weak (Avoid Blue/Yellow confusion, Use Red/Cyan)
        name = "Tritanopia",
        bg = {0.1, 0.05, 0.05, 1}, -- Reddish tint
        border = {1, 0.5, 0.5, 1},
        title = {0, 1, 1, 1}, -- Cyan title
        text = {1, 0.9, 0.9, 1},
        dropBg = {0.2, 0.5, 0.5, 0.4}, -- Cyan tint
        dropBorder = {0, 1, 1, 0.5},
        good = {0, 1, 1, 1}, -- Cyan for Success
        listBg = {0.2, 0.1, 0.1, 0.8},
        listBorder = {0.8, 0.4, 0.4, 0.5},
    }
}

function Provisioner:GetTheme()
    local themeName = ProvisionerDB.settings.theme or "Default"
    return Provisioner.Themes[themeName] or Provisioner.Themes.Default
end

function Provisioner:ApplyThemeToFrame(f, type)
    local theme = Provisioner:GetTheme()
    
    if type == "Main" then
        if f.SetBackdropColor then f:SetBackdropColor(unpack(theme.bg)) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(theme.border)) end
        if f.title then f.title:SetTextColor(unpack(theme.title)) end
    elseif type == "Manager" then
        if f.SetBackdropColor then f:SetBackdropColor(unpack(theme.managerBg or theme.bg)) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(theme.managerBorder or theme.border)) end
        if f.title then f.title:SetTextColor(unpack(theme.title)) end
    elseif type == "DropZone" then
        f:SetBackdropColor(unpack(theme.dropBg))
        f:SetBackdropBorderColor(unpack(theme.dropBorder))
    elseif type == "Row" then
        f:SetBackdropColor(unpack(theme.listBg))
        f:SetBackdropBorderColor(unpack(theme.listBorder))
        if f.name then f.name:SetTextColor(unpack(theme.title)) end
    end
end

-- --- Manager Window Logic ---

function Provisioner:CreateManagerWindow()
    if Provisioner.managerFrame then return end

    local f = CreateFrame("Frame", "ProvisionerManagerFrame", UIParent, "BackdropTemplate")
    f:SetSize(460, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Dark Premium Backdrop
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    Provisioner:ApplyThemeToFrame(f, "Manager")
    
    -- Title
    local titleBg = f:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetWidth(300)
    titleBg:SetHeight(64)
    titleBg:SetPoint("TOP", 0, 12)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", titleBg, "TOP", 0, -14)
    title:SetText(Provisioner.L["MANAGER_TITLE"])
    f.title = title
    Provisioner:ApplyThemeToFrame(f, "Manager") -- Re-apply to set title color

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- Info Button
    local infoBtn = CreateFrame("Button", nil, f)
    infoBtn:SetSize(24, 24)
    infoBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -5, -5)
    infoBtn:SetNormalTexture("Interface\\common\\help-i")
    infoBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    infoBtn:SetScript("OnClick", function()
        Provisioner:ToggleGuideWindow()
    end)

    -- Theme Switcher (Standard UI)
    local themeFrame = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    themeFrame:SetSize(140, 24)
    themeFrame:SetPoint("TOPLEFT", 15, -40) -- Moved lower to avoid Title overlap
    themeFrame:SetText(string.format(Provisioner.L["THEME"], (ProvisionerDB.settings.theme or "Default")))
    
    themeFrame:SetScript("OnClick", function()
        local current = ProvisionerDB.settings.theme or "Default"
        local nextTheme = "Default"
        if current == "Default" then nextTheme = "HighContrast"
        elseif current == "HighContrast" then nextTheme = "Protanopia"
        elseif current == "Protanopia" then nextTheme = "Deuteranopia"
        elseif current == "Deuteranopia" then nextTheme = "Tritanopia"
        elseif current == "Tritanopia" then nextTheme = "Default"
        end
        ProvisionerDB.settings.theme = nextTheme
        themeFrame:SetText(string.format(Provisioner.L["THEME"], nextTheme))
        
        Provisioner:ApplyThemeToFrame(f, "Manager")
        Provisioner:ApplyThemeToFrame(f.dropZone, "DropZone")
        Provisioner:UpdateManagerList()
        Provisioner:UpdateUI() 
    end)

    -- Scale Controls
    local function CreateScaleBtn(text, delta, relativeTo, xOff)
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(24, 24)
        btn:SetPoint("LEFT", relativeTo, "RIGHT", xOff, 0)
        btn:SetText(text)
        btn:SetScript("OnClick", function()
            local s = ProvisionerDB.settings.scale or 1.0
            s = s + delta
            if s < 0.5 then s = 0.5 end
            if s > 2.0 then s = 2.0 end
            ProvisionerDB.settings.scale = s
            Provisioner:UpdateUI() -- Triggers scale update
            f.scaleTxt:SetText(math.floor(s*100).."%")
        end)
        return btn
    end

    local scaleDown = CreateScaleBtn("-", -0.1, themeFrame, 10)
    
    local scaleTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleTxt:SetPoint("LEFT", scaleDown, "RIGHT", 5, 0)
    scaleTxt:SetText(math.floor((ProvisionerDB.settings.scale or 1.0)*100).."%")
    f.scaleTxt = scaleTxt
    
    local scaleUp = CreateScaleBtn("+", 0.1, scaleTxt, 5)

    -- Language Selector (Icon + Dropdown Style)
    local langButton = CreateFrame("Button", nil, f) -- Icon Button
    langButton:SetSize(24, 24)
    langButton:SetPoint("LEFT", scaleUp, "RIGHT", 15, 0)
    langButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    langButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local langDropdown = CreateFrame("Frame", "ProvisionerLangDropdown", f, "UIDropDownMenuTemplate")
    
    local function UpdateLangUI()
        f.title:SetText(Provisioner.L["MANAGER_TITLE"])
        themeFrame:SetText(string.format(Provisioner.L["THEME"], (ProvisionerDB.settings.theme or "Default")))
        f.profileChk.label:SetText(Provisioner.L["PROFILE_SPECIFIC"]) 
        f.dropZone.text:SetText(Provisioner.L["DRAG_ITEM_HERE"])
        Provisioner:UpdateManagerList()
        Provisioner:UpdateUI()
    end
    
    UIDropDownMenu_Initialize(langDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.isTitle = true
        info.text = Provisioner.L["LANG"]:gsub(": %%s", "") -- Strip ": %s" for proper title
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        
        local langs = {
            { code = "enUS", text = "English" },
            { code = "frFR", text = "Français" }
        }
        
        for _, l in ipairs(langs) do
            info = UIDropDownMenu_CreateInfo()
            info.text = l.text
            info.func = function()
                ProvisionerDB.settings.locale = l.code
                addon:LoadLocale(l.code)
                UpdateLangUI()
            end
            info.checked = (addon.Locales[l.code].name == addon.Locales[ProvisionerDB.settings.locale or "enUS"].name)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    langButton:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, langDropdown, self, 0, 0)
    end)
    
    langButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Provisioner.L["LANG"]:gsub(": %%s", ""))
        GameTooltip:Show()
    end)
    langButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Profile Checkbox
    local profileChk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    profileChk:SetSize(24, 24)
    profileChk:SetPoint("LEFT", langButton, "RIGHT", 15, 0)
    profileChk:SetChecked(ProvisionerDB.settings.useProfile)
    
    local chkLabel = profileChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chkLabel:SetPoint("LEFT", profileChk, "RIGHT", 2, 0)
    chkLabel:SetText(Provisioner.L["PROFILE_SPECIFIC"])
    
    profileChk:SetScript("OnClick", function(self)
        ProvisionerDB.settings.useProfile = self:GetChecked()
        Provisioner:UpdateManagerList()
        Provisioner:UpdateUI()
    end)
    profileChk.label = chkLabel
    f.profileChk = profileChk
    -- Ensure checkbox state is correct on show (though create only runs once, so we might need to sync it on show if settings changed elsewhere? Unlikely for now).

    -- Modern Drop Zone
    local dropZone = CreateFrame("Button", nil, f, "BackdropTemplate")
    dropZone:SetSize(400, 80)
    dropZone:SetPoint("TOP", 0, -80) -- Moved down further
    dropZone:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f.dropZone = dropZone
    Provisioner:ApplyThemeToFrame(dropZone, "DropZone")
    
    -- Icon for Drop Zone
    local dzIcon = dropZone:CreateTexture(nil, "ARTWORK")
    dzIcon:SetSize(32, 32)
    dzIcon:SetPoint("TOP", 0, -10)
    dzIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up") 
    dzIcon:SetDesaturated(true)
    
    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dropText:SetPoint("TOP", dzIcon, "BOTTOM", 0, -5)
    dropText:SetText(Provisioner.L["DRAG_ITEM_HERE"])
    dropText:SetTextColor(0.6, 0.6, 0.6)
    dropZone.text = dropText
    
    local function catchItem()
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" then
            Provisioner:ToggleItem(itemID)
            ClearCursor()
            Provisioner:UpdateManagerList()
        end
    end
    dropZone:SetScript("OnReceiveDrag", catchItem)
    dropZone:SetScript("OnClick", catchItem)
    dropZone:SetScript("OnEnter", function(self) 
        local theme = Provisioner:GetTheme()
        self:SetBackdropBorderColor(unpack(theme.border)) -- Highlight
        dropText:SetTextColor(1, 1, 1)
    end)
    dropZone:SetScript("OnLeave", function(self) 
        local theme = Provisioner:GetTheme()
        self:SetBackdropBorderColor(unpack(theme.dropBorder))
        dropText:SetTextColor(0.6, 0.6, 0.6)
    end)

    -- Scroll Frame for List
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -180) 
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50) -- Raised to make room for buttons

    -- Export/Import Buttons
    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(100, 24)
    exportBtn:SetPoint("BOTTOMLEFT", 20, 15)
    exportBtn:SetText(Provisioner.L["BTN_EXPORT"])
    exportBtn:SetScript("OnClick", function() Provisioner:CreateExportWindow() end)
    
    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 24)
    importBtn:SetPoint("BOTTOMRIGHT", -40, 15)
    importBtn:SetText(Provisioner.L["BTN_IMPORT"])
    importBtn:SetScript("OnClick", function() Provisioner:CreateImportWindow() end)

    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(380, 1) 
    scrollFrame:SetScrollChild(content)
    
    f.content = content
    Provisioner.managerFrame = f
end

function Provisioner:UpdateManagerList()
    if not Provisioner.managerFrame or not Provisioner.managerFrame:IsShown() then return end
    
    local content = Provisioner.managerFrame.content
    local kids = { content:GetChildren() }
    for _, child in ipairs(kids) do child:Hide() end
    
    local yOffset = 0
    local index = 0
    
    local yOffset = 0
    local index = 0
    local itemsList = Provisioner:GetTrackedItems()
    
    for itemID, data in pairs(itemsList) do
        index = index + 1
        local row = kids[index]
        if not row then
            row = CreateFrame("Frame", nil, content, "BackdropTemplate")
            row:SetSize(380, 50) 
            row:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(36, 36)
            row.icon:SetPoint("LEFT", 8, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) 
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 12, 0)
            row.name:SetWidth(210)
            row.name:SetJustifyH("LEFT")
            
            -- Delete Button (Rightmost)
            row.del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.del:SetSize(28, 28)
            row.del:SetPoint("RIGHT", -5, 0)
            row.del:SetScript("OnClick", function()
                Provisioner:ToggleItem(row.itemID)
                Provisioner:UpdateManagerList()
            end)

            -- Goal Edit (Next to Delete)
            row.goalAPI = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.goalAPI:SetSize(50, 24)
            row.goalAPI:SetPoint("RIGHT", row.del, "LEFT", -10, 0)
            row.goalAPI:SetNumeric(true)
            row.goalAPI:SetAutoFocus(false)
            row.goalAPI:SetJustifyH("CENTER")
            row.goalAPI:SetScript("OnEnterPressed", function(self)
                local val = tonumber(self:GetText())
                if row.itemID and val then
                    local items = Provisioner:GetTrackedItems()
                    if items[row.itemID] then
                        items[row.itemID].goal = val
                        Provisioner:UpdateUI()
                    end
                end
                self:ClearFocus()
            end)
        end
        
        -- Dynamic Styling
        Provisioner:ApplyThemeToFrame(row, "Row")
        
        local nm, _, _, _, _, _, _, _, _, txt = GetItemInfo(itemID)
        row.icon:SetTexture(txt or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(nm or "Loading...")
        row.goalAPI:SetText(data.goal or 0)
        row.itemID = itemID
        
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()
        yOffset = yOffset - 55 
    end
    
    content:SetHeight(math.abs(yOffset) + 20)
end



-- --- Hooking Logic (Universal) ---
-- (Removed by Request)


function Provisioner:ToggleGuideWindow()
    if not Provisioner.guideFrame then
        Provisioner:CreateGuideWindow()
    else
        if Provisioner.guideFrame:IsShown() then
            Provisioner.guideFrame:Hide()
        else
            Provisioner.guideFrame:Show()
        end
    end
end


function Provisioner:CreateGuideWindow()
    if Provisioner.guideFrame then Provisioner.guideFrame:Show() return end

    local f = CreateFrame("Frame", "ProvisionerGuideFrame", UIParent, "BackdropTemplate")
    f:SetSize(350, 450)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG") -- Higher than Manager
    
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -20)
    title:SetText(Provisioner.L["GUIDE_TITLE"])
    title:SetTextColor(1, 0.82, 0)
    
    local content = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    content:SetPoint("TOPLEFT", 20, -60)
    content:SetPoint("BOTTOMRIGHT", -20, 60)
    content:SetJustifyH("LEFT")
    content:SetJustifyV("TOP")
    
    -- EditBoxes for Socials (Page 3)
    local twitchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    twitchBox:SetSize(280, 20)
    twitchBox:SetPoint("BOTTOM", 0, 100) -- Above GitHub
    twitchBox:SetText("https://www.twitch.tv/mao_kzu")
    twitchBox:SetAutoFocus(false)
    twitchBox:Hide()

    local ghBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    ghBox:SetSize(280, 20)
    ghBox:SetPoint("BOTTOM", 0, 75)
    ghBox:SetText("https://github.com/Antigravity-Agent/Provisioner")
    ghBox:SetAutoFocus(false)
    ghBox:Hide()
    
    -- Paging Logic
    local currentPage = 1
    local totalPages = 3
    local pageNum = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageNum:SetPoint("BOTTOM", 0, 20)
    
    local prev = CreateFrame("Button", nil, f)
    prev:SetSize(32, 32)
    prev:SetPoint("BOTTOMLEFT", 10, 10)
    prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")

    local nextBtn = CreateFrame("Button", nil, f)
    nextBtn:SetSize(32, 32)
    nextBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    
    local function UpdatePage()
        pageNum:SetText("Page " .. currentPage .. " / " .. totalPages)
        prev:SetEnabled(currentPage > 1)
        nextBtn:SetEnabled(currentPage < totalPages)
        ghBox:Hide()
        twitchBox:Hide()
        
        if currentPage == 1 then
            content:SetText(Provisioner.L["GUIDE_PAGE1"])
        elseif currentPage == 2 then
            content:SetText(Provisioner.L["GUIDE_PAGE2"])
        elseif currentPage == 3 then
            content:SetText(Provisioner.L["GUIDE_PAGE3"])
            ghBox:Show() -- Show Github Link
            twitchBox:Show() -- Show Twitch Link
        end
    end
    
    prev:SetScript("OnClick", function() 
        if currentPage > 1 then currentPage = currentPage - 1 UpdatePage() end 
    end)
    nextBtn:SetScript("OnClick", function() 
        if currentPage < totalPages then currentPage = currentPage + 1 UpdatePage() end 
    end)
    
    UpdatePage()
    Provisioner.guideFrame = f
end

function Provisioner:ExportList()
    local items = Provisioner:GetTrackedItems()
    local parts = {}
    for id, data in pairs(items) do
        table.insert(parts, string.format("item:%d:%d", id, data.goal or 0))
    end
    return table.concat(parts, ";")
end

function Provisioner:ImportList(str)
    local items = Provisioner:GetTrackedItems()
    local count = 0
    for chunk in string.gmatch(str, "([^;]+)") do
        local type, id, goal = strsplit(":", chunk)
        if type == "item" then
            id = tonumber(id)
            goal = tonumber(goal)
            if id then
                items[id] = { goal = goal or 0 }
                count = count + 1
            end
        end
    end
    return count
end

function Provisioner:CreateExportWindow()
    if Provisioner.exportFrame then Provisioner.exportFrame:Show() end -- Re-use logic below
    
    local f = Provisioner.exportFrame or CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    if not Provisioner.exportFrame then
        f:SetSize(400, 200)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG") -- Higher than Manager
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -15)
        f.title = title
        
        local desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        desc:SetPoint("TOPLEFT", 20, -40)
        f.desc = desc
        
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -60)
        scroll:SetPoint("BOTTOMRIGHT", -30, 40)
        
        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetSize(330, 200)
        eb:SetMultiLine(true)
        eb:SetFontObject("ChatFontNormal")
        scroll:SetScrollChild(eb)
        f.eb = eb
        
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetSize(80, 24)
        close:SetPoint("BOTTOM", 0, 10)
        close:SetText(Provisioner.L["BTN_FERMER"] or "Close")
        close:SetScript("OnClick", function() f:Hide() end)
        
        local actionBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        actionBtn:SetSize(120, 24)
        actionBtn:SetPoint("BOTTOMRIGHT", -20, 10)
        actionBtn:Hide() -- Only for Import
        f.actionBtn = actionBtn
        
        Provisioner.exportFrame = f
    end

    f.title:SetText(Provisioner.L["EXPORT_TITLE"])
    f.desc:SetText(Provisioner.L["EXPORT_DESC"])
    f.eb:SetText(Provisioner:ExportList())
    f.eb:HighlightText()
    f.eb:SetFocus()
    f.actionBtn:Hide()
    f:Show()
end

function Provisioner:CreateImportWindow()
     if not Provisioner.exportFrame then Provisioner:CreateExportWindow() end -- Setup base frame
     local f = Provisioner.exportFrame
     
     f.title:SetText(Provisioner.L["IMPORT_TITLE"])
     f.desc:SetText(Provisioner.L["IMPORT_DESC"])
     f.eb:SetText("")
     f.eb:SetFocus()
     
     f.actionBtn:Show()
     f.actionBtn:SetText(Provisioner.L["IMPORT_BTN_ACTION"])
     f.actionBtn:SetScript("OnClick", function()
        local txt = f.eb:GetText()
        if txt and #txt > 0 then
            local count = Provisioner:ImportList(txt)
            if count > 0 then
                print(string.format(Provisioner.L["IMPORT_SUCCESS"], count))
                Provisioner:UpdateManagerList()
                Provisioner:UpdateUI()
                f:Hide()
            else
                 print(Provisioner.L["IMPORT_ERROR"])
            end
        end
     end)
     f:Show()
end
