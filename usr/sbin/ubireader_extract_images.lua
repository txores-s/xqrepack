#!/usr/bin/lua

settings = {}
logger = {}
ubi_file = {}
sort = {}
ubi = {}
utils = {}
image = {}
volume = {}
layout = {}
ec_hdr = {}
vid_hdr = {}
_vtbl_rec = {}
ubi_block = {}
display = {}


-- defines
-- Magic number
UBI_EC_HDR_MAGIC = string.char(0x55, 0x42, 0x49, 0x23)
-- Common Header.
UBIFS_NODE_MAGIC = string.char(0x31, 0x18, 0x10, 0x06) -- Set to LSB
-- File chunk size for reads.
FILE_CHUNK_SZ = 5 * 1024 * 1024
-- Error Count header.
EC_HDR_FORMAT = '>4sB3sQIII32sI'
EC_HDR_FIELDS = {'magic',           -- Magic string UBI#
                 'version',         -- UBI version meant to accept this image.
                 'padding',         -- Reserved for future, zeros.
                 'ec',              -- Erase counter
                 'vid_hdr_offset',  -- Where the VID header starts.
                 'data_offset',     -- Where user data starts.
                 'image_seq',       -- Image sequence number
                 'padding2',        -- Reserved for future, zeros.
                 'hdr_crc'}         -- EC header crc32 checksum.
-- Volume ID header.
UBI_VID_HDR_MAGIC = string.char(0x55, 0x42, 0x49, 0x21) -- UBI!
VID_HDR_FORMAT = '>4sBBBBII4sIIII4sQ12sI'
VID_HDR_FIELDS = {'magic',      -- Magic string UBI!
                  'version',    -- UBI version meant to accept this image.
                  'vol_type',   -- Volume type, Dynamic/Static
                  'copy_flag',  -- If this is a copied PEB b/c of wear leveling.
                  'compat',     -- Compatibility of this volume UBI_COMPAT_*
                  'vol_id',     -- ID of this volume.
                  'lnum',       -- LEB number.
                  'padding',    -- Reserved for future, zeros.
                  'data_size',  -- How many bytes of data this contains.
                                -- Used for static types only.
                  'used_ebs',   -- Total num of used LEBs in this volume.
                  'data_pad',   -- How many bytes at end of LEB are not used.
                  'data_crc',   -- CRC32 checksum of data, static type only.
                  'padding2',   -- Reserved for future, zeros.
                  'sqnum',      -- Sequence number.
                  'padding3',   -- Reserved for future, zeros.
                  'hdr_crc'}    -- VID header CRC32 checksum.
-- Volume table records.
VTBL_REC_FORMAT = '>IIIBBH128sB23sI'
VTBL_REC_FIELDS = {'reserved_pebs', -- How many PEBs reserved for this volume.
                   'alignment',     -- Volume alignment.
                   'data_pad',      -- Number of unused bytes at end of PEB.
                   'vol_type',      -- Volume type, static/dynamic.
                   'upd_marker',    -- If vol update started but not finished.
                   'name_len',      -- Length of name.
                   'name',          -- Volume name.
                   'flags',         -- Volume flags
                   'padding',       -- Reserved for future, zeros.
                   'crc'}           -- Vol record CRC32 checksum.
-- Max number of volumes allowed.
UBI_MAX_VOLUMES = 128
UBI_VTBL_REC_SZ = 172 -- struct.calcsize(VTBL_REC_FORMAT) -- 172
UBI_EC_HDR_SZ = 64 -- struct.calcsize(EC_HDR_FORMAT) -- 64
UBI_VID_HDR_SZ = 64 -- struct.calcsize(VID_HDR_FORMAT) -- 64
-- Internal Volume ID start.
UBI_INTERNAL_VOL_START = tonumber(2147479551)
PRINT_COMPAT_LIST = {0, 'Delete', 'Read Only', 0, 'Preserve', 'Reject'}
PRINT_VOL_TYPE_LIST = {0, 'dynamic', 'static'}
UBI_VTBL_AUTORESIZE_FLG = 1
CMD_HELP = [[
usage: ubireader_extract_images [options] filepath

Extract UBI or UBIFS images from file containing UBI data in it.

positional arguments:
  filepath              File to extract contents of.

optional arguments:
  -h, --help            show this help message and exit
  -l, --log             Print extraction information to screen.
  -v, --verbose-log     Prints nearly everything about anything to screen.
  -p BLOCK_SIZE, --peb-size BLOCK_SIZE
                        Specify PEB size.
  -u IMAGE_TYPE, --image-type IMAGE_TYPE
                        Specify image type to extract UBI or UBIFS. (default: UBIFS)
  -s START_OFFSET, --start-offset START_OFFSET
                        Specify offset of UBI data in file. (default: 0)
  -n END_OFFSET, --end-offset END_OFFSET
                        Specify end offset of UBI data in file.
  -g GUESS_OFFSET, --guess-offset GUESS_OFFSET
                        Specify offset to start guessing where UBI data is in file. (default: 0)
  -w, --warn-only-block-read-errors
                        Attempts to continue extracting files even with bad block reads. Some data will be missing or
                        corrupted! (default: False)
  -i, --ignore-block-header-errors
                        Forces unused and error containing blocks to be included and also displayed with log/verbose.
                        (default: False)
  -f, --u-boot-fix      Assume blocks with image_seq 0 are because of older U-boot implementations and include them.
                        (default: False)
  -o OUTPATH, --output-dir OUTPATH
                        Specify output directory path.
]]


