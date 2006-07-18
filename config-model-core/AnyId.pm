# $Author: ddumont $
# $Date: 2006-07-18 12:09:56 $
# $Name: not supported by cvs2svn $
# $Revision: 1.5 $

#    Copyright (c) 2005,2006 Dominique Dumont.
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

package Config::Model::AnyId ;
use Config::Model::Exception ;
use Scalar::Util qw(weaken) ;
use warnings ;
use Carp;
use strict;

use vars qw($VERSION) ;
$VERSION = sprintf "%d.%03d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

use base qw/Config::Model::WarpedThing/;

# Some idea for improvement

# suggest => 'foo' or '$bar foo'
# creates a method analog to next_id (or next_id but I need to change
# run_user_command) that suggest the next id as foo_<nb> where
# nb is incremented each time, or compute the passed formula 
# and performs the same

=head1 NAME

Config::Model::AnyId - Base class for hash or list element

=head1 SYNOPSIS

 $model ->create_config_class 
  (
   ...
   element 
   => [ 
       bounded_hash 
       => { type => 'hash',                 # hash id
            index_type  => 'integer',

            # hash boundaries
            min => 1, max => 123, max_nb => 2 ,
            collected_type => 'leaf',
            element_args => {value_type => 'string'},
          },
      bounded_list 
       => { type => 'list',                 # list id

            max => 123, 
            collected_type => 'leaf',
            element_args => {value_type => 'string'},
          },
      ]
  ) ;

=head1 DESCRIPTION

This class provides hash or list elements for a L<Config::Model::Node>.

The hash index can either be en enumerated type, a boolean, an integer
or a string.

=cut

=head1 CONSTRUCTOR

AnyId object should not be created directly.

=cut

sub new {
    my $type = shift;

    # args hash is modified for arg check in derived class constructor
    my $args_ref = shift ; 

    my $self= { } ;

    bless $self,$type;

    foreach my $p (qw/element_name collected_type instance config_model/) {
	$self->{$p} = delete $args_ref->{$p} or
	  croak "$type->new: Missing $p parameter" ;
    }

    $self->_set_parent(delete $args_ref->{parent}) ;

    $self->{element_class} = delete $args_ref->{element_class} ;

    return $self ;
}

=head1 Hash or list model declaration

A hash or list element must be declared with the following parameters:

=over

=item type

Mandatory element type. Must be C<hash> or C<list> to have a
collection element.  The actual element type must be specified by
C<collected_type> (See </"CAVEATS">).

=item index_type

Either C<integer> or C<string>. Mandatory for hash.

=item min

Specify the minimum value (optional, only for hash and for integer index)

=item max

Specify the maximum value (optional, only for integer index)

=item max_nb

Specify the maximum number of indexes. (hash only, optional, may also
be used with string index type)

=item default

When set, the default parameter (or set of parameters) are used as
default keys hashes and created automatically when the keys or exists
functions are used on an I<empty> hash.

Called with C<< default => 'foo' >>, or C<< default => ['foo', 'bar'] >>.

=item auto_create

When set, the default parameter (or set of parameters) are 
used as keys hashes and created automatically.

Called with C<< auto_create => 'foo' >>, or 
C<< auto_create => ['foo', 'bar'] >>.

=item warp

See L<section/"Warp: dynamic value configuration"> below.

=back

=head1 About checking value

By default, value checking is done while setting or reading a value.

You can use 
L<push_no_value_check()|Config::Model::Instance/"push_no_value_check ( [fetch] , [store], [type] )">
or 
L<pop_no_value_check()|Config::Model::Instance/"pop_no_value_check()">
from L<Config::Model::Instance>
to modify this behavior.

=head1 Warp: dynamic value configuration

The Warp functionnality enables an L<HashId|Config::Model::HashId> or
L<ListId|Config::Model::ListId> object to change its default settings
(e.g. C<min>, C<max> or C<max_nb> parameters) dynamically according to
the value of another C<Value> object. (See
L<Config::Model::WarpedThing> for explanation on warp mechanism)

For instance, with this model:

 $model ->create_config_class 
  (
   name => 'Root',
   'element'
   => [
       macro => { type => 'leaf',
                  value_type => 'enum',
                  name       => 'macro',
                  choice     => [qw/A B C/],
                },
       warped_hash => { type => 'hash',
                        index_type => 'integer',
                        max_nb     => 3,
                        warp       => {
                                       follow => '- macro',
                                       rules => { A => { max_nb => 1 },
                                                  B => { max_nb => 2 }
                                                }
                                      },
                        collected_type => 'node',
                        config_class_name => 'Dummy'
                      },
     ]
  );

