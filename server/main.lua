local config = require 'config.shared'
local VendorInventory = require 'server.classes.inventory'

local vendors = config.Vendors
local vendorInventories = {}

for vendorId, _ in pairs(vendors) do
    vendorInventories[vendorId] = VendorInventory.new(vendorId)
end

lib.callback.register('snowy_vendors:getVendorStock', function(source, vendorId)
    vendorInventories[vendorId]:load()

    local inventory = vendorInventories[vendorId]
    if not inventory then return {} end

    local stockData = {}
    for itemName, itemData in pairs(vendors[vendorId].shop.items) do
        stockData[itemName] = {
            stock = inventory:getStock(itemName),
            price = inventory:getDynamicPrice(source, itemName) or itemData.price,
            dynamic = itemData.dynamic or false
        }
    end

    return stockData
end)

lib.callback.register('snowy_vendors:buyItem', function(source, vendorId, itemName, amount)
    vendorInventories[vendorId]:load()

    local vendor = vendors[vendorId]
    local inventory = vendorInventories[vendorId]
    if not vendor or not inventory then return false, "Invalid vendor" end

    if vendor.hours.enabled then
        local currentHour
        if vendor.hours.realTime then
            currentHour = os.date("*t").hour
        else
            currentHour = lib.callback.await('snowy_vendors:getCurrentInGameTime', source)
        end

        if currentHour < vendor.hours.open or currentHour >= vendor.hours.close then
            return false, "This vendor is currently closed"
        end
    end

    if not inventory:canPurchase(itemName, amount) then
        return false, "Not enough stock"
    end

    local price = inventory:getDynamicPrice(source, itemName) or vendor.shop.items[itemName].price
    if not price then return false, "Invalid item" end

    local totalPrice = price * amount
    local money = exports.ox_inventory:GetItem(source, 'money', nil, true)
    if money < totalPrice then
        return false, "Not enough money"
    end

    if exports.ox_inventory:RemoveItem(source, 'money', totalPrice) then
        if exports.ox_inventory:AddItem(source, itemName, amount) then
            inventory:removeItem(itemName, amount)
            return true
        else
            exports.ox_inventory:AddItem(source, 'money', totalPrice)
            return false, "Inventory full"
        end
    end

    return false, "Transaction failed"
end)

lib.callback.register('snowy_vendors:sellItem', function(source, vendorId, itemName, amount)
    vendorInventories[vendorId]:load()

    local vendor = vendors[vendorId]
    local inventory = vendorInventories[vendorId]
    if not vendor or not inventory then return false, "Invalid vendor" end

    if vendor.hours.enabled then
        local currentHour
        if vendor.hours.realTime then
            currentHour = os.date("*t").hour
        else
            currentHour = lib.callback.await('snowy_vendors:getCurrentInGameTime', source)
        end
        
        if currentHour < vendor.hours.open or currentHour >= vendor.hours.close then
            return false, "This vendor is currently closed"
        end
    end
    if not CanSell(source, vendorId) then
        return false, "You cannot sell to this vendor at this time"
    end

    local item = exports.ox_inventory:GetItem(source, itemName, nil, true)
    if not item or item < amount then
        return false, "You don't have enough items"
    end

    local basePrice = inventory:getDynamicPrice(source, itemName) or vendor.shop.items[itemName].price
    local sellPrice = math.floor(basePrice * (vendor.shop.items[itemName].percentage or 1))
    local totalPrice = sellPrice * amount

    if exports.ox_inventory:RemoveItem(source, itemName, amount) then
        if exports.ox_inventory:AddItem(source, 'money', totalPrice) then
            local itemData = exports.ox_inventory:GetItem(source, itemName, nil, false)
            inventory:addItem(itemName, amount, itemData?.metadata, source, sellPrice)
            return true, totalPrice
        else
            exports.ox_inventory:AddItem(source, itemName, amount)
            return false, "Transaction failed"
        end
    end

    return false, "Transaction failed"
end)

lib.callback.register('snowy_vendors:getCurrentTime', function()
    return os.date("*t").hour
end)

lib.callback.register('snowy_vendors:getPlayerItem', function(source, itemName)
    return exports.ox_inventory:GetItem(source, itemName, nil, true) or 0
end)

function CanSell(source, vendorId)
    local vendor = vendors[vendorId]
    if not vendor then return false end
    
    local Players = exports.qbx_core:GetQBPlayers()

    for src, Player in pairs(Players) do
        if vendor.jobs?.noPurchase?[Player.PlayerData.job.name] and Player.PlayerData.job.onduty and src ~= source then
            lib.print.debug(("Found player %s with job %s on duty"):format(src, Player.PlayerData.job.name))
            return false
        end
    end
    return true
end

lib.callback.register('snowy_vendors:canSell', function (source, vendorId)
    return CanSell(source, vendorId)
end)