-- settings
settings.output_dir = 'ubifs-root'

settings.error_action = true                     -- if 'exit' on any error exit program.
settings.fatal_traceback = false                 -- Print traceback on fatal errors.

settings.ignore_block_header_errors = false      -- Ignore block errors.
settings.warn_only_block_read_errors = false     -- Warning instead of Fatal error.

settings.logging_on = false                      -- Print debug info on.
settings.logging_on_verbose = false              -- Print verbose debug info on.

settings.use_dummy_socket_file = false           -- Create regular file place holder for sockets.
settings.use_dummy_devices = false               -- Create regular file place holder for devices.

settings.uboot_fix = false                       -- Older u-boot sets image_seq to 0 on blocks it's written to.


-- global
function length(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end
function spairs(t)
	local sorted = {}
	local associated = {}
	for k, v in pairs(t) do
		table.insert(sorted, k)
	end
	table.sort(sorted)
	for i, v in ipairs(sorted) do
		associated[v] = i
	end
	local function snext(t, k)
		if k == nil then
			return sorted[1], t[sorted[1]]
		elseif associated[k] ~= nil then
			return sorted[associated[k] + 1], t[sorted[associated[k] + 1]]
		end
	end
	return snext, t, nil
end


-- logger
function logger:log(obj, message)
	if settings.logging_on or settings.logging_on_verbose then
		io.write(('%s %s\n'):format(type(obj) == type({}) and obj.__name__ or obj, message))
	end
end
function logger:verbose_log(obj, message)
	if settings.logging_on_verbose then
		logger:log(obj, message)
	end
end
function logger:verbose_display(displayable_obj)
	if settings.logging_on_verbose then
		io.write(displayable_obj:display('\t'))
	end
end
function logger:error(obj, level, message)
    if settings.error_action == 'exit' then
        io.write(('%s %s: %s\n'):format(type(obj) == type({}) and obj.__name__ or obj, level, message))
        if settings.fatal_traceback then
            io.write(debug and debug.traceback and debug.traceback())
		end
        os.exit(1)
    else
        if string.lower(level) == 'warn' then
            io.write(('%s %s: %s\n'):format(type(obj) == type({}) and obj.__name__ or obj, level, message))
        elseif string.lower(level) == 'fatal' then
            io.write(('%s %s: %s\n'):format(type(obj) == type({}) and obj.__name__ or obj, level, message))
            if settings.fatal_traceback then
                io.write(debug and debug.traceback and debug.traceback())
			end
            os.exit(1)
        else
            io.write(('%s %s: %s\n'):format(type(obj) == type({}) and obj.__name__ or obj, level, message))
		end
	end
end


-- ubi_file
function ubi_file:new(path, block_size, start_offset, end_offset)
	start_offset = start_offset or 0
	
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	function public:tell()
		return self._fhandle:seek()
	end
	function public:seek(offset)
        self._fhandle:seek("set", offset)
	end
	function public:read(size)
		if self.end_offset < self:tell() + size then
			logger:error(("%s.read"):format(self.__name__), 'Error', ('Block ends at %s which is greater than file size %s'):format(self:tell() + size, self.end_offset))
			print(debug.traceback())
			error('Bad Read Offset Request')
			-- os.exit(1)
		end
		self.last_read_addr = self:tell()
		logger:verbose_log(self, ('read loc: %s, size: %s'):format(self.last_read_addr, size))
		return self._fhandle:read(size)
	end
	function public:reset()
		self._fhandle:seek("set", self.start_offset)
	end
	function public:reader()
        self:reset()
		local result = {}
        while true do
            local cur_loc = self._fhandle:seek()
            if self.end_offset and cur_loc > self.end_offset then
                break
			elseif self.end_offset and self.end_offset - cur_loc < self.block_size then
                chunk_size = self.end_offset - cur_loc
            else
                chunk_size = self.block_size
			end
            local buf = self:read(chunk_size)
            if not buf then break end
            table.insert(result, buf)
		end
		return result
	end
	function public:read_block(block)
        self:seek(block.file_offset)
        return self._fhandle:read(block.size)
	end
	function public:read_block_data(block)
        self:seek(block.file_offset + block.ec_hdr.data_offset)
        buf = self._fhandle:read(block.size - block.ec_hdr.data_offset - block.vid_hdr.data_pad)
        return buf
	end

	public.__name__ = 'UBI_File'
	public.is_valid = False
	
	local f, err = io.open(path, "rb")
	if f then
		public._fhandle = f
	else
		logger:error(public, 'Fatal', string.format('Open file: %s', err))
	end
	
	public._fhandle:seek("end", 0)
	local file_size = public:tell()
	logger:log(public, string.format('File Size: %d', file_size))
	
	public.start_offset = start_offset
	logger:log(public, string.format('Start Offset: %d', (public.start_offset)))
	
	local tail
	if end_offset and end_offset ~= 0 then
		tail = file_size - end_offset
		public.end_offset = end_offset
	else
		tail = (file_size - start_offset) % block_size
		public.end_offset = file_size - tail
	end
	logger:log(public, string.format('End Offset: %d', public.end_offset))
	if tail > 0 then
		logger:log(public, string.format('File Tail Size: %d', tail))
	end

	public.block_size = block_size
	logger:log(public, string.format('Block Size: %s', block_size))

	if start_offset > public.end_offset then
		logger:error(public, 'Fatal', 'Start offset larger than end offset.')
	end

	if ( end_offset ~= nil ) and ( end_offset > file_size ) then
		logger:error(public, 'Fatal', 'End offset larger than file size.')
	end

	remainder = (public.end_offset - start_offset) % block_size
	if remainder ~= 0 then
		if settings.warn_only_block_read_errors then
			logger:error(public, 'Error', 'File read is not block aligned.')
		else
			logger:error(public, 'Fatal', 'File read is not block aligned.')
		end
	end

    public._fhandle:seek("set", public.start_offset)
    public.last_read_addr = public._fhandle:seek()
    public.is_valid = true

	return public
end


-- sort
function sort:by_image_seq(blocks, image_seq)
	local result = {}
	for k, v in spairs(blocks) do
		if v.ec_hdr.image_seq == image_seq or settings.uboot_fix and (image_seq == 0 or v.ec_hdr.image_seq == 0) then
			table.insert(result, v)
		end
	end
	return result
end
function sort:by_leb(blocks)
	local slist_len = length(blocks)
	local slist = {[0] = 'x'}
	for i = 1, slist_len - 1 do table.insert(slist, 'x') end
	for k, v in spairs(blocks) do
		if v.leb_num >= slist_len then
			local add_elements = v.leb_num - slist_len + 1
			for i = 1, add_elements do table.insert(slist, 'x') end
			slist_len = length(slist)
		end
		slist[v.leb_num] = k
	end
	return slist
end
function sort:by_vol_id(blocks, slist)
	local vol_blocks = {}
	for k, v in spairs(blocks) do
		if slist ~= nil and slist[k] == nil then
			-- goto continue
		elseif not v.is_valid then
			-- goto continue
		-- end
		else
			if vol_blocks[v.vid_hdr.vol_id] == nil then
				vol_blocks[v.vid_hdr.vol_id] = {}
			end
			table.insert(vol_blocks[v.vid_hdr.vol_id], v.peb_num)
		end
		-- ::continue::
	end
	return vol_blocks
end
function sort:by_type(blocks, slist)
	local layout = {}
	local data = {}
	local int_vol = {}
	local unknown = {}

	for k, v in spairs(blocks) do
		if slist ~= nil and slist[k] == nil then
			-- goto continue
		else
			if v.is_vtbl and v.is_valid then
				table.insert(layout, k)
			elseif v.is_internal_vol and v.is_valid then
				table.insert(int_vol, k)
			elseif v.is_valid then
				table.insert(data, k)
			else
				table.insert(unknown, k)
			end
		end
		-- ::continue::
	end

	return layout, data, int_vol, unknown
end


-- ubi
function ubi:new(ubi_file)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	function public:display(tab)
		return display:ubi(self, tab or '')
	end
	
	public.__name__ = 'UBI'
	public.file = ubi_file
	public.first_peb_num = 0
	public.blocks = ubi_block:extract_blocks(public)
	public.block_count = length(public.blocks)

	if public.block_count <= 0 then
		logger:error(public, 'Fatal', 'No blocks found.')
	end
	
	local arbitrary_block = 0
	for k, v in pairs(public.blocks) do
		arbitrary_block = arbitrary_block + 1
		if arbitrary_block == 2 then
			arbitrary_block = v
			break
		end
	end
	if tonumber(arbitrary_block) ~= nil then
		logger:error(public, 'Fatal', 'No arbitrary block found.')
	end
	public.min_io_size = arbitrary_block.ec_hdr.vid_hdr_offset
	public.leb_size = public.file.block_size - arbitrary_block.ec_hdr.data_offset
	
	
	local layout_list, data_list, int_vol_list, unknown_list = sort:by_type(public.blocks)

	if length(layout_list) < 2 then
		logger:error(public, 'Fatal', 'Less than 2 layout blocks found.')
	end

	public.layout_blocks_list = layout:get_newest(public.blocks, layout_list)
	public.data_blocks_list = data_list
	public.int_vol_blocks_list = int_vol_list
	public.unknown_blocks_list = unknown_list

	local layout_pairs = layout:group_pairs(public.blocks, public.layout_blocks_list)
	local layout_infos = layout:associate_blocks(public.blocks, layout_pairs, public.first_peb_num)

	public.images = {}
	for k, v in pairs(layout_infos) do
		table.insert(public.images, image:new(public.blocks, v))
	end

	return public
end


function utils:guess_filetype(path, start_offset)
	start_offset = start_offset or 0
	logger:log('guess_filetype', ('Looking for file type at %s'):format(start_offset))

	local f = io.open(path, 'rb')
	f:seek("set", start_offset)

	local buf = f:read(4)
	if buf == UBI_EC_HDR_MAGIC then
		ftype = UBI_EC_HDR_MAGIC
		logger:log('guess_filetype', 'File looks like a UBI image.')
	elseif buf == UBIFS_NODE_MAGIC then
		ftype = UBIFS_NODE_MAGIC
		logger:log('guess_filetype', 'File looks like a UBIFS image.')
	else
		ftype = nil
		logger:error('guess_filetype', 'Fatal', 'Could not determine file type.')
	end
	return ftype
end
function utils:guess_peb_size(path)
	local file_offset = nil
	local offsets = {}
	
	local f = io.open(path, 'rb')
	f:seek("end", 0)
	file_size = f:seek() + 1
	f:seek("set", 0)

	for i = 1, file_size, FILE_CHUNK_SZ do
		local buf = f:read(FILE_CHUNK_SZ)
		local m = buf:find(UBI_EC_HDR_MAGIC, 1, true)
		while m ~= nil do
			table.insert(offsets, m + (file_offset or 0) - 1)
			if file_offset == nil then
				file_offset = m
			end
			m = buf:find(UBI_EC_HDR_MAGIC, m + UBI_EC_HDR_MAGIC:len(), true)
		end
		file_offset = (file_offset or 0) + FILE_CHUNK_SZ
	end
	f:close()
	
	local occurances = {}
	for i, v in ipairs(offsets) do
		local diff = v - (offsets[i - 1] or 0)
		occurances[diff] = (occurances[diff] or 0) + 1
	end
	
	local most_frequent = 0
	local block_size = nil
	for k, v in pairs(occurances) do
		if v > most_frequent then
			most_frequent = v
			block_size = k
		end
	end
	
	return block_size
end
function utils:guess_start_offset(path, guess_offset)
	local file_offset = guess_offset or 0
	
	local f = io.open(path, 'rb')
	f:seek("end", 0)
	file_size = f:seek() + 1
	f:seek("set", file_offset)
	
	for i = 1, file_size, FILE_CHUNK_SZ do
		local buf = f:read(FILE_CHUNK_SZ)
		local ubi_loc = buf:find(UBI_EC_HDR_MAGIC, 1, true)
		local ubifs_loc = buf:find(UBIFS_NODE_MAGIC, 1, true)
	
		if ubi_loc == nil and ubifs_loc == nil then
			file_offset = file_offset + FILE_CHUNK_SZ
			-- goto continue
		else
			if ubi_loc == nil then
				ubi_loc = file_size + 1
			elseif ubifs_loc == nil then
				ubifs_loc = file_size + 1
			end
			if ubi_loc < ubifs_loc then
				logger:log('guess_start_offset', ('Found UBI magic number at %s'):format(file_offset + ubi_loc - 1))
				return  file_offset + ubi_loc - 1
			elseif ubifs_loc < ubi_loc then
				logger:log('guess_start_offset', ('Found UBIFS magic number at %s'):format(file_offset + ubifs_loc - 1))
				return file_offset + ubifs_loc - 1
			else
				logger:error('guess_start_offset', 'Fatal', 'Could not determine start offset.')
			end
		end
		-- ::continue::
	end
	f:close()
	logger:error('guess_start_offset', 'Fatal', 'Could not determine start offset.')
end
function utils:valueAt(data, index, start)
	local i = start or 1
	for k, v in spairs(data) do
		if i == index then
			return v
		end
		i = i + 1
	end
	return nil
end
function utils:strip(data, characters)
	local cTable = {}
	for i = 1, characters:len() do
		cTable[characters:byte(i, i)] = characters:byte(i, i)
	end
	for i = 1, data:len() do
		if cTable[data:byte(i, i)] == nil then
			for j = data:len(), 1, -1 do
				if cTable[characters:byte(j, j)] == nil then
					return data:sub(i, j)
				end
			end
		end
	end
	return ''
end
function utils:bytes_to_number(data, signed, big_endian)
	data = big_endian and data:reverse() or data
	local l = data:len()
	local result = 0
	for i = 1, l do
		result = result + data:byte(i) * (0x100 ^ (i - 1))
	end
	return (signed and (data:byte(l) / 0x80) >= 1) and (result - (2 ^ (l * 8))) or result
end
function utils:unpack_buffer(unpack_format, data)
	local isBE = string.char(unpack_format:byte(1))
	local result = {}
	isBE = isBE == '>' or isBE == '!'
	local sizes = { x = 1, c = 1, b = 1, ['?'] = 1, h = 2, i = 4, l = 4, q = 8, e = 2, f = 4, d = 8 }
	local position = 1
	local i = 1
	while i <= unpack_format:len() do
		local size = sizes[unpack_format:sub(i, i):lower()]
		if size == nil then
			while tonumber(unpack_format:sub(i, i)) do
				size = (size or 0) * 10 + tonumber(unpack_format:sub(i, i))
				i = i + 1
			end
			if unpack_format:sub(i, i) == 's' then
				table.insert(result, data:sub(position, position + (size or 0) - 1))
			end
		elseif unpack_format:sub(i, i) == '?' then
			table.insert(result, data:byte(position) ~= 0)
		elseif unpack_format:sub(i, i) ~= 'x' then
			table.insert(result, utils:bytes_to_number(data:sub(position, position + size - 1), sizes[unpack_format:sub(i, i)] ~= nil, isBE))
		end
		position = position + (size or 0)
		i = i + 1
	end
	return result
end
function utils:crc32(data, size)
	size = size or data:len()
	local cmd = ([[printf "%s" | ubicrc32]]):format(([[\x%02x]]):rep(size):format(data:byte(1, size)))
	local result = tonumber(io.popen(cmd):read("*all"), 16)
	if result == nil then
		cmd = ([[printf "%s" | gzip -c | tail -c8 | hexdump -n4 -e '"%%08X"']]):format(([[\x%02x]]):rep(size):format(data:byte(1, size)))
		result = tonumber('0xffffffff', 16) - tonumber(io.popen(cmd):read("*all"), 16) or 0
	end
	return result
end


function image:new(blocks, layout_info)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	function public:get_blocks(blocks)
        return ubi_block:get_blocks_in_list(blocks, self.block_list) -- range(self.start_peb, self.end_peb + 1))
	end
	function public:display(tab)
        return display:image(self, tab or '')
	end

	public.image_seq = blocks[utils:valueAt(layout_info, 0, 0)].ec_hdr.image_seq
	public.vid_hdr_offset = blocks[utils:valueAt(layout_info, 0, 0)].ec_hdr.vid_hdr_offset
	public.version = blocks[utils:valueAt(layout_info, 0, 0)].ec_hdr.version
	public.block_list = {}
	for k, v in pairs(utils:valueAt(layout_info, 2, 0)) do
		table.insert(public.block_list, v.peb_num)
	end
	public.start_peb = math.min(unpack(public.block_list))
	public.end_peb = math.max(unpack(public.block_list))
	public.volumes = volume:get_volumes(blocks, layout_info)
	logger:log('description:image', ('Created Image: %s, Volume Cnt: %s'):format(public.image_seq, length(public.volumes)))

	return public
