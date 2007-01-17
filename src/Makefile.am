# Makefile.am for slepos-image-builder/src

yncludedir = @yncludedir@/slepos-image-builder

client_DATA =				\
	slepos-image-builder.ycp		\
	slepos-image-builder_auto.ycp	\
	slepos-image-builder_proposal.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	subwizards.ycp		\
	subdialogs.ycp		\
	complex.ycp		\
	uifunctions.ycp		\
	routines.ycp

desktop_DATA =			\
	slepos-image-builder.desktop

module_DATA =			\
	SleposImageBuilder.ycp	\
	SleposImageBuilderXml.pm

YCPCFLAGS = -I.

ycpchook = slepos-image-builder

slepos-image-builder:
	ln -s . slepos-image-builder

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
