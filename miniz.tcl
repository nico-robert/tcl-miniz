# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# tcl-miniz - Tcl bindings for miniz (https://github.com/richgel999/miniz).

# 06-Dec-2025 : v0.1 Initial release

package require Tcl  8.6-
package require cffi 2.0

namespace eval miniz {

    variable libminizMinVersion "11.0.2"
    variable version 0.1
    variable packageDirectory [file dirname [file normalize [info script]]]
    variable supportedMinizVersions [list 3.1.0 310]
    variable allocSize 128

    proc load_miniz {} {
        # Locates and loads the miniz shared library
        #
        # Tries in order
        #   - the system default search path
        #   - platform specific subdirectories under the package directory
        #   - the toplevel package directory
        #   - the directory where the main program is installed
        # If all fail, simply tries the name as is in which case the
        # system will look up in the standard shared library search path.
        #
        # On success, creates the MINIZ cffi::Wrapper object in the global
        # namespace.
        variable packageDirectory
        variable supportedMinizVersions

        # First make up list of possible shared library names depending
        # on platform and supported shared library versions.
        set ext [info sharedlibextension]
        if {$::tcl_platform(platform) eq "windows"} {
            # Names depend on compiler (mingw/vc). VC -> miniz, mingw -> libminiz
            # Examples: miniz.dll, libminiz.dll, minizVERSION.dll, miniz-VERSION.dll
            foreach baseName {miniz miniz-1 libminiz} {
                foreach minizVersion $supportedMinizVersions {
                    lappend fileNames \
                        $baseName$minizVersion$ext \
                        $baseName-$minizVersion$ext
                }
                lappend fileNames $baseName$ext
            }
        } else {
            # Unix: libminiz.so, libminizVERSION.so, libminiz-VERSION.so, libminiz.so.VERSION
            foreach minizVersion $supportedMinizVersions {
                lappend fileNames \
                    libminiz$minizVersion$ext \
                    libminiz.$minizVersion$ext \
                    libminiz-$minizVersion$ext
            }
            lappend fileNames libminiz$ext
        }

        set attempts {}

        # First try the system default search paths by no explicitly
        # specifying the full path
        foreach fileName $fileNames {
            if {![catch {
                cffi::Wrapper create ::MINIZ $fileName
            } err]} {
                return
            }
            append attempts $fileName : $err \n
        }

        # Not on default search path. Look under platform specific directories
        # under the package directory.
        package require platform
        set searchPaths [lmap platform [platform::patterns [platform::identify]] {
            if {$platform eq "tcl"} {
                continue
            }
            file join $packageDirectory $platform
        }]
        # Also look in package directory and location of main executable.
        # On Windows, the latter is probably redundant but...
        lappend searchPaths $packageDirectory
        lappend searchPaths [file dirname [info nameofexecutable]]
        # Specific case for macOS where the shared library is installed
        # under '/usr/local/lib'.
        if {$::tcl_platform(platform) eq "unix"} {
            set searchPaths [linsert $searchPaths end "/usr/local/lib"]
        }
        # Now do the actual search over search path for each possible name
        foreach searchPath $searchPaths {
            foreach fileName $fileNames {
                set path [file join $searchPath $fileName]
                if {![catch {
                    cffi::Wrapper create ::MINIZ $path
                } err]} {
                    return
                }
                append attempts $path : $err \n
            }
        }
        return -code error "Failed to load libminiz:\n$attempts"
    }

    proc error {dict} {
        # Throws an exception with the miniz error message
        #
        # dict - dictionary created by the MINIZ cffi::Wrapper object
        #
        # Returns nothing

        set zip_archive [dict get $dict In pZip]
        set index       [mz_zip_get_last_error $zip_archive]
        set enum        [cffi::enum name mz_zip_error $index]
        set msg         [mz_zip_get_error_string $enum]

        cffi::memory free $zip_archive

        throw MINIZ_ERROR "miniz($enum): $msg."
    }