end


function volume:new(vol_id, vol_rec, block_list)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	function public:get_blocks(blocks)
		return ubi_block:get_blocks_in_list(blocks, self.block_list)
	end
	function public:display(tab)
		return display.volume(tab or '')
	end
	function public:reader(ubi)
		local result = {}
		for k, v in spairs(sort:by_leb(self:get_blocks(ubi.blocks))) do
			if v == 'x' then
				table.insert(result, string.char(0xff):rep(ubi.leb_size))
			else
				table.insert(result, ubi.file:read_block_data(ubi.blocks[v]))
			end
		end
		return result
	end

	public.vol_id = vol_id
	public.vol_rec = vol_rec
	public.name = public.vol_rec.name
	public.block_list = block_list
	logger:log('description:volume', ('Create Volume: %s, ID: %s, Block Cnt: %s'):format(public.name, public.vol_id, length(public.block_list)))

	return public
end
function volume:get_volumes(blocks, layout_info)
	local volumes = {}
	local vol_blocks_lists = sort:by_vol_id(blocks, utils:valueAt(layout_info, 2, 0))
	for i, vol_rec in pairs(blocks[utils:valueAt(layout_info, 0, 0)].vtbl_recs) do
		volumes[utils:strip(vol_rec.name, string.char(0))] = volume:new(vol_rec.rec_index, vol_rec, vol_blocks_lists[vol_rec.rec_index] or {})
	end
	return volumes
