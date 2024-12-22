#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use DBI;
use Digest::MD5 qw(md5_hex);
use CGI::Carp qw(fatalsToBrowser warningsToBrowser); # Para mostrar errores en el navegador durante desarrollo

# Crear un nuevo objeto CGI
my $cgi = CGI->new;

# Configuración de la conexión a la base de datos
my $dsn = "DBI:mysql:database=detsdb;host=localhost";
my $db_user = "root";           # Usuario de MySQL
my $db_pass = "12345678";       # Contraseña de MySQL

# Conectar a la base de datos
my $dbh = DBI->connect($dsn, $db_user, $db_pass, 
    { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 }) 
    or die "No se pudo conectar a la base de datos: $DBI::errstr";

# Inicializar mensaje
my $msg = '';

# Manejar la solicitud POST
if ($cgi->request_method() eq 'POST' && defined $cgi->param('register')) {
    my $email    = $cgi->param('email') || '';
    my $password = $cgi->param('password') || '';

    # Validar campos requeridos
    if ($email !~ /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {
        $msg = "Formato de correo electrónico inválido.";
    } elsif (length($password) < 6) {
        $msg = "La contraseña debe tener al menos 6 caracteres.";
    } else {
        # Hash de la contraseña usando MD5
        my $hashed_password = md5_hex($password);

        # Verificar si el email ya existe
        my $sth_check = $dbh->prepare("SELECT ID FROM tbluser WHERE Email = ?");
        $sth_check->execute($email);
        my @row = $sth_check->fetchrow_array;

        if (@row) {
            $msg = "El correo electrónico ya está registrado.";
        } else {
            # Insertar nuevo usuario
            my $sth = $dbh->prepare("INSERT INTO tbluser (Email, Password) VALUES (?, ?)");
            eval {
                $sth->execute($email, $hashed_password);
            };
            if ($@) {
                $msg = "Error al registrar el usuario. Por favor, intenta de nuevo.";
            } else {
                $msg = "Registro exitoso. Puedes iniciar sesión ahora.";
            }
            $sth->finish() if $sth;
        }

        $sth_check->finish() if $sth_check;
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

# Generar la página HTML
print $cgi->header(
    -type => 'text/html',
    -charset => 'UTF-8'
);

print <<"END_HTML";
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Daily Expense Tracker - Registro</title>
    <link href="/dets/css/bootstrap.min.css" rel="stylesheet">
    <link href="/dets/css/datepicker3.css" rel="stylesheet">
    <link href="/dets/css/styles.css" rel="stylesheet">
</head>
<body>
    <div class="row">
        <h2 align="center">Administrador de Gastos Personales</h2>
        <hr />
        <div class="col-xs-10 col-xs-offset-1 col-sm-8 col-sm-offset-2 col-md-4 col-md-offset-4">
            <div class="login-panel panel panel-default">
                <div class="panel-heading">Registrar</div>
                <div class="panel-body">
                    <p style="font-size:16px; color:red" align="center"> 
                        @{[html_escape($msg)]}
                    </p>
                    <form role="form" action="/cgi-bin/dets/register.pl" method="post" name="register">
                        <fieldset>
                            <div class="form-group">
                                <input class="form-control" placeholder="E-mail" name="email" type="email" autofocus required="true" value="@{[html_escape($cgi->param('email') || '')]}">
                            </div>
                            <div class="form-group">
                                <input class="form-control" placeholder="Contraseña" name="password" type="password" required="true">
                            </div>
                            <div class="checkbox">
                                <button type="submit" name="register" class="btn btn-primary">Registrar</button>
                                <span style="padding-left:250px">
                                    <a href="/cgi-bin/dets/index.pl" class="btn btn-primary">Iniciar Sesión</a>
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

