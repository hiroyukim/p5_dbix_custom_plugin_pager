package DBIx::Custom::Plugin::Pager;
use strict;
use warnings;
our $VERSION = '0.01';
use Data::Page;
use Carp;
use DBIx::Custom::Util qw/_array_to_hash _subname/;

no strict 'refs';
*{"DBIx::Custom\::select_with_pager"} = sub {
    my $self = shift;
    my $column = shift if @_ % 2;
    my %opt = @_;
    $opt{column} = $column if defined $column;

    # Options
    my $tables = ref $opt{table} eq 'ARRAY' ? $opt{table}
               : defined $opt{table} ? [$opt{table}]
               : [];
    $opt{table} = $tables;
    my $where_param = $opt{where_param} || delete $opt{param} || {};
    warn "select method where_param option is DEPRECATED!"
      if $opt{where_param};
    
    # Add relation tables(DEPRECATED!);
    if ($opt{relation}) {
        warn "select() relation option is DEPRECATED!";
        $self->_add_relation_table($tables, $opt{relation});
    }
    
    # Select statement
    my $sql = 'select ';
    
    # Prefix
    if( !$opt{prefix} || !( $opt{prefix} eq 'SQL_CALC_FOUND_ROWS' ) ) {
        $opt{prefix}  = 'SQL_CALC_FOUND_ROWS'; 
    }
    $sql .= "$opt{prefix} " if defined $opt{prefix};
    
    # Column
    if (defined $opt{column}) {
        my $columns
          = ref $opt{column} eq 'ARRAY' ? $opt{column} : [$opt{column}];
        for my $column (@$columns) {
            if (ref $column eq 'HASH') {
                $column = $self->column(%$column) if ref $column eq 'HASH';
            }
            elsif (ref $column eq 'ARRAY') {
                warn "select column option [COLUMN => ALIAS] syntax is DEPRECATED!" .
                  "use q method to quote the value";
                if (@$column == 3 && $column->[1] eq 'as') {
                    warn "[COLUMN, as => ALIAS] is DEPRECATED! use [COLUMN => ALIAS]";
                    splice @$column, 1, 1;
                }
                
                $column = join(' ', $column->[0], 'as', $self->q($column->[1]));
            }
            unshift @$tables, @{$self->_search_tables($column)};
            $sql .= "$column, ";
        }
        $sql =~ s/, $/ /;
    }
    else { $sql .= '* ' }
    
    # Table
    $sql .= 'from ';
    if ($opt{relation}) {
        my $found = {};
        for my $table (@$tables) {
            $sql .= $self->q($table) . ', ' unless $found->{$table};
            $found->{$table} = 1;
        }
    }
    else { $sql .= $self->q($tables->[-1] || '') . ' ' }
    $sql =~ s/, $/ /;
    croak "select method table option must be specified " . _subname
      unless defined $tables->[-1];

    # Add tables in parameter
    unshift @$tables,
            @{$self->_search_tables(join(' ', keys %$where_param) || '')};
    
    # Where
    my $w = $self->_where_clause_and_param($opt{where}, $where_param,
      delete $opt{id}, $opt{primary_key}, $tables->[-1]);
    
    # Add table names in where clause
    unshift @$tables, @{$self->_search_tables($w->{clause})};
    
    # Join statement
    $self->_push_join(\$sql, $opt{join}, $tables) if defined $opt{join};
    
    # Add where clause
    $sql .= "$w->{clause} ";
    
    # Relation(DEPRECATED!);
    $self->_push_relation(\$sql, $tables, $opt{relation}, $w->{clause} eq '' ? 1 : 0)
      if $opt{relation};
   
    # pager
    #XXX: only mysql
    if( 
        ( grep { defined $opt{$_} && $opt{$_} =~ /^\d+$/ } qw/rows page/ ) == 2 
    ) {
        my $offset    = ($opt{page} - 1) * $opt{rows};
        $opt{append} .= " LIMIT  @{[$offset]}, @{[$opt{rows}]} ";               

    }

    # Execute query
    $opt{statement} = 'select';
    my $result = $self->execute($sql, $w->{param}, %opt);

    # pager only mysql
    my $total  = $self->execute('SELECT FOUND_ROWS()')->fetch_first->[0];

    return {
        result => $result,
        pager  => Data::Page->new($total, $opt{rows}, $opt{page}),
    };
};

1;
__END__

=head1 NAME

DBIx::Custom::Plugin::Pager -

=head1 SYNOPSIS

    use DBIx::Custom;
    use DBIx::Custom::Plugin::Pager;
    use Try::Tiny;
    
    try {
        my $results = $dbi->select_with_pager(
            table  => 'member',
            page   => 1,
            rows   => 30,
        );

        $results->{result}->fetch_hash_all();
    }
    catch {
        my $e = shift;
        Carp::confess($e); 
    };

=head1 DESCRIPTION

DBIx::Custom::Plugin::Pager is

=head1 AUTHOR

yamanaka hiroyuki E<lt>default {at} example.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
