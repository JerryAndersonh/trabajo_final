#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Session;

# Crear un nuevo objeto CGI
my $cgi = CGI->new;

# Iniciar o continuar una sesión existente
my $session = CGI::Session->new(undef, $cgi, { Directory => '/tmp' });

# Eliminar todos los datos de la sesión
$session->delete();
$session->flush();

# Cerrar la sesión
undef $session;

# Redirigir al usuario a la página de inicio de sesión
print $cgi->redirect('/cgi-bin/dets/index.pl');
exit;

