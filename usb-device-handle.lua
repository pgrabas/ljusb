local core = require'ljusb/ljusb_ffi_core'
local ffi = require'ffi'

local usb_device_handle = {}
ffi.metatype('struct libusb_device_handle', { __index = usb_device_handle })

function usb_device_handle:close()
  core.libusb_close(self)
end

