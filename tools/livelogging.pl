#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use AnyEvent::WebSocket::Client;
use POSIX qw(strftime);

if ($#ARGV != 1) {
	die("Cannot be used stand-alone $#ARGV");
}

$| = 0;

my $host = $ARGV[0];
my $client = AnyEvent::WebSocket::Client->new;
my $ws = $client->connect($host)->recv;
my $timestamp = 0;
my $lasttime = 0;

$ws->on(each_message => sub {
	my $msg = pop->decoded_body;
	# Ignore register
	if (substr($msg, 0, 9) eq "register ") {
		printf "Live Logging started @ %s\n", (strftime "%a %b %e, %H:%M:%S %Y", localtime);
		$lasttime = $timestamp = time();
	} elsif ($msg eq "echo") {
		printf "----- | ALIVE | %-25.25s | ----- |\n", "KeepAlive Ping-Pong";
	} elsif (substr($msg, 0, 1) eq "{") {
		my $t = time();
		my $delta = $t - $lasttime;
		my $offset = $t - $timestamp;
		$lasttime = $t;

		my $data = decode_json($msg);
		if ($data->{'logs'}) {
			my $prefix = sprintf "%5d | ", $offset;
			if ($data->{'target'}->{'type'} eq 'InstalledSmartApp') {
				$prefix .= "  APP | ";
			} elsif ($data->{'target'}->{'type'} eq 'Device') {
				$prefix .= "  DEV | ";
			} else {
				$prefix .= $data->{'target'}->{'type'};
			}
			$prefix .= sprintf "%-25.25s", $data->{'target'}->{'label'};
			printLogArray( $prefix, $data->{'logs'});
		} elsif ( $data->{'event'} ) {
			printf "%5d | EVENT | Source: %-17.17s | ----- | %s\n", $offset, $data->{'event'}->{"eventSource"}, $data->{'event'}->{"value"};
		} else {
			print $msg . "\n";
		}
	}
});

my $timer = AnyEvent->timer(after => 3, interval => 30, cb => sub { $ws->send('ping'); });
AnyEvent->condvar->recv;

sub printLogArray {
	my ($prefix, $data) = @_;
	foreach ( @$data ) {
		my $line = $_;
		printf "%s | %-5.5s | %s\n", $prefix, $line->{'level'}, $line->{'msg'};
	}
}