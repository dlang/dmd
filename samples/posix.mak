##
# Example Makefile for the D programming language
##
TARGETS= \
	d2html \
	dhry \
	hello \
	htmlget \
	listener \
	pi \
	sieve \
	wc \
	wc2

## Those examples are Windows specific:
#	chello
#	dserver
#	dclient
#	winsamp

SRC	= \
	chello.d \
	d2html.d \
	dclient.d \
	dhry.d \
	dserver.d \
	hello.d	\
	htmlget.d \
	listener.d \
	pi.d \
	sieve.d	\
	wc.d \
	wc2.d \
	winsamp.d
DFLAGS	=
LFLAGS	=


##
## Those values are immutables
## For languages such as C and C++, builtin rules are provided.
## But for D, you had to had to do everything by hand.
## Basically, if you had some Makefile knowledge, this is all you need.
##
## For explanation / more advanced use, see:
## http://www.gnu.org/software/make/manual/html_node/Suffix-Rules.html
.SUFFIXES: .d
.d.o:
	$(DMD) $(DFLAGS) -c $< -of$@
##

LINK	= dmd
DMD	= dmd
RM	= rm -rf
OBJS	= $(SRC:.d=.o)

all:	$(TARGETS)

clean:
	$(RM) $(OBJS)

fclean: clean
	$(RM) $(TARGETS)
	$(RM) *.d.htm

re: fclean all

chello: $(OBJS)
	$(LINK) $(LFLAGS) $(OBJS) -of$@

.PHONY: all clean fclean re
.NOTPARALLEL: clean

d2html: d2html.o
	$(LINK) $(LFLAGS) $< -of$@

dclient: dclient.o
	$(LINK) $(LFLAGS) $< -of$@

dhry: dhry.o
	$(LINK) $(LFLAGS) $< -of$@

dserver: dserver.o
	$(LINK) $(LFLAGS) $< -of$@

hello: hello.o
	$(LINK) $(LFLAGS) $< -of$@

htmlget: htmlget.o
	$(LINK) $(LFLAGS) $< -of$@

listener: listener.o
	$(LINK) $(LFLAGS) $< -of$@

pi:	pi.o
	$(LINK) $(LFLAGS) $< -of$@

sieve:	sieve.o
	$(LINK) $(LFLAGS) $< -of$@

wc2:	wc2.o
	$(LINK) $(LFLAGS) $< -of$@

wc:	wc.o
	$(LINK) $(LFLAGS) $< -of$@

winsamp: winsamp.o
	$(LINK) $(LFLAGS) $< -of$@
