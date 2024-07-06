# Always run with nproc jobs by default. Can be overridden by the user.
MAKEFLAGS := --jobs=$(shell nproc)

# Comment out the below line if you want to be quiet by default.
VERBOSE ?= 1
ifeq ($(V),1)
E=@true
Q=
else
E=@echo
Q=@
MAKEFLAGS += -s
endif

SRCS := $(shell egrep '^.*\.v$$' _CoqProject | grep -v '^#')
AUXS := $(join $(dir $(SRCS)), $(addprefix ., $(notdir $(SRCS:.v=.aux))))

MONAD ?= solved
PROG ?= church

.PHONY: coq clean extract install uninstall pretty-timed make-pretty-timed-before make-pretty-timed-after print-pretty-timed-diff

coq: Makefile.coq
	$(E) "MAKE Makefile.coq"
	$(Q)$(MAKE) -f Makefile.coq

extract: coq
	$(Q)patch -Np1 -o src/Infer.hs -i Extract.patch

Makefile.coq: _CoqProject Makefile $(SRCS)
	$(E) "COQ_MAKEFILE Makefile.coq"
	$(Q)coq_makefile -f _CoqProject -o Makefile.coq

clean: Makefile.coq
	$(Q)$(MAKE) -f Makefile.coq clean
	$(Q)rm -f $(AUXS)
	$(Q)rm -f Makefile.coq *.bak *.d *~ result* Extract.hs src/Infer.hs
	$(Q)find theories \( -name "*.vo" -o -name "*.vo[sk]" \
		-o -name ".*.aux" -o -name ".*.cache" -o -name "*.glob" \) -delete

install uninstall pretty-timed make-pretty-timed-before make-pretty-timed-after print-pretty-timed-diff: Makefile.coq
	$(Q)$(MAKE) -f Makefile.coq $@

haskell-build: extract
	$(E) "Compiling Haskell implementation with Cabal"
	$(Q)cabal build

bench: haskell-build
	$(E) "Running ${PROG} benchmark on ${MONAD} monad with hyperfine"
	$(Q)hyperfine --warmup 3 --export-markdown bench/${PROG}.md -L num 10,100,1000,10000,100000,1000000 'cabal run em -- --${MONAD} examples/${PROG}-{num}.stlcb'

