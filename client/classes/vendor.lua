local VendorMenu = require 'client.classes.menu'
local Vendor = {}
Vendor.__index = Vendor

---@class Vendor
---@field id string
---@field coords vector3
---@field model string|number
---@field scenario? string
---@field point CPoint
---@field entity number

---Creates a new vendor instance
---@param data table
---@return Vendor
function Vendor.new(data)
    if not ValidateVendor(data.id) then return end
    local self = setmetatable({}, Vendor)
    self.id = data.id
    self.coords = data.ped.coords
    self.model = data.ped.model
    self.scenario = data.ped.scenario
    self.blip = nil
    self.blipData = data.blip
    self.blips = {}
    self.target = {}
    local options = {
        {
            label = 'Talk to Vendor',
            icon = 'fas fa-comments',
            distance = 2.0,
            onSelect = function(data)
                self:use()
            end
        }
    }
    self.point = lib.points.new({
        coords = self.coords,
        distance = 50,
    })

    function self.point:onEnter()
        self:spawn()
    end

    function self.point:onExit() 
        self:despawn()
    end

    self.point.spawn = function()
        if not self.entity or not DoesEntityExist(self.entity) then
            lib.requestModel(self.model)
            self.entity = CreatePed(0, self.model, self.coords.x, self.coords.y, self.coords.z - 1.0, self.coords.w or 0.0, false, false)
            SetEntityAsMissionEntity(self.entity, true, true)
            SetBlockingOfNonTemporaryEvents(self.entity, true)
            SetPedCanRagdollFromPlayerImpact(self.entity, false)
            FreezeEntityPosition(self.entity, true)
            SetEntityInvincible(self.entity, true)
            if self.scenario then
                TaskStartScenarioInPlace(self.entity, self.scenario, 0, true)
            end

            self.target = exports.ox_target:addLocalEntity(self.entity, options)
        end
    end

    self.point.despawn = function()
        if self.entity and DoesEntityExist(self.entity) then
            if self.target then
                exports.ox_target:removeLocalEntity(self.target)
                self.target = nil
            end
            DeleteEntity(self.entity)
            self.entity = nil
        end
    end

    self.use = function()
        local menu = VendorMenu.new(self.id)
        menu:show()
    end
    
    function self.blips.create()
        self.blip = AddBlipForCoord(self.coords.x, self.coords.y, self.coords.z)
        SetBlipSprite(self.blip, self.blipData.sprite)
        SetBlipDisplay(self.blip, 4)
        SetBlipScale(self.blip, self.blipData.scale)
        SetBlipColour(self.blip, self.blipData.color)
        SetBlipAsShortRange(self.blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(self.blipData.label)
        EndTextCommandSetBlipName(self.blip)
    end

    self.blips.remove = function ()
        if self.blip then
            RemoveBlip(self.blip)
            self.blip = nil
        end
    end

    self.blips.create()

    return self
end
return Vendor 