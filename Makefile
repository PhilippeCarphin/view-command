PREFIX ?= $(PWD)/localinstall

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
	$(INSTALL) -m 644 share/man/man1/whence.1 -D $(DESTDIR)$(PREFIX)/share/man/man1/whence.1

clean:
	rm -f share/man/man1/$(name).1
