#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Session;
use DBI;
use JSON;
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

# Establecer el nombre del usuario (valor por defecto)
my $name = 'Usuario';

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


# Obtener los datos de gastos por fecha
my $sth_expenses = $dbh->prepare("
    SELECT ExpenseDate, SUM(ExpenseCost) AS TotalExpense
    FROM tblexpense
    WHERE UserId = ?
    GROUP BY ExpenseDate
    ORDER BY ExpenseDate ASC
");
$sth_expenses->execute($userid);

my @dates;
my @expenses;
while (my $expense = $sth_expenses->fetchrow_hashref) {
    push @dates, $expense->{ExpenseDate};
    push @expenses, $expense->{TotalExpense};
}

# Convertir los arrays a un solo objeto JSON
my $json = JSON->new->utf8->encode({
    dates => \@dates,
    expenses => \@expenses
});

# Generar la página HTML
print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
print <<"END_HTML";
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Daily Expense Tracker || Reporte de Gastos Diarios</title>
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
            <li><a href="/cgi-bin/dets/dashboard.pl"><em class="fa fa-dashboard">&nbsp;</em> Dashboard</a></li>
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
            <li class="parent active"><a data-toggle="collapse" href="#sub-item-2">
                <em class="fa fa-navicon">&nbsp;</em> Reportes de Gastos <span data-toggle="collapse" href="#sub-item-2" class="icon pull-right"><em class="fa fa-plus"></em></span>
                </a>
                <ul class="children collapse in" id="sub-item-2">
                    <li class="active"><a class="" href="/cgi-bin/dets/expense-datewise-reports.pl">
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
                <li class="active">Reportes de Gastos Diarios</li>
            </ol>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-lg-12">
                <h1 class="page-header">Reportes de Gastos Diarios</h1>
            </div>
        </div><!--/.row-->
        
        <div class="row">
            <div class="col-md-12">
                <canvas id="expenseChart" width="800" height="400"></canvas>
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
    <script>
        // Obtener los datos pasados desde Perl
        var expenseData = $json;

        var labels = expenseData.dates;
        var data = expenseData.expenses;

        // Validación: Imprimir los datos en la consola
        console.log(labels);
        console.log(data);

        // Convertir las etiquetas a objetos Date para Chart.js
        var parsedLabels = labels.map(function(date) {
            return new Date(date);
        });

        var ctx = document.getElementById('expenseChart').getContext('2d');
        var expenseChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: parsedLabels,
                datasets: [{
                    label: 'Gastos Diarios',
                    data: data,
                    backgroundColor: 'rgba(54, 162, 235, 0.2)',
                    borderColor: 'rgba(54, 162, 235, 1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                return 'Gasto: $' + context.parsed.y;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'day',
                            tooltipFormat: 'YYYY-MM-DD'
                        },
                        title: {
                            display: true,
                            text: 'Fecha'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Gasto (USD)'
                        }
                    }
                }
            }
        });
    </script>
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

