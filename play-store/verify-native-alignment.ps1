param([Parameter(Mandatory = $true)][string]$BundlePath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $BundlePath))
try {
    $libraries = @($archive.Entries | Where-Object FullName -Match '^base/lib/(arm64-v8a|x86_64)/.*\.so$')
    if ($libraries.Count -eq 0) { throw 'No 64-bit native libraries found.' }
    foreach ($entry in $libraries) {
        $stream = $entry.Open()
        $memory = [IO.MemoryStream]::new()
        try { $stream.CopyTo($memory); $bytes = $memory.ToArray() }
        finally { $stream.Dispose(); $memory.Dispose() }
        if ($bytes[0] -ne 127 -or $bytes[1] -ne 69 -or $bytes[2] -ne 76 -or $bytes[3] -ne 70 -or $bytes[4] -ne 2 -or $bytes[5] -ne 1) {
            throw "Expected a little-endian ELF64 library: $($entry.FullName)"
        }
        $offset = [BitConverter]::ToUInt64($bytes, 32)
        $size = [BitConverter]::ToUInt16($bytes, 54)
        $count = [BitConverter]::ToUInt16($bytes, 56)
        $loads = 0
        for ($index = 0; $index -lt $count; $index++) {
            $header = [int]($offset + $index * $size)
            if ([BitConverter]::ToUInt32($bytes, $header) -eq 1) {
                $loads++
                $alignment = [BitConverter]::ToUInt64($bytes, $header + 48)
                if ($alignment -lt 16384) { throw "Insufficient PT_LOAD alignment ($alignment): $($entry.FullName)" }
            }
        }
        if ($loads -eq 0) { throw "No PT_LOAD headers: $($entry.FullName)" }
        Write-Output "$($entry.FullName): all $loads PT_LOAD segments aligned to at least 16 KB"
    }
    Write-Output 'ELF alignment passed. Play Console/device checks are still required for packaging and runtime compatibility.'
} finally { $archive.Dispose() }
