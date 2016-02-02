#!/bin/perl

#############################################################################
# (c) 2015
###
# Name: Network Health Check
# Written by: Hiko Davis, Principal Services Consultant, CA Technologies
###
# Description:
#   Monitors your array of servers/IPs by ping and socket tests
###
# Configuration:
#   Plug-in should be setup as a stateless plug-in with a min 60 sec interval.
#   Create a file (single entry per line) with hostnames or IPs and save to
#                                           the save location as this plug-in.
###
# Setup:
#   command: perl path-to-epa/epaplugins/HealthCheck/netcheck.pl path-to-epa/epaplugins/HealthCheck/datafile.txt
#   delayInSeconds: => 15, keeping in mind the number of servers and ports
#                                                               being tested.
##
# NOTE: Even for Windows users, please use "/" as separators.
# If there are spaces in the directory names, use the 8.3
# format by opening a command prompt and type 'dir /x' to
# see the truncated name.
# e.g. C:\Program Files becomes C:\Progra~1
# e.g. C:\Program Files (x86) becomes C:\Progra~2
#############################################################################
use FindBin;
use lib ("$FindBin::Bin", "$FindBin::Bin/lib/perl", "$FindBin::Bin/../lib/perl");
use Wily::PrintMetric;

use strict;

##### Do not modify the subroutines unless you know what you're doing! ###### 
sub doPing {
    # expects host or IP address as input
    for my $proto ( qw/ tcp /) {
        return !!1 if Net::Ping->new( $proto, 5 ) ->ping ( $_[0] );
    }
    return !!0;
}

sub doSocket {
    # expects 2 inputs IN ORDER
    # input#1- host or IP address
    # input#2- port to test
    use IO::Socket;
    my $sock = new IO::Socket::INET( PeerAddr => $_[0],
                                     PeerPort => $_[1],
                                     Proto    => 'tcp',
                                     );
    return 1 unless $sock; #return 1 for failed connection
    $sock->autoflush(1); #so the output gets there right away
    # test socket by sending zero length packet
    my $buff; my $flags=qw/MS_PEEK|MSG_NOWAIT/;
    my $ret = recv( $sock, $buff, 1, $flags );
    # close socket
    $sock->shutdown(0); #i have stopped reading data
    # return 0
    return 0;
}

sub printMetric {
# expects 5 input values IN ORDER to create the XML string
# Type- Metric type; refer to EPA guide for types available
# Resource- Metric node name for your metric
# Subresource- (optional) Node name created under Resource; must pass an
#  empty string if not used
# Name- Metric name
# Value- Metric value (to be converted to an integer)
    Wily::PrintMetric::printMetric( type        => '$_[0]',
                                    resource    => '$_[1]',
                                    subresource => '$_[2]',
                                    name        => '$_[3]',
                                    value       => int($_[4]),
                                    );  
}
########################## END OF SUBROUTINES ###############################


# Check to see if filename has been passed as input
die "ERROR: Filename argument is missing!" if ! $ARGV[0];

# Read in file which has the server/IPs & ports
my @testList = do { open my $fh, '<', $_[0]; <$fh>; };

# Skip first line of array
@testList = @testList[1..$#testList];

# Parse datafile results
foreach my $line (@testList) {
    chomp $line; #remove EOL char
    
    # split $line on space or tab, depending on how you create datafile.txt
    my @server = split(/[ \t]/, $line, 2);
    # remove any whitespace in port list
    $server[1] =~ s/\s//g;
    # split $server[1] to get port list
    my @ports = split(/,/, $server[1]);
    
    # call doPing to check server availability
    if (doPing($server[0]) == 0) {
        # test each port for server and report availability
        foreach my $port(@ports){
            if (doSocket($server[0], $port) == 0){
                # report success
                printMetric("IntCounter", "NetCheck", $server[0] . "|" . $port, "Status", 1);
            } else {
                # repot failure
                printMetric("IntCounter", "NetCheck", $server[0] . "|" . $port, "Status", 0);
            }
        }
        
        # report ping status
        printMetric("IntCounter", "NetCheck", $server[0], "Availability", 1);
    } else {
        # call printMetric and report ping failure
        printMetric("IntCounter", "NetCheck", $server[0], "Availability", 0);
    }

}