end


function layout:get_newest(blocks, layout_blocks)
	local to_remove = {}
	for ik, iv in pairs(layout_blocks) do
		for kk, kv in pairs(layout_blocks) do
			if to_remove[kk] then
				-- goto continue
			-- end
			elseif blocks[iv].ec_hdr.image_seq ~= blocks[kv].ec_hdr.image_seq then
				-- goto continue
			-- end
			elseif blocks[iv].leb_num ~= blocks[kv].leb_num then
				-- goto continue
			-- end
			elseif blocks[iv].vid_hdr.sqnum > blocks[kv].vid_hdr.sqnum then
				to_remove[kk] = true
				break
			end
			-- ::continue::
		end
	end
	local result = {}
	for k, v in spairs(layout_blocks) do
		if not to_remove[k] then
			table.insert(result, v)
		end
	end
	return result
end
function layout:group_pairs(blocks, layout_blocks_list)
	local image_dict = {}
	for k, v in pairs(layout_blocks_list) do
		local image_seq = blocks[v].ec_hdr.image_seq
		if image_dict[image_seq] == nil then
			image_dict[image_seq] = {}
		end
		table.insert(image_dict[image_seq], v)
	end
	local result = {}
	local pebs = {}
	for k, v in spairs(image_dict) do
		table.insert(result, v)
		table.insert(pebs, k)
	end
	logger:log('group_pairs', ('Layout blocks found at PEBs: [ %s ]'):format(table.concat(pebs, ', ')))
	return result
