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
# Create a zip archive
# level compression : MZ_NO_COMPRESSION, MZ_BEST_SPEED, MZ_BEST_COMPRESSION, MZ_UBER_COMPRESSION, MZ_DEFAULT_LEVEL, MZ_DEFAULT_COMPRESSION

miniz::zip archive.zip {file1.txt file2.txt} "MZ_BEST_SPEED"

# Unzip a zip archive
miniz::unzip archive.zip ./extracted

# Compress a string
set data "Hello World! [string repeat "Test... " 100]"
set compressed [miniz::compress $data]

# Uncompress a string
set uncompressed [miniz::uncompress $compressed]

expr {$data eq $uncompressed}
# 1
```

## Commands :
| commands           | args                    
| -------------------|-------------------------
| miniz::zip         | zip_fullpath file_list ?level_compression
| miniz::unzip       | zip_fullpath dest_dir
| miniz::compress    | data ?level
| miniz::uncompress  | data

## License : 
[MIT](LICENSE).

## Changes :
*  **06-Dec-2025** : 0.1
    - Initial release.