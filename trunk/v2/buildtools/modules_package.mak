####################################################################
#
# v2/buildtools/modules_package.mak
#
# Makefile component for a package with the modules supplied as 
# individual files to be uploaded by hand.
#
# Imports from parent Makefile:
#
# NAME
#     package name, e.g. "formmail_modules".
#
# MODULES
#     A list of the modules to go in the package, paths relative
#     to /v2/lib in the CVS tree.
#
# SOURCE_FILES
#     A list of the files on which the package contents depend,
#     paths relative to /v2 in the CVS tree.
#
# PKGFILES
#     A list of the files to go in the package, relative to the
#     root directory of the package archive.
#

include ../../buildtools/package.mak

.pkg/lib/CGI/NMS/Charset.pm: ../../lib/CGI/NMS/Charset.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Charset.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Validator.pm: ../../lib/CGI/NMS/Validator.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Validator.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Script.pm: ../../lib/CGI/NMS/Script.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Script.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Script/FormMail.pm: ../../lib/CGI/NMS/Script/FormMail.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Script/FormMail.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer.pm: ../../lib/CGI/NMS/Mailer.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer/Sendmail.pm: ../../lib/CGI/NMS/Mailer/Sendmail.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer/Sendmail.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer/SMTP.pm: ../../lib/CGI/NMS/Mailer/SMTP.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer/SMTP.pm) | (cd .pkg && tar xf -)

