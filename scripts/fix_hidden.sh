```Shell
for user in $(./dynamic_files/scoring_users.txt); do
  mv /home/.$user /home/$user
done
mv /home/.blueteam /home/blueteam
```
