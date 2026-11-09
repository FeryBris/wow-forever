-- Repairs your gear whenever a merchant that can repair is open.
--
-- Two things worth knowing about the implementation:
--
-- 1. Merchant state is tracked from MERCHANT_SHOW and MERCHANT_CLOSED rather
--    than by asking a Blizzard frame whether it is visible. The order in which
--    handlers run is not defined, so a frame can still be hidden while the
--    merchant is long open. Same reasoning as AutoSellGray.
--
-- 2. If the repair is unaffordable right now, we wait instead of giving up.
--    Selling junk takes a few seconds -- it is throttled on purpose -- and the
--    money for the repair is often still on its way. Rather than coupling this
--    module to the selling one, it simply listens for PLAYER_MONEY while the
--    merchant is open and tries again whenever the purse changes. It needs to
--    know nothing about where the money came from.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("AutoRepair", {
    title    = L["Auto Repair"],
    default  = true,
    desc     = L["Repairs your gear at merchants who offer repairs."],
    group    = "merchant",
    order    = 50,
    options = {
        { key = "announce", type = "toggle", default = true,
          label = L["Report the cost in chat"],
          desc  = L["Shows the repair cost in chat."] },
        { key = "holdShiftStop", type = "toggle", default = true,
          label = L["Hold Shift to pause"],
          desc  = L["While Shift is down, nothing is repaired."] },
    },
})

local merchantOpen = false
local waiting      = false   -- postponed until the purse grows

local function StopWaiting()
    if not waiting then return end
    waiting = false
    if M.frame then M.frame:UnregisterEvent("PLAYER_MONEY") end
end

--- Attempts a repair.
-- @param verbose  also report when nothing happens (used by /fplus repair)
function M:Run(verbose)
    if not merchantOpen then
        if verbose then FP:Print(L["No merchant open."]) end
        return
    end
    if self.db.holdShiftStop and IsShiftKeyDown() then
        if verbose then FP:Print(L["Shift is held, automation paused."]) end
        return
    end
    if not (CanMerchantRepair and GetRepairAllCost and RepairAllItems) then
        return FP:Warn(L["AutoRepair: the repair API is missing on this build."])
    end

    if not CanMerchantRepair() then
        if verbose then FP:Print(L["This merchant does not repair."]) end
        return
    end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then
        if verbose then FP:Print(L["Nothing to repair."]) end
        return
    end

    if GetMoney() < cost then
        -- See point 2 in the header: wait for money rather than refuse.
        if not waiting then
            waiting = true
            self.frame:RegisterEvent("PLAYER_MONEY")
            if self.db.announce or verbose then
                FP:Print(L["Repair costs %s, waiting until you can afford it."],
                    FP:Money(cost))
            end
        end
        return
    end

    RepairAllItems()
    StopWaiting()

    if self.db.announce then
        FP:Print(L["Repaired for %s."], FP:Money(cost))
    end
end

--- Self-test: reports for each building block whether it exists on this build.
function M:SelfTest()
    local function state(ok) return ok and "|cff44ff44ok|r" or "|cffff5555missing|r" end

    FP:Print("AutoRepair self-test:")
    local lines = {
        { "Merchant open (per event)", merchantOpen and "|cff44ff44yes|r" or "|cffff5555no|r" },
        { "CanMerchantRepair",         state(CanMerchantRepair ~= nil) },
        { "GetRepairAllCost",          state(GetRepairAllCost ~= nil) },
        { "RepairAllItems",            state(RepairAllItems ~= nil) },
        { "CanGuildBankRepair",        state(CanGuildBankRepair ~= nil) },
    }
    for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffffff%-26s|r %s", line[1], line[2]))
    end

    if merchantOpen and CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost then
        local cost = GetRepairAllCost()
        FP:Print("Repair cost right now: %s", FP:Money(cost or 0))
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            merchantOpen = true
            FP:Safe("AutoRepair:Run", M.Run, M, false)
        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
            StopWaiting()
        elseif event == "PLAYER_MONEY" then
            FP:Safe("AutoRepair:Run", M.Run, M, false)
        end
    end)
    self.frame:RegisterEvent("MERCHANT_SHOW")
    self.frame:RegisterEvent("MERCHANT_CLOSED")
end

function M:OnDisable()
    StopWaiting()
    if self.frame then self.frame:UnregisterAllEvents() end
    merchantOpen = false
end
