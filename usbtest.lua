local ffi = require'ffi'
local usb = require'ljusb'

local usb = require'ljusb'

print(usb:get_version())

usb:set_log_level(usb.LIBUSB_LOG_LEVEL_INFO)

usb:iterate_devices(function(dev)
  local i = dev:get_product_manufacturer_serial() or {}
  print(dev:get_device_port_numbers_string(), i.product or "", i.manufacturer or "", i.serial or "")
end)

