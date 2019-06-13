-- Copyright (C) Jingli Chen (Wine93)
-- Copyright (C) Jinzheng Zhang (tianchaijz)


local base = require "resty.addon.base"


local register = base.register
local register_handlers = base.register_handlers
local init = base.init
local run = base.run
local exec = base.exec
local next_handler = base.next_handler


local _handlers = {}
local _inits = {}  -- init worker hooks
local _inits_loaded = {}


local _M = {}
local _mt = { __index = _M }

_M.INIT_WORKER         = -1

_M.REWRITE_PHASE       = 1
_M.ACCESS_PHASE        = 2
_M.CONTENT_PHASE       = 3
_M.HEADER_FILTER_PHASE = 4
_M.BODY_FILTER_PHASE   = 5
_M.LOG_PHASE           = 6


function _M.register(typ, modules)
    register(typ, modules, _M.INIT_WORKER, _M.REWRITE_PHASE, _M.LOG_PHASE,
             _handlers, _inits, _inits_loaded)
end


function _M.register_handlers(registry)
    register_handlers(registry, _M.INIT_WORKER, _M.REWRITE_PHASE, _M.LOG_PHASE,
                      _handlers, _inits, _inits_loaded)
end


function _M.init()
    init(_inits)

    _inits = {}
    _inits_loaded = {}
end


function _M.new(typ)
    local addon = {
        _type = typ,
        _ctx = {},
        _phase = 0,
    }

    return setmetatable(addon, _mt)
end


_M.get_type = base.get_type
_M.set_type = base.set_type

_M.set_phase = base.set_phase
_M.get_phase = base.get_phase

_M.get_module_ctx = base.get_module_ctx
_M.set_module_ctx = base.set_module_ctx


function _M.run(self, phase)
    return run(self, phase, _handlers)
end


function _M.exec(self, typ)
    return exec(self, typ, _handlers)
end


function _M.next_handler(self, module)
    return next_handler(self, module, _handlers)
end


return _M
