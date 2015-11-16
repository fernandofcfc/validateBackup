package DbBkp::Validator::SQLServer;

=for comment

 Module:	DbBkp::Validator::SQLServer (extends DbBkp::Validator::Abstract)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Versão:	1.0
 
 see DbBkp::Validator::Abstract
 
=cut

use DbBkp::Validator::Abstract;
use DbConn::Exception;
use Util;
use Error qw(:try);
use strict;

our @ISA = qw(DbBkp::Validator::Abstract);

use constant DBMS		=> "SQLSERVER";	#

##
# public new
##
sub new
{
	my $class 	= $_[0];
	my $self	= $class->SUPER::new(DBMS);
	
	bless($self,$class);
	
	return $self;
}

##
# public validate
##
sub validate
{
	my $self		= shift;
	my $dbname		= shift;
	my $connHash	= shift;
	my $bkpPath		= shift;
	my $errorsPath	= shift;
	
	$self->_preValidate($connHash);
	
	my $errorCount	= 0;
	
	## intervalo validação
	try
	{
		$self->{_dbConn}->execute("RESTORE VERIFYONLY FROM  DISK = N'$bkpPath' WITH  FILE = 1,  NOUNLOAD,  NOREWIND");
	}
	catch DbConn::Exception with
	{
		my $ex	= shift;
		
		Util::stringToFile($errorsPath, $ex->text());
		$errorCount++;
	};
	## 
	
	$self->_posValidate();
	
	return $errorCount;
}

1;