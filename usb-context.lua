local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'
local bit = require'bit'

local usb_device_list = require "ljusb/usb-device-list"
local usb_device_handle = require "ljusb/usb-device-handle"
local usb_transfer = require "ljusb/usb-transfer"

ffi.cdef[[
typedef struct ljusb_context {
    struct libusb_context* handle[1];
} ljusb_context;
]]

ffi.metatype('struct ljusb_context', {
    __gc = function(t)
        if t.handle ~= nil then
            core.libusb_close(t.handle[0])
            t.handle[0] = nil
        end
    end
})

local usb_context = {}
usb_context.__index = function(_, k)
    return rawget(usb_context, k) or core[k]
end

usb_context.get_device_list = usb_device_list.__new
usb_context.iterate_devices = usb_device_list.__iterate
usb_context.iterate_devices_by_vid_pid = usb_device_list.__iterate_by_vid_pid
usb_context.new_transfer = usb_transfer.__new

function usb_context:__tostring()
    return "usb_context"
end

function usb_context.__new()
    local ctx = {
        ljusb_context = ffi.new("ljusb_context"),
    }

    assert(core.libusb_init(ctx.ljusb_context.handle) == ffi.C.LIBUSB_SUCCESS)

    return setmetatable(ctx, usb_context)
end

function usb_context:get_raw_handle()
    local h = self.ljusb_context.handle[0]
    assert(h ~= nil)
    return h
end

function usb_context:close()
    core.libusb_close(self:get_raw_handle())
end

function usb_context:get_version()
    local v = core.libusb_get_version()
    return string.format("libusb %i.%i.%i.%i", v.major, v.minor, v.micro, v.nano)
end

function usb_context:has_log_callback()
    local v = core.libusb_get_version()
    return v.micro >= 23
end

function usb_context:set_log_level(level)
    core.libusb_set_debug(self:get_raw_handle(), level)
end

-- function usb_context:set_log_callback(callback)
    -- TODO
    -- local usb_cb = new('libusb_log_cb', function(ctx, level, str)
    --   local text = ffi.string(str)
    --   cb(level, text)
    -- end)
    -- core.libusb_set_log_cb(usb, usb_cb, core.LIBUSB_LOG_CB_CONTEXT)
-- end

function usb_context:open_device_with_vid_pid(vid, pid)
    local h = core.libusb_open_device_with_vid_pid(self:get_raw_handle(), vid, pid)
    if h ~= nil then
      return usb_device_handle.__claim_handle(self, h)
    end
    return nil
end

function usb_context:find_devices_by_vid_pid(vid, pid)
    local r = {}
    self:iterate_devices_by_vid_pid(function(dev) table.insert(r, dev) end, vid, pid)
    return r
end

function usb_context:pool(time_seconds)
    local tv = ffi.new'struct timeval[1]'
    tv[0].tv_sec = time_seconds or 0
    tv[0].tv_usec = 0
    core.libusb_handle_events_timeout_completed(self:get_raw_handle(), tv, nil)
end

function usb_context:error_string(code)
	return ffi.string(core.libusb_error_name(code))
end

return usb_context
