local ffi = require'ffi'
local bit = require'bit'
local core = require'ljusb_ffi_core'

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

--contains Lua-implementations of all the libusb static-inline
--functions, plus the higher level Lua API
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

  transfer = function(iso_cnt)
    local trf = core.libusb_alloc_transfer(iso_cnt or 0)
    return trf
  end,

  pool = function(usb, time_seconds)
    local tv = ffi.new'timeval[1]'
    tv[0].tv_sec = time_seconds or 0
    tv[0].tv_usec = 0
    usb:libusb_handle_events_timeout_completed(tv, nil)
  end,

  get_version = function(usb)
    local v = usb.libusb_get_version()
    return string.format("libusb v%i.%i.%i.%i", v.major, v.minor, v.micro, v.nano)
  end,

  set_log_level = function(usb, level)
    core.libusb_set_debug(usb, level)
  end,
  has_log_callback = function(usb)
    local v = usb.libusb_get_version()
    return v.micro >= 23
  end,
  set_log_callback = function(usb, callback)
    local usb_cb = new('libusb_log_cb', function(ctx, level, str)
      local text = ffi.string(str)
      cb(level, text)
    end)
    core.libusb_set_log_cb(usb, usb_cb, core.LIBUSB_LOG_CB_CONTEXT)
  end,
}

metatype('struct libusb_context', {
  __index = function(_, k)
    return ctx_methods[k] or core[k]
  end,
})

metatype('struct libusb_transfer', {
  __index = {
    control_setup = function(t, bmRequestType, bRequest, wValue, wIndex, wLength, data)
      --data is optional and only applies on host-to-device transfers
      local len = C.LIBUSB_CONTROL_SETUP_SIZE + wLength

      if t.length < len then
        t.buffer = C.realloc(t.buffer, len)
        assert(len == 0 or t.buffer ~= nil, "out of memory")
      end
      t.length = len
      t.buffer[0] = bmRequestType
      t.buffer[1] = bRequest
      t.buffer[2] = band(wValue, 0xff)
      t.buffer[3] = band(rshift(wValue, 8), 0xff)
      t.buffer[4] = band(wIndex, 0xff)
      t.buffer[5] = band(rshift(wIndex, 8), 0xff)
      t.buffer[6] = band(wLength, 0xff)
      t.buffer[7] = band(rshift(wLength, 8), 0xff)

      if data ~= nil and band(bmRequestType, 0x80) == 0 then
        --host to device transfer with data
        copy(t.buffer + C.LIBUSB_CONTROL_SETUP_SIZE, data, wLength)
      end
      return t
    end,
    submit = function(t, dev_hnd, cb, timeout)
      t.dev_handle = dev_hnd
      t.callback = new('libusb_transfer_cb_fn', function(trf) cb(trf) end)
      t.timeout = timeout or 0
      local err = core.libusb_submit_transfer(t)
      if err ~= C.LIBUSB_SUCCESS then
        print('transfer submit error - ' .. ffi.string(core.libusb_error_name(err)))
        return nil, ffi.string(core.libusb_error_name(err))
      end
      return t
    end,
  },
  __gc = function(t)
    print("collecting transfer")
    core.libusb_free_transfer(t)
  end,
})

local ctxptr = new'libusb_context *[1]'
if 0 ~= core.libusb_init(ctxptr) then
  return nil, "failed to initialize usb library"
end
local ctx = new('struct libusb_context *', ctxptr[0])

return ctx
