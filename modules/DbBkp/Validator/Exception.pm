package DbBkp::Validator::Exception;

=for comment

 Module:	DbBkp::Validator::Exception (extends DbBkp::Exception)
 Autor:		Pedro Ilton Junior
 			Vinicius Porto Lima
 Vers�o:	1.0
 
 see DbBkp::Exception
 
=cut

use DbBkp::Exception;
use strict;

our @ISA = qw(DbBkp::Exception);

##
# public new
#
# @param $value		C�digo da exce��o
# @param $message	Mensagem de erro
##
sub new
{
	my $self	= 	shift;
	my $value	=	shift;
	my $message	=	shift;
	
	local $Error::Depth = $Error::Depth + 1;
	
	$self->SUPER::new($value,$message);
}

1;