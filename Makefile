PREFIX ?= $(PWD)/localinstall
this_makefile_dir = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifeq ($(shell uname),Darwin)
	INSTALL=ginstall
else
	INSTALL=install
endif

name = vc

share/man/man1/%.1:share/man/man1/%.org
	pandoc -s -f org -t man $^ -o $@

install: share/man/man1/$(name).1
	$(INSTALL) -m 644 etc/profile.d/$(name).bash -D $(DESTDIR)$(PREFIX)/etc/profile.d/$(name).bash
	$(INSTALL) -m 644 etc/profile.d/$(name).zsh -D $(DESTDIR)$(PREFIX)/etc/profile.d/$(name).zsh
	$(INSTALL) -m 644 share/man/man1/$(name).1 -D $(DESTDIR)$(PREFIX)/share/man/man1/$(name).1

install-dev: share/man/man1/$(name).1
	install -d $(DESTDIR)$(PREFIX)/etc/profile.d
	install -d $(DESTDIR)$(PREFIX)/share/man/man1
	ln -snf $(this_makefile_dir)etc/profile.d/vc.bash $(DESTDIR)$(PREFIX)/etc/profile.d/vc.bash
	ln -snf $(this_makefile_dir)etc/profile.d/vc.zsh $(DESTDIR)$(PREFIX)/etc/profile.d/vc.zsh
	ln -snf $(this_makefile_dir)share/man/man1/vc.1 $(DESTDIR)$(PREFIX)/share/man/man1/vc.1

vars:
	@env | grep ^MAKE
	@echo "MAKEFILE_LIST: $(MAKEFILE_LIST)"
	@echo "this_makefile_dir: $(this_makefile_dir)"
clean:
	rm -f share/man/man1/$(name).1
