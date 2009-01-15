# Makefile
# --------
# Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
# Licence   : BSD3
#
# This file is a part of obus, an ocaml implemtation of dbus.

OC = ocamlbuild
OF = ocamlfind

# Targets
SAMPLES = hello bus_functions eject notify monitor signals list_services \
	  ping pong progress_server progress_client
LIB = obus
BINDINGS = hal notification
TOOLS = obus_introspect obus_binder obus_dump
TEST = test_serialization test_printing test_communication valid auth server errors logging

.PHONY: all
all:
	$(OC) \
	  $(LIB:=.cma) $(LIB:=.cmxa) $(LIB:=.cmxs) \
	  $(BINDINGS:=.cma) $(BINDINGS:=.cmxa) $(BINDINGS:=.cmxs) \
	  $(TOOLS:%=tools/%.byte) $(TOOLS:%=tools/%.native) \
	  $(SAMPLES:%=samples/%.byte) $(SAMPLES:%=samples/%.native) \
	  obus.docdir/index.html META

.PHONY: dist
dist:
	DARCS_REPO=$(PWD) darcs dist --dist-name obus-`head -n 1 VERSION`

.PHONY: clean
clean:
	$(OC) -clean

# List all needed packages
.PHONY: list-deps
list-deps:
	@grep -o 'pkg_[^ ,]*' _tags | cut -c 5- | sort | uniq

# +------------------+
# | Specific targets |
# +------------------+

.PHONY: lib-byte
lib-byte:
	$(OC) $(LIB:=.cma)

.PHONY: lib-native
lib-native:
	$(OC) $(LIB:=.cmxa)

.PHONY: lib-shared
lib-shared:
	$(OC) $(LIB:=.cmxs)

.PHONY: lib
lib:
	$(OC) $(LIB:=.cma) $(LIB:=.cmxa) $(LIB:=.cmxs)

.PHONY: bindings-byte
bindings-byte:
	$(OC) $(BINDINGS:=.cma)

.PHONY: bindings-native
bindings-native:
	$(OC) $(BINDINGS:=.cmxa)

.PHONY: bindings-shared
bindings-shared:
	$(OC) $(BINDINGS:=.cmxs)

.PHONY: bindings
bindings:
	$(OC) $(BINDINGS:=.cma) $(BINDINGS:=.cmxa) $(BINDINGS:=.cmxs)

.PHONY: samples-byte
samples-byte:
	$(OC) $(SAMPLES:%=samples/%.byte)

.PHONY: samples-native
samples-native:
	$(OC) $(SAMPLES:%=samples/%.native)

.PHONY: samples
samples:
	$(OC) $(SAMPLES:%=samples/%.byte) $(SAMPLES:%=samples/%.native)

.PHONY: tools-byte
tools-byte:
	$(OC) $(TOOLS:%=tools/%.byte)

.PHONY: tools-native
tools-native:
	$(OC) $(TOOLS:%=tools/%.native)

.PHONY: tools
tools:
	$(OC) $(TOOLS:%=tools/%.byte) $(TOOLS:%=tools/%.native)

.PHONY: test
test:
	$(OC) $(TEST:%=test/%.d.byte)

.PHONY: test-syntax
test-syntax:
	$(OC) syntax/pa_obus.ml
	camlp4o _build/syntax/pa_obus.cmo test/syntax_extension.ml

# +---------------+
# | Documentation |
# +---------------+

doc:
	$(OC) obus.docdir/index.html

dot:
	$(OC) obus.docdir/index.dot

# +--------------------+
# | Installation stuff |
# +--------------------+

.PHONY: prefix
prefix:
	@if [ -z "$(PREFIX)" ]; then \
	  echo "please define PREFIX"; \
	  exit 1; \
	fi

.PHONY: install
install: prefix
	$(OF) install obus _build/META \
	 _build/syntax/pa_obus.cmo \
	 $(LIB:%=%/*.mli) \
	 $(LIB:%=_build/%/*.cmi) \
	 $(LIB:%=_build/%.cma) \
	 $(LIB:%=_build/%.cmxa) \
	 $(LIB:%=_build/%.cmxs) \
	 $(LIB:%=_build/%.a) \
	 $(BINDINGS:%=bindings/%/*.mli) \
	 $(BINDINGS:%=_build/bindings/%/*.cmi) \
	 $(BINDINGS:%=_build/%.cma) \
	 $(BINDINGS:%=_build/%.cmxa) \
	 $(BINDINGS:%=_build/%.cmxs) \
	 $(BINDINGS:%=_build/%.a)
	for tool in $(TOOLS); do \
	  install -vm 0755 _build/tools/$$tool.native $(PREFIX)/bin/`echo $$tool|sed s/_/-/`; \
	done
	mkdir -p $(PREFIX)/share/doc/obus/samples
	mkdir -p $(PREFIX)/share/doc/obus/html
	mkdir -p $(PREFIX)/share/doc/obus/scripts
	install -vm 0644 LICENSE $(PREFIX)/share/doc/obus
	install -vm 0644 _build/obus.docdir/* $(PREFIX)/share/doc/obus/html
	install -vm 0644 samples/*.ml $(PREFIX)/share/doc/obus/samples
	install -vm 0755 utils/scripts/* $(PREFIX)/share/doc/obus/scripts

.PHONY: uninstall
uninstall: prefix
	$(OF) remove obus
	rm -vf $(TOOLS:%=$(PREFIX)/bin/%)
	rm -rvf $(PREFIX)/share/doc/obus