    proc zip {zip_fullpath file_list {compression "MZ_DEFAULT_COMPRESSION"} {comment ""}} {
        # Creates a zip archive
        #
        # zip_fullpath - full path to zip archive
        # file_list    - list of files to add to archive
        # compression  - compression level
        #
        # Returns nothing
        variable allocSize

        set zip_archive [cffi::memory allocate $allocSize ::mza]
        cffi::memory fill $zip_archive 0 $allocSize

        mz_zip_writer_init_file $zip_archive $zip_fullpath 0

        foreach file $file_list {
            mz_zip_writer_add_file $zip_archive \
                [file tail $file] \
                $file \
                $comment \
                [string length $comment] \
                $compression
        }

        mz_zip_writer_finalize_archive $zip_archive
        mz_zip_writer_end $zip_archive
        cffi::memory free $zip_archive

        return {}
    }

    proc unzip {zip_fullpath dest_dir} {
        # Unzips a zip archive
        #
        # zip_fullpath - full path to zip archive
        # dest_dir     - destination directory
        #
        # Returns nothing
        variable allocSize

        file mkdir $dest_dir

        set zip_archive [cffi::memory allocate $allocSize ::mza]
        cffi::memory fill $zip_archive 0 $allocSize

        mz_zip_reader_init_file $zip_archive $zip_fullpath 0
        set num_files [mz_zip_reader_get_num_files $zip_archive]

        for {set i 0} {$i < $num_files} {incr i} {
            mz_zip_reader_get_filename $zip_archive $i filename 512
            if {$filename eq ""} {
                continue
            }
            set dest_path [file join $dest_dir $filename]

            set is_directory [mz_zip_reader_is_file_a_directory $zip_archive $i]

            if {$is_directory} {
                file mkdir $dest_path
            } else {
                set parent_dir [file dirname $dest_path]
                if {![file exists $parent_dir]} {
                    file mkdir $parent_dir
                }
                mz_zip_reader_extract_to_file $zip_archive $i $dest_path 0
            }
        }

        mz_zip_reader_end $zip_archive
        cffi::memory free $zip_archive

        return {}
    }

    proc addInPlace {zip_fullpath file_name data {compression "MZ_DEFAULT_COMPRESSION"} {comment ""}} {
        # Adds data in place to a zip archive in memory.
        #
        # zip_fullpath - full path to zip archive
        # file_name    - file name
        # data         - data to add to archive
        # compression  - compression level
        # comment      - file comment
        #
        # Returns nothing

        mz_zip_add_mem_to_archive_file_in_place $zip_fullpath \
            $file_name \
            $data \
            [expr {[string length $data] + 1}] \
            $comment \
            [string length $comment] \
            $compression

        return {}
    }

    proc unzipInMemory {zip_fullpath callback_command} {
        # Unzips a zip archive in memory.
        #
        # zip_fullpath     - full path to zip archive
        # callback_command - callback command
        #
        # Returns nothing
        variable allocSize

        set cb [cffi::callback new ::mz_file_write_func $callback_command 0]

        set zip_archive [cffi::memory allocate $allocSize ::mza]
        cffi::memory fill $zip_archive 0 $allocSize

        mz_zip_reader_init_file $zip_archive $zip_fullpath 0
        set num_files [mz_zip_reader_get_num_files $zip_archive]
        
        for {set i 0} {$i < $num_files} {incr i} {
            mz_zip_reader_extract_to_callback $zip_archive $i $cb NULL 0
        }

        mz_zip_reader_end $zip_archive
        cffi::callback free $cb
        cffi::memory free $zip_archive

        return {}
    }

    proc getZipStats {zip_fullpath} {
        # Gets zip archive stats
        #
        # zip_fullpath - full path to zip archive
        #
        # Returns dictionary of stats.
        variable allocSize

        set zip_archive [cffi::memory allocate $allocSize ::mza]
        cffi::memory fill $zip_archive 0 $allocSize

        mz_zip_reader_init_file $zip_archive $zip_fullpath 0
        set num_files [mz_zip_reader_get_num_files $zip_archive]
        set statFiles [dict create]

        for {set i 0} {$i < $num_files} {incr i} {
            mz_zip_reader_file_stat $zip_archive $i stat
            dict set statFiles $i $stat
        }

        mz_zip_reader_end $zip_archive
        cffi::memory free $zip_archive

        return $statFiles
    }

