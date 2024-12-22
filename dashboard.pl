#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Session;
use DBI;
use POSIX qw(strftime);
use CGI::Carp qw(fatalsToBrowser warningsToBrowser); # Para mostrar errores en el navegador durante desarrollo

my $cgi = CGI->new;
my $session = CGI::Session->new(undef, $cgi, { Directory => '/tmp' });
my $userid = $session->param('detsuid');

# Depuración: Imprimir ID de sesión y usuario en el error log
print STDERR "Dashboard Session ID: " . $session->id() . ", UserID: $userid\n";

unless (defined $userid && $userid ne '') {
    print STDERR "Usuario no autenticado. Redirigiendo a logout.pl\n";
    print $cgi->redirect('/cgi-bin/dets/logout.pl');
    exit;
}

# Configuración de la conexión a la base de datos
my $dsn = "DBI:mysql:database=detsdb;host=localhost";
my $db_user = "root";     # Usuario de MySQL
my $db_pass = "12345678"; # Contraseña de MySQL

my $dbh = DBI->connect($dsn, $db_user, $db_pass, 
    { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 }) 
    or die "No se pudo conectar a la base de datos: $DBI::errstr";

# Obtener la fecha actual y otras fechas necesarias
my $tdate = strftime("%Y-%m-%d", localtime);
my $ydate = strftime("%Y-%m-%d", localtime(time - 86400)); # Ayer
my $pastdate_week = strftime("%Y-%m-%d", localtime(time - 7*86400)); # Hace una semana
my $pastdate_month = strftime("%Y-%m-%d", localtime(time - 30*86400)); # Hace un mes
my $cyear = strftime("%Y", localtime);

# Consultas a la base de datos usando la subrutina get_sum_expense
my $sum_today_expense      = get_sum_expense($dbh, $userid, "ExpenseDate = ?", $tdate);
my $sum_yesterday_expense  = get_sum_expense($dbh, $userid, "ExpenseDate = ?", $ydate);
my $sum_weekly_expense     = get_sum_expense($dbh, $userid, "ExpenseDate BETWEEN ? AND ?", $pastdate_week, $tdate);
my $sum_monthly_expense    = get_sum_expense($dbh, $userid, "ExpenseDate BETWEEN ? AND ?", $pastdate_month, $tdate);
my $sum_yearly_expense     = get_sum_expense($dbh, $userid, "YEAR(ExpenseDate) = ?", $cyear);

# Para el total de gastos no agregamos una condición extra, sólo "1=1"
# Esto resultará en: WHERE UserId = ? AND 1=1 -> efectivo para mostrar todos los gastos del usuario
my $sum_total_expense      = get_sum_expense($dbh, $userid, "1=1");

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

# Finalizar conexión antes de generar la página
$dbh->disconnect();

# Generar la página HTML
print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
print <<"END_HTML";
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Daily Expense Tracker - Dashboard</title>
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
                <li><a href="#">
                    <em class="fa fa-home"></em>
                </a></li>
                <li class="active">Dashboard</li>
            </ol>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-lg-12">
                <h1 class="page-header">Dashboard</h1>
            </div>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Gasto de Hoy</h4>
                        <div class="easypiechart" id="easypiechart-blue" data-percent="100">
                            <span class="percent">\$${sum_today_expense}</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Gasto de Ayer</h4>
                        <div class="easypiechart" id="easypiechart-orange" data-percent="100">
                            <span class="percent">\$${sum_yesterday_expense}</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Últimos 7 Días</h4>
                        <div class="easypiechart" id="easypiechart-teal" data-percent="100">
                            <span class="percent">\$${sum_weekly_expense}</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Últimos 30 Días</h4>
                        <div class="easypiechart" id="easypiechart-red" data-percent="100">
                            <span class="percent">\$${sum_monthly_expense}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Gasto Anual</h4>
                        <div class="easypiechart" id="easypiechart-yellow" data-percent="100">
                            <span class="percent">\$${sum_yearly_expense}</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Gasto Total</h4>
                        <div class="easypiechart" id="easypiechart-pink" data-percent="100">
                            <span class="percent">\$${sum_total_expense}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
    </div>  <!--/.main-->
    
    <footer>
        <div class="container">
            <p class="text-muted">© 2024 Daily Expense Tracker. Todos los derechos reservados.</p>
        </div>
    </footer>
    
    <script src="/dets/js/jquery-1.11.1.min.js"></script>
    <script src="/dets/js/bootstrap.min.js"></script>
    <script src="/dets/js/chart.min.js"></script>
    <script src="/dets/js/chart-data.js"></script>
    <script src="/dets/js/easypiechart.js"></script>
    <script src="/dets/js/easypiechart-data.js"></script>
    <script src="/dets/js/bootstrap-datepicker.js"></script>
    <script src="/dets/js/custom.js"></script>
    <script>
        window.onload = function () {
            // Inicialización de gráficos si es necesario
        };
    </script>
</body>
</html>
END_HTML

exit;

sub get_sum_expense {
    my ($dbh, $userid, $condition, @params) = @_;
    my $sth = $dbh->prepare("SELECT SUM(ExpenseCost) AS sum_expense FROM tblexpense WHERE UserId = ? AND $condition");
    $sth->execute($userid, @params);
    my $result = $sth->fetchrow_hashref;
    return defined $result->{sum_expense} ? $result->{sum_expense} : 0;
}

