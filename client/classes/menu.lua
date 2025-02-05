local config = require 'config.shared'

---@class VendorMenu
VendorMenu = {}
VendorMenu.__index = VendorMenu

---@param vendorId number
---@return VendorMenu
function VendorMenu.new(vendorId)
    local self = setmetatable({}, VendorMenu)
    self.vendorId = vendorId
    self.vendorConfig = config.Vendors[vendorId]
    return self
end

function VendorMenu:openShop()
    if self.vendorConfig.hours.enabled then
        local currentHour
        if self.vendorConfig.hours.realTime then
            currentHour = lib.callback.await('snowy_vendors:getCurrentTime', false)
        else
            currentHour = GetClockHours()
        end
    
        if currentHour < self.vendorConfig.hours.open or currentHour >= self.vendorConfig.hours.close then
            lib.notify({
                title = 'Vendor',
                description = ('This vendor is closed. Open from %d:00 to %d:00'):format(
                    self.vendorConfig.hours.open,
                    self.vendorConfig.hours.close
                ),
                type = 'error'
            })
            return
        end
    end

    local foundJob = false
    if self.vendorConfig.jobs.blacklisted then
        for _, job in pairs(self.vendorConfig.jobs.blacklisted) do
            if QBX.PlayerData.job.name == job then
                foundJob = true
                break
            end
        end
    end
    if foundJob then
        lib.notify({
            title = 'Vendor',
            description = 'You are not allowed to use this vendor',
            type = 'error'
        })
        return
    end

    local isRestrictedJob = false
    if self.vendorConfig.jobs.blacklisted then
        for _, jobName in pairs(self.vendorConfig.jobs.blacklisted) do
            if QBX.PlayerData.job.name == jobName and QBX.PlayerData.job.onduty then
                isRestrictedJob = true
                break
            end
        end
    end

    if isRestrictedJob or (not self.vendorConfig.jobs.canNoJobsUse and QBX.PlayerData.job == "unemployed") then
        lib.notify({
            title = 'Vendor',
            description = 'You cannot use this vendor while on duty',
            type = 'error'
        })
        return
    end

    local options = self:getItemOptions()

    lib.registerContext({
        id = 'vendor_shop_' .. self.vendorId,
        title = 'Vendor Shop',
        menu = 'vendor_menu_' .. self.vendorId,
        options = options
    })

    lib.showContext('vendor_shop_' .. self.vendorId)
end

function VendorMenu:show()
    self:openShop()
end


function VendorMenu:close()
    lib.hideContext()
end


---@return table
function VendorMenu:getItemOptions()
    local options = {}

    local stockData = lib.callback.await('snowy_vendors:getVendorStock', false, self.vendorId)

    for itemName, itemData in pairs(self.vendorConfig.shop.items) do
        local metadata = exports.ox_inventory:Items()[itemName]
        if metadata then
            local stock = stockData[itemName]
            if stock then
                local price = itemData.price
                local currentStock = stock.stock

                local buyPrice = math.floor(price * (config.Vendors[self.vendorId].jobs.jobs[QBX.PlayerData.job.name]?.writeUp or config.Vendors[self.vendorId].jobs.noJobPercentage ) / 100)

                local description = ('Price: $%d'):format(buyPrice)
                if stock.dynamic then
                    description = description .. ('\nStock: %d'):format(currentStock)
                    if currentStock <= 0 then
                        description = description .. '\nOut of Stock'
                    end
                end

                if metadata.client then
                    if metadata.client.image then
                        imageName = metadata.client.image
                    elseif metadata.client.imageurl then
                        imageName = metadata.client.imageurl
                    end
                else
                    imageName = 'nui://ox_inventory/web/images/' .. itemName .. '.png'
                end

                options[#options+1] = {
                    title = metadata.label,
                    description = description,
                    icon = imageName,
                    onSelect = function()
                        self:showItemMenu(itemName, {
                            price = buyPrice,
                            stock = currentStock,
                            dynamic = stock.dynamic,
                            percentaje = percentaje,
                            metadata = iteminfo,
                        })
                    end
                }
            end
        else
            lib.print.error('Item ' .. itemName .. ' not found in ox_inventory items table')
        end
    end

    return options
end

---@param itemName string
---@param itemData table
function VendorMenu:showItemMenu(itemName, itemData)
    local options = {}

    if self.vendorConfig.shop.canBuy then
        options[#options+1] = {
            title = 'Buy',
            icon = 'fas fa-shopping-cart',
            disabled = itemData.stock <= 0,
            description = ('Price: $%d'):format(math.floor(itemData.price)) .. (itemData.stock <= 0 and '\nOut of Stock' or ''),
            onSelect = function()
                local input = lib.inputDialog('Buy Item', {
                    { type = 'number', label = 'Amount', default = 1, min = 1, max = itemData.dynamic and itemData.stock or 100 }
                })

                if input then
                    local success, result = lib.callback.await('snowy_vendors:buyItem', false, self.vendorId, itemName, input[1])
                    lib.notify({
                        title = success and 'Success' or 'Error',
                        description = result or (success and 'Purchase successful' or 'Purchase failed'),
                        type = success and 'success' or 'error'
                    })

                    if success then
                        self:openShop()
                    end
                end
            end
        }
    end

    local canSell = lib.callback.await('snowy_vendors:canSell', false, self.vendorId)
    if self.vendorConfig.shop.canSell then
        options[#options+1] = {
            title = 'Sell',
            icon = 'fas fa-dollar-sign',
            disabled = not canSell,
            description = canSell and ('Price: $%d / each'):format(itemData.price * 0.7) or 'You cannot sell to this vendor at this time',
            onSelect = function()
                local amount = lib.callback.await('snowy_vendors:getPlayerItem', false, itemName)
                if amount <= 0 then
                    lib.notify({ type = 'error', description = "You don't have any of this item" })
                    return
                end

                local input = lib.inputDialog('Sell Item', {
                    { type = 'number', label = 'Amount', default = 1, min = 1, max = amount }
                })

                if input then
                    local success, result = lib.callback.await('snowy_vendors:sellItem', false, self.vendorId, itemName, input[1])
                    lib.notify({
                        title = success and 'Success' or 'Error',
                        description = result and (success and ('Sold for $%d'):format(result) or result) or (success and 'Sale successful' or 'Sale failed'),
                        type = success and 'success' or 'error'
                    })

                    if success then
                        self:openShop()
                    end
                end
            end
        }
    end
    if not (self.vendorConfig.shop.canSell and canSell) and not self.vendorConfig.shop.canBuy then
        lib.print.error('Vendor ' .. self.vendorId .. ' has no buy or sell options')
        return lib.notify({ type = 'error', description = 'Vendor has no buy or sell options, this is a bug, please contact server' })
    end

    lib.registerContext({
        id = 'vendor_item_' .. itemName,
        title = exports.ox_inventory:Items()[itemName].label,
        menu = 'vendor_shop_' .. self.vendorId,
        options = options
    })

    lib.showContext('vendor_item_' .. itemName)
end

return VendorMenu
