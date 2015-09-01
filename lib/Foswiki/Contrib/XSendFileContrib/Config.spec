# ---+ Extensions
# ---++ XSendFileContrib
# **PERL HIDDEN**
# This setting is required to enable executing the xsendfile service from the bin directory
$Foswiki::cfg{SwitchBoard}{xsendfile} = ['Foswiki::Contrib::XSendFileContrib', 'xsendfile', {xsendfile => 1}];

# **SELECT none,X-Sendfile,X-LIGHTTPD-send-file,X-Accel-Redirect**
# Enable efficient delivery of static files 
# using the xsendfile feature available in apache, nginx and lighttpd.
# Use <ul>
# <li>X-Sendfile for Apache2 </li>
# <li>X-LIGHTTPD-send-file for Lighttpd</li>
# <li>X-Accel-Redirect for Nginx</li>
# </ul>
# Note that you will need to configure your http server accordingly.
$Foswiki::cfg{XSendFileContrib}{Header} = 'none';

# **PATH**
# Location that the http server will process internally to send protected files.
# Leave it to {PubDir} for Lighttpd; use the <code>/protected_files</code> location
# as configured for an Nginx.
$Foswiki::cfg{XSendFileContrib}{Location} = '';

# **PERL**
# By default view rights of the topic are controlling the access rights to download
# all attachments on this topic. In some cases you might want to use <i>change</i>
# rights to protect attachments being downloaded, or assert special DOWNLOAD rights.
# This can be achieved using an array of {AccessRules} where each rule has got the
# format 
# <code>
# {
#   web => "regular expression",
#   topic => "regular expression",
#   file => "regular expression",
#   requiredAccess => "VIEW|CHANGE|DOWNLOAD|...",
# }
# </code>
# These rules will be tested in the given order whenever an attachment is requested.
# When one of the rules matches will the access rights required be checked.
# Normal VIEW access rights are apploed in case where none of the rules apply.
# As a special case a rule of the form requiredAccess => "" means that access is granted
# unconditionally.
$Foswiki::cfg{XSendFileContrib}{AccessRules} = [
  {
      web => "Sandbox",
      topic => "TestUpload",
      file => ".*\.pdf",

      requiredAccess => "CHANGE",
  },
  {

      file => "igp_.*\.[png|gif|jpe?g|bmp|tiff]",

      requiredAccess => "",
  },
];

1;
