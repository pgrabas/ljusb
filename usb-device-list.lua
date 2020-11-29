local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'
local bit = require'bit'

local usb_device = require "ljusb/usb-device"

ffi.cdef[[
typedef struct ljusb_device_list {
    struct libusb_device **handle[1];
} ljusb_device_list;
]]

local usb_device_list = {}
usb_device_list.__index = usb_device_list

function usb_device_list.__gc(t)
    if t.handle[0] ~= nil then
      core.libusb_free_device_list(t.handle[0], 1)
      t.handle[0] = nil
    end
end

function usb_device_list.__new(context)
    local object = {
        ljusb_device_list = ffi.new("ljusb_device_list"),
        count = 0,
        context = context,
    }
    local r = core.libusb_get_device_list(context:get_raw_handle(), object.ljusb_device_list.handle)
    if r > 0 then
        object.count = r
    end
    return setmetatable(object, usb_device_list)
end

function usb_device_list.__iterate(context, func)
    local lst = usb_device_list.__new(context)
    for dev in lst:iterator() do
        func(dev)
    end
end

function usb_device_list.__iterate_by_vid_pid(context, func, vid, pid)
    usb_device_list.__iterate(context, function(dev)
        local vp = dev:get_vid_pid()
        if not vp then
            --TODO
        else
            if vp.vid == vid and vp.pid == pid then
                func(dev)
            end
        end
    end)
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
        local dev = self.ljusb_device_list.handle[0][pos]
        pos = pos + 1
        return usb_device.__new(self.context, dev)
    end
end

return usb_device_list
