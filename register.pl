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

# Depuración: Imprimir ID de sesión y usuario
print STDERR "Dashboard Session ID: " . $session->id() . ", UserID: $userid\n";

unless (defined $userid && $userid ne '') {
    print STDERR "Usuario no autenticado. Redirigiendo a logout.pl\n";
    print $cgi->redirect('/cgi-bin/dets/logout.pl');
    exit;
}

# Configuración de la conexión a la base de datos
my $dsn = "DBI:mysql:database=detsdb;host=localhost";
my $db_user = "root";           # Usuario de MySQL
my $db_pass = "12345678";       # Contraseña de MySQL

my $dbh = DBI->connect($dsn, $db_user, $db_pass, 
    { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 }) 
    or die "No se pudo conectar a la base de datos: $DBI::errstr";

# Obtener la fecha actual y otras fechas necesarias
my $tdate = strftime("%Y-%m-%d", localtime);
my $ydate = strftime("%Y-%m-%d", localtime(time - 86400)); # Ayer
my $pastdate_week = strftime("%Y-%m-%d", localtime(time - 7*86400)); # Hace una semana
my $pastdate_month = strftime("%Y-%m-%d", localtime(time - 30*86400)); # Hace un mes
my $cyear = strftime("%Y", localtime);

# Consultas a la base de datos
my $sum_today_expense = get_sum_expense($dbh, $userid, "ExpenseDate = ?", $tdate);
my $sum_yesterday_expense = get_sum_expense($dbh, $userid, "ExpenseDate = ?", $ydate);
my $sum_weekly_expense = get_sum_expense($dbh, $userid, "ExpenseDate BETWEEN ? AND ?", $pastdate_week, $tdate);
my $sum_monthly_expense = get_sum_expense($dbh, $userid, "ExpenseDate BETWEEN ? AND ?", $pastdate_month, $tdate);
my $sum_yearly_expense = get_sum_expense($dbh, $userid, "YEAR(ExpenseDate) = ?", $cyear);
my $sum_total_expense = get_sum_expense($dbh, $userid, "UserId = ?", $userid);

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
        <nav class="navbar navbar-inverse navbar-fixed-top" role="navigation">
            <div class="container-fluid">
                <div class="navbar-header">
                    <a class="navbar-brand" href="#">Daily Expense Tracker</a>
                </div>
                <ul class="nav navbar-nav navbar-right">
                    <li><a href="/cgi-bin/dets/logout.pl">Cerrar Sesión</a></li>
                </ul>
            </div>
        </nav>
    </header>
    
    <!-- Incluir Sidebar -->
    <div id="sidebar-collapse" class="col-sm-3 col-lg-2 sidebar">
        <ul class="nav menu">
            <li class="active"><a href="/cgi-bin/dets/dashboard.pl"><em class="fa fa-dashboard">&nbsp;</em> Dashboard</a></li>
            <li><a href="/cgi-bin/dets/add_expense.pl"><em class="fa fa-plus">&nbsp;</em> Agregar Gasto</a></li>
            <li><a href="/cgi-bin/dets/view_expenses.pl"><em class="fa fa-eye">&nbsp;</em> Ver Gastos</a></li>
            <!-- Agrega más enlaces según tus necesidades -->
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
                            <span class="percent">\$$sum_today_expense</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Gasto de Ayer</h4>
                        <div class="easypiechart" id="easypiechart-orange" data-percent="100">
                            <span class="percent">\$$sum_yesterday_expense</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Últimos 7 Días</h4>
                        <div class="easypiechart" id="easypiechart-teal" data-percent="100">
                            <span class="percent">\$$sum_weekly_expense</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Últimos 30 Días</h4>
                        <div class="easypiechart" id="easypiechart-red" data-percent="100">
                            <span class="percent">\$$sum_monthly_expense</span>
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
                            <span class="percent">\$$sum_yearly_expense</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xs-6 col-md-3">
                <div class="panel panel-default">
                    <div class="panel-body easypiechart-panel">
                        <h4>Gasto Total</h4>
                        <div class="easypiechart" id="easypiechart-pink" data-percent="100">
                            <span class="percent">\$$sum_total_expense</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Aquí puedes agregar más secciones, gráficos, tablas, etc. -->
    </div>	<!--/.main-->
    
    <!-- Incluir Footer -->
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
            var chart1 = document.getElementById("line-chart").getContext("2d");
            window.myLine = new Chart(chart1).Line(lineChartData, {
                responsive: true,
                scaleLineColor: "rgba(0,0,0,.2)",
                scaleGridLineColor: "rgba(0,0,0,.05)",
                scaleFontColor: "#c5c7cc"
            });
        };
    </script>
</body>
</html>
END_HTML

# Cerrar la conexión a la base de datos
$dbh->disconnect() if $dbh && $dbh->ping();
exit;

# Subrutina para obtener la suma de gastos
sub get_sum_expense {
    my ($dbh, $userid, $condition, @params) = @_;
    my $sth = $dbh->prepare("SELECT SUM(ExpenseCost) AS sum_expense FROM tblexpense WHERE UserId = ? AND $condition");
    $sth->execute($userid, @params);
    my $result = $sth->fetchrow_hashref;
    return defined $result->{sum_expense} ? $result->{sum_expense} : 0;
}

