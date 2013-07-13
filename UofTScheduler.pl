use strict;
use warnings;
use File::Basename;
use Data::Dumper;

open (FALL2013, '<', 'Fall2013.csv') or die "cannot open Fall2013.csv: $!";
my @file = <FALL2013>;
close FALL2013;

shift @file;

my $previousSection;
my $fallSemesterHash = {};

foreach my $line (@file){
        my ($name, $section, $meet, $day, $start, $finish, $notes) = split (',', $line);
        
        if ($section ne '') {
            $previousSection = $section;
        } else {
            $section = $previousSection;
        }
        
        $previousSection =~ /(\S+)\s+(\S+)/ or die "ERROR with line $line";

        $fallSemesterHash->{$name}->{$1}->{$2}->{$meet}->{day} = $day;
        $fallSemesterHash->{$name}->{$1}->{$2}->{$meet}->{start} = $start;
        $fallSemesterHash->{$name}->{$1}->{$2}->{$meet}->{finish} = $finish;
        $fallSemesterHash->{$name}->{$1}->{$2}->{$meet}->{notes} = defined $notes ? $notes : undef;
}

print "INFO:  Fall semester loaded\n";

open (WINTER2013, '<', 'Winter2014.csv') or die "cannot open Winter2014.csv: $!";
@file = <WINTER2013>;
close WINTER2013;

shift @file;

$previousSection = '';
my $winterSemesterHash = {};

foreach my $line (@file){
        my ($name, $section, $meet, $day, $start, $finish, $notes) = split (',', $line);
        
        if ($section ne '') {
            $previousSection = $section;
        } else {
            $section = $previousSection;
        }
        
        $previousSection =~ /(\S+)\s+(\S+)/ or die "ERROR with line $line";
        
        $winterSemesterHash->{$name}->{$1}->{$2}->{$meet}->{day} = $day;
        $winterSemesterHash->{$name}->{$1}->{$2}->{$meet}->{start} = $start;
        $winterSemesterHash->{$name}->{$1}->{$2}->{$meet}->{finish} = $finish;
        $winterSemesterHash->{$name}->{$1}->{$2}->{$meet}->{notes} = defined $notes ? $notes : undef;
}

print "INFO:  Winter semester loaded\n";

print "\n\n";

print "###########################################\n";
print "Uoft Scheduler: 0.1\n";
print "\@ Patrice Boisclair-Laberge\n";
print "###########################################\n\n";
my $courseNum= '';
my $semester = '';

while (1) {
    print "Which semester would you like to schedule? (Fall or Winter)\n";
    $semester = <STDIN>;
    chomp($semester);
    $semester = uc $semester;
    last if ($semester =~ /^(FALL)|(WINTER)$/);
    print "The input does not seem to match fall or winter\n\n";
}

while (1) {
    print "\nHow many courses would you like to add to your schedule?\n";
    $courseNum = <STDIN>;
    chomp($courseNum);
    if ($courseNum =~ /^\d+$/){
        if ($courseNum < 8) {
            last;
        } else {
            print "It is unlikely that that many courses would fit in your schedule\n";
            next;
        }
    }
    print "The input does not seem to be a valid number\n\n";
}

my $semesterHash = $semester eq 'FALL' ? $fallSemesterHash : $winterSemesterHash;

my $courses = {};

for (my $i = 0; $i < $courseNum; $i++) {
    while (1) {
        print "\nWhich course would you like to add? (ex: ECE302H1F or ECE*) $i\n";
        my $courseName;
        $courseName = <STDIN>;
        chomp($courseName);
        $courseName = uc $courseName;
        $courseName =~ s/\*/\.\*/g;
        my @possibleCourses = grep(/$courseName/, keys %{$semesterHash});
        if (scalar @possibleCourses > 1) {
            print "Possible Matches:\n\n";
            map {print "$_\n"} sort @possibleCourses;
            print "\n";
        } elsif (@possibleCourses == 1) {
            my $course = $possibleCourses[0];
            unless (exists $semesterHash->{$course}) {
                print "The course code $course does not seem to be valid. Did you forget H1/Y1 or F/S\n\n";
                next;
            }
            print "Would you like to add $course to your course selection? [Y/N]\n";
            my $decision;
            while (1) {
                $decision = <STDIN>;
                chomp($decision);
                $decision = uc $decision;
                last if ($decision =~ /^Y|N$/);
            }
            if ($decision eq 'Y') {
                $courses->{$course} = $semesterHash->{$course};
                print "\n$course was added to your selection\n";
                last;
            } else {
                next;
            }
        } else {
            print "The input $courseName did not find any match in the database.\n";
        }
    }
}
my $maxNumberOfConflict;
while (1) {
    print "\nWhat is the maximum number of hours of conflict acceptable?\n";
    $maxNumberOfConflict = <STDIN>;
    chomp($maxNumberOfConflict);
    last if ($maxNumberOfConflict =~ /^\d+$/);
    print "The input does not seem to be a valid number\n\n";
}

