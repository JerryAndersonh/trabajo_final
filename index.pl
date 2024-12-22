#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Session;
use DBI;
use Digest::MD5 qw(md5_hex);
use CGI::Carp qw(fatalsToBrowser warningsToBrowser); # Para mostrar errores en el navegador durante desarrollo

# Crear un nuevo objeto CGI
my $cgi = CGI->new;

# Iniciar o continuar una sesión existente
my $session = CGI::Session->new(undef, $cgi, { Directory => '/tmp' });
my $userid = $session->param('detsuid');

# Si el usuario ya está autenticado, redirigir a dashboard.pl
if (defined $userid && $userid ne '') {
    print $cgi->redirect('/cgi-bin/dets/dashboard.pl');
    exit;
}

# Configuración de la conexión a la base de datos
# Configuración de la conexión a la base de datos
my $dsn = "DBI:mysql:database=detsdb;localhost;port=3306";
my $db_user = "root";           # Usuario de MySQL
my $db_pass = "12345678";       # Contraseña de MySQL

# Conectar a la base de datos
my $dbh = DBI->connect($dsn, $db_user, $db_pass, 
    { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 }) 
    or die "No se pudo conectar a la base de datos: $DBI::errstr";

# Inicializar mensaje
my $msg = '';

# Manejar la solicitud POST
if ($cgi->request_method() eq 'POST' && defined $cgi->param('login')) {
    my $email    = $cgi->param('email') || '';
    my $password = $cgi->param('password') || '';

    # Validar formato de correo electrónico
    if ($email !~ /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {
        $msg = "Formato de correo electrónico inválido.";
    } else {
        # Hash de la contraseña usando MD5
        my $hashed_password = md5_hex($password);

        # Preparar y ejecutar la consulta SQL
        my $sth = $dbh->prepare("SELECT ID FROM tbluser WHERE Email = ? AND Password = ?");
        eval {
            $sth->execute($email, $hashed_password);
        };
        if ($@) {
            $msg = "Error al ejecutar la consulta. Por favor, intenta de nuevo.";
        } else {
            my @row = $sth->fetchrow_array;

            if (@row) {
                # Establecer la variable de sesión
                $session->param('detsuid', $row[0]);

                # Finalizar el handle de declaración antes de desconectar
                $sth->finish();

                # Cerrar la conexión a la base de datos
                $dbh->disconnect();

                # Redirigir a dashboard.pl y salir sin imprimir HTML
                print $cgi->redirect('/cgi-bin/dets/dashboard.pl');
                exit;
            } else {
                $msg = "Detalles inválidos. Por favor, intenta de nuevo.";
            }
        }

        # Finalizar el handle de declaración en caso de error
        if ($sth) {
            $sth->finish();
        }
    }
}

# Función para escapar caracteres HTML (evitar inyección de HTML)
sub html_escape {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&#39;/g;
    return $text;
}

# Generar y enviar la cookie de sesión con la cabecera
my $cookie = $session->cookie;
print $cgi->header(
    -type => 'text/html',
    -charset => 'UTF-8',
    -cookie => $cookie
);

# Generar la página HTML
print <<"END_HTML";
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Daily Expense Tracker - Iniciar Sesión</title>
    <link href="/dets/css/bootstrap.min.css" rel="stylesheet">
    <link href="/dets/css/datepicker3.css" rel="stylesheet">
    <link href="/dets/css/styles.css" rel="stylesheet">
</head>
<body>
    <div class="row">
        <h2 align="center">Daily Expense Tracker</h2>
        <hr />
        <div class="col-xs-10 col-xs-offset-1 col-sm-8 col-sm-offset-2 col-md-4 col-md-offset-4">
            <div class="login-panel panel panel-default">
                <div class="panel-heading">Iniciar Sesión</div>
                <div class="panel-body">
                    <p style="font-size:16px; color:red" align="center"> 
                        @{[html_escape($msg)]}
                    </p>
                    <form role="form" action="/cgi-bin/dets/index.pl" method="post" name="login">
                        <fieldset>
                            <div class="form-group">
                                <input class="form-control" placeholder="E-mail" name="email" type="email" autofocus required="true" value="@{[html_escape($cgi->param('email') || '')]}">
                            </div>
                            <div class="form-group">
                                <input class="form-control" placeholder="Contraseña" name="password" type="password" required="true">
                            </div>
                            <div class="checkbox">
                                <button type="submit" name="login" class="btn btn-primary">Iniciar Sesión</button>
                                <span style="padding-left:250px">
                                    <a href="/cgi-bin/dets/register.pl" class="btn btn-primary">Registrar</a>
                                </span>
                            </div>
                        </fieldset>
                    </form>
                </div>
            </div>
        </div><!-- /.col-->
    </div><!-- /.row -->	

    <script src="/dets/js/jquery-1.11.1.min.js"></script>
    <script src="/dets/js/bootstrap.min.js"></script>
</body>
</html>
END_HTML

# Cerrar la conexión a la base de datos si aún está abierta
$dbh->disconnect() if $dbh && $dbh->ping();
exit;

