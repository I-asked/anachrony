#!/bin/bash
# Copyright (C) 2015 Florent Revest <revestflo@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

declare -a devices=("anthias" "bass" "beluga" "catfish" "dory" "firefish" "harmony" "hoki" "koi" "inharmony" "lenok" "minnow" "mooneye" "narwhal" "nemo" "pike" "qemux86" "ray" "smelt" "sparrow" "sparrow-mainline" "sprat" "sturgeon" "sawfish" "skipjack" "swift" "tetra" "triggerfish" "wren")

declare -a layers=(
    "src/oe-core                   https://github.com/openembedded/openembedded-core.git mickledore"
    "src/oe-core/bitbake           https://github.com/openembedded/bitbake.git           2.4"
    "src/meta-openembedded         https://github.com/openembedded/meta-openembedded.git master c5f330bc9ae72989b8f880aa15e738a3c8fce4e7"
    "src/meta-qt5                  https://github.com/meta-qt5/meta-qt5                  mickledore"
    "src/meta-smartphone           https://github.com/shr-distribution/meta-smartphone   mickledore"
    "src/meta-asteroid             https://github.com/AsteroidOS/meta-asteroid           master"
    "src/meta-smartwatch           https://github.com/AsteroidOS/meta-smartwatch.git     master"
    "src/meta-anachrony            https://github.com/I-asked/meta-anachrony.git         main"
    "src/meta-clang                https://github.com/kraj/meta-clang.git                mickledore"
)

declare -a layers_conf=(
    "meta-clang"
    "meta-qt5"
    "oe-core/meta"
    "meta-anachrony"
    "meta-asteroid"
    "meta-openembedded/meta-oe"
    "meta-openembedded/meta-multimedia"
    "meta-openembedded/meta-gnome"
    "meta-openembedded/meta-networking"
    "meta-smartphone/meta-android"
    "meta-openembedded/meta-python"
    "meta-openembedded/meta-filesystems"
)

function printNoDeviceInfo {
    echo "Usage:"
    echo -e "Updating the sources:\t$ . ./prepare-build.sh update"
    echo -e "Building Anachrony:\t$ . ./prepare-build.sh device\n"
    echo -e "Available devices:\n"

    for device in ${devices[*]}; do
        echo "$device"
    done

    echo -e "\nWiki - Building Anachrony: https://anachrony.invalid/wiki/building-anachrony/"

    return 1
}

# When updating, if the user has a personal fork of the subproject, and has set the 
# upstream URL, this will fetch updates from the upstream repository
function pull_dir {
    if [ -d $1/.git/ ] ; then
        [ "$1" != "." ]   && pushd $1 > /dev/null
        git symbolic-ref HEAD &> /dev/null
        if [ $? -eq 0 ] ; then
            echo -e "\e[32mPulling $1\e[39m"
            if git remote get-url upstream &> /dev/null
            then
                git pull upstream --rebase "$2"
            else
                git pull --rebase
            fi
            [ $? -ne 0 ] && echo -e "\e[91mError pulling $1\e[39m"
            git checkout "$2"
        else
            echo -e "\e[35mSkipping $1\e[39m"
        fi
        [ "$1" != "." ]   && popd > /dev/null
    fi
}

function clone_dir {
    if [ ! -d $1 ] ; then
        echo -e "\e[32mCloning branch $3 of $2 in $1\e[39m"
        git clone -b $3 $2 $1
        [ $? -ne 0 ] &&  echo -e "\e[91mError cloning $1\e[39m"
        if [ $# -eq 4 ]
        then
            pushd $1
            git checkout $4
            popd
        fi
    fi
}

function update_layer_config() {
    # Find all layers under src/meta-smartwatch, remove the src/ prefix, sort alphabetically, and store it in an array.
    layers_smartwatch=($(find src/meta-smartwatch -mindepth 1 -name "*meta-*" -type d | sed -e 's|src/||' | sort))
    layers=("${layers_conf[@]}" "${layers_smartwatch[@]}")
    for l in "${layers[@]}"; do
        layer_line="  \${SRCDIR}/${l} \\\\"
        # Check if layer exists, insert if it doesn't.
        awk -i inplace -v line="$layer_line" -v l="$l" "
        FNR==NR {
            if(\$0~l){ found=1 }
            next
        }
        /BBLAYERS/ && found==\"\" {
            print \$0 ORS line
            next
        }
        1
        " build/conf/bblayers.conf build/conf/bblayers.conf
    done
}

