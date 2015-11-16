package DbBkp::Validator;

=for comment
 
 Module	:	DbBkp::Validator (static)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Versão:	1.0

=cut

use DbBkp::Validator::PostgreSQL;
use DbBkp::Validator::SQLServer;
use DbBkp::Validator::Exception;
use strict;

# constants
use constant POSTGRESQL	=> "PGSQL";
use constant SQLSERVER	=> "SQLSERVER";

##
# public static instance
#
# param $dbms	nome do DBMS
# return		new DbBkp::Validator::Abstract
##
sub instance
{
	my $dbms	= shift;
	
	if($dbms	eq POSTGRESQL)
	{
		return DbBkp::Validator::PostgreSQL->new();
	}
	elsif($dbms	eq SQLSERVER)
	{
		return DbBkp::Validator::SQLServer->new();
	}
	else
	{
		throw DbBkp::Validator::Exception(1,"Cannot validate DBMS $dbms");
	}
}

1;