my $counter = 0;
my $totalCount = 0;
my @schedules;
my $currentPerc = 0;

recursiveProbabilityCount($courses, 0, [sort keys %{$courses}]);
recursiveProbability({}, $courses, 0, [sort keys %{$courses}]);
print "$counter\/$totalCount\n";
sub recursiveProbabilityCount
{
    my $courses = shift @_;
    my $idx = shift @_;
    my @keys = @{shift(@_)};
    
    if ($idx == scalar @keys ) {
        $totalCount = $totalCount + 1;
        return;
    }
    
    foreach my $lecMeet (keys %{$courses->{$keys[$idx]}->{LEC}}) {
        if (exists $courses->{$keys[$idx]}->{TUT}) {
            foreach my $tutMeet (keys %{$courses->{$keys[$idx]}->{TUT}}) {
                if (exists $courses->{$keys[$idx]}->{PRA}) {
                    foreach my $praMeet (keys %{$courses->{$keys[$idx]}->{PRA}}) {
                        recursiveProbabilityCount($courses, $idx + 1, \@keys);
                    }
                } else {
                    recursiveProbabilityCount($courses, $idx + 1, \@keys);
                }
            }
        } else {
            if (exists $courses->{$keys[$idx]}->{PRA}) {
                foreach my $praMeet (keys %{$courses->{$keys[$idx]}->{PRA}}) {
                    recursiveProbabilityCount($courses, $idx + 1, \@keys);
                }
            } else {
                recursiveProbabilityCount($courses, $idx + 1, \@keys);
            }
        }
    }
    
}

sub recursiveProbability
{
    my %instance = %{shift(@_)};
    my $courses = shift @_;
    my $idx = shift @_;
    my @keys = @{shift(@_)};
    
    if ($idx == scalar @keys ) {
        my @possiblilities = checkNumberOfConflicts(\%instance);
        push @schedules, [$possiblilities[1], $possiblilities[2], $possiblilities[0]]  if ($possiblilities[0] <= $maxNumberOfConflict);
        $counter = $counter + 1;
        if (($counter/$totalCount*100) > ($currentPerc  + 5)) {
            $currentPerc = $currentPerc + 5;
            print "$currentPerc\%\n" 
        }
        return;
    }
    
    foreach my $lecMeet (keys %{$courses->{$keys[$idx]}->{LEC}}) {
        $instance{$keys[$idx]}->{LEC} =  {$lecMeet => $courses->{$keys[$idx]}->{LEC}->{$lecMeet}};
        if (exists $courses->{$keys[$idx]}->{TUT}) {
            foreach my $tutMeet (keys %{$courses->{$keys[$idx]}->{TUT}}) {
                $instance{$keys[$idx]}->{TUT} = {$tutMeet =>$courses->{$keys[$idx]}->{TUT}->{$tutMeet}};
                if (exists $courses->{$keys[$idx]}->{PRA}) {
                    foreach my $praMeet (keys %{$courses->{$keys[$idx]}->{PRA}}) {
                        $instance{$keys[$idx]}->{PRA} = {$praMeet => $courses->{$keys[$idx]}->{PRA}->{$praMeet}};
                        recursiveProbability(\%instance, $courses, $idx + 1, \@keys);
                    }
                } else {
                    recursiveProbability(\%instance, $courses, $idx + 1, \@keys);
                }
            }
        } else {
            if (exists $courses->{$keys[$idx]}->{PRA}) {
                foreach my $praMeet (keys %{$courses->{$keys[$idx]}->{PRA}}) {
                    $instance{$keys[$idx]}->{PRA} = {$praMeet => $courses->{$keys[$idx]}->{PRA}->{$praMeet}};
                    recursiveProbability(\%instance, $courses, $idx + 1, \@keys);
                }
            } else {
                recursiveProbability(\%instance, $courses, $idx + 1, \@keys);
            }
        }
    }
    
}

