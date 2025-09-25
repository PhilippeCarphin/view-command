PREFIX ?= $(PWD)/localinstall

name = vc

share/man/man1/%.1:share/man/man1/%.org
	pandoc -s -f org -t man $^ -o $@

install: share/man/man1/$(name).1
	ginstall -m 644 etc/profile.d/$(name).bash -D $(DESTDIR)$(PREFIX)/etc/profile.d/$(name).bash
	ginstall -m 644 etc/profile.d/$(name).zsh -D $(DESTDIR)$(PREFIX)/etc/profile.d/$(name).zsh
	ginstall -m 644 share/man/man1/$(name).1 -D $(DESTDIR)$(PREFIX)/share/man/man1/$(name).1
	ginstall -m 644 share/man/man1/whence.1 -D $(DESTDIR)$(PREFIX)/share/man/man1/whence.1

clean:
	rm -f share/man/man1/$(name).1
