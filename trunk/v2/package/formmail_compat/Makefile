#
# v2/package/formmail_compat/Makefile
#
# Makefile for the compatability FormMail package
#

NAME=formmail

MODULES=../../lib/CGI/NMS/Charset.pm         \
	../../lib/CGI/NMS/Validator.pm       \
	../../lib/CGI/NMS/Script.pm          \
	../../lib/CGI/NMS/Script/FormMail.pm \
	../../lib/CGI/NMS/Mailer.pm          \
	../../lib/CGI/NMS/Mailer/Sendmail.pm \
	../../lib/CGI/NMS/Mailer/SMTP.pm 

SOURCES=../../src/formmail/FormMail.pl       \
	../../src/formmail/README            \
	../../src/formmail/EXAMPLES          \
	../../buildtools/inline.pl           \
	../../buildtools/tarballs.pl         \
	Makefile $(MODULES)

PKGFILES=.pkg/README .pkg/EXAMPLES .pkg/FormMail.pl .pkg/ChangeLog

######################################################################

TARBALLS=../../.tarballs/$(NAME).tar.gz ../../.tarballs/$(NAME).zip

$(TARBALLS): ../../.tarballs $(PKGFILES) ../../buildtools/tarballs.pl
	../../buildtools/tarballs.pl ../../.tarballs $(NAME) $(PKGFILES)

.pkg/ChangeLog: .pkg $(SOURCES)
	../../buildtools/cvs2cl.pl --revisions -f .pkg/ChangeLog \
		$(SOURCES) 

.pkg/README: .pkg ../../src/formmail/README
	cp ../../src/formmail/README .pkg/

.pkg/EXAMPLES: .pkg ../../src/formmail/EXAMPLES
	cp ../../src/formmail/EXAMPLES .pkg/

.pkg/FormMail.pl: .pkg ../../src/formmail/FormMail.pl ../../buildtools/inline.pl $(MODULES)
	../../buildtools/inline.pl ../../lib ../../src/formmail/FormMail.pl .pkg/FormMail.pl

.pkg:
	mkdir -p .pkg

../../.tarballs:
	mkdir -p ../../.tarballs

clean:
	rm -rf .pkg ../../.tarballs/$(NAME).*

.PHONY: clean

