#!/bin/bash

# Demander à l'utilisateur d'entrer les variables
read -p "Veuillez entrer le chemin de la clé SSH (appuyez sur Entrée pour utiliser le chemin par défaut) : " ssh_key_path_and_name
read -p "Veuillez entrer votre nom de domaine : " domain
read -p "Veuillez entrer le nom de votre base de données : " db_name
read -p "Veuillez entrer le nom d'utilisateur de votre base de données : " db_user
read -p "Veuillez entrer le mot de passe de votre base de données : " db_password
read -p "Veuillez entrer le chemin du repo git en SSH : " git_path

# Afficher les variables
echo "Chemin de la clé SSH : $ssh_key_path_and_name"
echo "Nom de domaine : $domain"
echo "Nom de la base de données : $db_name"
echo "Nom d'utilisateur de la base de données : $db_user"
echo "Mot de passe de la base de données : $db_password"
echo "Chemin du repo Git en SSH : $git_path"

# Demander à l'utilisateur de valider
read -p "Confirmez-vous les variables ci-dessus ? (y/n) : " confirmation
if [ "$confirmation" != "y" ]; then
    echo "Vous n'avez pas confirmé. Le script s'arrête."
    exit 1
fi

# Générer une clé SSH
if [ -z "$ssh_key_path_and_name" ]; then
    ssh_key_path_and_name="$HOME/.ssh/id_rsa"
fi

ssh-keygen -f "$ssh_key_path_and_name"

# Afficher la clé SSH générée
echo -e "\nVoici votre clé SSH générée :"
cat "$ssh_key_path_and_name.pub"
echo -e "\nVeuillez ajouter cette clé SSH à votre compte GitHub avant de continuer."

# Demander à l'utilisateur de confirmer qu'il a ajouté la clé SSH à GitHub
read -p "Une fois que vous avez ajouté la clé SSH à GitHub, veuillez écrire 'y' pour continuer : " confirmation
if [ "$confirmation" != "y" ]; then
    echo "Vous n'avez pas confirmé. Le script s'arrête."
    exit 1
fi

# Demander à l'utilisateur d'entrer les variables
read -p "Veuillez entrer votre nom de domaine : " domain
read -p "Veuillez entrer le nom de votre base de données : " db_name
read -p "Veuillez entrer le nom d'utilisateur de votre base de données : " db_user
read -p "Veuillez entrer le mot de passe de votre base de données : " db_password
read -p "Veuillez entrer le chemin du repo git en SSH : " git_path

# Mettre à jour le système
sudo apt-get update
sudo apt-get upgrade

# Installer les dépendances nécessaires
sudo apt-get install nginx ufw -y
sudo ufw allow ssh
sudo ufw allow https
sudo ufw enable
sudo ufw allow 80
sudo apt install mariadb-server -y

# Installer PHP 8.1
sudo apt-get install ca-certificates apt-transport-https software-properties-common wget curl lsb-release -y
curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x
sudo apt-get update -y
sudo apt-get install php8.1-fpm php8.1-cli php8.1-common php8.1-curl php8.1-bcmath php8.1-intl php8.1-mbstring php8.1-xmlrpc php8.1-mcrypt php8.1-mysql php8.1-gd php8.1-xml php8.1-cli php8.1-zip -y
sudo apt-get install php8.1-fpm libapache2-mod-fcgid -y
sudo a2enmod proxy_fcgi setenvif 
sudo a2enconf php8.1-fpm
sudo systemctl restart apache2
sudo systemctl status php8.1-fpm

sudo mkdir /var/www/$domain
sudo chown $USER:$USER /var/www/$domain
sudo nano /etc/nginx/sites-available/$domain

# Copiez et collez votre configuration Nginx ici
cat <<EOF | sudo tee /etc/nginx/sites-available/$domain > /dev/null
server {
    listen 80;
    server_name $domain;
    root /var/www/$domain/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF


# Lancer le reste des commandes avec le domaine spécifié
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
sudo unlink /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# Configurer la base de données MySQL
sudo mysql -e "CREATE DATABASE $db_name;"
sudo mysql -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_password' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"

# Installer Composer
sudo apt install wget php-cli php-zip unzip -y
wget -O composer-setup.php https://getcomposer.org/installer
sudo php composer-setup.php --2.2 --install-dir=/usr/local/bin --filename=composer

# Installer Node.js avec NVM
sudo apt install nodejs -y
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.bashrc
nvm install node --latest

# Installer Git
sudo apt-get install git -y
git clone $git_path /var/www/$domain

# Configurer l'application Laravel
cd /var/www/$domain
composer install --ignore-platform-reqs
npm install
sudo chown -R $USER:www-data storage
sudo chown -R $USER:www-data bootstrap/cache
npm run build

# Configurer le fichier .env
cat <<EOL > .env
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=true
APP_URL=http://$domain

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$db_name
DB_USERNAME=$db_user
DB_PASSWORD=$db_password

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="\${APP_NAME}"
EOL

php artisan key:generate

# Installer Certbot pour Let's Encrypt
sudo apt-get install snapd -y
sudo snap install core; sudo snap refresh core
sudo apt-get remove certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx

# Afficher les variables à la fin du script
echo -e "\nRécapitulatif des variables :"
echo "Domaine: $domain"
echo "Base de données: $db_name"
echo "Utilisateur MySQL: $db_user"
echo "Mot de passe MySQL: $db_password"
echo "Utilisateur Git SSH: $git_user"