end
function layout:associate_blocks(blocks, layout_pairs, start_peb_num)
	for k, v in spairs(layout_pairs) do
		table.insert(layout_pairs[k], sort:by_image_seq(blocks, blocks[v[1]].ec_hdr.image_seq))
	end
	return layout_pairs
end


function ec_hdr:new(buf)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	local data = utils:unpack_buffer(EC_HDR_FORMAT, buf)
	for i = 1, length(EC_HDR_FIELDS) do
		public[EC_HDR_FIELDS[i]] = data[i]
	end
	public.errors = {}
	local crc_chk = utils:crc32(buf, buf:len() - 4)
	if public.hdr_crc ~= crc_chk then
		logger:log('ec_hdr', ('CRC Failed: expected %s got %s'):format(public.hdr_crc, crc_chk))
		table.insert(public.errors, 'crc')
	end
	
	return public
end
function vid_hdr:new(buf)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	local data = utils:unpack_buffer(VID_HDR_FORMAT, buf)
	for i = 1, length(VID_HDR_FIELDS) do
		public[VID_HDR_FIELDS[i]] = data[i]
	end
	public.errors = {}
	local crc_chk = utils:crc32(buf, buf:len() - 4)
	if public.hdr_crc ~= crc_chk then
		logger:log('vid_hdr', ('CRC Failed: expected %s got %s'):format(public.hdr_crc, crc_chk))
		table.insert(public.errors, 'crc')
	end
	
	return public
