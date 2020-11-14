local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'
local bit = require'bit'

local usb_transfer = {}

function usb_transfer.__gc(t)
    print("collecting transfer")
    core.libusb_free_transfer(t)
end

ffi.metatype('struct libusb_transfer', {
    __index = usb_transfer,
    __gc = usb_transfer.__gc,
})

function usb_transfer.control_setup(t, bmRequestType, bRequest, wValue, wIndex, wLength, data)
--data is optional and only applies on host-to-device transfers
    local len = ffi.C.LIBUSB_CONTROL_SETUP_SIZE + wLength

    print("wValue " .. type(wValue) .. " - " .. tostring(wValue))
    print("wIndex/dev/bus/usb/001/009: " .. type(wIndex) .. " - " .. tostring(wIndex))
    print("wLength " .. type(wLength) .. " - " .. tostring(wLength))

    if t.length < len then
        t.buffer = ffi.C.realloc(t.buffer, len)
        assert(len == 0 or t.buffer ~= nil, "out of memory")
    end
    t.length = len
    t.buffer[0] = bmRequestType
    t.buffer[1] = bRequest
    t.buffer[2] = bit.band(wValue, 0xff)
    t.buffer[3] = bit.band(bit.rshift(wValue, 8), 0xff)
    t.buffer[4] = bit.band(wIndex, 0xff)
    t.buffer[5] = bit.band(bit.rshift(wIndex, 8), 0xff)
    t.buffer[6] = bit.band(wLength, 0xff)
    t.buffer[7] = bit.band(bit.rshift(wLength, 8), 0xff)

    if data ~= nil and bit.band(bmRequestType, 0x80) == 0 then
        --host to device transfer with data
        ffi.copy(t.buffer + ffi.C.LIBUSB_CONTROL_SETUP_SIZE, data, wLength)
    end
    return t
end

function usb_transfer.submit(t, dev_hnd, cb, timeout)
    t.dev_handle = dev_hnd
    t.callback = ffi.new('libusb_transfer_cb_fn', function(trf) cb(trf) end)
    t.timeout = timeout or 0
    local err = core.libusb_submit_transfer(t)
    if err ~= ffi.C.LIBUSB_SUCCESS then
        print('transfer submit error - ' .. ffi.string(core.libusb_error_name(err)))
        return false, ffi.string(core.libusb_error_name(err))
    end
    return true
end