Setting C<macro> to C<A> will mean that C<warped_hash> can only accept
one instance of C<Dummy>.

Setting C<macro> to C<B> will mean that C<warped_hash> will accept two
instances of C<Dummy>.

Like other warped class, a HashId or ListIf can have multiple warp
masters (See L<Config::Model::WarpedThing/"Warp follow argument">:

  warp => { follow => ['- macro1', '- macro2'],
            rules  => [ [ 'A','A2' ]  => { max_nb => 1},
                        [ 'A','B2' ] => { max_nb => 2}
                      ],
          }

=head2 Warp and auto_create

When a warp is applied with C<auto_create> parameter, the auto_created
items are created if they are not already present. But this warp will
never remove items that were previously auto created.

For instance, if a tied hash is created with 
C<< auto_create => [a,b,c] >>, the hash contains C<(a,b,c)>.

Then if a warp is applied with C<< auto_create => [c,d,e] >>, the hash
will contain C<(a,b,c,d,e)>. The items created by the first
auto_create are not removed.

=head2 Warp and max_nb

When a warp is applied, the items that do not fit the constraint
(e.g. min, max) are removed.

For the max_nb constraint, an exception will be raised if a warp 
leads to a nb of items greater than the max_nb constraint.

=cut

my @common_params =  qw/min max max_nb default auto_create 
                             element_args/ ;

my @allowed_warp_params = (@common_params,qw/config_class_name permission/) ;


# this method can be called by the warp mechanism to alter (warp) the
# feature of the Id object.
sub set {
    my $self= shift;

    # mega cleanup
    map(delete $self->{$_}, @allowed_warp_params);

    my %args = (%{$self->{backup}},@_) ;

    print $self->name," set called with @_\n" if $::debug;

    map { $self->{$_} =  delete $args{$_} if defined $args{$_} }
      @common_params ;

    Config::Model::Exception::Model
	->throw (
		 object => $self,
		 error => "Undefined index_type"
		) unless defined $self->{index_type};

    Config::Model::Exception::Model
	->throw (
		 object => $self,
		 error => "Unexpected index_type $self->{index_type}"
		) unless ($self->{index_type} eq 'integer' or 
			  $self->{index_type} eq 'string');

    my @current_idx = $self->_get_all_indexes( );
    if (@current_idx) {
	my $first_idx = shift @current_idx ;
	my $last_idx  = pop   @current_idx ;

	foreach my $idx ( ($first_idx, $last_idx)) {
	    my $ok = $self->check($first_idx) ;
	    next if $ok ;

	    # here a user input may trigger an exception even if fetch
	    # or set value check is disabled. That's mostly because,
	    # we cannot enforce more strict settings without random
	    # deletion of data. For instance, if a hash contains 5
	    # items and the max_nb of items is reduced to 3. Which 2
	    # items should we remove ?

	    # Since we cannot choose, we must raise an exception in
	    # all cases.
	    Config::Model::Exception::WrongValue 
		-> throw (
			  error => "Error while setting id property:".
			  join("\n\t",@{$self->{error}}),
			  object => $self
			 ) ;
	}
    }

    if (defined $self->{auto_create}) {
        my $auto_p = $self->{auto_create} ;
        # create empty slots
        map {$self->{data}{$_} = undef unless exists $self->{data}{$_};
	 }  (ref $auto_p ? @$auto_p : ($auto_p)) ;
    }

    # handle config_class_name warp
    $self->set_element_class(\%args)  ;

    Config::Model::Exception::Model
	->throw (
		 object => $self,
		 error => "Unexpected parameters :". join(' ', keys %args)
		) if scalar keys %args ;
}

=head1 Introspection methods

The following methods returns the current value of the Id object (as
declared in the model unless they were warped):

=over

=item min 

=item max 

=item max_nb 

=item index_type 

=item default 

=item auto_create 

=item collected_type 

=item element_class 

=item element_args morph

=item config_model

=back

=cut

for my $datum (qw/min max max_nb index_type default auto_create 
                  collected_type element_class element_args morph
                  config_model/) {
    no strict "refs";       # to register new methods in package
    *$datum = sub {
        my $self= shift; 
        return $self->{$datum};
    } ;
}

=head2 get_cargo_type()

Returns the object type contained by the hash or list (i.e. returns
C<collected_type>).

=cut

sub get_cargo_type {
    my $self = shift ;
    #my @ids = $self->get_all_indexes ;
    # the returned cargo type might be different from collected type
    # when collected type is 'warped_node'. 
    #return @ids ? $self->fetch_with_id($ids[0])->get_cargo_type
    #  : $self->{collected_type} ;
    return $self->{collected_type} ;
}

=head2 name()

Returns the object name. The name finishes with ' id'.

=cut

sub name
  {
    my $self = shift ;
    return $self->{parent}->name . ' '.$self->{element_name}.' id' ;
  }

=head2 config_class_name()

Returns the config_class_name of collected elements. Valid only
for collection of nodes.

This method will return undef if C<collected_type> is not C<node>.

=cut

sub config_class_name
  {
    my $self = shift ;
    return $self->{config_class_name} ;
  }

# internal. This method will deal with warp when collected elements
# are node type. This will handle morphing (i.e loose copy of
# configuration data from old node object to new node object).
sub set_element_class {
    my $self=shift;
    my $arg_ref = shift ;

    return unless $self->{collected_type} eq 'node' ;

    $self->set_parent_element_property($arg_ref) ;

    my $config_class_name = delete $arg_ref->{config_class_name};
    # cleanup of argument
    delete $arg_ref->{permission} ;

    my @current_idx = $self->_get_all_indexes ;

    if (not defined $config_class_name)
      {
	map {$self->delete($_);} @current_idx ;
        return ;
      }

    foreach my $idx (@current_idx) {
	# check if some action is needed
	my $old_object = $self->_fetch_with_id( $idx ) ;

	next unless defined $old_object ;

	next if $old_object->config_class_name eq $config_class_name ;
	$self->{config_class_name} = $config_class_name ;
	$self->delete($idx) ;

	my $morph = $self->{warp}{morph} ;
	my $args = $self->{element_args} || [] ;

	# create a new object from scratch
	$self->auto_vivify($idx) ;

	if (defined $old_object and $morph) {
	    # there an old object that we need to translate
	    print "morphing ",$old_object->name," from ",
	      $old_object->config_class_name,
		" to $config_class_name\n"
		  if $::debug ;
	    $self->fetch_with_id( $idx )->copy_from($old_object) ;
	}
    }

    $self->{config_class_name} = $config_class_name ;
}

# internal. Handle model declaration arguments
sub handle_args {
    my $self = shift ;
    my %args = @_ ;

    my $warp_info = delete $args{warp} ;

    map { $self->{$_} =  delete $args{$_} if defined $args{$_} }
         qw/index_class index_type morph/;

    %{$self->{backup}}  = %args ;

    $self->set(%args) if defined $self->{index_type} ;

    if (defined $warp_info) {
	$self->check_warp_args( \@allowed_warp_params, $warp_info) ;
    }

    $self->submit_to_warp($self->{warp}) if $self->{warp} ;

    return $self ;
}

# internal function to check the validity of the index
sub check {
    my ($self,$idx) = @_ ; 

    my @error  ;

    my $nb =  $self->fetch_size ;
    my $new_nb = $nb ;
    $new_nb++ unless $self->_exists($idx) ;

    Config::Model::Exception::Internal
	-> throw (
		  object => $self,
		  error => "check method: hash index is not defined"
		 ) unless defined $idx ;

    if ($idx eq '') {
        push @error,"Index is empty";
    }
    elsif ($self->{index_type} eq 'integer' and $idx =~ /\D/) {
	push @error,"Index is not integer ($idx)";
    }
    elsif (defined $self->{max} and $idx > $self->{max}) {
        push @error,"Index $idx > max limit $self->{max}" ;
    }
    elsif ( defined $self->{min} and $idx < $self->{min}) {
        push @error,"Index $idx < min limit $self->{min}";
    }

    push @error,"Too many instances ($new_nb) limit $self->{max_nb}, ".
      "rejected id '$idx'"
	if defined $self->{max_nb} and $new_nb > $self->{max_nb};

    if (scalar @error) {
	my @a = $self->get_all_indexes ;
        push @error, "Instance ids are '".join(',', @a)."'" ,
          $self->warp_error  ;
    }

    $self->{error} = \@error ;
    return not scalar @error ;
}

=head1 Informations management

=head2 fetch_with_id ( index )

Fetch the collected element held by the hash or list.

=cut

sub fetch_with_id {
    my ($self,$idx) = @_ ;

    $self->warp 
      if ($self->{warp} and @{$self->{warp_info}{computed_master}});

    my $ok = $self->check($idx) ;

    if ($ok) {
	$self->auto_vivify($idx) unless $self->_defined($idx) ;
        return $self->_fetch_with_id($idx) ;
      }
    elsif ($self->instance->get_value_check('fetch')) {
        Config::Model::Exception::WrongValue 
	    -> throw (
		      error => join("\n\t",@{$self->{error}}),
		      object => $self
		     ) ;
    }

    return undef ;
}

=head2 fetch_all()

Returns an array containing all elements held by the hash or list.

=cut

sub fetch_all {
    my $self = shift ;
    my @keys  = $self->get_all_indexes ;
    return map { $self->fetch_with_id($_) ;} @keys ;
}

=head2 fetch_all_values()

Returns an array containing all values held by the hash or list.

=cut

sub fetch_all_values {
    my $self = shift ;
    my @keys  = $self->get_all_indexes ;
    return map { $self->fetch_with_id($_)->fetch ;} @keys ;
}

=head2 get_all_indexes()

Returns an array containing all indexes of the hash or list.

=cut

sub get_all_indexes {
    my $self = shift;
    $self->create_default if defined $self->{default};
    return $self->_get_all_indexes ;
}


# auto vivify must create according to collected_type
# node -> Node or user class
# leaf -> Value or user class

# warped node cannot be used. Same effect can be achieved by warping 
# element_args 

my %element_default_class 
  = (
     node        => 'Node',
     leaf        => 'Value',
    );

my %can_override_class 
  = (
     node        => 0,
     leaf        => 1,
    );

#internal
sub auto_vivify {
    my ($self,$idx) = @_ ;
    my $class = $self->{element_class} ;
    my $element_args = $self->{element_args} || {} ;

    my $collected_type = $self->{collected_type} ;

    Config::Model::Exception::Model 
	-> throw (
		  object => $self,
		  message => "unknown '$collected_type' collected_type:  "
		  ."in element_args. Expected "
		  .join (' or ',keys %element_default_class)
		 ) 
	      unless defined $element_default_class{$collected_type} ;

    my $el_class = 'Config::Model::'
      . $element_default_class{$collected_type} ;

    if (defined $class) {
	Config::Model::Exception::Model 
	    -> throw (
		      object => $self,
		      message => "$collected_type class "
		      ."cannot be overidden by '$class'"
		     ) 
	      unless $can_override_class{$collected_type} ;
	$el_class = $class;
    }

    if (not defined *{$el_class.'::new'}) {
	my $file = $el_class.'.pm';
	$file =~ s!::!/!g;
	require $file ;
    }

    my @common_args = (
		       element_name => $self->{element_name},
		       index_value  => $idx,
		       instance     => $self->{instance} ,
		      );
    my $item ;

    # check parameters passed by the user
    if ($collected_type eq 'node') {
	Config::Model::Exception::Model 
	    -> throw (
		      object => $self,
		      message => "Missing 'element_args' parameter (hash ref)"
		     ) 
	      unless ref $element_args eq 'HASH' ;

	Config::Model::Exception::Model 
	    -> throw (
		      object => $self,
		      message => "missing 'config_class_name' "
		      ."parameter",
		     ) 
	      unless defined $self->{config_class_name} ;

	$item = $self->{parent} 
	  -> new( @common_args ,
		  config_class_name => $self->{config_class_name},
		  %$element_args) ;
    }
    else {
	$item = $el_class->new( @common_args,
				parent => $self->{parent} ,
				instance => $self->{instance} ,
				%$element_args) ;
    }

    $self->_store($idx,$item) ;
}

=head2 defined ( index )

Returns true if the value held at C<index> is defined.

=cut

sub defined {
    my ($self,$idx) = @_ ;

    $self->warp 
      if ($self->{warp} and @{$self->{warp_info}{computed_master}});

    return $self->_defined($idx);
}

=head2 exists ( index )

Returns true if the value held at C<index> exists (i.e the key exists
but the value may be undefined). This method may not make sense for
list element.

=cut

sub exists {
    my ($self,$idx) = @_ ;

    $self->warp 
      if ($self->{warp} and @{$self->{warp_info}{computed_master}});

    return $self->_exists($idx);
}

=head2 delete ( index )

Delete the C<index>ed value 

=cut

sub delete {
    my ($self,$idx) = @_ ;

    $self->warp 
      if ($self->{warp} and @{$self->{warp_info}{computed_master}});

    return $self->_delete($idx);
  }

=head2 clear()

Delete all values.

=cut

sub clear {
    my ($self) = @_ ;

    $self->warp 
      if ($self->{warp} and @{$self->{warp_info}{computed_master}});

    $self->_clear;
  }

1;

__END__

=head1 CAVEATS

The argument that specifies the type of the element stored in the hash
or list is named C<collected_type>. This name sounds lame. If a native
english speaker can suggest a better name, I'll be glad to change it.

=head1 AUTHOR

Dominique Dumont, domi@komarr.grenoble.hp.com

=head1 SEE ALSO

L<Config::Model::Model>,
L<Config::Model::Instance>,
L<Config::Model::HashId>,
L<Config::Model::ListId>,
L<Config::Model::WarpedNode>,
L<Config::Model::Value>


=cut

