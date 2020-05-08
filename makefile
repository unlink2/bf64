CC=lasm 
BIN=bf64.prg
LST=bf64.sym
MSN=bf64.mlb

BINDIR=./bin
MAIN = main.asm

# main

microbrain: | init
	$(CC) -o$(BINDIR)/$(BIN) -l${BINDIR}/${LST} -m${BINDIR}/${MSN} -msram $(MAIN) -wall

# other useful things

.PHONY: clean
clean:
	rm $(BINDIR)/*


.PHONY: setup
init:
	mkdir -p $(BINDIR)