sub checkNumberOfConflicts
{
    my $instance = shift;
    my $numConflicts = 0;
    my $week = {};
    foreach my $course (keys %{$instance}) {
        foreach my $meetType (keys %{$instance->{$course}}) {
            foreach my $sectionInHash (keys %{$instance->{$course}->{$meetType}}) {
                foreach my $meet (keys %{$instance->{$course}->{$meetType}->{$sectionInHash}}) {
                    my $meetHash = $instance->{$course}->{$meetType}->{$sectionInHash}->{$meet};
                    my $notes = $meetHash->{notes};
                    my $day = $meetHash->{day};
                    my $start = $meetHash->{start};
                    $start =~ s/(\d+):\d+/$1/;
                    my $finish = $meetHash->{finish};
                    $finish =~ s/(\d+):\d+/$1/;
                    
                    for (my $i = $start; $i < $finish; $i++) {
                        $week->{$day}->{"$i\:00"}->{$course} = {$meetType => $sectionInHash};
                        if (exists $week->{$day}->{"$i\:00"}->{count}) {
                            $numConflicts = $numConflicts + 1;
                            $week->{$day}->{"$i\:00"}->{count} = $week->{$day}->{"$i\:00"}->{count} + 1;
                        } else {
                            $week->{$day}->{"$i\:00"}->{count} = 0;
                        }
                    }
                }
            }
        }
    }
    return ($numConflicts, $week, $instance);
}

