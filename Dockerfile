# Usar Ubuntu 22.04 como imagen base
FROM ubuntu:22.04

# Variables de entorno para evitar preguntas durante la instalación
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

# Establecer la zona horaria
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Actualizar los índices de paquetes e instalar paquetes necesarios
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        apache2 \
        libapache2-mod-perl2 \
        perl \
        libwww-perl \
        libcgi-pm-perl \
        libcgi-session-perl \
        libdbi-perl \
        libdigest-md5-perl \
        libapache2-mod-fcgid \
        wget \
        gnupg \
        supervisor \
        libdbd-mysql-perl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Instalar módulos Perl adicionales
RUN perl -MCPAN -e "install DBI" && \
    perl -MCPAN -e "install DBD::MySQL"

# Habilitar módulos de Apache necesarios
RUN a2enmod perl fcgid cgid && \
    a2enconf serve-cgi-bin && \
    a2dissite 000-default.conf && \
    a2ensite 000-default.conf

# Crear directorios necesarios
RUN mkdir -p /usr/lib/cgi-bin/dets /var/www/html/dets

# Copiar archivos de configuración y scripts
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY init.sh /init.sh
COPY . /usr/lib/cgi-bin/dets
COPY . /var/www/html/dets

# Dar permisos de ejecución a los scripts Perl y al init.sh
RUN chmod -R +x /usr/lib/cgi-bin/dets && \
    chmod -R +x /var/www/html/dets && \
    chmod +x /init.sh

# Exponer puertos necesarios
EXPOSE 80

# Definir el directorio de trabajo
WORKDIR /usr/lib/cgi-bin

# Ejecutar supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
