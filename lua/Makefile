ROOT			= /Users/vova/ports
CFLAGS			= -I$(ROOT)/include -Wall -Werror -pedantic
LDFLAGS			= -L$(ROOT)/lib -shared -fpic
SRC 			= $(wildcard ./*.c)
OBJ				= $(SRC:.c=.o)
SO				= $(OBJ:.o=.so)
LUA				= luajit

default: $(SO)

test: $(SO)
	@$(LUA) test.lua

%.so: %.o
	@printf "    %s\n" "linking $@ ..."
	@$(CC) $(LDFLAGS) -lluajit-5.1.2 -o $@ $<

%.o: %.c
	@printf "cc  %s\n" $<
	@$(CC) $< -c -o $@ $(CFLAGS)

clean:
	@$(foreach c, $(OBJ), $(RM) -f $(c))

remove:
	$(RM) $(MODULE)