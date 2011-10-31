#!/usr/bin/perl -w
use strict;
use File::Slurp;
use DBI;
use Getopt::Long;
use Data::Dumper;

my ($database,$help,$sql_user);
GetOptions('db:s' => \$database, 'help' =>\$help,'user:s' => \$sql_user);

#####   VERBOSE HELP STUFF - CHECK VALIDITY OF ARGUMENTS AND DISPLAY APROPRIATE HELP #####
&displayHelp("Must be run as root") if ($< != 0);
&displayHelp("") if(not defined $database or $database eq '');
&displayHelp("Arguments:\n  database - name of the MySQL databse\n  h or help - Help.Display this.") if(defined $help);

#####    START THE PROGRAM
my $user = 'root';
my $pass = '';
if(defined $sql_user) {
  $user = $sql_user;
  print "Enter MySQL password for $sql_user: ";
  chomp($pass = <>);
} 

my $dbh = DBI->connect("DBI:mysql:$database","$user",$pass) or die "$!\n";
my $sql = qq[ SHOW TABLES ];
my @tables = $dbh->tables();

my @output;

foreach(@tables) {
  $_ =~ /\`.+?`\.\`(.+?)\`/;
  my $table_name = $1;
  my $sth = $dbh->prepare("SELECT * FROM $table_name");
  $sth->execute();
  my $fields = $sth->{NAME};
  while (my $result = $sth->fetchrow_hashref()) {
      my $line = "db.$table_name.save({";
      for(my $i = 0; $i < scalar @{$fields} ; $i++) {
         next if($fields->[$i] eq "id");
         my $data = '';
         $data = $result->{$fields->[$i]} if (defined $result->{$fields->[$i]});
         if($data ne '') {
           $data =~ s/'/\\'/g;
           $data =~ s/\n/\\n/g;
           $data =~ s/\r/\\n/g;
         }
         $line .= "$fields->[$i] : '$data'," if($sth->{TYPE}->[$i] ne '4');
         $line .= "$fields->[$i] : $data,"   if($sth->{TYPE}->[$i] eq '4');#integers are of type 4, don't coerce as strings
      }
      $line =~ s/,$//;#remove trailing comma
      $line .= "});";
  
      push(@output,$line."\n");

  }
}

write_file("$database.mongo.js",@output);

sub displayHelp {
  die "\n$_[0]\n\nUsage: perl $0 -db <databasename>\n";
}

print "\n";

1;
