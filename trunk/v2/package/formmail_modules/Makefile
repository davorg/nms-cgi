###############################################################################
#
# v2/package/formmail_modules/Makefile
#
# Makefile for the FormMail package with seperate modules
#

NAME = formmail_modules

MODULES = \
	CGI/NMS/Charset.pm         \
	CGI/NMS/Validator.pm       \
	CGI/NMS/Script.pm          \
	CGI/NMS/Script/FormMail.pm \
	CGI/NMS/Mailer.pm          \
	CGI/NMS/Mailer/ByScheme.pm \
	CGI/NMS/Mailer/Sendmail.pm \
	CGI/NMS/Mailer/SMTP.pm

SOURCE_FILES = \
	src/formmail/FormMail.pl        \
	src/formmail/README             \
	src/formmail/EXAMPLES           \
	buildtools/tarballs             \
	package/$(NAME)/Makefile        \
	package/$(NAME)/README.install  \
	package/$(NAME)/README.manifest \
	$(MODULES:%=lib/%)

PKGFILES = FormMail.pl README EXAMPLES ChangeLog MANIFEST $(MODULES:%=lib/%)

include ../../buildtools/modules_package.mak

.pkg/FormMail.pl: .pkg ../../src/formmail/FormMail.pl
	cp ../../src/formmail/FormMail.pl .pkg/

.pkg/README: .pkg ../../src/formmail/README README.manifest README.install
	../../buildtools/template ../../src/formmail/README >$@

.pkg/EXAMPLES: .pkg ../../src/formmail/EXAMPLES
	cp ../../src/formmail/EXAMPLES .pkg/

