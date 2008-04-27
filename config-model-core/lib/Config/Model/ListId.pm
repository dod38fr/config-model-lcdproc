# $Author$
# $Date$
# $Revision$

#    Copyright (c) 2005-2007 Dominique Dumont.
#
#    This file is part of Config-Model.
#
#    Config-Model is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser Public License as
#    published by the Free Software Foundation; either version 2.1 of
#    the License, or (at your option) any later version.
#
#    Config-Model is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser Public License for more details.
#
#    You should have received a copy of the GNU Lesser Public License
#    along with Config-Model; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA

package Config::Model::ListId ;
use Config::Model::Exception ;
use Scalar::Util qw(weaken) ;
use warnings ;
use Carp;
use strict;

use base qw/Config::Model::AnyId/ ;

use vars qw($VERSION) ;
$VERSION = sprintf "1.%04d", q$Revision$ =~ /(\d+)/;

=head1 NAME

Config::Model::ListId - Handle list element for configuration model

=head1 SYNOPSIS

 $model ->create_config_class 
  (
   ...
   element 
   => [ 
       bounded_list 
       => { type => 'list',
            max => 123, 
            max_nb => 2 ,
            cargo_type => 'leaf',
            cargo_args => {value_type => 'string'},
          },
      ]
  ) ;

=head1 DESCRIPTION

This class provides list elements for a L<Config::Model::Node>.

=cut

=head1 CONSTRUCTOR

ListId object should not be created directly.

=cut

sub new {
    my $type = shift;
    my %args = @_ ;

    my $self = $type->SUPER::new(\%args) ;

    $self->{data} = [] ;

    Config::Model::Exception::Model->throw 
        (
         object => $self,
         error =>  "Cannot use max_nb with ".$self->get_type." element"
        ) if defined $args{max_nb};

    Config::Model::Exception::Model->throw 
        (
         object => $self,
         error => "Cannot use min with ".$self->get_type." element"
        ) if defined $args{min};

    # Supply the mandatory parameter
    $self->handle_args(%args, index_type => 'integer') ;
    return $self;
}

=head1 List model declaration

See
L<model declaration section|Config::Model::AnyId/"Hash or list model declaration">
from L<Config::Model::AnyId>.

=cut

sub set {
    my $self = shift ;

    $self->SUPER::set(@_) ;

    # remove unwanted items
    my $data = $self->{data} ;

    return unless defined $self->{max} ;

    # delete entries that no longer fit the constraints imposed by the
    # warp mechanism
    foreach my $k (0 .. $#{$data}) {
	next unless  $k >  $self->{max};
	print "set: ",$self->name," deleting index $k\n" if $::debug ;
	delete $data->[$k] ;
    }
}

=head1 Methods

=head2 get_type

Returns C<list>.

=cut

sub get_type {
    my $self = shift;
    return 'list' ;
}

=head2 fetch_size

Returns the nb of elements of the list.

=cut

sub fetch_size {
    my $self =shift ;
    confess "Undef data " unless defined $self->{data} ;
    return scalar @{$self->{data}} ;
}

sub _get_all_indexes {
    my $self =shift ;
    my $data = $self->{data} ;
    return (0 .. $#$data ) ;
}

# fetch without any check 
sub _fetch_with_id {
    my ($self, $idx) = @_ ;
    return $self->{data}[$idx];
}

sub store_set {
    my $self = shift ;
    my $idx = 0 ;
    map { $self->fetch_with_id( $idx++ )->store( $_ ) ; } @_ ;
}

# store without any check 
sub _store {
    my ($self, $idx, $value) =  @_ ;
    return $self->{data}[$idx] = $value ;
}

sub _defined {
    my ($self,$key) = @_ ;
    return defined $self->{data}[$key];
}

sub _exists {
    my ($self, $idx) = @_ ;
    return exists $self->{data}[$idx];
}

sub _delete {
    my ($self,$idx) = @_ ;
    return delete $self->{data}[$idx];
}

sub _clear {
    my ($self)= @_ ;
    $self->{data} = [] ;
}

=head2 push( value )

push some value at the end of the list.

=cut

# list only methods
sub push {
    my $self = shift ;
    my $idx   = scalar @{$self->{data}};

    map { $self->fetch_with_id( $idx++ )->store( $_ ) ; } @_ ;
}

=head2 swap ( ida, idb )

Swap 2 elements within the array

=cut

sub swap {
    my $self = shift ;
    my $ida  = shift ;
    my $idb  = shift ;

    my $tmp = $self->{data}[$ida] ;
    $self->{data}[$ida] = $self->{data}[$idb] ;
    $self->{data}[$idb] = $tmp ;
}

=head2 remove ( idx )

Remove an element from the list. Equivalent to C<splice @list,$idx,1>

=cut

sub remove {
    my $self = shift ;
    my $idx  = shift ;
    splice @{$self->{data}}, $idx , 1 ;
}

#internal
sub auto_create_elements {
    my $self = shift ;

    my $auto_p = $self->{auto_create} - 1;
    # create empty slots
    map {
	$self->{data}[$_] = undef unless defined $self->{data}[$_];
    }  (0 .. $auto_p ) ;
}

# internal
sub create_default {
    my $self = shift ;

    return if @{$self->{data}} ;

    # list is empty so create empty element for default keys
    my $def = $self->get_default_keys ;

    map {$self->{data}[$_] = undef } @$def ;

    if (defined $self->{default_with_init}) {
	foreach my $def_key (keys %{$self->{default_with_init}}) {
	    $self->fetch_with_id($def_key)->load($def->{$def_key}) ;
	}
    }
}

=head2 load_data ( list_ref )

Load list as an array ref. 

=cut

sub load_data {
    my $self = shift ;
    my $data = shift ;

    $self->clear ;
    if (ref ($data)  eq 'ARRAY') {
	my $idx = 0;
	print "ListId load_data (",$self->location,") will load idx ",
	  "0..$#$data\n" if $::verbose ;
	foreach my $item (@$data ) {
	    my $obj = $self->fetch_with_id($idx++) ;
	    $obj -> load_data($item) ;
	}
    }
    elsif (not ref ($data)) {
	print "ListId load_data (",$self->location,") will load idx ",
	  "0\n" if $::verbose ;
	$self->fetch_with_id(0) -> load_data($data) ;
    }
    else {
	Config::Model::Exception::LoadData
	    -> throw (
		      object => $self,
		      message => "load_data called with non array ref arg",
		      wrong_data => $data,
		     ) ;
    }
}

1;

__END__

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model::Model>, 
L<Config::Model::Instance>, 
L<Config::Model::AnyId>,
L<Config::Model::HashId>,
L<Config::Model::Value>

=cut