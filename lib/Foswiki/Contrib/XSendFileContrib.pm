# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2013-2014 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Contrib::XSendFileContrib;

use strict;
use warnings;
use Encode ();
use Foswiki::Sandbox ();
use Foswiki::Func ();
use Foswiki::Time ();
use File::MMagic ();

our $VERSION = '3.05';
our $RELEASE = '3.05';
our $SHORTDESCRIPTION = 'A viewfile replacement to send static files efficiently';
our $mimeTypeInfo;
our $mmagic;

sub xsendfile {

  my $session = shift;
  my $request = $session->{request};
  my $response = $session->{response};

  my $web = $session->{webName};
  my $topic = $session->{topicName};
  my $fileName = $request->param('filename');
  my $dispositionMode = $request->param('mode') || 'inline'; 

  unless (defined $fileName) {
    my $pathInfo = $request->path_info();
    my @path = split(/\/+/, $pathInfo);
    shift(@path) unless $path[0];

    # work out the web, topic and filename
    my @web;
    my $pel = Foswiki::Sandbox::untaint($path[0], \&Foswiki::Sandbox::validateWebName);

    while ($pel && Foswiki::Func::webExists(join('/', @web, $pel))) {
      push(@web, $pel);
      shift(@path);
      $pel = Foswiki::Sandbox::untaint($path[0], \&Foswiki::Sandbox::validateWebName);
    }

    $web = join('/', @web);
    unless ($web) {
      $response->status(404);
      $response->print("404 - no web found\n");
      return;
    }

    # Must set the web name, otherwise plugins may barf if
    # they try to manipulate the topic context when an oops is generated.
    $session->{webName} = $web;

    # The next element on the path has to be the topic name
    $topic = Foswiki::Sandbox::untaint(shift(@path), \&Foswiki::Sandbox::validateTopicName);

    unless ($topic) {
      $response->status(404);
      $response->print("404 - no topic found\n");
      return;
    }

    # See comment about webName above
    $session->{topicName} = $topic;

    # What's left in the path is the attachment name.
    $fileName = join('/', @path);
  }

  # not found
  if (!defined($fileName) || $fileName eq '') {
    $response->status(404);
    $response->print("404 - no file found\n");
    return;
  }

  #print STDERR "web=$web, topic=$topic, fileName=$fileName\n";

  $fileName = Foswiki::urlDecode($fileName);
  $fileName = Encode::decode_utf8($fileName);
  #$fileName = Foswiki::Sandbox::untaint($fileName, \&Foswiki::Sandbox::validateAttachmentName);
  $fileName = sanitizeAttachmentName($fileName);;

  # invalid 
  unless (defined $fileName) {
    $response->status(404);
    $response->print("404 - file not valid\n");
    return;
  }

  my $topicObject = Foswiki::Meta->new($session, $web, $topic);

  # not found
  unless ($topicObject->existsInStore()) {
    $response->status(404);
    $response->print("404 - topic $web.$topic does not exist\n");
    return;
  }

  # not found
  
  unless ($topicObject->hasAttachment($fileName)) {
    $response->status(404);
    $response->print("404 - attachment $fileName not found at $web.$topic\n");
    return;
  }

  # unauthorized
  unless (checkAccess($topicObject, $fileName, $session->{user})) {
    $response->status(401);
    $response->print("401 - access denied\n");
    return;
  }

  # construct file path to protected location
  my $location = $Foswiki::cfg{XSendFileContrib}{Location} || $Foswiki::cfg{PubDir};
  my $fileLocation = $location.'/'.$web.'/'.$topic.'/'.$fileName;
  my $filePath = $Foswiki::cfg{PubDir}.'/'.$web.'/'.$topic.'/'.$fileName;
  my @stat = stat($filePath);
  my $lastModified = Foswiki::Time::formatTime($stat[9] || $stat[10] || 0, '$http', 'gmtime');
  my $ifModifiedSince = $request->header('If-Modified-Since') || '';

  my $headerName = $Foswiki::cfg{XSendFileContrib}{Header} || 'X-LIGHTTPD-send-file';

  $fileName = Encode::encode_utf8($fileName);
  $fileLocation = Encode::encode_utf8($fileLocation);

  if ($lastModified eq $ifModifiedSince) {
    $response->header(
      -status => 304,
    );
  } else {
    $response->header(
      -status => 200,
      -type => mimeTypeOfFile($filePath),
      -content_disposition => "$dispositionMode; filename=\"$fileName\"",
      -last_modified => $lastModified,
      $headerName => $fileLocation,
    );
  }

  #  $response->print("OK");

  return;
}

sub checkAccess {
  my ($topicObject, $fileName, $user) = @_;

  if (defined $Foswiki::cfg{XSendFileContrib}{AccessRules}) {
    my $web = $topicObject->web;
    my $topic = $topicObject->topic;
    foreach my $rule (@{$Foswiki::cfg{XSendFileContrib}{AccessRules}}) {
      #print STDERR "rule: web=$rule->{web}, topic=$rule->{topic}, file=$rule->{file}, requiredAccess=$rule->{requiredAccess}\n";
      if ((!defined($rule->{web}) || $web =~ /^$rule->{web}$/) &&
          (!defined($rule->{topic}) || $topic =~ /^$rule->{topic}$/) &&
          (!defined($rule->{file}) || $fileName =~ /^$rule->{file}$/)) {

        return 1 if !defined($rule->{requiredAccess}) || $rule->{requiredAccess} eq "";
        return $topicObject->haveAccess($rule->{requiredAccess}, $user);
      }
    }
  } 

  # fallback
  return $topicObject->haveAccess("VIEW", $user);
}

sub mimeTypeOfFile {
  my $fileName = shift;

  if ($fileName && $fileName =~ /\.([^.]+)$/) {
    my $suffix = $1;

    $mimeTypeInfo = Foswiki::Func::readFile($Foswiki::cfg{MimeTypesFileName}) 
      unless defined $mimeTypeInfo;

    if ($mimeTypeInfo =~ /^([^#]\S*).*?\s$suffix(?:\s|$)/im) {
      return $1;
    }
  }

  $mmagic = File::MMagic->new() unless defined $mmagic;

  my $mimeType = $mmagic->checktype_filename($fileName);

  if (defined $mimeType && $mimeType ne "x-system/x-error") {
    #print STDERR "mmagic says $mimeType to $fileName\n";
    return $mimeType;
  }

  #print STDERR "unknown mime type of $fileName\n";

  return 'application/octet-stream';
}

sub sanitizeAttachmentName {
  my $fileName = shift;

  $fileName =~ s{[\\/]+$}{};    # Get rid of trailing slash/backslash (unlikely)
  $fileName =~ s!^.*[\\/]!!;    # Get rid of leading directory components
  $fileName =~ s/[\*?~^\$@%`"'&;|<>\[\]#\x00-\x1f\(\)]//g; # Get rid of a subset of Namefilter

  return Foswiki::Sandbox::untaintUnchecked($fileName);
}

1;