    proc compress {data {level 6}} {
        # Compresses a string
        #
        # data   - string to compress
        # level  - compression level
        #
        # Returns compressed string
        set source_len [string length $data]
        set maxLenOut [mz_compressBound $source_len]
        set dest [cffi::memory allocate $maxLenOut ::dest]
        set dest_len $maxLenOut

        set result [mz_compress2 $dest dest_len $data $source_len $level]

        if {$result != 0} {
            cffi::memory free $dest
            set enum [cffi::enum name mz_zip $result]
            throw MINIZ_ERROR "miniz($enum): string compression failed."
        }

        set compressed_data [cffi::memory tobinary $dest $dest_len]

        cffi::memory free $dest

        return $compressed_data
    }

    proc uncompress {data} {
        # Uncompresses a string
        #
        # data - compressed string
        #
        # Returns uncompressed string
        set source_len [string length $data]
        set max_size [expr {1000 * $source_len}]
        set dest [cffi::memory allocate $max_size ::dest]

        set dest_len $max_size

        set result [mz_uncompress $dest dest_len $data $source_len]

        if {$result != 0} {
            cffi::memory free $dest
            set enum [cffi::enum name mz_zip $result]
            throw MINIZ_ERROR "miniz($enum): string uncompression failed."
        }

        set uncompressed_data [cffi::memory tobinary $dest $dest_len]

        cffi::memory free $dest

        return $uncompressed_data
    }

}

miniz::load_miniz

MINIZ function mz_version string {}

if {[package vcompare [mz_version] $::miniz::libminizMinVersion] < 0} {
    error "tcl-miniz zlib version '[mz_version]' is\
        unsupported. Need '$::miniz::libminizMinVersion' or later."
}

cffi::alias load C

cffi::alias define mz_ulong ulong
cffi::alias define mza pointer
cffi::alias define mz_bool {int nonzero {onerror miniz::error}}
cffi::alias define mz_uint64 uint64_t
cffi::alias define mz_uint32 int
cffi::alias define mz_uint int
cffi::alias define mz_uint16 ushort

cffi::enum define levelFlags {
    MZ_NO_COMPRESSION      0
    MZ_BEST_SPEED          1
    MZ_BEST_COMPRESSION    9
    MZ_UBER_COMPRESSION    10
    MZ_DEFAULT_LEVEL       6
    MZ_DEFAULT_COMPRESSION -1
}

cffi::enum sequence mz_zip_error {
    MZ_ZIP_NO_ERROR
    MZ_ZIP_UNDEFINED_ERROR
    MZ_ZIP_TOO_MANY_FILES
    MZ_ZIP_FILE_TOO_LARGE
    MZ_ZIP_UNSUPPORTED_METHOD
    MZ_ZIP_UNSUPPORTED_ENCRYPTION
    MZ_ZIP_UNSUPPORTED_FEATURE
    MZ_ZIP_FAILED_FINDING_CENTRAL_DIR
    MZ_ZIP_NOT_AN_ARCHIVE
    MZ_ZIP_INVALID_HEADER_OR_CORRUPTED
    MZ_ZIP_UNSUPPORTED_MULTIDISK
    MZ_ZIP_DECOMPRESSION_FAILED
    MZ_ZIP_COMPRESSION_FAILED
    MZ_ZIP_UNEXPECTED_DECOMPRESSED_SIZE
    MZ_ZIP_CRC_CHECK_FAILED
    MZ_ZIP_UNSUPPORTED_CDIR_SIZE
    MZ_ZIP_ALLOC_FAILED
    MZ_ZIP_FILE_OPEN_FAILED
    MZ_ZIP_FILE_CREATE_FAILED
    MZ_ZIP_FILE_WRITE_FAILED
    MZ_ZIP_FILE_READ_FAILED
    MZ_ZIP_FILE_CLOSE_FAILED
    MZ_ZIP_FILE_SEEK_FAILED
    MZ_ZIP_FILE_STAT_FAILED
    MZ_ZIP_INVALID_PARAMETER
    MZ_ZIP_INVALID_FILENAME
    MZ_ZIP_BUF_TOO_SMALL
    MZ_ZIP_INTERNAL_ERROR
    MZ_ZIP_FILE_NOT_FOUND
    MZ_ZIP_ARCHIVE_TOO_LARGE
    MZ_ZIP_VALIDATION_FAILED
    MZ_ZIP_WRITE_CALLBACK_FAILED
    MZ_ZIP_TOTAL_ERRORS
}

