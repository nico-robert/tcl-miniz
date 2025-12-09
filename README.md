# tcl-miniz - Zip library for Tcl.

Tcl bindings for [**miniz**](https://github.com/richgel999/miniz)

## Compatibility :
- [Tcl](https://www.tcl.tk/) 8.6 or higher

## Dependencies :

- [tcl-cffi](https://github.com/apnadkarni/tcl-cffi) >= 2.0

## Cross-Platform :
- Windows, Linux, macOS support.

## Example :
```tcl
package require miniz

# Create a zip archive :
# level compression : MZ_NO_COMPRESSION, MZ_BEST_SPEED, MZ_BEST_COMPRESSION,
# MZ_UBER_COMPRESSION, MZ_DEFAULT_LEVEL, MZ_DEFAULT_COMPRESSION

miniz::zip archive.zip {file1.txt file2.txt} "MZ_BEST_SPEED"

# Unzip a zip archive :
miniz::unzip archive.zip ./extracted

# Compress a string
set data "Hello World! [string repeat "Test... " 100]"
set compressed [miniz::compress $data]

puts "Original data: [string length $data] bytes"
puts "Compressed: [string length $compressed] bytes"

# Uncompress a string
set uncompressed [miniz::uncompress $compressed]

expr {$data eq $uncompressed}
# 1

# Adds data in place to a zip archive in memory :
set data "Hello World!"
miniz::addInPlace archive.zip "file.txt" $data

# Unzip a zip archive in memory :
proc callbackCommand {pOpaque file_ofs pBuf n} {
    # Callback function for `miniz::unzipInMemory`
    #
    # pOpaque  - opaque pointer (NULL in this case)
    # file_ofs - file offset
    # pBuf     - pointer to buffer
    # n        - number of bytes to read
    #
    # Returns the number of bytes written to the buffer.

    set safeP [cffi::pointer safe $pBuf]
    # Do something with $data ...
    set data  [cffi::memory tostring $safeP]

    cffi::pointer dispose $safeP
    
    # Important to return the number of bytes written.
    return $n
}

# The data in memory is passed to the callback command.
miniz::unzipInMemory archive.zip "callbackCommand"

# Returns a dictionary of zip archive stats.
set stats [miniz::getZipStats archive.zip]

```

## Commands :
| commands                | args                    
| ------------------------|-------------------------
| `miniz::zip`            | zip_fullpath file_list ?level_compression ?comment
| `miniz::unzip`          | zip_fullpath dest_dir
| `miniz::compress`       | data ?level
| `miniz::uncompress`     | data
| `miniz::addInPlace`     | zip_fullpath file_name data ?level_compression ?comment
| `miniz::unzipInMemory`  | zip_fullpath command
| `miniz::getZipStats`    | zip_fullpath

## License : 
[MIT](LICENSE).

## Changes :
*  **06-Dec-2025** : 0.1
    - Initial release.
*  **09-Dec-2025** : 0.12
    - Update package with new procedures (`addInPlace`, `getZipStats`, `unzipInMemory`)