```Shell
mv /home/.blueteam /home/blueteam
for user in $(/home/blueteam/Cyber-Games/dynamic_files/scoring_users.txt); do
  mv /home/.$user /home/$user
done
```
