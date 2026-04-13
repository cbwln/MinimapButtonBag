local addonName, addon = ...

local ClearAllPoints = UIParent.ClearAllPoints
local SetPoint = UIParent.SetPoint

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
local icon = LibStub("LibDBIcon-1.0", true)

local buttonContainer
local baggedButtons = {}

local plugin = ldb:NewDataObject(addonName, {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_Coin_01"
})

function plugin.OnClick(self, button)
    if button == "LeftButton" then
        buttonContainer:SetShown(not buttonContainer:IsShown())
    elseif button == "RightButton" then
        Settings.OpenToCategory(addon.settingsCategory:GetID())
    end
end

local function noop() end

local function updateLayout()
    table.sort(baggedButtons, function(a, b)
        return strlower(a:GetName() or "") > strlower(b:GetName() or "")
    end)

    local count = 0
    for _, button in ipairs(baggedButtons) do
        if button:IsShown() then
            ClearAllPoints(button)
            SetPoint(button, "RIGHT", buttonContainer, "RIGHT", -(count * 31), 0)
            count = count + 1
        end
    end
    buttonContainer:SetSize(math.max(1, count) * 31, 31)
end

local function bagButton(button)
    button:SetParent(buttonContainer)

    button.ClearAllPoints = noop
    button.SetPoint = noop
    button.SetParent = noop
    button.SetScale = noop

    hooksecurefunc(button, "Show", updateLayout)
    hooksecurefunc(button, "Hide", updateLayout)

    tinsert(baggedButtons, button)
end

local function unbagButton(button, buttonName)
    button.ClearAllPoints = nil
    button.SetPoint = nil
    button.SetParent = nil
    button.SetScale = nil

    button:ClearAllPoints()
    button:SetParent(Minimap)

    table.remove(baggedButtons, tIndexOf(baggedButtons, button))

    icon:Refresh(buttonName)
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    if not icon then return end

    MinimapButtonBagDB = MinimapButtonBagDB or {}
    MinimapButtonBagDB.minimap = MinimapButtonBagDB.minimap or { hide = false }
    MinimapButtonBagDB.excluded = MinimapButtonBagDB.excluded or {}

    icon:Register(addonName, plugin, MinimapButtonBagDB.minimap)

    buttonContainer = CreateFrame("Frame", nil, UIParent)
    buttonContainer:Hide()
    buttonContainer:SetPoint("RIGHT", icon:GetMinimapButton(addonName), "LEFT", 0, 0)

    local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)
    addon.settingsCategory = category
    Settings.RegisterAddOnCategory(category)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Excluded Addons"))

    local function registerExcludeCheckbox(buttonName)
        MinimapButtonBagDB.excluded[buttonName] = MinimapButtonBagDB.excluded[buttonName] or false
        local setting = Settings.RegisterAddOnSetting(category, addonName.."_excluded_"..buttonName, buttonName, MinimapButtonBagDB.excluded, "boolean", buttonName, false)
        Settings.CreateCheckbox(category, setting, "Exclude "..buttonName.." from the minimap button bag.")
        setting:SetValueChangedCallback(function()
            if setting:GetValue() then
                unbagButton(icon:GetMinimapButton(buttonName), buttonName)
            else
                bagButton(icon:GetMinimapButton(buttonName))
            end
        end)
    end

    for _, buttonName in ipairs(icon:GetButtonList()) do
        if buttonName ~= addonName then
            registerExcludeCheckbox(buttonName)
            if not MinimapButtonBagDB.excluded[buttonName] then
                bagButton(icon:GetMinimapButton(buttonName))
            end
        end
    end
    updateLayout()

    icon.RegisterCallback(addonName, "LibDBIcon_IconCreated", function(_, button, buttonName)
        registerExcludeCheckbox(buttonName)
        if not MinimapButtonBagDB.excluded[buttonName] then
            bagButton(button)
            updateLayout()
        end
    end)
end)
frame:RegisterEvent("ADDON_LOADED")