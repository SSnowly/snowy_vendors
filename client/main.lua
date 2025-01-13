local config = require 'config.shared'
local vendors = config.Vendors
local Vendor = require 'client.classes.vendor'
local trackedVendors = {}

function ValidateVendor(vendorId)
    local vendor = vendors[vendorId]
    local item = 0
    if not vendor then return false end
    local items = vendor.shop.items
    local itemCount = 0
    for _ in pairs(items) do
        itemCount = itemCount + 1
    end
    for currentItem, _ in pairs(items) do
        if not exports.ox_inventory:Items()[currentItem] then
            lib.print.error('Vendor ' .. vendorId .. ' is missing item: ' .. currentItem)
            item = item + 1
        end
    end
    if item > 0 and itemCount <= item then
        lib.print.error('Vendor ' .. vendorId .. ' is missing all items, this will disable it')
        return false
    end
    return true
end

function RegisterVendors()
    if not vendors then return end

    for vendorId, vendorData in pairs(vendors) do
        vendorData.id = vendorId
        trackedVendors[vendorId] = Vendor.new(vendorData)
    end
end

function RemoveVendors()
    for _, vendor in pairs(trackedVendors) do
        if vendor.entity and DoesEntityExist(vendor.entity) then
            if vendor.target then
                exports.ox_target:removeLocalEntity(vendor.target)
                vendor.target = nil
            end
            DeleteEntity(vendor.entity)
            vendor.entity = nil
        end
        vendor.blips.remove()
        vendor.point:remove()
    end
end
CreateThread(function()
    RegisterVendors()
end)

lib.callback.register('snowy_vendors:getCurrentInGameTime', function()
    return GetClockHours()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RemoveVendors()
    end
end)
