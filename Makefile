.SUFFIXES:

SOURCES=$(wildcard *.swift)

TARGETS=gameoflife

all: $(TARGETS)
clean:
	rm -rf $(TARGETS)

gameoflife: $(SOURCES)
	swiftc -import-objc-header defs.h $^ -o $@
