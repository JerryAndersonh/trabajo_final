#!/bin/bash

# Iniciar MySQL
service mysql start

# Esperar hasta que MySQL esté listo
while ! mysqladmin ping -h "127.0.0.1" --silent; do
    echo "Esperando a que MySQL se inicie..."
    sleep 2
done

# Configurar la contraseña del usuario root y permitir acceso remoto
mysql -u root <<-EOSQL
    ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '12345678';
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
EOSQL

# (Opcional) Crear un nuevo usuario para la aplicación
mysql -u root -p12345678 <<-EOSQL
    CREATE USER 'app_user'@'%' IDENTIFIED BY 'app_password';
    GRANT ALL PRIVILEGES ON detsdb.* TO 'app_user'@'%';
    FLUSH PRIVILEGES;
EOSQL

# Ejecutar scripts de inicialización de la base de datos
mysql -u root -p12345678 < /docker-entrypoint-initdb.d/detsdb.sql

# Iniciar Apache
service apache2 start

# Iniciar Supervisor para gestionar otros procesos si es necesario
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

# Mantener el contenedor en ejecución
tail -f /dev/null
