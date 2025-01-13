return {
    Vendors = {
        ['vendor1'] = {
            ped = {
                model = 's_m_m_highsec_01',
                coords = vector4(2438.1616, 3971.6055, 36.6422, 180.0),
                scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            },
            blip = {
                enabled = true,
                sprite = 52,
                color = 2,
                scale = 0.8,
                label = 'Vendor Store'
            },
            hours = {
                enabled = false,
                realTime = true, -- If true, the time will use real-life time based on the user's location. If false, the time will use in-game time.
                open = 2,  -- Opening hour (24-hour format)
                close = 8, -- Closing hour (24-hour format)
            },
            jobs = {
                noJobPercentage = 50, -- Default markup percentage
                canNoJobsUse = false, -- Whether unemployed players can use the vendor
                jobs = {
                    ['police'] = {
                        writeUp = 20, -- Job-specific markup percentage
                    },
                },
                noPurchase = {
                    ['police'] = true, -- Prevents selling when this job is on duty
                }
            },
            shop = {
                canSell = true,
                canBuy = true,
                persistInventory = true, -- Saves inventory between server restarts
                items = {
                    ["water"] = {
                        price = 200,
                        amount = 100,
                        dynamic = true, -- Price fluctuates based on supply/demand
                    },
                }
            }
        }
    }
}