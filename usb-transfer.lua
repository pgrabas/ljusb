local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'
local bit = require'bit'

ffi.cdef[[
typedef struct ljusb_transfer {
    struct libusb_transfer *handle;
} ljusb_transfer;
]]

ffi.metatype('struct ljusb_transfer', {
    __gc = function(t)
        if t.handle.callback ~= nil then
            t.handle.callback:free()
        end
        core.libusb_free_transfer(t.handle)
    end
})

local usb_transfer = {}
usb_transfer.__index = usb_transfer

function usb_transfer.__new(iso_cnt)
    local tr = {
        ljusb_transfer = ffi.new("ljusb_transfer")
    }
    tr.ljusb_transfer.handle = core.libusb_alloc_transfer(iso_cnt or 0)
    return setmetatable(tr, usb_transfer)
end

function usb_transfer:get_raw_handle()
    local h = self.ljusb_transfer.handle
    assert(h ~= nil)
    return h
end

function usb_transfer:control_setup(bRequestType, bRequest, wValue, wIndex, data)
    self:set_data(data)

    local t = self:get_raw_handle()
    t.buffer[0] = bRequestType
    t.buffer[1] = bRequest
    t.buffer[2] = bit.band(wValue, 0xff)
    t.buffer[3] = bit.band(bit.rshift(wValue, 8), 0xff)
    t.buffer[4] = bit.band(wIndex, 0xff)
    t.buffer[5] = bit.band(bit.rshift(wIndex, 8), 0xff)

    return self
end

function usb_transfer:data()
    local t = self:get_raw_handle()
    if t.actual_length == 0 then
        return ""
    end
    return ffi.string(t.buffer + ffi.C.LIBUSB_CONTROL_SETUP_SIZE, t.actual_length)
end

function usb_transfer:set_data(data)
    local t = self:get_raw_handle()

    if data == nil and t.length >= ffi.C.LIBUSB_CONTROL_SETUP_SIZE then
        return
    end

    local data_len = 0
    if data == nil then
        data = ""
    elseif type(data) == "number" then
        data_len = data
        data = ""
    else
        data_len = data:len()
    end

    local len = ffi.C.LIBUSB_CONTROL_SETUP_SIZE + data_len

    if t.length < len then
        t.buffer = ffi.gc(ffi.C.malloc(len), ffi.C.free)
    end
    if data:len() > 0 then
        ffi.copy(t.buffer + ffi.C.LIBUSB_CONTROL_SETUP_SIZE, data, data:len())
    end

    t.length = len
    t.actual_length = data:len()
    t.buffer[6] = bit.band(data_len, 0xff)
    t.buffer[7] = bit.band(bit.rshift(data_len, 8), 0xff)

    return self
end

function usb_transfer:unpack_data(fmt)
    local struct = require "struct"
    local d = self:data()
    if d:len() > 0 then
        return struct.unpack(fmt, d)
    else
        return nil
    end
end

function usb_transfer:pack_data(fmt, ...)
    local struct = require "struct"
    return self:set_data(struct.pack(fmt, ...))
end

function usb_transfer:submit(dev_hnd, cb, timeout)
    local t = self:get_raw_handle()
    t.dev_handle = dev_hnd:get_raw_handle()
    t.callback = ffi.new('libusb_transfer_cb_fn', function()
        cb(self)
        local t = self:get_raw_handle()
        t.callback:free()
        t.callback = nil
    end)
    t.timeout = timeout or 0
    local err = core.libusb_submit_transfer(t)
    if err ~= ffi.C.LIBUSB_SUCCESS then
        -- print('transfer submit error - ' .. ffi.string(core.libusb_error_name(err)))
        return false, err
    end
    return true
end

return usb_transfer
