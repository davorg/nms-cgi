#
# v2/package/formmail_compat/Makefile
#
# Makefile for the compatability FormMail package
#

NAME = formmail_compat

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
	      buildtools/cl2ver                       \
	      $(MODULES:%=lib/%)

PKGFILES = README EXAMPLES FormMail.pl ChangeLog MANIFEST

######################################################################

include ../../buildtools/package.mak

.pkg/FormMail.pl: ../../src/formmail/FormMail.pl ../../buildtools/inline $(MODULES:%=../../lib/%) .pkg/VERSION
	../../buildtools/inline ../../lib ../../src/formmail/FormMail.pl >.pkg/FormMail.pl.in
	../../buildtools/template .pkg/FormMail.pl.in >$@
	rm .pkg/FormMail.pl.in
	chmod 755 $@

.pkg/README: ../../src/formmail/README README.manifest README.install .pkg/VERSION
	../../buildtools/template ../../src/formmail/README >$@

.pkg/EXAMPLES: .pkg ../../src/formmail/EXAMPLES
	cp ../../src/formmail/EXAMPLES .pkg/

