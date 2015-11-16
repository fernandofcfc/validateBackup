package DbBkp::Exception;

=for comment

 Module:	DbBkp::Exception (extends Error)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Versão:	1.0
 
 see Error
 
=cut

use Error;
use strict;

our @ISA = qw(Error);

use constant UNDEFINED_FAILURE	=>	"UNDEFINED FAILURE";

#
# Mapeamento de Exceções
# 
my %exceptionList	=	(
							# MAPA CODIGO => DESCRIÇÃO
							1	=> "NOT IMPLEMENTED YET",
							2	=> "COULD NOT RESTORE DATABASE"
						);

##
# public new
#
# param $value	código da exceção
# param $text 	mensagem da exceção
##
sub new
{
	my $self	= shift;
	
	my $value	= shift;
	my $message	= shift;
	my $text	= "";
	my @args 	= ();
	
	if(defined  $exceptionList{"$value"}) 
	{
		$text .=  $exceptionList{"$value"};
	}
	else
	{
		$text .= UNDEFINED_FAILURE;
	}
	
	$text	.=	" - $message"	if(defined $message);
	
	local $Error::Depth = $Error::Depth + 1;	# Muda a profundidade de informação do stacktrace	
	local $Error::Debug = 1;					# Habilita o stacktrace
	
	$self->SUPER::new(-text => $text, -value => $value, @args);
}

1;