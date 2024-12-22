#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Session;
use DBI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser); # Para mostrar errores en el navegador

# Crear un nuevo objeto CGI
my $cgi = CGI->new;

# Iniciar o continuar una sesión existente
my $session = CGI::Session->new(undef, $cgi, { Directory => '/tmp' });
my $userid = $session->param('detsuid');

# Verificar si el usuario está autenticado
unless (defined $userid && $userid ne '') {
    print $cgi->redirect('/cgi-bin/dets/logout.pl');
    exit;
}

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

# Obtener el nombre del usuario para la barra lateral
my $sth = $dbh->prepare("SELECT FullName FROM tbluser WHERE ID = ?");
$sth->execute($userid);
my $row = $sth->fetchrow_hashref;

my $name = 'Usuario'; # Valor por defecto
if (defined $row && defined $row->{FullName}) {
    $name = $row->{FullName};
    print STDERR "Nombre Obtenido: $name\n"; # Depuración
} else {
    print STDERR "No se encontró el usuario con ID: $userid\n"; # Depuración
}

# Manejar la solicitud POST
if ($cgi->request_method() eq 'POST' && defined $cgi->param('submit')) {
    my $dateexpense = $cgi->param('dateexpense') || '';
    my $item        = $cgi->param('item') || '';
    my $costitem    = $cgi->param('costitem') || '';

    # Validar el costo del artículo
    if ($costitem !~ /^\d+(\.\d{1,2})?$/) {
        $msg = "El costo del artículo debe ser un número válido.";
    } else {
        # Insertar el gasto en la base de datos
        my $sth = $dbh->prepare("INSERT INTO tblexpense (UserId, ExpenseDate, ExpenseItem, ExpenseCost) VALUES (?, ?, ?, ?)");
        my $success = $sth->execute($userid, $dateexpense, $item, $costitem);

        if ($success) {
            print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
            print <<"END_HTML";
            <script>
                alert('El gasto ha sido añadido correctamente.');
                window.location.href = '/cgi-bin/dets/manage_expense.pl';
            </script>
END_HTML
            $dbh->disconnect();
            exit;
        } else {
            $msg = "Algo salió mal. Por favor, inténtalo de nuevo.";
        }
    }
}

# Función para escapar caracteres HTML
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
print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
print <<"END_HTML";
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Daily Expense Tracker || Agregar Gasto</title>
    <link href="/dets/css/bootstrap.min.css" rel="stylesheet">
    <link href="/dets/css/font-awesome.min.css" rel="stylesheet">
    <link href="/dets/css/datepicker3.css" rel="stylesheet">
    <link href="/dets/css/styles.css" rel="stylesheet">
    
    <!--Custom Font-->
    <link href="https://fonts.googleapis.com/css?family=Montserrat:300,300i,400,400i,500,500i,600,600i,700,700i" rel="stylesheet">
    <!--[if lt IE 9]>
    <script src="/dets/js/html5shiv.js"></script>
    <script src="/dets/js/respond.min.js"></script>
    <![endif]-->
