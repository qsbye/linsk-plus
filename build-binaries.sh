rm -rf build
mkdir build

version=$1

if [ -z "$version" ]; then
    echo "Version is not specified (first positional argument)"
    exit 1
fi

# Check that embedded resource files exist before building.
# These files are embedded into the binary for offline support.
function check_embedded_assets() {
    local arch=$1
    local missing=0

    if [ "$arch" == "amd64" ] || [ "$arch" == "x86_64" ]; then
        if [ ! -f "assets/files/alpine-virt-3.20.3-x86_64.iso" ]; then
            echo "ERROR: Missing embedded asset: assets/files/alpine-virt-3.20.3-x86_64.iso (required for $arch builds)"
            missing=1
        fi
    fi

    if [ "$arch" == "arm64" ] || [ "$arch" == "aarch64" ]; then
        if [ ! -f "assets/files/alpine-virt-3.20.3-aarch64.iso" ]; then
            echo "ERROR: Missing embedded asset: assets/files/alpine-virt-3.20.3-aarch64.iso (required for $arch builds)"
            missing=1
        fi
        if [ ! -f "assets/files/edk2-aarch64-code.fd" ]; then
            echo "ERROR: Missing embedded asset: assets/files/edk2-aarch64-code.fd (required for $arch builds)"
            missing=1
        fi
    fi

    return $missing
}

function build() {
    name="linsk_${1}_${2}_${version}"
    binary_name="$name"
    if [ $1 == "windows" ]; then
        binary_name="$binary_name.exe"
    fi

    check_embedded_assets $2
    if [ $? -ne 0 ]; then
        echo "Build aborted for $1/$2: missing embedded assets."
        echo "Please download the required files and place them in assets/files/ before building."
        echo "See assets/files/.gitignore for download URLs."
        exit 1
    fi
    
    CGO_ENABLED=0 GOOS=$1 GOARCH=$2 go build -trimpath -o build/$binary_name
    cd build
    zip $name.zip $binary_name
    rm $binary_name
    cd ..
}

build windows amd64
build darwin amd64
build darwin arm64

cd build

hashes_file="linsk_sha256_$version.txt"

sha256sum * > $hashes_file
gpg --output ${hashes_file}.sig --detach-sign --local-user F7231DFD3333A27F71D171383B627C597D3727BD --armor $hashes_file