print "\n###########################################\n\n";
print "Total possible schedules: ".scalar(@schedules)."\n";
print "\n###########################################\n\n";
if (scalar(@schedules) > 0) {
    print "Would you like to export those schedules? [Y/N]\n";
    my $decision;
    while (1) {
        $decision = <STDIN>;
        chomp($decision);
        $decision = uc $decision;
        last if ($decision =~ /^Y|N$/);
    }
    @schedules = sort {$a->[2] cmp $b->[2]} @schedules;
    if ($decision eq 'Y') {
        exportHTML();
     }
 }
 sub exportHTML
 {
    `mkdir -p results`;
    `rm results/*`;
    my @fl;
    my $numberofschedules = scalar @schedules;
    my @daysOfWeek = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri');
    my @colorArray = ('#FF7F00', '#AB82FF', '#C0C0C0', '#DEB887', '#6495ED', '#FF7F50', '#FAEBD7', '#5F9EA0');
    for (my $i = 0; $i < $numberofschedules; $i++) {
        my @coursesChosen = sort keys %{$schedules[$i]->[1]};
        my %colorHash;
        for (my $j = 0; $j <= $#coursesChosen; $j++) {
            $colorHash{$coursesChosen[$j]} = $j;
        }
    
    
        my $fileName = "schedule$i\.html";
        push @fl, $fileName;
        my $week = $schedules[$i]->[0];
        open OUTPUT,">" . "results\/$fileName" or die "$!";
        select OUTPUT;
        print "<!DOCTYPE html>\n";
        print "<html>\n";
        print "<body>\n";
        print "<h1>Schedule $i</h1>\n";
        
        print "<h2>Schedules:</h2>\n";
        
        print "<table border=\"1\">\n";
        
        print "<tr align =\"center\">\n    <td><b>Time</b></td>\n    <td><b>Monday</b></td>\n    <td><b>Tuesday</b></td>\n    <td><b>Wednesday</b></td>\n    <td><b>Thursday<b></td>\n    <td><b>Friday<b></td>\n</tr>\n";
        
        for (my $i = 8; $i < 21; $i++) {
            print "<tr align =\"center\">\n";
            print "    <td><b>$i\:00<b></ti>\n";
            
            foreach my $day (@daysOfWeek) {
                if (exists $week->{$day} && exists $week->{$day}->{"$i\:00"}){
                    if ($week->{$day}->{"$i\:00"}->{count} == 0) {
                            foreach my $course (keys %{$week->{$day}->{"$i\:00"}}) {
                                next if ($course eq 'count');
                                print "    <td bgcolor=\"".$colorArray[$colorHash{$course}]."\">";
                                print "$course<br>";
                                foreach my $key (keys %{$week->{$day}->{"$i\:00"}->{$course}}) {
                                    print $key.' '.$week->{$day}->{"$i\:00"}->{$course}->{$key};
                                }
                            }
                        print "</td>\n";
                    } else {
                        print "    <td bgcolor=\"red\"><font color=\"white\">";
                        
                        foreach my $course (keys %{$week->{$day}->{"$i\:00"}}) {
                                next if ($course eq 'count');
                                print "<u>$course</u><br>";
                                foreach my $key (keys %{$week->{$day}->{"$i\:00"}->{$course}}) {
                                    print $key.' '.$week->{$day}->{"$i\:00"}->{$course}->{$key}.'<br>';
                                }
                        }
                        
                        print "</font></td>\n";
                    }
                } else {
                    print "    <td></td>\n";
                }
            }
            
            print "<tr>\n";
        }
        
        print "</table>\n";
        
        
        print "<h2>Courses:</h2>\n";
        print "<ul>\n";
        
        foreach my $course (sort keys %{$schedules[$i]->[1]}) {
            print "    <li>\n";
            print "        <b><font color=\"".$colorArray[$colorHash{$course}]."\">$course</font></b>\n";
            print "        <ul>\n";
            
            foreach my $meet (keys %{$schedules[$i]->[1]->{$course}}) {
                print "            <li>$meet ";
                
                foreach my $section (keys %{$schedules[$i]->[1]->{$course}->{$meet}}) {
                    print $section;
                }
                
                print "</li>\n";
            }
            
            print "        </ul>\n";
            print "    </li>\n";
        }
        
        print "</ul>\n";

        print "</body>\n";
        print "</html>\n";
        close OUTPUT;
    }
    
    open OUTPUT,">" . 'results/index.html' or die "$!";
    print "<!DOCTYPE html>\n";
    print "<html>\n";
    print "<body>\n";
    print "<h1>Schedules</h1>\n";
    print "<ul>\n";
    for (my $i = 0; $i <= $#fl; $i++) {
        my $week = $schedules[$i]->[0];
        my @coursesChosen = sort keys %{$schedules[$i]->[1]};
        my %colorHash;
        for (my $j = 0; $j <= $#coursesChosen; $j++) {
            $colorHash{$coursesChosen[$j]} = $j;
        }
        print "<a href=\"".$fl[$i]."\"><h2>".$fl[$i]."</h2></a>\n";
        
        print "<table border=\"1\">\n";
        
        print "<tr align =\"center\">\n    <td><b>Time</b></td>\n    <td><b>Monday</b></td>\n    <td><b>Tuesday</b></td>\n    <td><b>Wednesday</b></td>\n    <td><b>Thursday<b></td>\n    <td><b>Friday<b></td>\n</tr>\n";
        
        for (my $i = 8; $i < 21; $i++) {
            print "<tr align =\"center\">\n";
            print "    <td><b>$i\:00<b></ti>\n";
            
            foreach my $day (@daysOfWeek) {
                if (exists $week->{$day} && exists $week->{$day}->{"$i\:00"}){
                    if ($week->{$day}->{"$i\:00"}->{count} == 0) {
                            foreach my $course (keys %{$week->{$day}->{"$i\:00"}}) {
                                next if ($course eq 'count');
                                print "    <td bgcolor=\"".$colorArray[$colorHash{$course}]."\">";
                                print "$course<br>";
                                foreach my $key (keys %{$week->{$day}->{"$i\:00"}->{$course}}) {
                                    print $key.' '.$week->{$day}->{"$i\:00"}->{$course}->{$key};
                                }
                            }
                        print "</td>\n";
                    } else {
                        print "    <td bgcolor=\"red\"><font color=\"white\">";
                        
                        foreach my $course (keys %{$week->{$day}->{"$i\:00"}}) {
                                next if ($course eq 'count');
                                print "<u>$course</u><br>";
                                foreach my $key (keys %{$week->{$day}->{"$i\:00"}->{$course}}) {
                                    print $key.' '.$week->{$day}->{"$i\:00"}->{$course}->{$key}.'<br>';
                                }
                        }
                        
                        print "</font></td>\n";
                    }
                } else {
                    print "    <td></td>\n";
                }
            }
            
            print "<tr>\n";
        }
        
        print "</table>\n";
        
        
        print "<br>\n";
    }
    print "</ul>\n";
    print "</body>\n";
    print "</html>\n";
    close OUTPUT;
 }
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
