local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'
local bit = require'bit'

local usb_device = require "ljusb/usb-device"

ffi.cdef[[
typedef struct ljusb_device_list {
    struct libusb_device **handle[1];
    struct libusb_context *ctx;
    int count;
} ljusb_device_list;
]]

local usb_device_list = {}
usb_device_list.__index = usb_device_list
ffi.metatype('struct ljusb_device_list', usb_device_list)

function usb_device_list.__gc(t)
    if t.handle[0] ~= nil then
      core.libusb_free_device_list(t.handle[0], 1)
      t.handle[0] = nil
    end
end

function usb_device_list.__new(ctx)
    local list = ffi.new("ljusb_device_list")
    list.ctx = ctx
    list.count = 0
    local r = core.libusb_get_device_list(ctx, list.handle)
    if r > 0 then
      list.count = r
    end
    return list
end

function usb_device_list:len()
    return self.count
end

function usb_device_list:iterator()
    local pos = 0
    return function()
        if pos >= self.count then
            return nil
        end
        local dev = self.handle[0][pos]
        pos = pos + 1
        return usb_device.__new(ctx, dev)
    end
end

return usb_device_list
