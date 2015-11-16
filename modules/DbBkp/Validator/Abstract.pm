package DbBkp::Validator::Abstract;

=for comment

 Module:	DbBkp::Validator::Abstract (abstract)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Vers�o:	1.0

=cut

use DbConn;
use Util;
use strict;

##
# public new
#
# param $dbms	nome do SGBD que ter� os backups validados
##
sub new
{
	my $class	= shift;
	my $self	= {};
	
	my $dbms	= shift;
	
	$self->{_dbConn}	= DbConn::getDbmsConn($dbms);	# protected
	
	bless($self,$class);
	
	return $self;
}

##
# protected _preValidate
#
# Realiza as atividades anteriores a valida��o do backup, que se resumem � conex�o com 
# a inst�ncia de banco de dados e, opcionalmente, � cria��o da base de dados para os testes.
#
# param $connHash	hash ref contendo os par�metros -host, -dbname, -user, e, opcionalmente, -pass
# param $dbname		nome do banco de dados de testes a ser criado (opcional)
# param $params		hash ref com os par�metros opcionais para a cria��o do banco de dados (opcional)
##
sub _preValidate
{
	my $self		= shift;
	my $connHash	= shift;
	my $dbname		= shift;
	my $params		= shift;
	
	$self->{_dbConn}->connect($connHash);
	$self->{_dbConn}->createDatabase($dbname,$params) if(defined $dbname);
}

##
# abstract public validate
#
# Valida arquivo de backup utilizando conex�o a um banco de dados de testes
#
# param $dbname		nome da base de dados a ser validada
# param $connHash	Ref Hash com dados para conex�o com o banco
# param $bkpPath	path do arquivo de backup a ser validado
# param $errorsPath	path do arquivo que conter� todos os erros ocorridos na valida��o
# return			total de erros ocorridos
##
sub validate {}

##
# protected _posValidate
# 
# Realiza as atividades p�s valida��o do arquivo de backup, resumidas ao drop do banco de dados criado
# para os testes e disconex�o da inst�ncia de banco de dados.
#
# param $dbname	nome do banco de dados de testes (opcional)
##
sub _posValidate
{
	my $self	= shift;
	my $dbname	= shift;
	
	$self->{_dbConn}->dropDatabase($dbname) if(defined $dbname);
	$self->{_dbConn}->disconnect();
}

1;