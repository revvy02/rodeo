local process = require("@lune/process")

type Arch = process.Arch | "arm" | "x86"
export type ExecutableDescriptor = {
	os: process.OS,
	arch: { Arch },
}

local ENDIANNESS = {
	function(x: number)
		return x
	end,
	bit32.byteswap,
}

return function(binaryContents: buffer): ExecutableDescriptor?
	-- Windows PE
	do
		local DOS_HEADER = "MZ"
		local PE_HEADER_OFFSET = 0x3c
		local PE_MAGIC_SIGNATURE = "PE\x00\x00"
		local PE_MACHINE_TYPES: { [number]: Arch } = {
			[0x8664] = "x86_64",
			[0x01c0] = "arm",
			[0xaa64] = "aarch64",
			[0x014c] = "x86",
		}

		if buffer.readstring(binaryContents, 0, 2) == DOS_HEADER then
			-- File was a DOS executable, jump to PE header to get the magic offset
			local signatureOffset = buffer.readu32(binaryContents, PE_HEADER_OFFSET)

			-- Check if the value at the magic offset was the PE magic signature
			if buffer.readstring(binaryContents, signatureOffset, 4) == PE_MAGIC_SIGNATURE then
				-- After the first 4 magic bytes, the next 2 bytes are architecture information
				local machineType = buffer.readu16(binaryContents, signatureOffset + 4)
				return {
					os = "windows",
					arch = { PE_MACHINE_TYPES[machineType] },
				}
			end
		end
	end

	-- Linux ELF
	do
		local ELF_MAGIC_START = 0x7f
		local ELF_MAGIC_SIGNATURE = "ELF"
		local ELF_MACHINE_TYPES: { [number]: Arch } = {
			[0x3e] = "x86_64",
			[0x28] = "arm",
			[0xb7] = "aarch64",
			[0x03] = "x86",
		}

		-- ELF files have a magic signature of [0x7f, 'E', 'L', 'F']
		if
			buffer.readu8(binaryContents, 0) == ELF_MAGIC_START
			and buffer.readstring(binaryContents, 1, 3) == ELF_MAGIC_SIGNATURE
		then
			-- Machine type is located after 16 bytes of ident and 2 bytes of type
			local machineType = buffer.readu16(binaryContents, 18)
			return {
				os = "linux",
				arch = { ELF_MACHINE_TYPES[machineType] },
			}
		end
	end

	-- macOS Mach-O
	-- Unlike other types of executables, which are either strictly defined to an endianness
	-- or their endianness doesn't matter, Mach-O's executables' endianness is not defined,
	-- and it matters, so we have to brute force it
	for _, endianness in ENDIANNESS do
		local MACHO_MAGIC_32 = endianness(0xFEEDFACE)
		local MACHO_MAGIC_64 = endianness(0xFEEDFACF)
		local MACHO_MAGIC_UN = endianness(0xCAFEBABE)

		local MACHO_CPU_TYPES: { [number]: Arch? } = {
			[endianness(0x00000007)] = "x86",
			[endianness(0x0000000C)] = "arm",
			[endianness(0x01000007)] = "x86_64",
			[endianness(0x0100000C)] = "aarch64",
		}

		-- First 4 bytes are the magic number
		local headerStart = buffer.readu32(binaryContents, 0)
		if headerStart == MACHO_MAGIC_UN then
			-- Next 4 bytes is the number of images in this binary
			local imagesAmount = endianness(buffer.readu32(binaryContents, 4))
			local arches: { Arch } = {}

			for i = 0, imagesAmount - 1 do
				-- 4 bytes for the CPU type
				-- 4 bytes for the CPU subtype
				-- 4 bytes for the file offset
				-- 4 bytes for the size
				-- 4 bytes for the section alignment
				-- += 20
				local cpuType = buffer.readu32(binaryContents, 8 + i * 20)
				local arch = MACHO_CPU_TYPES[cpuType]
				if arch then
					table.insert(arches, arch)
				end
			end

			return {
				os = "macos",
				arch = arches,
			}
		end

		if headerStart == MACHO_MAGIC_64 or headerStart == MACHO_MAGIC_32 then
			-- Next 4 bytes are the CPU type
			local cpuType = buffer.readu32(binaryContents, 4)
			local arch: Arch? = MACHO_CPU_TYPES[cpuType]

			return {
				os = "macos",
				arch = if arch then { arch } else {},
			}
		end
	end

	return nil
end
