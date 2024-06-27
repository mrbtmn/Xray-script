###hostName Changer
#!/bin/bash



clear

echo -e "\e[32mEnter New Hostname:\e[0m "

read hostName

sudo hostnamectl set-hostname $hostName

sudo systemctl restart systemd-hostnamed

hostnamectl



# Set the text color to green

echo -e "\e[32mDo you want to reboot the system? (yes/no):\e[0m"



# Read user input

read choice



# Check the user's choice

if [ "$choice" == "yes" ]; then

  for i in {5..1}; do

    echo -e "\e[33mRebooting the system in $i seconds...\e[0m"

    sleep 1  # Delay for 5 seconds

  done

sudo reboot

elif [ "$choice" == "no" ]; then

    echo -e "\e[33mNo reboot requested. Exiting.\e[0m"

else

    echo -e "\e[33mInvalid choice. Please enter 'yes' or 'no'.\e[0m"

fi