end
function _vtbl_rec:new(buf)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	local data = utils:unpack_buffer(VTBL_REC_FORMAT, buf)
	for i = 1, length(VTBL_REC_FIELDS) do
		public[VTBL_REC_FIELDS[i]] = data[i]
	end
	public.errors = {}
	public.rec_index = -1
	public.name = public.name:sub(1, public.name_len)
	local crc_chk = utils:crc32(buf, buf:len() - 4)
	if public.crc ~= crc_chk then
		logger:log('_vtbl_rec', ('CRC Failed: expected %s got %s'):format(public.crc, crc_chk))
		table.insert(public.errors, 'crc')
	end
	
	return public
end
function vtbl_recs(buf)
	local data_buf = buf
	local vtbl_recs = {}
	local vtbl_rec_ret
	for i = 0, UBI_MAX_VOLUMES - 1 do    
		local offset = i * UBI_VTBL_REC_SZ + 1
		local vtbl_rec_buf = data_buf:sub(offset, offset + UBI_VTBL_REC_SZ - 1)
		if vtbl_rec_buf:len() == UBI_VTBL_REC_SZ then
			vtbl_rec_ret = _vtbl_rec:new(vtbl_rec_buf)
			if length(vtbl_rec_ret.errors) == 0 and (vtbl_rec_ret.name_len or 0) > 0 then
				vtbl_rec_ret.rec_index = i
				table.insert(vtbl_recs, vtbl_rec_ret)
			end
		end
	end
	return vtbl_recs
end


function ubi_block:new(block_buf)
	local public = {}
	setmetatable(public, self)
	self.__index = self
	
	function public:display(tab)
		return display:block(self, tab or '')
	end
		
	public.__name__ = "ubi_block"
	
	public.file_offset = -1
	public.peb_num = -1
	public.leb_num = -1
	public.size = -1
	
	public.vid_hdr = nil
	public.is_internal_vol = false
	public.vtbl_recs = {}
	
	public.ec_hdr = ec_hdr:new(block_buf:sub(1, UBI_EC_HDR_SZ))
	if length(public.ec_hdr.errors) == 0 or settings.ignore_block_header_errors then
		public.vid_hdr = vid_hdr:new(block_buf:sub(public.ec_hdr.vid_hdr_offset + 1, public.ec_hdr.vid_hdr_offset + UBI_VID_HDR_SZ))
		if length(public.vid_hdr.errors) == 0 or settings.ignore_block_header_errors then
			public.is_internal_vol = public.vid_hdr.vol_id >= UBI_INTERNAL_VOL_START
			if public.vid_hdr.vol_id >= UBI_INTERNAL_VOL_START then
				public.vtbl_recs = vtbl_recs(block_buf:sub(public.ec_hdr.data_offset + 1))
			end
			public.leb_num = public.vid_hdr.lnum
		end
	end
	
	public.is_vtbl = length(public.vtbl_recs) > 0
	public.is_valid = length(public.ec_hdr.errors) == 0 and length(public.vid_hdr.errors) == 0 or settings.ignore_block_header_errors
	
	return public
end
function ubi_block:get_blocks_in_list(blocks, idx_list)
	local result = {}
	for k, v in spairs(idx_list) do
		result[v] = blocks[v]
	end
	return result
end
function ubi_block:extract_blocks(ubi)
	local blocks = {}
	local peb_count = 0
	local cur_offset = 0
	local bad_blocks = {}
	ubi.file:seek(ubi.file.start_offset)
	for i = ubi.file.start_offset, ubi.file.end_offset - 1, ubi.file.block_size do
		local status, buf = pcall(ubi.file.read, ubi.file, ubi.file.block_size)
		local continue = false
		if not status then
			if settings.warn_only_block_read_errors then
				logger:error('extract_blocks', 'Error', ('PEB: %s: %s'):format(ubi.first_peb_num + peb_count, buf))
				continue = true -- goto continue
			else
				logger:error('extract_blocks', 'Fatal', ('PEB: %s: %s'):format(ubi.first_peb_num + peb_count, buf))
			end
		end
		if not continue then
			if buf:sub(1, UBI_EC_HDR_MAGIC:len()) == UBI_EC_HDR_MAGIC then
				local blk = ubi_block:new(buf)
				blk.file_offset = i
				blk.peb_num = ubi.first_peb_num + peb_count
				blk.size = ubi.file.block_size
				blocks[blk.peb_num] = blk
				peb_count = peb_count + 1
				logger:log('extract_blocks', table.concat(blk))
				logger:verbose_log('extract_blocks', ('file addr: %s'):format(ubi.file.last_read_addr))

				local ec_hdr_errors = ''
				local vid_hdr_errors = ''
				if length(blk.ec_hdr.errors) > 0 then
					ec_hdr_errors = table.concat(blk.ec_hdr.errors, ', ')
				end
				if blk.vid_hdr and length(blk.vid_hdr.errors) > 0 then
					vid_hdr_errors = table.concat(blk.vid_hdr.errors, ', ')
				end
		
				if (ec_hdr_errors:len() + vid_hdr_errors:len()) > 0 then
					if bad_blocks[blk.peb_num] ~= nil then
						bad_blocks[blk.peb_num] = blk.peb_num
						logger:log('extract_blocks', ('PEB: %s has possible issue EC_HDR [%s], VID_HDR [%s]'):format(blk.peb_num, ec_hdr_errors, vid_hdr_errors))
					end
				end
				logger:verbose_display(blk)
			else
				cur_offset = cur_offset + ubi.file.block_size
				ubi.first_peb_num = math.floor(cur_offset / ubi.file.block_size)
				ubi.file.start_offset = cur_offset
			end
		end
		-- ::continue::
	end
	return blocks
