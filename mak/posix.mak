include mak/MANIFEST
MANIFEST:=$(subst \,/,$(MANIFEST))

include mak/DOCS
DOCS:=$(subst \,/,$(DOCS))

include mak/IMPORTS
IMPORTS:=$(subst \,/,$(IMPORTS))

include mak/COPY
COPY:=$(subst \,/,$(COPY))

include mak/SRCS
SRCS:=$(subst \,/,$(SRCS))
