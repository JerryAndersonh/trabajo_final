#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Session;
use DBI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser); # Para mostrar errores en el navegador durante desarrollo

# Crear objeto CGI
my $cgi = CGI->new;

# Crear o recuperar la sesión
my $session = CGI::Session->new(undef, $cgi, { Directory => '/tmp' });

# Obtener el ID de usuario de la sesión
my $userid = $session->param('detsuid');

# Depuración: Imprimir ID de sesión y usuario en el error log
print STDERR "Dashboard Session ID: " . $session->id() . ", UserID: $userid\n";

# Verificar si el usuario está autenticado
unless (defined $userid && $userid ne '') {
    print STDERR "Usuario no autenticado. Redirigiendo a logout.pl\n";
    print $cgi->redirect('/cgi-bin/dets/logout.pl');
    exit;
}

# Configuración de la conexión a la base de datos
my $dsn = "DBI:mysql:database=detsdb;host=localhost";
my $db_user = "root";         # Usuario de MySQL
my $db_pass = "12345678";     # Contraseña de MySQL

# Conectar a la base de datos
my $dbh = DBI->connect($dsn, $db_user, $db_pass,
    { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die "No se pudo conectar a la base de datos: $DBI::errstr";

# Manejo de la eliminación de gastos
if ($cgi->param('delid')) {
    my $rowid = $cgi->param('delid');
    $rowid =~ s/\D//g; # Sanitizar input: eliminar todo excepto dígitos

    if ($rowid) {
        my $delete_sth = $dbh->prepare("DELETE FROM tblexpense WHERE ID = ?");
        if ($delete_sth->execute($rowid)) {
            # Éxito en la eliminación
            print $cgi->redirect('/cgi-bin/dets/manage-expense.pl?msg=Registro%20eliminado%20correctamente');
            exit;
        } else {
            # Error en la eliminación
            print $cgi->redirect('/cgi-bin/dets/manage-expense.pl?msg=Algo%20salió%20mal.%20Por%20favor,%20intenta%20de%20nuevo');
            exit;
        }
    } else {
        # ID inválido
        print $cgi->redirect('/cgi-bin/dets/manage-expense.pl?msg=ID%20de%20registro%20inválido');
        exit;
    }
}

# Obtener el nombre del usuario para la barra lateral
my $sth_user = $dbh->prepare("SELECT FullName FROM tbluser WHERE ID = ?");
$sth_user->execute($userid);
my $row_user = $sth_user->fetchrow_hashref;

my $name = 'Usuario'; # Valor por defecto
if (defined $row_user && defined $row_user->{FullName}) {
    $name = $row_user->{FullName};
    print STDERR "Nombre Obtenido: $name\n"; # Depuración
} else {
    print STDERR "No se encontró el usuario con ID: $userid\n"; # Depuración
}

# Obtener los gastos del usuario
my $sth_expense = $dbh->prepare("SELECT * FROM tblexpense WHERE UserId = ? ORDER BY ExpenseDate DESC");
$sth_expense->execute($userid);
my @expenses;
while (my $row = $sth_expense->fetchrow_hashref) {
    push @expenses, $row;
}

# Cerrar la conexión a la base de datos
$dbh->disconnect();

# Obtener mensajes para mostrar (si existen)
my $msg = $cgi->param('msg') || '';

# Generar la página HTML
print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
print <<"END_HTML";
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Daily Expense Tracker || Gestionar Gastos</title>
    <link href="/dets/css/bootstrap.min.css" rel="stylesheet">
    <link href="/dets/css/font-awesome.min.css" rel="stylesheet">
    <link href="/dets/css/datepicker3.css" rel="stylesheet">
    <link href="/dets/css/styles.css" rel="stylesheet">
    
    <!--Fuente Personalizada-->
    <link href="https://fonts.googleapis.com/css?family=Montserrat:300,300i,400,400i,500,500i,600,600i,700,700i" rel="stylesheet">
    <!--[if lt IE 9]>
    <script src="/dets/js/html5shiv.js"></script>
    <script src="/dets/js/respond.min.js"></script>
    <![endif]-->
    <style>
        /* Asegura que el contenido no quede oculto detrás de la navbar fija */
        body {
            padding-top: 70px;
        }
    </style>
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
                    <a class="navbar-brand" href="#">Daily Expense Tracker</a>
                </div>
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
                <div class="profile-usertitle-name">$name</div>
                <div class="profile-usertitle-status"><span class="indicator label-success"></span> En Línea</div>
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

    <!-- Contenido Principal -->
    <div class="col-sm-9 col-sm-offset-3 col-lg-10 col-lg-offset-2 main">
        <!-- Breadcrumb -->
        <div class="row">
            <ol class="breadcrumb">
                <li><a href="#">
                    <em class="fa fa-home"></em>
                </a></li>
                <li class="active">Gastos</li>
            </ol>
        </div><!--/.row-->
        
        <!-- Panel de Expense -->
        <div class="row">
            <div class="col-lg-12">
                <div class="panel panel-default">
                    <div class="panel-heading">Gastos</div>
                    <div class="panel-body">
                        <p style="font-size:16px; color:red" align="center"> 
                            $msg
                        </p>
                        <div class="col-md-12">
                            <div class="table-responsive">
                                <table class="table table-bordered mg-b-0">
                                  <thead>
                                    <tr>
                                      <th>S.NO</th>
                                      <th>Artículo del Gasto</th>
                                      <th>Costo del Gasto</th>
                                      <th>Fecha del Gasto</th>
                                      <th>Acción</th>
                                    </tr>
                                  </thead>
                                  <tbody>
END_HTML

# Verificar si hay gastos para mostrar
if (@expenses) {
    my $cnt = 1;
    foreach my $expense (@expenses) {
        my $id = $expense->{ID};
        my $item = $expense->{ExpenseItem};
        my $cost = $expense->{ExpenseCost};
        my $date = $expense->{ExpenseDate};
        
        # Escape HTML para evitar inyección
        $item =~ s/&/&amp;/g;
        $item =~ s/</&lt;/g;
        $item =~ s/>/&gt;/g;
        
        print <<"ROW";
                            <tr>
                              <td>$cnt</td>
                              <td>$item</td>
                              <td>\$$cost</td>
                              <td>$date</td>
                              <td><a href="/cgi-bin/dets/manage-expense.pl?delid=$id" onclick="return confirm('¿Estás seguro de que deseas eliminar este registro?');">Eliminar</a></td>
                            </tr>
ROW
        $cnt++;
    }
} else {
    print <<"NO_RECORDS";
                            <tr>
                              <td colspan="5" align="center">No se encontraron registros.</td>
                            </tr>
NO_RECORDS
}

# Continuar con el HTML
print <<"END_HTML";
                                  </tbody>
                                </table>
                              </div>
                        </div>
                    </div>
                </div><!-- /.panel-->
            </div><!-- /.col-->
        </div><!-- /.row -->
    </div><!--/.main-->
    
    <footer>
        <div class="container">
            <p class="text-muted">© 2024 Daily Expense Tracker. Todos los derechos reservados.</p>
        </div>
    </footer>
    
    <!-- Incluye los Scripts al Final del Body -->
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

exit;

