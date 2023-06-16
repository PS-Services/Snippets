#!/bin/bash

pushd $(pwd)

__result="0";

function Install-Dotnet {
    local apt=$(type -t apt);
    if [ $apt ]
    then
        echo "Installing libicu with apt." &> /dev/tty
        sudo apt install libicu-dev;

        if [ "$?" != "0" ] ; then
            __result="$?"
            echo "\`sudo apt install libicu-dev\` failed with exit code: ${__result}" &> /dev/tty
            return
        fi
    else
        local yum=$(type -t yum)
        if [ $yum ]
        then
            echo "Installing libicu with yum." &> /dev/tty
            sudo yum install libicu;

            if [ "$?" != "0" ] ; then
                __result="$?"
                echo "\`sudo yum install libicu\` failed with exit code: ${__result}" &> /dev/tty
                return
            fi

            sudo yum install libicu-devel.x86_64;

            if [ "$?" != "0" ] ; then
                __result="$?"
                echo "\`sudo yum install libicu-devel.x86_64\` failed with exit code: ${__result}" &> /dev/tty
                return
            fi

            sudo /usr/bin/pecl install intl;

            if [ "$?" != "0" ] ; then
                __result="$?"
                echo "\`sudo /usr/bin/pecl install intl\` failed with exit code: ${__result}" &> /dev/tty
                return
            fi
        else
            local zypper=$(type -t zypper)
            if [ $zypper ]
            then
                echo "Installing libicu with zypper." &> /dev/tty
                sudo zypper install libicu70;

                if [ "$?" != "0" ] ; then
                    __result="$?"
                    echo "\`sudo zypper install libicu70\` failed with exit code: ${__result}" &> /dev/tty
                    return
                fi
            fi
        fi
    fi

    if [ $__result != "0" ] ; then
        echo "Error installing libicu"
        exit $(echo "${__result}" | tr -dc '0-9')
    fi

    echo

    url="https://download.visualstudio.microsoft.com/download/pr/7fe73a07-575d-4cb4-b2d3-c23d89e5085f/d8b2b7e1c0ed99c1144638d907c6d152/dotnet-sdk-7.0.101-linux-x64.tar.gz";
    echo "Downlading $url" &> /dev/tty
    curl -o dotnet-sdk-6.0.100-linux-x64.tar.gz --verbose $url;

    if [ "$?" != "0" ] ; then
        __result="$?"
        echo "\`curl -o dotnet-sdk-6.0.100-linux-x64.tar.gz --verbose \$url\` failed with exit code: ${__result}" &> /dev/tty
        exit $(echo "${__result}" | tr -dc '0-9')
    fi

    echo "Extracting to $HOME/dotnet" &> /dev/tty
    mkdir -p $HOME/dotnet && tar zxf dotnet-sdk-6.0.100-linux-x64.tar.gz -C $HOME/dotnet;

    if [ "$?" != "0" ] ; then
        __result="$?"
        echo "\`mkdir -p \$HOME/dotnet && tar zxf dotnet-sdk-6.0.100-linux-x64.tar.gz -C \$HOME/dotnet\` failed with exit code: ${__result}" &> /dev/tty
        exit $(echo "${__result}" | tr -dc '0-9')
    fi

    echo "Exporting variables." &> /dev/tty
    export DOTNET_ROOT=$HOME/dotnet;
    export PATH=$PATH:$HOME/dotnet:$HOME/.dotnet/tools;

    dotnet=$(type -t dotnet);
    echo "dotnet: $dotnet" &> /dev/tty

    echo "Updating ~/.profile" &> /dev/tty
    echo "export DOTNET_ROOT=\$HOME/dotnet" >> ~/.profile;
    echo "export PATH=\$PATH:\$HOME/dotnet:\$HOME/.dotnet/tools" >> ~/.profile;

    __result="0";
}

function Install-PowerShell {
    echo "Installing PowerShell as dotnet tool." &> /dev/tty
    # Install Powershell
    dotnet tool update --global PowerShell &> /dev/tty

    __result="$?";
}

function Setup-Snippets {
    destination="$HOME/.config/powershell"

    rm -f -r $destination
    mkdir -p $destination;

    cd $destination;

    git clone https://github.com/PS-Services/Snippets.git &> /dev/tty

    if [ "$?" != "0" ] ; then
        __result="$?"
        echo "Git Clone failed with exit code: ${__result}" &> /dev/tty
        exit $(echo "${__result}" | tr -dc '0-9')
    fi

    echo "# SNIPPETS BEGIN" > "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
    cat "$HOME/.config/powershell/Snippets/Linux-ReadmeTest.ps9" >> "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
    echo "# SNIPPETS END" >> "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"

    if [ -f "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1" ]
    then
        echo "Installation succeeded.  Start PowerShell by typing 'pwsh'" &> /dev/tty
    else
        echo "Installation failed.  Cannot find $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1" &> /dev/tty
        exit 1
    fi

    __result="0"
}

function Continue-With {
    local result=$(echo "$1" | tr -dc '0-9');
    local continuation="$2";
    local reason="$3";

    echo "Called Continue-With \"$1\" \"$2\" \"$3\"" &> /dev/tty

    if [ "${result}" == "0" ] ; then
        eval ${continuation}
        echo "Continuing with: [${continuation}] resulted in [${__result}]" &> /dev/tty
    else
        echo $reason &> /dev/tty
        exit $(echo "${result}" | tr -dc '0-9')
    fi
}

function Check-Dotnet {
    if [ ! $(type -t dotnet) ]
    then
        Install-Dotnet
    else
        echo "Dotnet is already installed." &> /dev/tty
        __result="0"
    fi
}

Check-Dotnet;
Continue-With "${__result}" "Install-PowerShell" "1: Dotnet not found and unable to install it.";
Continue-With "${__result}" "Setup-Snippets" "2: Powershell not found and unable to install it.";

popd &> /dev/null

if [ "${__result}" != "0" ] ; then
    echo "Failed to Setup Snippets with exit code: ${__result}"
fi

exit $(echo "${__result}" | tr -dc '0-9')
