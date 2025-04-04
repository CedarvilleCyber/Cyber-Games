#! usr/bin/bash

findservice() {

if systemctl status apache2 | grep -q "loaded"; then
    sudo systemctl start apache2; echo "apache2"
elif systemctl status nginx l grep_ -q "Loaded"; then
    sudo systemctl start nginx; echo "nginx"
fi

}

details() {
    echo "hostnamectl status:"; hostnamectl status 
    echo -n "Current User: "; whoami 
    echo "All Users: "; who
}
setup() {
    echo -n "Removing rogue cronjobs:"; crontab
    local service=$(findservice)
(crontab -l; echo "*/10 * * * * sudo systemctl restart $service") | crontab echo -n "Current cronjobs:"; crontab -l

}

findservice 
echo ""
details 
echo ""
setup 
echo ""
echo "Script Completed"