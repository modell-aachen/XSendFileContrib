# ---+ Extensions
# ---++ XSendFileContrib
# **PERL H**
# This setting is required to enable executing the xsendfile service from the bin directory
$Foswiki::cfg{SwitchBoard}{xsendfile} = ['Foswiki::Contrib::XSendFileContrib', 'xsendfile', {xsendfile => 1}];

# **SELECT none,X-Sendfile,X-LIGHTTPD-send-file,X-Accel-Redirect**
# Enable efficient delivery of static files 
# using the xsendfile feature available in apache, nginx and lighttpd.
# Use <ul>
# <li>X-Sendfile for Apache2 <li>
# <li>X-LIGHTTPD-send-file for Lighttpd<li>
# <li>X-Accel-Redirect for Nginx<li>
# </ul>
# Note that you will need to configure your http server accordingly.
$Foswiki::cfg{XSendFileContrib}{Header} = 'none';

# **PATH M**
# Location that the http server will process internally to send protected files.
# Leave it to {PubDir} for Lighttpd; use the <code>/protected_files</code> location
# as configured for an Nginx.
$Foswiki::cfg{XSendFileContrib}{location} = '';

1;
