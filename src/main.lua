(function()
	local exepath = package.cpath:sub(1, package.cpath:find(';')-6)
	package.path = package.path .. ';' .. exepath .. '..\\src\\?.lua'
	package.path = package.path .. ';' .. exepath .. '..\\src\\?\\init.lua'
end)()

require 'filesystem'
require 'utility'
fs.current_path(fs.path(arg[0]):parent_path():parent_path())
local parser = require 'parser'
local optimizer = require 'optimizer'

local function format_error(info)
    return ([[[%s]%s:%d:  %s]]):format(info.level, info.file, info.line, info.err)
end

local function main()
    if arg[1] then
        local exepath  = package.cpath:sub(1, package.cpath:find(';')-6)
        local root     = fs.path(exepath):parent_path():parent_path()
        local common   = io.load(root / 'common.j') or io.load(root / 'src' / 'jass' / 'common.j')
        local blizzard = io.load(root / 'blizzard.j') or io.load(root / 'src' / 'jass' / 'blizzard.j')

        local path = fs.path(arg[1])
        local jass = io.load(path)

        local option = {}
        local ast
        local suc, e = xpcall(function()
            ast = parser.parser(common,   'common.j',   option)
            ast = parser.parser(blizzard, 'blizzard.j', option)
            ast = parser.parser(jass,     'war3map.j',  option)
        end, debug.traceback)
        if not suc then
            print(e)
            return
        end

        for _, error in ipairs(option.errors or {}) do
            print(format_error(error))
        end

        local config = {}
        config.confusion = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
        config.confused = true

        local buf, report = optimizer(ast, option.state, config)
        io.save(root / 'optimized.j', buf)

        print('正在对优化后的代码进行语法检查，可能会和源代码的检查有重复的警告信息...')
        option = {}
        parser.checker(common,   'common.j', option)
        parser.checker(blizzard, 'blizzard.j', option)
        local errors = parser.checker(buf, 'war3map.j', option)
        if #errors > 0 then
            for _, error in ipairs(errors) do
                print(format_error(error))
            end
            return
        end

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
