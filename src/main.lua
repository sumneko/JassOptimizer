(function()
	local exepath = package.cpath:sub(1, package.cpath:find(';')-6)
	package.path = package.path .. ';' .. exepath .. '..\\src\\?.lua'
	package.path = package.path .. ';' .. exepath .. '..\\src\\?\\init.lua'
end)()

require 'filesystem'
require 'utility'
local parser = require 'parser'
local optimizer = require 'optimizer'

local function main()
    if arg[1] then
        local exepath  = package.cpath:sub(1, package.cpath:find(';')-6)
        local root     = fs.path(exepath):parent_path():parent_path()
        local common   = io.load(root / 'src' / 'jass' / 'common.j')
        local blizzard = io.load(root / 'src' / 'jass' / 'blizzard.j')

        local path = fs.path(arg[1])
        local jass = io.load(path)

        local option = {}
        local ast
        local suc, e = xpcall(function()
            ast = parser.parser(common,   'common.j',   option)
            ast = parser.parser(blizzard, 'blizzard.j', option)
            ast = parser.parser(jass,     'war3map.j',  option)
        end, debug.traceback)

        local config = {}
        config.confusion = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'

        local buf, report = optimizer(ast, option.state, config)
        io.save(root / 'optimized.j', buf)
        for type, msgs in pairs(report) do
            for _, msg in ipairs(msgs) do
                print(type, msg[1], msg[2])
            end
        end
    else
        
    end
    print('完成', os.clock())
end

main()
