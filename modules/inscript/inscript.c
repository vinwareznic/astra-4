/*
 * Astra Module: Built-in script
 * https://cesbo.com/astra
 *
 * Copyright (C) 2014, Andrey Dyldin <and@cesbo.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef INSCRIPT_APP

#include <astra.h>
#include "inscript.h"

static const char __module_name[] = "inscript";

static int load_inscript(const char *buffer, size_t size, const char *name)
{
    int load;

    load = luaL_loadbuffer(lua, buffer, size, name);
    if(load != 0)
        return -1;

    load = lua_pcall(lua, 0, LUA_MULTRET, 0);
    if(load != 0)
        return -1;

    return 0;
}

static int fn_inscript_callback(lua_State *L)
{
    __uarg(L);

    int load;

    load = load_inscript((const char *)base, sizeof(base), "=base");
    if(load != 0)
        luaL_error(lua, "[main] %s", lua_tostring(lua, -1));

    lua_getglobal(lua, "argv");
    const int argc = luaL_len(lua, -1);

    if(argc == 0)
    {
        lua_pop(lua, 1); // argv

        lua_getglobal(lua, "astra_usage");
        luaL_checktype(lua, -1, LUA_TFUNCTION);
        lua_call(lua, 0, 0);
        return 0;
    }

    int argv_idx = 1;

    lua_rawgeti(lua, -1, 1);
    const char *script = luaL_checkstring(lua, -1);
    lua_pop(lua, 2); // script + argv

    load = load_inscript((const char *)stream, sizeof(stream), "=stream");
    if(load != 0)
        luaL_error(lua, "[main] %s", lua_tostring(lua, -1));

    if(!strcmp(script, "-"))
    {
        load = luaL_dofile(lua, NULL);
        argv_idx += 1;
    }
    else if(!strcmp(script, "--stream"))
    {
        load = 0;
        argv_idx += 1;
    }
    else if(!strcmp(script, "--analyze"))
    {
        load = load_inscript((const char *)analyze, sizeof(analyze), "=app");
        argv_idx += 1;
    }
    else if(!strcmp(script, "--xproxy"))
    {
        load = load_inscript((const char *)relay, sizeof(relay), "=app");
        argv_idx += 1;
    }
    else if(!strcmp(script, "--relay"))
    {
        load = load_inscript((const char *)relay, sizeof(relay), "=app");
        argv_idx += 1;
    }
    else if(!strcmp(script, "--dvbls"))
    {
        load = load_inscript((const char *)dvbls, sizeof(dvbls), "=app");
        argv_idx += 1;
    }
    else if(!access(script, R_OK))
    {
        load = luaL_dofile(lua, script);
        argv_idx += 1;
    }
    if(load != 0)
        luaL_error(lua, "[main] %s", lua_tostring(lua, -1));

    lua_getglobal(lua, "astra_parse_options");
    luaL_checktype(lua, -1, LUA_TFUNCTION);
    lua_pushnumber(lua, argv_idx);
    lua_call(lua, 1, 0);

    lua_getglobal(lua, "main");
    if(lua_isfunction(lua, -1))
        lua_call(lua, 0, 0);
    else
        lua_pop(lua, 1);

    return 0;
}

LUA_API int luaopen_inscript(lua_State *L)
{
    lua_pushcclosure(L, fn_inscript_callback, 0);
    lua_setglobal(L, __module_name);

    return 1;
}

#else

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#define MAX_BUFFER_SIZE 4096

typedef struct string_buffer_t string_buffer_t;

struct string_buffer_t
{
    char buffer[MAX_BUFFER_SIZE];
    int size;

    string_buffer_t *last;
    string_buffer_t *next;
};

static void string_buffer_addchar(string_buffer_t *buffer, char c)
{
    string_buffer_t *last = buffer->last;
    if(last->size >= MAX_BUFFER_SIZE)
    {
        last->next = malloc(sizeof(string_buffer_t));
        last = last->next;
        last->size = 0;
        last->last = NULL;
        last->next = NULL;
        buffer->last = last;
    }

    last->buffer[last->size] = c;
    ++last->size;
}

static const char * skip_sp(const char *source)
{
    if(!source)
        return NULL;

    while(*source)
    {
        switch(*source)
        {
            case '\0':
                return NULL;
            case '\t':
            case ' ':
            case '\r':
                ++source;
                break;
            default:
                return source;
        }
    }

    return NULL;
}

static bool check_string_tail(const char *source, int l)
{
    if(source[0] != ']' || source[l + 1] != ']')
    {
        return false;
    }

    for(int i = 0; i < l; ++i)
    {
        if(source[i + 1] != '=')
            return false;
    }

    return true;
}

static const char * skip_comment(const char *source, string_buffer_t *buffer)
{
    if(*source == '[')
    {
        ++source;
        int l = 0;
        for(; *source == '='; ++source, ++l)
            ;

        if(*source == '[')
        {
            ++source;
            for(; *source; ++source)
            {
                if(*source == ']' && check_string_tail(source, l))
                    return source + l + 2;

                if(*source == '\n')
                    string_buffer_addchar(buffer, '\n');
            }
        }
    }
    else
    {
        for(; *source && *source != '\n'; ++source)
            ;
        if(*source == '\n')
            return source;
    }

    printf("Wrong comment format\n");
    abort();
    return NULL;
}

static const char * parse_string(const char *source, string_buffer_t *buffer)
{
    if(*source == '[')
    {
        string_buffer_addchar(buffer, '[');
        ++source;
        int l = 0;
        for(; *source == '='; ++source, ++l)
            string_buffer_addchar(buffer, '=');

        if(*source == '[')
        {
            string_buffer_addchar(buffer, '[');
            ++source;

            for(; *source; ++source)
            {
                if(*source == ']' && check_string_tail(source, l))
                {
                    string_buffer_addchar(buffer, ']');
                    for(int i = 0; i < l; ++i)
                        string_buffer_addchar(buffer, '=');
                    string_buffer_addchar(buffer, ']');
                    return source + l + 2;
                }

                string_buffer_addchar(buffer, *source);
            }
        }
    }
    else
    {
        char c = *source;
        string_buffer_addchar(buffer, c);
        ++source;

        for(; *source; ++source)
        {
            string_buffer_addchar(buffer, *source);

            if(*source == c)
                return source + 1;

            if(source[0] == '\\' && source[1] == c)
            {
                string_buffer_addchar(buffer, c);
                ++source;
            }
        }
    }

    printf("Wrong string format\n");
    abort();
    return NULL;
}

static string_buffer_t * parse(const char *source)
{
    string_buffer_t *buffer = malloc(sizeof(string_buffer_t));
    buffer->size = 0;
    buffer->last = buffer;
    buffer->next = NULL;

    bool is_new_line = true;

    for(; source && *source; ++source)
    {
        if(is_new_line)
        {
            is_new_line = false;
            source = skip_sp(source);
            if(!source)
                break;
        }

        if(source[0] == '-' && source[1] == '-')
            source = skip_comment(&source[2], buffer);

        if(source[0] == '\'' || source[0] == '"')
            source = parse_string(source, buffer);

        if(source[0] == '[' && (source[1] == '=' || source[1] == '['))
            source = parse_string(source, buffer);

        if(source[0] == '\r')
            continue;

        string_buffer_addchar(buffer, source[0]);

        if(source[0] == '\n')
            is_new_line = true;
    }

    return buffer;
}

static void print_block(uint8_t *block, size_t len)
{
    printf("  ");
    for(size_t i = 0; i < len; ++i)
        printf("  0x%02X,", block[i]);
    printf("\n");
}

int main(int argc, char const *argv[])
{
    int fd = open(argv[2], O_RDONLY);
    if(fd == -1)
    {
        fprintf(stderr, "Failed to open file: %s\n", argv[1]);
        return -1;
    }
    int filesize = lseek(fd, 0, SEEK_END);
    lseek(fd, 0, SEEK_SET);

    char *script = malloc(filesize + 1);
    if(read(fd, script, filesize) != filesize)
    {
        fprintf(stderr, "Failed to read file\n");
        free(script);
        close(fd);
        return -1;
    }
    script[filesize] = '\0';
    close(fd);

    size_t skip;
    string_buffer_t *buffer;
    string_buffer_t *next_next;

    // first clean
    buffer = parse(script);
    skip = 0;
    for(string_buffer_t *next = buffer
        ; next && (next_next = next->next, 1)
        ; next = next_next)
    {
        memcpy(&script[skip], next->buffer, next->size);
        skip += next->size;
        free(next);
    }
    script[skip] = 0;

    // second clean
    buffer = parse(script);
    skip = 0;
    for(string_buffer_t *next = buffer
        ; next && (next_next = next->next, 1)
        ; next = next_next)
    {
        memcpy(&script[skip], next->buffer, next->size);
        skip += next->size;
        free(next);
    }
    script[skip] = 0;

    printf("static unsigned char %s[] = {\n", argv[1]);
    const size_t tail = skip % 8;
    const size_t limit = skip - tail;
    for(size_t i = 0; i < limit; i += 8)
        print_block((uint8_t *)&script[i], 8);
    if(limit < skip)
        print_block((uint8_t *)&script[limit], tail);
    printf("};\n");

    free(script);

    return 0;
}

#endif
