local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'

local function error_str(code)
	return ffi.string(core.libusb_error_name(code))
end

ffi.cdef[[
typedef struct ljusb_device_handle {
    struct libusb_device_handle *handle[1];
} ljusb_device_handle;
]]

ffi.metatype('struct ljusb_device_handle', {
    __gc = function(t)
        if t.handle[0] ~= nil then
            core.libusb_close(t.handle[0])
            t.handle[0] = nil
        end
    end
})

local usb_device_handle = {}
usb_device_handle.__index = usb_device_handle

function usb_device_handle:__tostring()
    return "usb_device_handle"
end

function usb_device_handle.__open_device(context, device)
    local h = {
        ljusb_device_handle = ffi.new("ljusb_device_handle") ,
        context = context,
        -- device = device -- TODO as weak
    }
    local r = core.libusb_open(device:get_raw_handle(), h.ljusb_device_handle.handle)
    if r == ffi.C.LIBUSB_SUCCESS then
        return setmetatable(h, usb_device_handle)
    end
    return nil, r
end

function usb_device_handle.__claim_handle(context, handle)
    local h = {
        ljusb_device_handle = ffi.new("ljusb_device_handle") ,
        context = context,
    }
    h.ljusb_device_handle.handle[0] = handle
    return setmetatable(h, usb_device_handle)
end

function usb_device_handle:get_raw_handle()
    local h = self.ljusb_device_handle.handle[0]
    assert(h ~= nil)
    return h
end

function usb_device_handle:get_string_descriptor_ascii(index)
    local max_len = 256
    local memory = ffi.gc(ffi.C.malloc(max_len), ffi.C.free)
    local buffer = ffi.cast("unsigned char*", memory)
    local r = core.libusb_get_string_descriptor_ascii(self:get_raw_handle(), index, buffer, max_len)
    if r < ffi.C.LIBUSB_SUCCESS then
        return nil, r
    end
    return ffi.string(buffer, r)
end


function usb_device_handle:get_device()
    if self.device then
        return self.device
    else
        local usb_device = require "ljusb/usb-device"
        --self.device =
        local h = self:get_raw_handle()
        return usb_device.__new(self.context, core.libusb_get_device(h))
    end
end

return usb_device_handle
