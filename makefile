CC=lasm 
BIN=main.prg
LST=main.sym
MSN=main.mlb

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

