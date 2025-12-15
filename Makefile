# This Makefile uses ocamlbuild but does not rely on ocamlfind or the Opam
# package manager to build.
#
# See README.me for instructions.


# Configuration

NAME =		waml
EXT =		$(NAME)
UNOPT =		$(NAME).debug
OPT =		$(NAME)
RUNTIME =	$(NAME)-runtime

WASMLINK =	wln
WASMLINK_BIN =	scripts/wln-link

DIRS =		src
PKGS =		wasm unix
FLAGS = 	-lexflags -ml -cflags '-w +a-4-27-37-42-44-45-70 -warn-error +a-3'
OCB =		ocamlbuild -use-ocamlfind -no-hygiene -verbose 8 $(FLAGS) $(DIRS:%=-I %) $(PKGS:%=-pkg %)

NODE =		node --experimental-wasm-gc
WASM_BIN ?=	vendor/spec/interpreter/wasm


# Main targets

.PHONY:		default debug opt unopt interpreter

default:	opt
debug:		unopt
opt:		$(OPT)
unopt:		$(UNOPT)
interpreter:	$(WASM_BIN)
all:		unopt opt interpreter test


# Vendor dependencies

$(WASM_BIN):
	mkdir -p vendor
	if [ ! -d "vendor/spec" ]; then \
		git clone https://github.com/WebAssembly/spec.git vendor/spec; \
	fi
	$(MAKE) -C vendor/spec/interpreter


# Building linker

.PHONY:	$(WASMLINK)

$(WASMLINK):
		@true


# Building executable

.INTERMEDIATE:	_tags
_tags:
		echo >$@ "true: bin_annot"
		echo >>$@ "true: debug"

$(UNOPT): main.byte
		mv $< $@

$(OPT):		main.native
		mv $< $@

.PHONY:		main.byte main.native
main.byte: _tags
	$(OCB) -quiet $@

main.native: _tags
	$(OCB) -quiet $@


# Executing test suite

TESTDIR =	test
TESTFILES =	$(shell cd $(TESTDIR); ls *.$(EXT))
LINKFILES =	$(shell cd $(TESTDIR); ls *.$(WASMLINK))
TESTS =		$(TESTFILES:%.$(EXT)=%)

.PHONY:		test runtimetest evaltest debugtest wasmtest wasmntest nodetest linktest

test:	runtimetest evaltest wasmtest wasmntest linktest # nodetest

evaltest:		titletest/Test-eval $(TESTFILES:%.$(EXT)=evaltest/%)
debugtest:	titletest/Test-debug $(TESTFILES:%.$(EXT)=debugtest/%)
wasmtest:		cleantest titletest/Test-wasm $(TESTFILES:%.$(EXT)=wasmtest/%)
		@make cleantest
wasmntest:		cleantest titletest/Test-wasm-headless $(TESTFILES:%.$(EXT)=wasmntest/%)
		@make cleantest
nodetest:		cleantest titletest/Test-node $(RUNTIME).wasm $(TESTFILES:%.$(EXT)=nodetest/%)
		@make cleantest
linktest:		titletest/Test-link $(LINKFILES:%.$(WASMLINK)=linktest/%)
		@make cleantest

titletest/%:	$(OPT)
		@echo ==== $(@F) ====

evaltest/%:		$(OPT)
		@file=$(TESTDIR)/$(@F).$(EXT); \
		flags="$(shell grep "@FLAGS" $(TESTDIR)/$(@F).$(EXT) | sed 's/.*@FLAGS//g')"; \
		echo -n '$(@F).$(EXT)> '; \
		if grep -q "@FAIL-TYPECHECK" $$file; then \
		  if ./$(NAME) -r $$flags $$file; then \
		    echo " ** expected type error"; exit 1; \
		  fi; \
		else \
		  ./$(NAME) -r $$flags $$file; \
		fi

debugtest/%:	$(UNOPT)
		@file=$(TESTDIR)/$(@F).$(EXT); \
		flags="$(shell grep "@FLAGS" $(TESTDIR)/$(@F).$(EXT) | sed 's/.*@FLAGS//g')"; \
		echo -n '$(@F).$(EXT)> '; \
		if grep -q "@FAIL-TYPECHECK" $$file; then \
		  if ./$(NAME) -r $$flags $$file; then \
		    echo " ** expected type error"; exit 1; \
		  fi; \
		else \
		  ./$(NAME) -r $$flags $$file; \
		fi

runtimetest:	$(OPT) titletest/Test-runtime
		@./$(NAME) -v -g $(TESTDIR)/$(RUNTIME).wasm -g $(TESTDIR)/$(RUNTIME).wat
		@make cleantest

wasmtest/%:		$(OPT)
	  @ if ! grep -q "@FAIL-WASM\|@FAIL-TYPECHECK" $(TESTDIR)/$(@F).$(EXT); \
		  then \
		    /bin/echo -n '$(@F).$(EXT)> '; \
		    ./$(NAME) -r -c -v $(shell grep "@FLAGS" $(TESTDIR)/$(@F).$(EXT) | sed 's/.*@FLAGS//g') $(TESTDIR)/$(@F).$(EXT); \
		  else echo '**' Skipping $(@F).$(EXT); \
		fi

wasmntest/%:	$(OPT)
	  @ if ! grep -q "@FAIL-WASM\|@FAIL-TYPECHECK" $(TESTDIR)/$(@F).$(EXT); \
		  then \
		    /bin/echo -n '$(@F).$(EXT)> '; \
		    ./$(NAME) -r -c -v -n $(shell grep "@FLAGS" $(TESTDIR)/$(@F).$(EXT) | sed 's/.*@FLAGS//g') $(TESTDIR)/$(@F).$(EXT); \
		  else echo '**' Skipping $(@F).$(EXT); \
		fi

nodetest/%:		$(OPT)
		@ if ! grep -q "@FAIL-WASM\|@FAIL-V8\|@FAIL-TYPECHECK" $(TESTDIR)/$(@F).$(EXT); \
		  then \
		    echo $(@F).$(EXT); \
		    ./$(NAME) -c -v $(shell grep "@FLAGS" $(TESTDIR)/$(@F).$(EXT) | sed 's/.*@FLAGS//g') $(TESTDIR)/$(@F).$(EXT); \
		    $(NODE) js/$(NAME).js $(TESTDIR)/$(@F); \
		  else echo '**' Skipping $(@F).$(EXT); \
		fi

linktest/%:		$(WASMLINK) $(RUNTIME).wasm
		@ if ! grep -q "@FAIL-LINK" $(TESTDIR)/$(@F).$(WASMLINK); \
		  then \
		    echo $(@F).$(WASMLINK); \
		    inputs="$(RUNTIME).wasm"; \
		    for file in $$(cat $(TESTDIR)/$(@F).$(WASMLINK)); do \
		      ./$(NAME) -c -v $$file.$(EXT); \
		      inputs="$$inputs $$file.wasm"; \
		    done; \
		    output=$(TESTDIR)/$(@F).wast; \
		    $(WASMLINK_BIN) $$inputs -o $$output; \
		    $(WASM_BIN) -i $$output; \
		  else echo '**' Skipping $(@F).$(WASMLINK); \
		fi; \
		# $(NODE) js/$(NAME).js $(TESTDIR)/$(@F)

$(RUNTIME).wasm:	$(OPT)
		@./$(NAME) -g $@


# Miscellaneous targets

.PHONY:		clean

clean: cleantest
	rm -rf $(RUNTIME).wasm _tags
	$(OCB) -clean

cleantest:
	rm -f test/*.wasm test/*.wat test/*.wast