cffi::enum define mz_zip {
    MZ_OK            0
    MZ_STREAM_END    1
    MZ_NEED_DICT     2
    MZ_ERRNO         -1
    MZ_STREAM_ERROR  -2
    MZ_DATA_ERROR    -3
    MZ_MEM_ERROR     -4
    MZ_BUF_ERROR     -5
    MZ_VERSION_ERROR -6
    MZ_PARAM_ERROR   -10000
}

cffi::Struct create mz_dummy_time_t {
    m_dummy1 mz_uint32
    m_dummy2 mz_uint32
}

cffi::Struct create mz_zip_archive_file_stat {
    m_file_index mz_uint32
    m_central_dir_ofs mz_uint64
    m_version_made_by mz_uint16
    m_version_needed mz_uint16
    m_bit_flag mz_uint16
    m_method mz_uint16
    m_crc32 mz_uint32
    m_comp_size mz_uint64
    m_uncomp_size mz_uint64
    m_internal_attr mz_uint16
    m_external_attr mz_uint32
    m_local_header_ofs mz_uint64
    m_comment_size mz_uint32
    m_is_directory int
    m_is_encrypted int
    m_is_supported int
    m_filename chars[512]
    m_comment chars[512]
    m_time struct.mz_dummy_time_t
}

cffi::prototype function mz_file_write_func size_t {
    pOpaque  {pointer unsafe}
    file_ofs mz_uint64
    pBuf     {pointer unsafe}
    n        size_t
}

MINIZ functions {
    mz_compress int {
        pDest {pointer.dest unsafe}
        pDest_len {mz_ulong inout}
        pSource string
        source_len mz_ulong
    }

    mz_zip_writer_init_file mz_bool {
        pZip      {mza unsafe}
        pFilename string
        size_to_reserve_at_beginning mz_uint64
    }

    mz_zip_writer_add_file mz_bool {
        pZip {mza unsafe}
        pArchive_name string
        pSrc_filename string
        pComment {string nullifempty}
        comment_size mz_uint16
        level_and_flags {mz_uint {enum levelFlags}}
    }

    mz_zip_reader_init_file mz_bool {
        pZip {mza unsafe}
        pFilename string
        flags mz_uint32
    }

    mz_zip_reader_get_num_files mz_uint {
        pZip {mza unsafe}
    }

    mz_zip_reader_is_file_a_directory mz_uint {
        pZip {mza unsafe}
        file_index mz_uint
    }

    mz_zip_reader_get_filename mz_uint {
        pZip {mza unsafe}
        file_index mz_uint
        pFilename {chars[filename_buf_size] out}
        filename_buf_size mz_uint
    }

    mz_zip_reader_extract_to_file mz_bool {
        pZip {mza unsafe}
        file_index mz_uint
        pDst_filename string
        flags mz_uint
    }

    mz_zip_writer_finalize_archive mz_bool {
        pZip {mza unsafe}
    }

    mz_zip_writer_end mz_bool {
        pZip {mza unsafe}
    }

    mz_zip_reader_end mz_bool {
        pZip {mza unsafe}
    }

    mz_zip_zero_struct void {
        pZip {mza unsafe}
    }

    mz_zip_get_last_error {int {enum mz_zip_error}} {
        pZip {mza unsafe}
    }

    mz_zip_get_error_string string {
        mz_err {int {enum mz_zip_error}}
    }

    mz_compress2 int {
        pDest {pointer.dest unsafe}
        pDest_len {mz_ulong inout}
        pSource string
        source_len mz_ulong
        level int
    }

    mz_compressBound mz_ulong {
        source_len mz_ulong
    }

    mz_uncompress int {
        pDest {pointer.dest unsafe}
        pDest_len {mz_ulong inout}
        pSource binary
        source_len mz_ulong
    }

    mz_zip_add_mem_to_archive_file_in_place mz_bool {
        pZip_filename string
        pArchive_name string
        pBuf {chars[buf_size]}
        buf_size mz_ulong
        pComment {string nullifempty}
        comment_size mz_uint16
        level_and_flags {mz_uint {enum levelFlags}}
    }

    mz_zip_reader_extract_to_callback mz_bool {
        pZip {mza unsafe}
        file_index mz_uint
        pCallback pointer.mz_file_write_func
        pOpaque {pointer nullok}
        flags mz_uint
    }

    mz_zip_reader_file_stat mz_bool {
        pZip {mza unsafe}
        file_index mz_uint
        pStat {struct.mz_zip_archive_file_stat out}
    }

}

package provide miniz $::miniz::version