</head>
<body>
    <!-- Incluir Header -->
    <header>
        <nav class="navbar navbar-custom navbar-fixed-top" role="navigation">
            <div class="container-fluid">
                <!-- Navbar Header -->
                <div class="navbar-header">
                    <!-- Botón para colapsar en móviles -->
                    <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar-collapse">
                        <span class="sr-only">Alternar navegación</span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                    </button>
                    <!-- Marca o Título -->
                    <a class="navbar-brand" href="#">Gestor de finanzas personales</a>
                </div>
                <!-- Elementos de la Navbar (opcional) -->
                <!-- Puedes agregar elementos adicionales aquí si es necesario -->
            </div>
        </nav>
    </header>
    <!-- Incluir Sidebar -->
    <div id="sidebar-collapse" class="col-sm-3 col-lg-2 sidebar">
        <div class="profile-sidebar">
            <div class="profile-userpic">
                <img src="http://placehold.it/50/30a5ff/fff" class="img-responsive" alt="Foto de Perfil">
            </div>
            <div class="profile-usertitle">
                <div class="profile-usertitle-name">${name}</div>
                <div class="profile-usertitle-status"><span class="indicator label-success"></span> Online</div>
            </div>
            <div class="clear"></div>
        </div>
        <div class="divider"></div>

        <ul class="nav menu">
            <li class="active"><a href="/cgi-bin/dets/dashboard.pl"><em class="fa fa-dashboard">&nbsp;</em> Dashboard</a></li>
            <li class="parent"><a data-toggle="collapse" href="#sub-item-1">
                <em class="fa fa-navicon">&nbsp;</em> Gastos <span data-toggle="collapse" href="#sub-item-1" class="icon pull-right"><em class="fa fa-plus"></em></span>
                </a>
                <ul class="children collapse" id="sub-item-1">
                    <li><a class="" href="/cgi-bin/dets/add_expense.pl">
                        <span class="fa fa-arrow-right">&nbsp;</span> Agregar Gasto
                    </a></li>
                    <li><a class="" href="/cgi-bin/dets/manage_expense.pl">
                        <span class="fa fa-arrow-right">&nbsp;</span> Ver Gastos
                    </a></li>
                </ul>
            </li>
            <li class="parent"><a data-toggle="collapse" href="#sub-item-2">
                <em class="fa fa-navicon">&nbsp;</em> Reportes de Gastos <span data-toggle="collapse" href="#sub-item-2" class="icon pull-right"><em class="fa fa-plus"></em></span>
                </a>
                <ul class="children collapse" id="sub-item-2">
                    <li><a class="" href="/cgi-bin/dets/expense-datewise-reports.pl">
                        <span class="fa fa-arrow-right">&nbsp;</span> Gastos Diarios
                    </a></li>
                    <li><a class="" href="/cgi-bin/dets/expense-monthwise-reports.pl">
                        <span class="fa fa-arrow-right">&nbsp;</span> Gastos Mensuales
                    </a></li>
                    <li><a class="" href="/cgi-bin/dets/expense-yearwise-reports.pl">
                        <span class="fa fa-arrow-right">&nbsp;</span> Gastos Anuales
                    </a></li>
                </ul>
            </li>
            <li><a href="/cgi-bin/dets/user-profile.pl"><em class="fa fa-user">&nbsp;</em> Perfil</a></li>
            <li><a href="/cgi-bin/dets/change-password.pl"><em class="fa fa-clone">&nbsp;</em> Cambiar Contraseña</a></li>
            <li><a href="/cgi-bin/dets/logout.pl"><em class="fa fa-power-off">&nbsp;</em> Cerrar Sesión</a></li>
        </ul>
    </div><!--/.sidebar-->
   
    <div class="col-sm-9 col-sm-offset-3 col-lg-10 col-lg-offset-2 main">
        <div class="row">
            <ol class="breadcrumb">
                <li><a href="/cgi-bin/dets/dashboard.pl">
                    <em class="fa fa-home"></em>
                </a></li>
                <li class="active">Agregar Gasto</li>
            </ol>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-lg-12">
                <h1 class="page-header">Agregar Gasto</h1>
            </div>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-md-12">
                <form role="form" method="post" action="/cgi-bin/dets/add_expense.pl">
                    <div class="form-group">
                        <label>Fecha del Gasto</label>
                        <input class="form-control" type="date" name="dateexpense" required="true" value="@{[html_escape($cgi->param('dateexpense') || '')]}">
                    </div>
                    <div class="form-group">
                        <label>Artículo</label>
                        <input type="text" class="form-control" name="item" required="true" value="@{[html_escape($cgi->param('item') || '')]}">
                    </div>
                    <div class="form-group">
                        <label>Costo del Artículo</label>
                        <input class="form-control" type="text" name="costitem" required="true" value="@{[html_escape($cgi->param('costitem') || '')]}">
                    </div>
                    <button type="submit" class="btn btn-primary" name="submit">Agregar</button>
                </form>
                <p style="font-size:16px; color:red" align="center"> 
                    @{[html_escape($msg)]}
                </p>
            </div>
        </div><!--/.row-->
        
        <!-- Incluir Footer -->
        <footer>
            <div class="container">
                <p class="text-muted">© 2024 Daily Expense Tracker. Todos los derechos reservados.</p>
            </div>
        </footer>
    </div>	<!--/.main-->
    
    <script src="/dets/js/jquery-1.11.1.min.js"></script>
    <script src="/dets/js/bootstrap.min.js"></script>
    <script src="/dets/js/chart.min.js"></script>
    <script src="/dets/js/chart-data.js"></script>
    <script src="/dets/js/easypiechart.js"></script>
    <script src="/dets/js/easypiechart-data.js"></script>
    <script src="/dets/js/bootstrap-datepicker.js"></script>
    <script src="/dets/js/custom.js"></script>
</body>
</html>
END_HTML

# Cerrar la conexión a la base de datos
$dbh->disconnect();
exit;

# Subrutina para escapar caracteres HTML
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

