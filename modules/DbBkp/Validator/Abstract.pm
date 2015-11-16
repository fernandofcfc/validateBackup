package DbBkp::Validator::Abstract;

=for comment

 Module:	DbBkp::Validator::Abstract (abstract)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Versão:	1.0

=cut

use DbConn;
use Util;
use strict;

##
# public new
#
# param $dbms	nome do SGBD que terá os backups validados
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
# Realiza as atividades anteriores a validação do backup, que se resumem à conexão com 
# a instância de banco de dados e, opcionalmente, à criação da base de dados para os testes.
#
# param $connHash	hash ref contendo os parâmetros -host, -dbname, -user, e, opcionalmente, -pass
# param $dbname		nome do banco de dados de testes a ser criado (opcional)
# param $params		hash ref com os parâmetros opcionais para a criação do banco de dados (opcional)
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
# Valida arquivo de backup utilizando conexão a um banco de dados de testes
#
# param $dbname		nome da base de dados a ser validada
# param $connHash	Ref Hash com dados para conexão com o banco
# param $bkpPath	path do arquivo de backup a ser validado
# param $errorsPath	path do arquivo que conterá todos os erros ocorridos na validação
# return			total de erros ocorridos
##
sub validate {}

##
# protected _posValidate
# 
# Realiza as atividades pós validação do arquivo de backup, resumidas ao drop do banco de dados criado
# para os testes e disconexão da instância de banco de dados.
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