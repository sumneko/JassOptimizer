local confuser = require 'optimizer.confuser'

local ipairs = ipairs
local pairs = pairs

local jass, report, confuse
local current_function, current_line, has_call
local executes, executed_any
local mark_exp, mark_lines, mark_function

local function get_function(name)
    return jass.functions[name]
end

local function get_arg(name)
    if current_function and current_function.args then
        return current_function.args[name]
    end
end

local function get_local(name)
    if current_function then
        local locals = current_function.locals
        if locals then
            for i = #locals, 1, -1 do
                local loc = locals[i]
                if loc.name == name and loc.line < current_line then
                    return loc
                end
            end
        end
    end
end

local function get_global(name)
    return jass.globals[name]
end

local function get_var(name)
    local var = get_local(name)
    if var then
        return var, 'local'
    end
    local var = get_arg(name)
    if var then
        return var, 'arg'
    end
    local var = get_global(name)
    if var then
        return var, 'global'
    end
end

local function mark_var(var)
    local use_var, type = get_var(var.name)
    if type == 'global' and use_var.file ~= 'war3map.j' then
        return
    end
    use_var.used = true
    if confuse then
        use_var.confused = confuse(var.name)
    end
end

function mark_exp(exp)
    if not exp then
        return
    end
    if exp.type == 'null' or exp.type == 'integer' or exp.type == 'real' or exp.type == 'string' or exp.type == 'boolean' then
    elseif exp.type == 'var' or exp.type == 'vari' then
        mark_var(exp)
    elseif exp.type == 'call' or exp.type == 'code' then
        mark_function(exp)
    end
    for i = 1, #exp do
        mark_exp(exp[i])
    end
end

local function mark_locals(locals)
    for _, loc in ipairs(locals) do
        if loc[1] then
            current_line = loc.line
            has_call = false
            mark_exp(loc[1])
            if has_call then
                loc.used = true
                if confuse then
                    loc.confused = confuse(loc.name)
                end
            end
        end
    end
end

local function mark_execute(line)
    if not executes then
        executes = {}
    end
    local exp = line[1]
    if exp.type == 'string' then
        if get_function(exp.value) then
            mark_function(get_function(exp.value))
        end
        return
    end
    if exp.type == '+' then
        if exp[1].type == 'string' then
            local head = exp[1].value
            executes[head] = true
            report('引用函数', ('引用函数： %s...'):format(head), ('第[%d]行：ExecuteFunc("%s" + ...)'):format(line.line, head))
            return
        end
    end
    if not executed_any then
        executed_any = true
        report('强制引用全部函数', '强制引用全部函数', ('第[%d]行：完全动态的ExecuteFunc'):format(line.line))
    end
end

local function mark_call(line)
    has_call = true
    mark_function(line)
    for _, exp in ipairs(line) do
        mark_exp(exp)
    end
    if line.name == 'ExecuteFunc' then
        mark_execute(line)
    end
end

local function mark_set(line)
    mark_var(line)
    mark_exp(line[1])
end

local function mark_seti(line)
    mark_var(line)
    mark_exp(line[1])
    mark_exp(line[2])
end

local function mark_return(line)
    if line[1] then
        mark_exp(line[1])
    end
end

local function mark_exit(line)
    mark_exp(line[1])
end

local function mark_if(data)
    mark_exp(data.condition)
    mark_lines(data)
end

local function mark_elseif(data)
    mark_exp(data.condition)
    mark_lines(data)
end

local function mark_else(data)
    mark_lines(data)
end

local function mark_ifs(chunk)
    for _, data in ipairs(chunk) do
        if data.type == 'if' then
            mark_if(data)
        elseif data.type == 'elseif' then
            mark_elseif(data)
        else
            mark_else(data)
        end
    end
end

local function mark_loop(chunk)
    mark_lines(chunk)
end

function mark_lines(lines)
    for _, line in ipairs(lines) do
        current_line = line.line
        if line.type == 'call' then
            mark_call(line)
        elseif line.type == 'set' then
            mark_set(line)
        elseif line.type == 'seti' then
            mark_seti(line)
        elseif line.type == 'return' then
            mark_return(line)
        elseif line.type == 'exit' then
            mark_exit(line)
        elseif line.type == 'if' then
            mark_ifs(line)
        elseif line.type == 'loop' then
            mark_loop(line)
        end
    end
end

local function mark_takes(args)
    if not args then
        return
    end
    for _, arg in ipairs(args) do
        if confuse then
            arg.confused = confuse(arg.name)
        end
    end
end

function mark_function(call)
    local func = get_function(call.name)
    if func.native then
        func.used = true
        return
    end
    if confuse and func.file == 'war3map.j' then
        func.confused = confuse(func.name)
    end
    if func.used or func.file ~= 'war3map.j' then
        return
    end
    func.used = true
    local _current_function = current_function
    local _current_line     = current_line
    current_function = func
    mark_takes(func.args)
    mark_locals(func.locals)
    mark_lines(func)
    current_function = _current_function
    current_line     = _current_line
end

local function mark_globals()
    for _, global in ipairs(jass.globals) do
        if global[1] then
            current_line = global.line
            has_call = false
            mark_exp(global[1])
            if has_call then
                global.used = true
                if confuse then
                    global.confused = confuse(global.name)
                end
            end
        end
    end
end

local function mark_executed()
    if not executes then
        return
    end
    for _, func in ipairs(jass.functions) do
        if not func.used then
            local name = func.name
            if executed_any then
                mark_function(func)
            else
                for head in pairs(executes) do
                    if name:sub(1, #head) == head then
                        mark_function(func)
                        break
                    end
                end
            end
        end
    end
end

local function init_confuser(confusion)
    if not confusion then
        return
    end
    local err
    confuse, err = confuser(confusion)
    if not confuse then
        report('脚本混淆失败', '脚本混淆失败', err)
        return
    end

    function confuse:can_use(name)
        local func = get_function(name)
        if func then
            if func.file ~= 'war3map.j' then
                return false
            end
            return true
        end
        local var, type = get_var(name)
        if type == 'global' then
            if var.file ~= 'war3map.j' then
                return false
            end
            return true
        elseif type == 'arg' or type == 'local' then
            return true
        end
        return true
    end
end

return function (ast, config, _report)
    jass = ast
    report = _report

    init_confuser(config.confusion)
    mark_globals()
    mark_function(get_function 'config')
    mark_function(get_function 'main')
    mark_executed()
end
