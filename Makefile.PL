use inc::Module::Install;
name 'DBIx-Custom-Plugin-Pager';
all_from 'lib/DBIx/Custom/Plugin/Pager.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
