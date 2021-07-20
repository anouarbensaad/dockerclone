if [[ $UID -ne 0 ]];then
    printf "\n   $(tput bold)$(tput setaf 1)%s$(tput sgr0)\n\n" "You must run with root." 2>/dev/null
    exit 1
fi
sudo apt-get install -y jq
echo -e "#!/bin/bash
bash /usr/share/dockerclone/dockerclone.sh" '${1+"$@"}' > "dockerclone";
chmod +x "dockerclone";
sudo mkdir "/usr/share/dockerclone"
sudo cp "install.sh" "/usr/share/dockerclone"
sudo cp "dockerclone.py" "/usr/share/dockerclone"
sudo cp ".dockerclone_rc" "/usr/share/dockerclone"
sudo cp ".dockerclone_rc" "$HOME"
sudo cp "dockerclone" "/usr/local/bin/"
rm "dockerclone";
if [ -d "/usr/share/dockerclone" ] ;
then
    printf "\nTool $(tput bold)$(tput setaf 2)%s$(tput sgr0) Installed!\n" "Successfully"
    dockerclone
else
    echo -e "\nTool $(tput bold)$(tput setaf 1)%s$(tput sgr0) Be Installed On Your System! Use It As Portable !\n" "Cannot"
    exit
fi 