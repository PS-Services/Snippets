#!/bin/bash

__result="0";

if [ $(pwd) == "~/.config/powershell/Snippets" ] ; then
    cd ~
fi

if [ -d ~/.config/powershell/Snippets ] ; then
    rm -rf ~/.config/powershell/Snippets
    __result="$?"
fi

if [ "${__result}" != "0" ] ; then
    echo "Failed to Uninstall Snippets with exit code: ${__result}"
else
    echo "Succesfully Uninstalled Snippets with exit code: ${__result}" 
fi

exit $(echo "${__result}" | tr -dc '0-9')
