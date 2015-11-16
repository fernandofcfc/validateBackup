package DbBkp::Validator::PostgreSQL;

=for comment

 Module:	DbBkp::Validator::PostgreSQL (extends DbBkp::Validator::Abstract)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Versão:	1.0
 
 see DbBkp::Validator::Abstract
 
=cut

use DbBkp::Validator::Abstract;
use DbBkp::Validator::Exception;
use Util;
use strict;

our @ISA = qw(DbBkp::Validator::Abstract);

use constant DBMS	=> "PGSQL";

my @_knownErrors	= (		# lista de erros conhecidos e que devem ser ignorados
							"ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres",	
							" role "
						);

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
	
	my $encoding	= "LATIN1";	# encoding default
	
	# recuperando o encoding do arquivo para ser usado na criação do banco
	my $encodingString	= `head -100 $bkpPath | grep client_encoding`;
	(my $dbEncoding)	= $encodingString	=~ /= '([A-Z0-9]+)';/;
	
	$encoding	= $dbEncoding	if(($dbEncoding =~ /[A-Z0-9]+/) && ($encoding ne $dbEncoding));
	
	# pré validação, com criação de novo banco
	$self->_preValidate($connHash,$dbname,{"TEMPLATE" => "template0", "ENCODING" => "'$encoding'"});
	
	my $tmpErrorsPath	= $errorsPath.".tmp";
	my $errorCount		= 0;
	
	### intervalo validação
	$ENV{PGPASSWORD}	= $$connHash{-pass} if(exists $$connHash{-pass});
	system("psql -h $$connHash{-host} -U $$connHash{-user} -d $dbname -f $bkpPath > /dev/null 2> $tmpErrorsPath") == 0 or 
		throw DbBkp::Validator::Exception(2,"database $dbname");
		
	# colocando cada erro em um elemento do array
	my @lines	= split "\n", Util::fileToString($tmpErrorsPath);
	my @errors	= ();
	
	Util::removeFile($tmpErrorsPath);
	
	for my $line (@lines)
	{
		if ($line =~ /ERROR|INFO|NOTICE|WARNING|LOG|FATAL|PANIC|DEBUG[1-5]/)
		{
			push @errors, $line;
		}
		else
		{
			push(@errors, (pop(@errors)."\n".$line));
		}
	}
	
	# retirando os erros que devem ser ignorados
	my $errorLog = "";
	
	for my $error (@errors)
	{
		my $deleteFlag		= 0;
		
		for my $knownError (@_knownErrors)
		{
			if($error =~ /$knownError/)	# verificando se o erro já é um dos erros conhecidos
			{
				$deleteFlag = 1;
			}
		}
		
		if(!$deleteFlag)
		{
			$errorLog .= $error."\n";	# construindo o log a ser salvo no arquivo de logs filtrados
			$errorCount++;
		}
	}
	
	# gravando logs de erro
	Util::stringToFile($errorsPath, $errorLog) if($errorCount);
	
	### 
	
	$self->_posValidate($dbname, $bkpPath);
	
	return $errorCount;
}

1;