#############################################################################
#
#           Binaries we are going to build
#
#############################################################################
#
C_SO_NAME = libac.so
LUA_SO_NAME = ahocorasick.so

#############################################################################
#
#           Compile and link flags
#
#############################################################################

PREFIX = /usr/local
LUA_VERSION := 5.1
PREFIX = /usr/local
LUA_INCLUDE_DIR := $(PREFIX)/include/lua$(LUA_VERSION)
SO_TARGET_DIR := $(PREFIX)/lib/lua/$(LUA_VERSION)
LUA_TARGET_DIR := $(PREFIX)/share/lua/$(LUA_VERSION)

# Available directives:
# -DDEBUG : Turn on debugging support
# -DVERIFY : To verify if the slow-version and fast-version implementations
#            get exactly the same result. Note -DVERIFY implies -DDEBUG.
#
CFLAGS = -msse2 -msse3 -msse4.1 -O3 #-g -DVERIFY
COMMON_FLAGS = -fvisibility=hidden -Wall $(CFLAGS) $(MY_CFLAGS) $(MY_CXXFLAGS)

SO_CXXFLAGS = $(COMMON_FLAGS) -fPIC
NON_SO_CXXFLAGS = $(COMMON_FLAGS)
SO_LFLAGS = $(COMMON_FLAGS)
NON_SO_FLAGS = $(COMMON_FLAGS)

# -DVERIFY implies -DDEBUG
ifneq ($(findstring -DVERIFY, $(COMMON_FLAGS)), )
ifeq ($(findstring -DDEBUG, $(COMMON_FLAGS)), )
    COMMON_FLAGS += -DDEBUG
endif
endif

#############################################################################
#
#           Make rules
#
#############################################################################
#
.PHONY = all clean test benchmark
all : $(C_SO_NAME) $(LUA_SO_NAME)
	-cat *.d > dep.txt

-include dep.txt

COMMON_CXX_SRC = ac_fast.cxx ac_slow.cxx
C_SO_CXX_SRC = ac.cxx
LUA_SO_CXX_SRC = ac_lua.cxx

COMMON_OBJ = ${COMMON_CXX_SRC:.cxx=.o}
C_SO_OBJ = ${C_SO_CXX_SRC:.cxx=.o}
LUA_SO_OBJ = ${LUA_SO_CXX_SRC:.cxx=.o}

# Static-Pattern-Rules for the objects comprising the shared objects.
$(COMMON_OBJ) $(C_SO_OBJ) : %.o : %.cxx
	$(CXX) $< -c $(SO_CXXFLAGS) -MMD

# Static-Pattern-Rules for aho-corasick.so's interface object files, which
# need to call LUA C-API.
$(LUA_SO_OBJ) : %.o : %.cxx
	$(CXX) $< -c $(SO_CXXFLAGS) -I$(LUA_INCLUDE_DIR) -MMD

# Build libac.so
$(C_SO_NAME) : $(COMMON_OBJ) $(C_SO_OBJ)
	$(CXX) $+ -shared -Wl,-soname=$(C_SO_NAME) $(SO_LFLAGS) -o $@

# Build aho-corasick.so
$(LUA_SO_NAME) : $(COMMON_OBJ) $(LUA_SO_OBJ)
	$(CXX) $+ -shared -Wl,-soname=$(LUA_SO_NAME) $(SO_LFLAGS) -o $@

test : $(C_SO_NAME)
	$(MAKE) -C tests && \
	luajit tests/lua_test.lua && \
	luajit tests/load_ac_test.lua

benchmark: $(C_SO_NAME)
	$(MAKE) benchmark -C tests

#############################################################################
#
#           Misc
#
#############################################################################
#
clean :
	-rm -f *.o *.d dep.txt $(TEST) $(C_SO_NAME) $(LUA_SO_NAME) $(TEST)
	make clean -C tests

install:
	install -D -m 755 $(C_SO_NAME) $(DESTDIR)/$(SO_TARGET_DIR)/$(C_SO_NAME)
	install -D -m 755 $(LUA_SO_NAME) $(DESTDIR)/$(SO_TARGET_DIR)/$(LUA_SO_NAME)
	install -D -m 664 load_ac.lua $(DESTDIR)/$(LUA_TARGET_DIR)/load_ac.lua
