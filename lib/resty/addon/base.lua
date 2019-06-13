-- Copyright (C) Jingli Chen (Wine93)
-- Copyright (C) Jinzheng Zhang (tianchaijz)


local pairs = pairs
local ipairs = ipairs
local assert = assert
local table_sort = table.sort


local _M = {}


local function is_tbl(obj) return type(obj) == "table" end


local function load_module_phase(module, phase)
    local phase_ctx
    if is_tbl(module) then
        local export = module.export
        if is_tbl(export) and not export[phase] then
            return
        end

        local ctx = module.ctx
        if is_tbl(ctx) then
            phase_ctx = ctx[phase] or ctx
        end

        module = module[1]
    end

    local mod = assert(require(module), module)

    return module, mod[phase], phase_ctx or {}
end


local function phase_handler(modules, phase)
    local chain
    local index = {}
    for idx = #modules, 1, -1 do
        local module, ph, ctx = load_module_phase(modules[idx], phase)
        if ph then
            chain = { next = chain, handler = ph.handler, ctx = ctx }
            index[module] = chain
        end
    end

    return { chain = chain, index = index }
end


local function register(typ, modules, phase_init, phase_begin, phase_end,
                        handlers, inits, inits_loaded)
    local handler = {}
    for phase = phase_begin, phase_end, 1 do
        handler[phase] = phase_handler(modules, phase)
    end

    handlers[typ] = handler

    for _, mod in ipairs(modules) do
        local module, init, ctx = load_module_phase(mod, phase_init)
        if init and init.handler then
            if not ctx then
                if inits_loaded[module] then
                    ngx.log(ngx.ERR, module,
                            " init multiple times without context")
                else
                    inits_loaded[module] = true
                end
            end

            inits[#inits + 1] = { init.handler, ctx }
        end
    end

    ngx.log(ngx.INFO, "addon registered: ", typ)
end
_M.register = register


function _M.register_handlers(registry, phase_init, phase_begin, phase_end,
                              handlers, inits, inits_loaded)
    local array = {}
    for typ, handler in pairs(registry) do
        if handler.enable ~= false then
            local p = handler.priority or 999
            array[#array + 1] = { p, typ, handler.modules }
        end
    end

    -- lower priorities indicate programs that start first
    table_sort(array, function(a, b) return a[1] < b[1] end)

    for _, handler in ipairs(array) do
        register(handler[2], handler[3], phase_init, phase_begin, phase_end,
                 handlers, inits, inits_loaded)
    end
end


function _M.init(inits)
    local handler, ctx
    for _, init in ipairs(inits) do
        handler, ctx = init[1], init[2]
        handler(ctx)
    end
end


function _M.get_type(self)
    return self._type
end


local function set_type(self, typ)
    self._type = typ
end
_M.set_type = set_type


local function set_phase(self, phase)
    self._phase = phase
end
_M.set_phase = set_phase


function _M.get_phase(self)
    return self._phase
end


function _M.get_module_ctx(self, module)
    return self._ctx[module]
end


function _M.set_module_ctx(self, module, ctx)
    self._ctx[module] = ctx
end


local function run_phase(self, handlers)
    local ph = handlers[self._type][self._phase]
    local chain = ph.chain
    if chain then
        chain.handler(self, chain.ctx)
    end
end


function _M.run(self, phase, handlers)
    local old_phase = self._phase
    set_phase(self, phase)
    run_phase(self, handlers)
    set_phase(self, old_phase)
end


function _M.exec(self, typ, handlers)
    local old_phase = self._phase
    set_type(self, typ)
    run_phase(self, handlers)
    set_phase(self, old_phase)
end


function _M.next_handler(self, module, handlers)
    local ph = handlers[self._type][self._phase]
    if not ph then
        return
    end

    local chain = ph.index[module].next
    if chain then
        return chain.handler(self, chain.ctx)
    end
end


return _M
