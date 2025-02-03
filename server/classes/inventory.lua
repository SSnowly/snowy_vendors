local config = require 'config.shared'

---@class VendorInventory
local VendorInventory = {}
VendorInventory.__index = VendorInventory

local inventories = {}

function VendorInventory.new(vendorId)
    local self = setmetatable({}, VendorInventory)
    self.vendorId = vendorId
    self.items = {}
    self:load()
    return self
end

function VendorInventory:load()
    if not config.Vendors[self.vendorId].shop.persistInventory then
        -- Initialize with default shop items
        for itemName, itemData in pairs(config.Vendors[self.vendorId].shop.items) do
            self.items[itemName] = {
                amount = itemData.amount or 0,
                basePrice = itemData.price,
                soldItems = {},
                dynamic = itemData.dynamic or false
            }
        end
        self:save() -- Save initial data
        return
    end
    
    -- Load from database or JSON file
    local savedData = json.decode(LoadResourceFile(GetCurrentResourceName(), ('data/%s.json'):format(self.vendorId)))
    if savedData then
        self.items = savedData
    else
        -- Initialize with default shop items
        for itemName, itemData in pairs(config.Vendors[self.vendorId].shop.items) do
            self.items[itemName] = {
                amount = itemData.amount or 0,
                basePrice = itemData.price,
                soldItems = {},
                dynamic = itemData.dynamic or false
            }
        end
        self:save() -- Save initial data
    end
end

function VendorInventory:save()
    if not config.Vendors[self.vendorId].shop.persistInventory then return end
    SaveResourceFile(GetCurrentResourceName(), ('data/%s.json'):format(self.vendorId), json.encode(self.items), -1)
end

function VendorInventory:getDynamicPrice(source, itemName)
    if not self.items[itemName] then return nil end
    local Player = exports.qbx_core:GetPlayer(source)
    local item = self.items[itemName]
    if not item.dynamic then
        return config.Vendors[self.vendorId].shop.items[itemName].price
    end

    return math.floor(config.Vendors[self.vendorId].shop.items[itemName].price * (config.Vendors[self.vendorId].jobs.jobs[Player.PlayerData.job.name]?.writeUp or config.Vendors[self.vendorId].jobs.noJobPercentage ) / 100)

end

function VendorInventory:addItem(itemName, amount, metadata, source, price)
    if not self.items[itemName] then
        self.items[itemName] = {
            amount = 0,
            basePrice = config.Vendors[self.vendorId].shop.items[itemName].price,
            soldItems = {},
            dynamic = config.Vendors[self.vendorId].shop.items[itemName].dynamic or false
        }
    end
    
    self.items[itemName].amount = self.items[itemName].amount + amount
    
    if metadata then
        self.items[itemName].soldItems[#self.items[itemName].soldItems+1] = {
            metadata = metadata,
            source = source,
            timestamp = os.time()
        }
    end
    
    self:save()
    return true
end

function VendorInventory:removeItem(itemName, amount)
    if not self.items[itemName] then return false end
    
    if self.items[itemName].amount >= amount then
        self.items[itemName].amount = self.items[itemName].amount - amount
        self:save()
        return true
    end
    
    return false
end

function VendorInventory:getStock(itemName)
    if not self.items[itemName] then return 0 end
    return self.items[itemName].amount
end

function VendorInventory:canPurchase(itemName, amount)
    if not self.items[itemName] then return false end
    return self.items[itemName].amount >= amount
end

return VendorInventory 