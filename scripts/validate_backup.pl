#!/usr/bin/perl

=for comment
 Script: 	validate_backup.pl
 Autor:		Vinicius Porto Lima
 			Pedro Ilton Junior
 Vers�o:	0.8

 Descri��o:
 Script que executa a valida��o dos backups das bases de dados. Para tanto, faz uso de um
 arquivo de configura��es .ini.

=cut

use Util;
use Util::Exception;
use Logger;
use DbBkp::Validator;
use DbBkp::Validator::Exception;
use DbConn::Exception;
use FileFetcher;
use FileFetcher::Exception;
use Mail::Text;
use Mail::Exception;
use Error qw(:try);
use strict;

#
# constantes
#

use constant VERSION	=> "0.8";

# diret�rios
use constant LOG_DIR	=> "log";			# diret�rio de logs
use constant ERROR_DIR	=> "error";			# diret�rio de arquivos com erros de valida��o
use constant STAGE_DIR	=> "stage";			# diret�rio de staging para arquivos

use constant ERROR_SUFFIX	=> ".error";	# sufixo do arquivo de erros de valida��o
use constant LOG_PREFIX		=> "validate";	# prefixo dos logs
use constant EXCPT_PREFIX	=> "exception";	# prefixo de exce��es

# campos de valida��o de arquivo .ini
use constant SECTION_FIELDS	=> [ "dbms_section", "dir", "home"];			
use constant DBMS_FIELDS	=> [ "dbms", "host", "user"];
use constant REMOTE_FIELDS	=> [ "ip", "user"];
use constant EMAIL_FIELDS	=> [ "list", "smtp", "from"];

# valores default
use constant DEF_CONN		=> "local";

# valores de teste
use constant CONN_LOCAL		=> "local";
use constant CONN_REMOTE	=> "remote";

# email
use constant EMAIL_SUBJECT	=> "Valida��o de backups";

#
# parametros
#
my $confPath	= shift;	# path do arquivo de configura��o (.ini)
my $section		= shift;	# nome do bloco (entre colchetes) dentro do arquivo de configura��o
my $fileName	= shift;	# nome do arquivo de backup, caso deseja-se efetuar o teste em apenas 1 arquivo

help() if(($confPath eq "-h") || ($confPath eq "--help"));
version() if(($confPath eq "-v") || ($confPath eq "--version"));

#
# variaveis
#
my $iniHash		= Util::readIniFileSection($confPath,$section,SECTION_FIELDS);					# configura��o para o script
my $dbHash		= Util::readIniFileSection($confPath,$$iniHash{dbms_section},DBMS_FIELDS);		# configura��o para conex�o no banco

my $logDir		= $$iniHash{home}."/".LOG_DIR;		# diret�rio onde ser�o salvos os logs
my $errorDir	= $$iniHash{home}."/".ERROR_DIR;	# diret�rio onde ser�o salvos os arquivos com erros de valida��o
my $stageDir	= $$iniHash{home}."/".STAGE_DIR;	# diret�rio para o qual os arquivos de backup ser�o temporariamente copiados

my @filesToGet	= ();						# arquivos de backup a serem processados
my %outputs		= ();						# hash com todos os outputs das valida��es de backups
my $regexp		= $$iniHash{regexp_file};	# regexp do arquivo
my $startTime	= time();					# timestamp de in�cio do processamento
 
# seta valores default na vari�vel hash
$$iniHash{conn}	= DEF_CONN if(	(not exists $$iniHash{conn})||
								((exists $$iniHash{conn})&&($$iniHash{conn} ne CONN_LOCAL)&&($$iniHash{conn} ne CONN_REMOTE)));

# cria diret�rios no home
Util::makeDir($logDir);
Util::makeDir($errorDir);
Util::makeDir($stageDir);

my $fileFetcher	= FileFetcher->new($$iniHash{dir},$stageDir);	# objeto que realiza download de arquivos, se necess�rio

#
# rotina
#
Logger::addLog("Starting backup validation");

# monta lista de arquivos a serem processados
if($$iniHash{conn} eq CONN_REMOTE)
{
	my $remoteHash	= Util::readIniFileSection($confPath, $$iniHash{remote_section}, REMOTE_FIELDS);	
	$fileFetcher->startRemoteHandler( $$remoteHash{ip}, $$remoteHash{user});	# objeto de conex�o � m�quina remota
}

if(defined $fileName)	# se definido nome do arquivo, somente este ser� copiado
{
	Logger::addLog("Fetching file $fileName only");
	
	push @filesToGet, $fileName;	
}
else					# caso contr�rio, copia todos os arquivos contidos no diret�rio
{
	my $dateString	= Util::timestampFormattedString(time()-($$iniHash{retro_days}*86400),$$iniHash{mask_date});
	
	Logger::addLog("Fetching files with string $dateString");
	
	if ($$iniHash{conn} eq CONN_LOCAL)
	{
		@filesToGet	= @{Util::listDirFiles($$iniHash{dir},$dateString)}; 
	}
	else
	{
		@filesToGet	= @{$fileFetcher->getRemoteFilesList($dateString)};	# nomes dos arquivos com os timestamps de sua �ltima modifica��o
	}
}

