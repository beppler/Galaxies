.PHONY: all run test

ifeq ($(OS),Windows_NT)
FLAGS := -subsystem:windows
MKDIR := if not exist bin mkdir bin
else
MKDIR := mkdir -p bin
endif

all:
	@$(MKDIR)
	odin build src -out:bin/galaxies -o:speed $(FLAGS)

run: all
	./bin/galaxies

test:
	odin test src -out:bin/galaxies_test -define:ODIN_TEST_THREADS=1
