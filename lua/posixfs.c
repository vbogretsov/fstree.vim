#include <errno.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>

#include <luajit-2.0/lua.h>
#include <luajit-2.0/lauxlib.h>

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

    lua_setglobal(L, "posixfs");

    return 0;
}