# c�pia dos arquivos para o diret�rio de stage
foreach my $fileToGet (@filesToGet)
{
	next if(!($fileToGet =~ /$regexp/));
	
	my @components		= $fileToGet	=~ /$regexp/;
	my %validateParams	= ();
		
	for(my $i = 0; $i < scalar(@{$$iniHash{itens_file}}); $i++)
	{
		$validateParams{$$iniHash{itens_file}[$i]}	= $components[$i];
	}
	
	my $isExcluded	= 0;
	
	foreach my $excludeDbname (@{$$iniHash{exclude_dbname}})
	{
		$isExcluded	= 1 if($validateParams{dbname} eq $excludeDbname);
	}
	
	next if($isExcluded);
	
	Logger::addLog("Validate $fileToGet");
	
	my $nok	= 0;
	
	if ($$iniHash{conn} eq CONN_LOCAL)
	{
		try
		{
			Util::copyFile($$iniHash{dir}."/".$fileToGet, $stageDir."/".$fileToGet);
		}
		catch Util::Exception with
		{
			my $ex	= shift;	#objeto da exce��o
			$nok	= 1;
			Logger::addException($ex->text(),$ex->value(),$ex->stacktrace());
		};
	}
	else
	{
		try
		{
			$fileFetcher->fetchFile($fileToGet);
		}
		catch FileFetcher::Exception with
		{
			my $ex	= shift;	#objeto da exce��o
			$nok	= 1;
			Logger::addException($ex->text(),$ex->value(),$ex->stacktrace());
		};
	}
	
	if(!$nok)
	{
		# valida��o do backup
		my $backupPath 			= Util::decompressGzipFile($stageDir."/".$fileToGet);	# descomprime o arquivo de backup
		
		my %connHash		= (-host => $$dbHash{host}, -user => $$dbHash{user}, -dbname => $$dbHash{dbname});
		$connHash{-pass}	= $$dbHash{pass} if (defined $$dbHash{pass});
		
		my $validateErrorsPath	= $errorDir."/".$validateParams{host}."_".$validateParams{dbname}."_"
								. Util::timestampFormattedString(time(),"\%Y\%m\%d_\%H\%M\%S").ERROR_SUFFIX;
		
		my $errorCount			= 0;
		
		try
		{ 
			if(exists $$iniHash{net_stage})	# chamada da valida��o quando base de dados possuir pasta de stage compartilhada
			{
				$errorCount	= DbBkp::Validator::instance($$dbHash{dbms})->validate(	$validateParams{dbname}, 
																					\%connHash, 
																					$$iniHash{net_stage}."\\".Util::getFileName($backupPath), 
																					$validateErrorsPath);
			}
			else	# chamada de valida��o padr�o
			{
				$errorCount	= DbBkp::Validator::instance($$dbHash{dbms})->validate(	$validateParams{dbname}, 
																					\%connHash, 
																					$backupPath, 
																					$validateErrorsPath);
			}
		}
		catch DbConn::Exception with
		{
			my $ex	= shift;
			Logger::addException($ex->text(),$ex->value(),$ex->stacktrace());
		}	
		catch DbBkp::Validator::Exception with
		{
			my $ex	= shift;
			Logger::addException($ex->text(),$ex->value(),$ex->stacktrace());
		};																												
		
		$outputs{$validateParams{host}}{$validateParams{dbname}}{FILE}	= $fileToGet;
		$outputs{$validateParams{host}}{$validateParams{dbname}}{COUNT}	= $errorCount;
		$outputs{$validateParams{host}}{$validateParams{dbname}}{ERROR}	= $validateErrorsPath;
		
		Util::removeFile($backupPath);
		
		Logger::addLog("$errorCount error(s) found");
	}
}

# gera��o de output
my $output	= "Valida��o iniciada em ".Util::timestampFormattedString($startTime,"\%d/\%m/\%Y \%H:\%M")." - Resultado:\n\n";

foreach my $host (keys %outputs)
{
	$output	.=	"- Host $host:\n";
	
	foreach my $dbname (keys %{$outputs{$host}})
	{
		$output	.= "\t. $dbname (".$outputs{$host}{$dbname}{FILE}.") - ".$outputs{$host}{$dbname}{COUNT}." error(s)";
		$output	.= " -> log ".$outputs{$host}{$dbname}{ERROR} if($outputs{$host}{$dbname}{COUNT});
		$output	.= "\n";
	}
	
	$output	.= "\n";
}

$output	.= "Finalizada em ".Util::timestampFormattedString(time(),"\%d/\%m/\%Y \%H:\%M")."\n";

if(defined $fileName)
{
	print $output;
}
else	# enviando email
{
	my $emailHash	= Util::readIniFileSection($confPath,$$iniHash{email_section},EMAIL_FIELDS);
	
	my $mailText	= Mail::Text->new();
	$mailText->setSubject(EMAIL_SUBJECT." - ".$section);
	$mailText->setData($output);
	$mailText->setFrom($$emailHash{from});
	
	if($$emailHash{list} =~ /ARRAY/)
	{
		foreach my $to (@{$$emailHash{list}})
		{
			$mailText->addTo($to);
		}
	}
	else
	{
		$mailText->addTo($$emailHash{list});
	}     								
	
  	try
  	{
  		$mailText->send($$emailHash{smtp});
  	}
  	catch Mail::Exception with
  	{
  		my $ex	= shift;
  		Logger::addException($ex->text(),$ex->value(),$ex->stacktrace());
  	};
}

# salvando logs
Logger::addLog("Process ending");

Logger::dumpLogs($logDir, LOG_PREFIX);
Logger::dumpExceptions($logDir, EXCPT_PREFIX);

#
# fun��es
#

##
# sub help
#
# Print mensagem de help na tela
## 
sub help
{
	print "Script $0 - valida��o de backups de bases de dados
	
	Chamada: perl $0 <ini_path> <section> [<backup_file>]
	
	Par�metros: 
		. ini_path:		path para o arquivo .ini
		. section:		nome da se��o a ser lida do arquivo .ini
		. remote_file:	nome do arquivo a ser validado (opcional)\n\n";
	
	exit(0);
}

##
# sub version
#
# Print da vers�o do script.
##
sub version
{
	print "Version ".VERSION."\n";
	exit(0);
}
