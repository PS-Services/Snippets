#!/bin/bash

pwsh=$(type -t pwsh)
echo "pwsh: $pwsh"

if [ ! $pwsh ]
then
    dotnet=$(type -t dotnet)
    echo "dotnet: $dotnet"

    if [ ! $dotnet ]
    then
        apt=$(type -t apt)
        if [ $apt ]
        then
            echo "Installing libicu with apt."
            sudo apt install libicu-dev;
        else
            yum=$(type -t yum)
            if [ $yum ]
            then
                echo "Installing libicu with yum."
                sudo yum install libicu;

                sudo yum install libicu-devel.x86_64;

                sudo /usr/bin/pecl install intl;
            else
                zypper=$(type -t zypper)
                if [ $zypper ]
                then
                    echo "Installing libicu with zypper."
                    sudo zypper install libicu70;
                fi
            fi
        fi

        echo

        url="https://download.visualstudio.microsoft.com/download/pr/17b6759f-1af0-41bc-ab12-209ba0377779/e8d02195dbf1434b940e0f05ae086453/dotnet-sdk-6.0.100-linux-x64.tar.gz";
        echo "Downlading $url"
        curl -o dotnet-sdk-6.0.100-linux-x64.tar.gz --verbose $url;
        echo "Extracting to $HOME/dotnet"
        mkdir -p $HOME/dotnet && tar zxf dotnet-sdk-6.0.100-linux-x64.tar.gz -C $HOME/dotnet;

        echo "Exporting variables."
        export DOTNET_ROOT=$HOME/dotnet;
        export PATH=$PATH:$HOME/dotnet:$HOME/.dotnet/tools;

        dotnet=$(type -t dotnet);
        echo "dotnet: $dotnet"

        echo "Updating ~/.profile"
        echo "export DOTNET_ROOT=\$HOME/dotnet" >> ~/.profile;
        echo "export PATH=\$PATH:\$HOME/dotnet:\$HOME/.dotnet/tools" >> ~/.profile;
    fi

    if [ $dotnet ]
    then
        echo "Installing PowerShell as dotnet tool."
        # Install Powershell
        dotnet tool install --global PowerShell

        pwsh=$(type -t pwsh)
        echo "pwsh: $pwsh"

        destination=$HOME/.config/powershell/Snippets
        mkdir -p $destination;
        git clone https://github.com/sharpninja/Snippets.git
        cp Linux-ReadmeTest.ps9 $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1

        mkdir $HOME/.config/powershell
        if [ -f $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1 ]
        then
            echo "Installation succeeded.  Start PowerShell by typing 'pwsh'"
        else
            echo "Installation failed.  Cannot find $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
        fi
    fi
else
    echo "Powershell already installed."

    destination=$HOME/.config/powershell/Snippets
    mkdir -p $destination;
    git clone https://github.com/sharpninja/Snippets.git
    cp Linux-ReadmeTest.ps9 $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1

    mkdir $HOME/.config/powershell
    if [ -f $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1 ]
    then
        echo "Installation succeeded.  Start PowerShell by typing 'pwsh'"
    else
        echo "Installation failed.  Cannot find $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
    fi
fi
