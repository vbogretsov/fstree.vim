NAME			= posixfs
ROOT			= /Users/vova/ports
CFLAGS			= -I$(ROOT)/include -Wall -Werror -pedantic
LDFLAGS			= -L$(ROOT)/lib -shared -fpic
SRC 			= $(wildcard ./*.c)
OBJ				= $(SRC:.c=.o)
MODULE			= $(NAME).so

default: $(MODULE)

$(MODULE): $(OBJ)
	@printf "    %s\n" linking...
	@$(CC) $(LDFLAGS) -lluajit-5.1.2 -o $@ $(OBJ)
	@printf "    %s\n" done

%.o: %.c
	@printf "cc  %s\n" $<
	@$(CC) $< -c -o $@ $(CFLAGS)

clean:
	@$(foreach c, $(OBJ), $(RM) -f $(c))

remove:
	$(RM) $(MODULE)