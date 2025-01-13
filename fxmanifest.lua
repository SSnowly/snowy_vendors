--[[ FX Information ]]--
fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'nuh'
game         'gta5'

author 'Snowy'
description 'Vendor system'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}
server_scripts {
    'server/*.lua'
}
client_scripts {
    'client/*.lua',
    'client/classes/*.lua',
    '@qbx_core/modules/playerdata.lua'
}
files {
    'config/shared.lua',
    'client/classes/*.lua',
    'data/*.json'
}
