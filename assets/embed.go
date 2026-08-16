// Linsk - A utility to access Linux-native file systems on non-Linux operating systems.
// Copyright (c) 2023 The Linsk Authors.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

package assets

import (
	"embed"
	"io"
	"io/fs"
)

// These files must be placed in assets/files/ before building.
// They are embedded into the binary to support offline machines.

//go:embed files/alpine-virt-3.20.3-x86_64.iso
var AlpineBaseImageX86 []byte

//go:embed files/alpine-virt-3.20.3-aarch64.iso
var AlpineBaseImageARM []byte

//go:embed files/edk2-aarch64-code.fd
var Aarch64EFIImage []byte

//go:embed files/vmimages
var vmImageARMFS embed.FS

//go:embed files/apks
var apkCacheFS embed.FS

// readEmbedFSFile reads a file from an embed.FS into a byte slice.
func readEmbedFSFile(fsys embed.FS, name string) []byte {
	f, err := fsys.Open(name)
	if err != nil {
		return nil
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		return nil
	}
	return data
}

// GetVMImageBytes returns the embedded pre-built VM image for the current architecture.
// Returns nil if no embedded VM image is available for this architecture.
func GetVMImageBytes(arch string) []byte {
	switch arch {
	case "arm64", "aarch64":
		return readEmbedFSFile(vmImageARMFS, "files/vmimages/3.20.3-aarch64-linsk1.qcow2")
	}
	return nil
}

// HasEmbeddedVMImage returns true if a pre-built VM image is embedded for the given architecture.
func HasEmbeddedVMImage(arch string) bool {
	return GetVMImageBytes(arch) != nil
}

// ApkCacheFS provides access to embedded APK package cache.
// This is used for offline VM image building.
// The directory structure is: files/apks/<version>/<arch>/<apk files>
func GetApkCacheFS() fs.FS {
	fsys, err := fs.Sub(apkCacheFS, "files/apks")
	if err != nil {
		return nil
	}
	return fsys
}

// HasApkCache returns true if embedded APK cache is available.
func HasApkCache() bool {
	return GetApkCacheFS() != nil
}

// GetAlpineBaseImageBytes returns the embedded Alpine ISO for the current architecture.
// Returns nil if no embedded image is available for this architecture.
func GetAlpineBaseImageBytes(arch string) []byte {
	switch arch {
	case "amd64", "x86_64":
		if len(AlpineBaseImageX86) > 0 {
			return AlpineBaseImageX86
		}
	case "arm64", "aarch64":
		if len(AlpineBaseImageARM) > 0 {
			return AlpineBaseImageARM
		}
	}
	return nil
}

// GetAarch64EFIImageBytes returns the embedded aarch64 EFI image.
func GetAarch64EFIImageBytes() []byte {
	if len(Aarch64EFIImage) > 0 {
		return Aarch64EFIImage
	}
	return nil
}
