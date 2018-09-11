#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <dirent.h>

#include <luajit-2.0/lua.h>
#include <luajit-2.0/lauxlib.h>

static const char SEPARATOR = '/';
static const char* ROOT = "/";

enum fsitem {
    FSITEM_UNKNOWN,
    FSITEM_DIR,
    FSITEM_FILE,
    FSITEM_LINK,
};

static enum fsitem mapdt(__uint8_t native) {
    switch (native) {
    case DT_DIR:
        return FSITEM_DIR;
    case DT_REG:
        return FSITEM_FILE;
    case DT_LNK:
        return FSITEM_LINK;
    default:
        return FSITEM_UNKNOWN;
    }
}

static int dir_iter(lua_State *L) {
    DIR *d = *(DIR**)lua_touserdata(L, lua_upvalueindex(1));
    struct dirent *entry;
    if ((entry = readdir(d)) != NULL) {
        lua_createtable(L, 0, 2);
        lua_pushstring(L, entry->d_name);
        lua_setfield(L, -2, "name");
        lua_pushnumber(L, mapdt(entry->d_type));
        lua_setfield(L, -2, "type");
        return 1;
    }
    else return 0;
}

static int dir_gc(lua_State *L) {
    DIR *d = *(DIR**)lua_touserdata(L, 1);
    if (d) {
        closedir(d);
    }
    return 0;
}

static int scan(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);

    DIR** d = (DIR**)lua_newuserdata(L, sizeof(DIR*));

    luaL_getmetatable(L, "posixfs.scan");
    lua_setmetatable(L, -2);

    if ((*d = opendir(path)) == NULL) {
        luaL_error(L, "cannot open %s: %s", path, strerror(errno));
    }

    lua_pushcclosure(L, dir_iter, 1);

    return 1;
}

static int _trim(lua_State* L, const char* base) {
    size_t len = strlen(base);

    if (strcmp(base, ROOT) == 0) {
        lua_pushstring(L, ROOT);
        return 1;
    }

    char const* p = base + len - 1;
    if (*p == SEPARATOR) {
        --p;
    }

    while (p != base && *p != SEPARATOR) {
        --p;
    }

    if (p == base) {
        lua_pushstring(L, ROOT);
        return 1;
    }

    char* path = (char*)malloc((p - base) * sizeof(char));
    strncpy(path, base, p - base);

    lua_pushstring(L, path);
    free(path);

    return 1;
}

static int _join(lua_State* L, const char* base, const char* tail) {
    size_t base_len = strlen(base);
    size_t tail_len = strlen(tail);

    char* path = (char*)malloc((base_len + tail_len + 1) + sizeof(char));
    strcpy(path, base);

    char* p = path + base_len - 1;
    if (*p != SEPARATOR) {
        *(++p) = SEPARATOR;
    }

    ++p;

    strcpy(p, tail);

    p = p + tail_len - 1;
    if (*p == SEPARATOR) {
        *p = '\0';
    }

    lua_pushstring(L, path);
    free(path);

    return 1;
}

static int path_join(lua_State* L) {
    const char* base = luaL_checkstring(L, 1);
    if (*base != SEPARATOR) {
        return luaL_error(L, "expected absolute path as first argument");
    }

    const char* tail = luaL_checkstring(L, 2);
    if (*tail == SEPARATOR) {
        return luaL_error(L, "expected relative path as second argument");
    }

    if (strcmp(tail, "..") == 0) {
        return _trim(L, base);
    }

    return _join(L, base, tail);
}

int luaopen_posixfs(lua_State* L) {
    luaL_newmetatable(L, "posixfs.scan");

    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, dir_gc);
    lua_settable(L, -3);

    lua_newtable(L);

    lua_pushstring(L, "scan");
    lua_pushcfunction(L, scan);
    lua_settable(L, -3);

    lua_pushstring(L, "FSITEM_UNKNOWN");
    lua_pushnumber(L, FSITEM_UNKNOWN);
    lua_settable(L, -3);

    lua_pushstring(L, "FSITEM_DIR");
    lua_pushnumber(L, FSITEM_DIR);
    lua_settable(L, -3);

    lua_pushstring(L, "FSITEM_FILE");
    lua_pushnumber(L, FSITEM_FILE);
    lua_settable(L, -3);

    lua_pushstring(L, "FSITEM_LINK");
    lua_pushnumber(L, FSITEM_LINK);
    lua_settable(L, -3);

    lua_pushstring(L, "path_join");
    lua_pushcfunction(L, path_join);
    lua_settable(L, -3);

    return 1;
}
