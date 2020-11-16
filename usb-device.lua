local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'
local bit = require'bit'

local usb_device_handle = require "ljusb/usb-device-handle"

ffi.cdef[[
typedef struct ljusb_device {
    struct libusb_device *handle;
} ljusb_device;
]]

ffi.metatype('struct ljusb_device', {
    __gc = function(t)
        if t.handle ~= nil then
            core.libusb_unref_device(t.handle)
            t.handle = nil
        end
    end
})

local usb_device = {}
usb_device.__index = usb_device

function usb_device:__tostring()
    return "usb_device"
end

function usb_device.__new(context, device)
    local dev = {
        ljusb_device = ffi.new("ljusb_device") ,
        context = context,
    }
    dev.ljusb_device.handle = core.libusb_ref_device(device)
    if dev.ljusb_device.handle ~= nil then
        return setmetatable(dev, usb_device)
    else
        return nil
    end
end

function usb_device:get_device_port_numbers()
    local max_len = 8 -- libusb doc says limit is 7
    local memory = ffi.gc(ffi.C.malloc(max_len), ffi.C.free)
    local buffer = ffi.cast("uint8_t*", memory)
    local r = core.libusb_get_port_numbers(self:get_raw_handle(), buffer, max_len)
    if r < ffi.C.LIBUSB_SUCCESS then
        return nil, r
    end
    local path = {}
    for i=0,r-1 do
        table.insert(path, buffer[i])
    end
    return path
end

function usb_device:get_device_port_numbers_string(dev)
    local path, err = self:get_device_port_numbers(dev)
    if not path then
        return nil, err
    end
    local s = {}
    for _,v in ipairs(path) do
        table.insert(s, tostring(v))
    end
    return table.concat(s, ".")
end

function usb_device:get_raw_handle()
    local h = self.ljusb_device.handle
    assert(h ~= nil)
    return h
end

function usb_device:open()
    --TODO store as weak
    return usb_device_handle.__open_device(self.context, self)
end

function usb_device:get_descriptor()
    if not self.descriptor then
        local desc = ffi.new("struct libusb_device_descriptor ")
        local r = core.libusb_get_device_descriptor(self:get_raw_handle(), desc)
        if r == ffi.C.LIBUSB_SUCCESS then
            self.descriptor = desc
            return desc
        end
        error("Failed to get device descriptor: " .. error_str(r))
    end
    return self.descriptor
end

function usb_device:get_vid_pid()
    local d = self:get_descriptor()
    return { vid=d.idVendoridVendor, pid=d.idProduct }
end

function usb_device:get_product_manufacturer_serial()
    local d = self:get_descriptor()
    local h, c = self:open()
    if not h then
        return nil, c
    end
    local product = h:get_string_descriptor_ascii(d.iProduct)
    local manufacturer = h:get_string_descriptor_ascii(d.iManufacturer)
    local serial = h:get_string_descriptor_ascii(d.iSerialNumber)
    return { product=product, manufacturer=manufacturer, serial=serial }
end

return usb_device
