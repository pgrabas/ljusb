local ffi = require'ffi'
local bit = require'bit'
local core = require'ljusb/ljusb_ffi_core'

local bor, band, lshift, rshift = bit.bor, bit.band, bit.lshift, bit.rshift
local new, typeof, metatype = ffi.new, ffi.typeof, ffi.metatype
local cast, C = ffi.cast, ffi.C

--need those for buffer management
ffi.cdef[[
void * malloc (size_t size);
void * realloc (void *ptr, size_t size);
void * memmove (void *destination, const void *source, size_t num);
void free (void *ptr);
]]

local little_endian = ffi.abi'le'
local libusb_control_setup_ptr = typeof'struct libusb_control_setup *'

local libusb_cpu_to_le16 = function(i)
  i = band(i, 0xffff)
  if little_endian then
    return i
  else
    return bor(lshift(i, 8), rshift(i, 8))
  end
end

local usb_context = require "ljusb/usb-context"

local ctx_methods = {
  libusb_cpu_to_le16 = libusb_cpu_to_le16,

  libusb_fill_control_transfer = function(trf, dev_hnd, buffer, cb, user_data, timeout)
    local setup = cast(libusb_control_setup_ptr, buffer)
    trf.dev_handle = dev_hnd
    trf.endpoint = 0
    trf.type = core.LIBUSB_TRANSFER_TYPE_CONTROL
    trf.timeout = timeout
    trf.buffer = buffer
    if setup ~= nil then
      trf.length = core.LIBUSB_CONTROL_SETUP_SIZE +
          libusb_le16_to_cpu(setup.wLength)
    end
    trf.user_data = user_data
    trf.callback = cb
  end,

  has_hotplug_capatibility = function(usb)
    return core.libusb_has_capability(usb, code.LIBUSB_CAP_HAS_HOTPLUG) > 0
  end,
}

return usb_context.__new()