# Update layers in src/
if [[ "$1" == "update" ]]; then
    pull_dir . main
    for l in "${layers[@]}"; do
        if [ -n "$ZSH_VERSION" ]; then
            read -A layer <<< "$l"
        else
            read -a layer <<< "$l"
        fi
        if [ -d "${layer[@]:0:1}" ]; then
            pull_dir "${layer[@]:0:1}" "${layer[@]:2:1}"
        fi
    done
    update_layer_config
elif [[ "$1" == "git-"* ]]; then
    base=$(dirname $0)
    gitcmd=${1:4} # drop git-
    shift
    for d in $base $base/src/* $base/src/oe-core/bitbake; do
        if [ $(git -C $d $gitcmd "$@" | wc -c) -ne 0 ]; then
            echo -e "\e[35mgit -C $d $gitcmd $@ \e[39m"
            git -C $d $gitcmd "$@"
        fi
    done
# Prepare bitbake
else
    mkdir -p src build/conf

    if [ "$#" -gt 0 ]; then

        # checking if the device is supported
        valid=false
        for device in ${devices[*]}; do
            [[ "${1}" == "$device" ]] && valid=true
        done

        if [[ "$valid" = true ]]; then
            export MACHINE=${1}
        else
            printNoDeviceInfo
            return 1
        fi
    else
        printNoDeviceInfo
        return 1
    fi

    # Fetch all the needed layers in src/
    for l in "${layers[@]}"; do
        if [ -n "$ZSH_VERSION" ]; then
            read -A layer <<< "$l"
        else
            read -a layer <<< "$l"
        fi
        clone_dir "${layer[@]:0:1}" "${layer[@]:1:1}" "${layer[@]:2:1}" "${layer[@]:3:1}"
    done

    pushd src/oe-core || exit 1
      git fetch origin master
      git checkout -f
      git clean -fdx
      git cherry-pick -X theirs -n 39e05f9b0fdc3f76f8b80a12989f78614bc9ea5c \
                                   d1af583c290eb0cff5e36363f7531832a863a1a8 \
                                   c3eba94ee44adcd3a0aa61f6b087c15c02e4697f \
                                   ad4369d7901c1239e5f07473b1f2517edc4a23ea \
                                   30637cdeb31fae02544fdc643a455d0ebb126ee6 \
                                   d1386bbf2211c7616527e62f2f7b069a935b0d68 \
                                   728c40b939c6af6358a483237298ca834cbb8993 \
                                   84f46dd2503bb0ef238fef0097c66fda88f6cbda \
                                   b98373075c6cc416bd0375b98b6bbdddf599d9a1
    popd

    # Create local.conf and bblayers.conf on first run
    if [ ! -e build/conf/local.conf ]; then
        echo -e "\e[32mWriting build/conf/local.conf\e[39m"
        echo 'DISTRO = "anachrony"
PACKAGE_CLASSES = "package_ipk"' >> build/conf/local.conf
    fi

    if [ ! -e build/conf/bblayers.conf ]; then
        echo -e "\e[32mWriting build/conf/bblayers.conf\e[39m"
        echo 'BBPATH = "${TOPDIR}"
SRCDIR = "${@os.path.abspath(os.path.join("${TOPDIR}", "../src/"))}"

BBLAYERS = " \
"' > build/conf/bblayers.conf
    update_layer_config
    fi

    # Init build env
    cd src/oe-core
    . ./oe-init-build-env ../../build > /dev/null

    echo "Welcome to the Anachrony compilation script.

If you meet any issue you can report it to the project's github page:
    https://github.com/I-asked

You can now run the following command to get started with the compilation:
    bitbake anachrony-image

Have fun!"
fi