end


function display:ubi(ubi, tab)
	tab = tab or ''
	local buf = ('%sUBI File\n'):format(tab) 
	buf = buf .. ('%s---------------------\n'):format(tab)
	buf = buf .. ('\t%sMin I/O: %s\n'):format(tab, ubi.min_io_size)
	buf = buf .. ('\t%sLEB Size: %s\n'):format(tab, ubi.leb_size)
	buf = buf .. ('\t%sPEB Size: %s\n'):format(tab, ubi.peb_size)
	buf = buf .. ('\t%sTotal Block Count: %s\n'):format(tab, ubi.block_count)
	buf = buf .. ('\t%sData Block Count: %s\n'):format(tab, length(ubi.data_blocks_list))
	buf = buf .. ('\t%sLayout Block Count: %s\n'):format(tab, length(ubi.layout_blocks_list))
	buf = buf .. ('\t%sInternal Volume Block Count: %s\n'):format(tab, length(ubi.int_vol_blocks_list))
	buf = buf .. ('\t%sUnknown Block Count: %s\n'):format(tab, length(ubi.unknown_blocks_list))
	buf = buf .. ('\t%sFirst UBI PEB Number: %s\n'):format(tab, ubi.first_peb_num)
	return buf
end
function display:image(image, tab)
	tab = tab or ''
	local buf = ('%s%s\n'):format(tab, 'image')
	buf = buf .. ('%s---------------------\n'):format(tab)
	buf = buf .. ('\t%sImage Sequence Num: %s\n'):format(tab, image.image_seq)
	for volume in image.volumes do
		buf = buf .. ('\t%sVolume Name:%s\n'):format(tab, volume)
	end
	buf = buf .. ('\t%sPEB Range: %s - %s\n'):format(tab, image.peb_range[1], image.peb_range[2])
	return buf
end
function display:volume(volume, tab)
	tab = tab or ''
	local buf = ('%s%s\n'):format(tab, 'volume')
	buf = buf .. ('%s---------------------\n'):format(tab)
	buf = buf .. ('\t%sVol ID: %s\n'):format(tab, volume.vol_id)
	buf = buf .. ('\t%sName: %s\n'):format(tab, volume.name)
	buf = buf .. ('\t%sBlock Count: %s\n'):format(tab, volume.block_count)
	buf = buf .. '\n'
	buf = buf .. ('\t%sVolume Record\n'):format(tab) 
	buf = buf .. ('\t%s---------------------\n'):format(tab)
	buf = buf .. self:vol_rec(volume.vol_rec, ('\t\t%s'):format(tab))
	buf = buf .. '\n'
	return buf
end
function display:block(block, tab)
	tab = tab or ''
	local buf = ('%s%s\n'):format(tab, block.__name__)
	buf = buf .. ('%s---------------------\n'):format(tab)
	buf = buf .. ('\t%sFile Offset: %s\n'):format(tab, block.file_offset)
	buf = buf .. ('\t%sPEB #: %s\n'):format(tab, block.peb_num)
	buf = buf .. ('\t%sLEB #: %s\n'):format(tab, block.leb_num)
	buf = buf .. ('\t%sBlock Size: %s\n'):format(tab, block.size or 'nil')
	buf = buf .. ('\t%sInternal Volume: %s\n'):format(tab, block.is_internal_vol and 'true' or 'false')
	buf = buf .. ('\t%sIs Volume Table: %s\n'):format(tab, block.is_vtbl and 'true' or 'false')
	buf = buf .. ('\t%sIs Valid: %s\n'):format(tab, block.is_valid and 'true' or 'false')
	
	if block.ec_hdr.errors and length(block.ec_hdr.errors) == 0 or settings.ignore_block_header_errors then
		buf = buf .. '\n'
		buf = buf .. ('\t%sErase Count Header\n'):format(tab)
		buf = buf .. ('\t%s---------------------\n'):format(tab)
		buf = buf .. self:ec_hdr(block.ec_hdr, ('\t\t%s'):format(tab))
	end
	if (block.vid_hdr and length(block.vid_hdr.errors) == 0) or settings.ignore_block_header_errors then
		buf = buf .. '\n'        
		buf = buf .. ('\t%sVID Header\n'):format(tab)
		buf = buf .. ('\t%s---------------------\n'):format(tab)
		buf = buf .. self:vid_hdr(block.vid_hdr, ('\t\t%s'):format(tab))
	end
	if block.vtbl_recs and length(block.vtbl_recs) > 0 then
		buf = buf .. '\n'
		buf = buf .. ('\t%sVolume Records\n'):format(tab) 
		buf = buf .. ('\t%s---------------------\n'):format(tab)
		for _, vol in spairs(block.vtbl_recs) do
			buf = buf .. self:vol_rec(vol, ('\t\t%s'):format(tab))
		end
	end
	buf = buf .. '\n'
	return buf
end
function display:ec_hdr(ec_hdr, tab)
	tab = tab or ''
	local buf = ''
	for key, value in spairs(ec_hdr) do
		if key == 'errors' then
			value = table.concat(value, ',')
		end
		buf = buf .. ('%s%s: %s\n'):format(tab, key, value)
	end
	return buf
