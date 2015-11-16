#!/bin/bash

DIR=`dirname $0`
PERL5LIB=$PERL5LIB:$DIR/../modules

perl $DIR/validate_backup.pl $*
