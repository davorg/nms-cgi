#
# v2/package/formmail_compat/Makefile
#
# Makefile for the compatability FormMail package
#

NAME=formmail

MODULES=CGI/NMS/Charset.pm         \
	CGI/NMS/Validator.pm       \
	CGI/NMS/Script.pm          \
	CGI/NMS/Script/FormMail.pm \
	CGI/NMS/Mailer.pm          \
	CGI/NMS/Mailer/Sendmail.pm \
	CGI/NMS/Mailer/SMTP.pm 

SOURCE_FILES= src/formmail/FormMail.pl                \
	      src/formmail/README                     \
	      src/formmail/EXAMPLES                   \
	      package/formmail_compat/Makefile        \
	      package/formmail_compat/README.manifest \
	      package/formmail_compat/README.install  \
	      buildtools/inline                       \
	      buildtools/tarballs                     \
	      $(MODULES:%=lib/%)

PKGFILES = README EXAMPLES FormMail.pl ChangeLog MANIFEST

######################################################################

include ../../buildtools/package.mak

.pkg/FormMail.pl: .pkg ../../src/formmail/FormMail.pl ../../buildtools/inline $(MODULES:%=../../lib/%)
	../../buildtools/inline ../../lib ../../src/formmail/FormMail.pl >.pkg/FormMail.pl
	chmod 755 .pkg/FormMail.pl

.pkg/README: .pkg ../../src/formmail/README README.manifest README.install
	../../buildtools/template ../../src/formmail/README >$@

.pkg/EXAMPLES: .pkg ../../src/formmail/EXAMPLES
	cp ../../src/formmail/EXAMPLES .pkg/