end
function display:vid_hdr(vid_hdr, tab)
	tab = tab or ''
	local buf = ''
	for key, value in spairs(vid_hdr) do
		if key == 'errors' then
			value = table.concat(value, ',')
		elseif key == 'compat' then
			if PRINT_COMPAT_LIST[value] ~= nil then
				value = PRINT_COMPAT_LIST[value]
			else
				value = -1
			end
		elseif key == 'vol_type' then
			if value < length(PRINT_VOL_TYPE_LIST) then
				value = PRINT_VOL_TYPE_LIST[value]
			else
				value = -1
			end
		end
		buf = buf .. ('%s%s: %s\n'):format(tab, key, value)
	end
	return buf
end
function display:vol_rec(vol_rec, tab)
	tab = tab or ''
	local buf = ''
	for key, value in spairs(vol_rec) do
		if key == 'errors' then
			value = table.concat(value, ',')
		elseif key == 'vol_type' then
			if value < length(PRINT_VOL_TYPE_LIST) then
				value = PRINT_VOL_TYPE_LIST[value]
			else
				value = -1
			end
		elseif key == 'flags' and value == UBI_VTBL_AUTORESIZE_FLG then
			value = 'autoresize'
		elseif key == 'name' then
			value = utils:strip(value, string.char(0x00))
		end
		buf = buf .. ('%s%s: %s\n'):format(tab, key, value)
	end
	return buf
end


function create_output_dir(outpath)
	local result = io.popen(([[mkdir -p '%s' 2>&1 && printf 0]]):format(outpath)):read('*all')
	if tonumber(result) == 0 then
		logger:log('create_output_dir', ('Created output path: %s'):format(outpath))
	else
		logger:error('create_output_dir', 'Fatal', result)
	end
end


local path = nil
local outpath = nil
local block_size = nil
local image_type = 'UBIFS'
local start_offset = nil
local end_offset = nil
local guess_offset = nil
local i = math.min(1, #arg)
while i <= #arg do
	if arg[i] == '-l' or arg[i] == '--log' then
		settings.logging_on = true
	elseif arg[i] == '-v' or arg[i] == '--verbose-log' then
		settings.logging_on_verbose = true
	elseif arg[i] == '-p' or arg[i] == '--peb-size' then
		i = i + 1
		block_size = tonumber(arg[i])
	elseif arg[i] == '-u' or arg[i] == '--image-type' then
		i = i + 1
		image_type = arg[i] and arg[i]:upper() or image_type
	elseif arg[i] == '-s' or arg[i] == '--start-offset' then
		i = i + 1
		start_offset = tonumber(arg[i])
	elseif arg[i] == '-n' or arg[i] == '--end-offset' then
		i = i + 1
		end_offset = tonumber(arg[i])
	elseif arg[i] == '-g' or arg[i] == '--guess-offset' then
		i = i + 1
		guess_offset = tonumber(arg[i])
	elseif arg[i] == '-w' or arg[i] == '--warn-only-block-read-errors' then
		settings.warn_only_block_read_errors = true
	elseif arg[i] == '-i' or arg[i] == '--ignore-block-header-errors' then
		settings.ignore_block_header_errors = true
	elseif arg[i] == '-f' or arg[i] == '--u-boot-fix' then
		settings.uboot_fix = args.uboot_fix
	elseif arg[i] == '-o' or arg[i] == '--output-dir' then
		i = i + 1
		outpath = arg[i]
	elseif arg[i] == '-h' or arg[i] == '--help' then
		print(CMD_HELP)
		os.exit(0)
	elseif i == #arg and #arg ~= 0 then
		path = arg[#arg]
	else
		print("Usage is incorrect.")
		print("Try 'ubireader_extract_images --help' for more imformation.")
		os.exit(1)
	end
	i = i + 1
end
if io.open(path, 'rb') == nil then
	error("File path doesn't exist.")
	os.exit(1)
end

start_offset = start_offset or utils:guess_start_offset(path, guess_offset)
if utils:guess_filetype(path, start_offset) ~= UBI_EC_HDR_MAGIC then
	error('File does not look like UBI data.')
	os.exit(1)
end
outpath = outpath or ("%s/%s"):format(settings.output_dir, path:match("([^/]+)$"))
block_size = block_size or utils:guess_peb_size(path)
if block_size == nil then
	error('Block size could not be determined.')
	os.exit(1)
end
-- Create file object.
local ufile_obj = ubi_file:new(path, block_size, start_offset, end_offset)
-- Create UBI object
local ubi_obj = ubi:new(ufile_obj)
-- Loop through found images in file.
for ik, image in pairs(ubi_obj.images) do
	if image_type == 'UBI' then
		-- Create output path and open file.
		local img_outpath = ("%s/%s"):format(outpath, ('img-%s.ubi'):format(image.image_seq))
		create_output_dir(outpath)
		local f = io.open(img_outpath, 'wb')
	
		-- Loop through UBI image blocks
		for bk, block in spairs(image:get_blocks(ubi_obj.blocks)) do
			if block.is_valid then
				-- Write block (PEB) to file
				f:write(ubi_obj.file:read_block(block))
			end
		end
	elseif image_type == 'UBIFS' then
		-- Loop through image volumes
		for vk, volume in pairs(image.volumes) do
			-- Create output path and open file.
			local vol_outpath = ("%s/%s"):format(outpath, ('img-%s_vol-%s.ubifs'):format(image.image_seq, vk))
			create_output_dir(outpath)
			local f = io.open(vol_outpath, 'wb')
			-- Loop through and write volume block data (LEB) to file.
			for bk, block in ipairs(volume:reader(ubi_obj)) do
				f:write(block)
			end
		end
	end
end