-- Astra Base Script
-- https://cesbo.com/astra/
--
-- Copyright (C) 2014, Andrey Dyldin <and@cesbo.com>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

table.dump = function(t, p, i)
    if not p then p = print end
    if not i then
        p("{")
        table.dump(t, p, "    ")
        p("}")
        return
    end

    for key,val in pairs(t) do
        if type(val) == "table" then
            p(i .. tostring(key) .. " = {")
            table.dump(val, p, i .. "    ")
            p(i .. "}")
        elseif type(val) == "string" then
            p(i .. tostring(key) .. " = \"" .. val .. "\"")
        else
            p(i .. tostring(key) .. " = " .. tostring(val))
        end
    end
end

-- Deprecated
function dump_table(t, p, i)
    log.error("dump_table() method deprecated. use table.dump() instead")
    return table.dump(t, p, i)
end

string.split = function(s, d)
    if s == nil then
        return nil
    elseif type(s) == "string" then
        --
    elseif type(s) == "number" then
        s = tostring(s)
    else
        log.error("[split] string required")
        astra.abort()
    end

    local p = 1
    local t = {}
    while true do
        b = s:find(d, p)
        if not b then table.insert(t, s:sub(p)) return t end
        table.insert(t, s:sub(p, b - 1))
        p = b + 1
    end
end

-- Deprecated
function split(s, d)
    log.error("split() method deprecated. use string.split() instead")
    return string.split(s, d)
end

ifaddr_list = nil
if utils.ifaddrs then ifaddr_list = utils.ifaddrs() end

-- ooooo  oooo oooooooooo  ooooo
--  888    88   888    888  888
--  888    88   888oooo88   888
--  888    88   888  88o    888      o
--   888oo88   o888o  88o8 o888ooooo88

function parse_url(url)
    if not url then return nil end

    local function parse_opts(r, opts)
        local function parse_key_val(o)
            local k, v
            local x = o:find("=")
            if x then
                k = o:sub(1, x - 1)
                v = o:sub(x + 1)
            else
                k = o
                v = true
            end
            local x = k:find("%.")
            if x then
                local _k = k:sub(x + 1)
                k = k:sub(1, x - 1)
                if not r[k] then r[k] = {} end
                table.insert(r[k], { _k, v })
            else
                r[k] = v
            end
        end
        local p = 1
        while true do
            local x = opts:find("&", p)
            if x then
                parse_key_val(opts:sub(p, x - 1))
                p = x + 1
            else
                parse_key_val(opts:sub(p))
                return nil
            end
        end
    end

    local data={}
    local b = url:find("://")
    if not b then return nil end

    data.format = url:sub(1, b - 1)
    url = url:sub(b + 3)
    b = url:find("#")
    if b then
        parse_opts(data, url:sub(b + 1))
        url = url:sub(1, b - 1)
    end

    local function parse_udp_address()
        local b = url:find("/")
        if b then
            url = url:sub(1, b - 1)
        end
        local b = url:find("@")
        if b then
            if b > 1 then
                data.localaddr = url:sub(1, b - 1)
                if ifaddr_list then
                    local ifaddr = ifaddr_list[data.localaddr]
                    if ifaddr and ifaddr.ipv4 then data.localaddr = ifaddr.ipv4[1] end
                end
            end
            url = url:sub(b + 1)
        end
        local b = url:find(":")
        if b then
            data.port = tonumber(url:sub(b + 1))
            data.addr = url:sub(1, b - 1)
        else
            data.port = 1234
            data.addr = url
        end

        -- check address
        if not data.port or data.port < 0 or data.port > 65535 then
            return false
        end

        local o = { data.addr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
        if #o ~= 4 then
            return false
        end
        for _,i in ipairs(o) do
            local n = tonumber(i)
            if n < 0 or n > 255 then
                return false
            end
        end

        return true
    end

    local function parse_http_address()
        local b = url:find("/")
        if b then
            data.path = url:sub(b)
            url = url:sub(1, b - 1)
        else
            data.path = "/"
        end
        local b = url:find("@")
        if b then
            if b > 1 then
                local a = url:sub(1, b - 1)
                local bb = a:find(":")
                if bb then
                    data.login = a:sub(1, bb - 1)
                    data.password = a:sub(bb + 1)
                end
            end
            url = url:sub(b + 1)
        end
        local b = url:find(":")
        if b then
            data.host = url:sub(1, b - 1)
            data.port = tonumber(url:sub(b + 1))
        else
            data.host = url
            data.port = nil
        end
    end

    if data.format == "udp" then
        if not parse_udp_address() then
            return nil
        end
    elseif data.format == "rtp" then
        if not parse_udp_address() then
            return nil
        end
    elseif data.format == "file" then
        data.filename = url
    elseif data.format == "dvb" then
        data.addr = url
    elseif data.format == "http" then
        parse_http_address()
        if data.port == nil then data.port = 80 end
    elseif data.format == "https" then
        parse_http_address()
        if data.port == nil then data.port = 443 end
    elseif data.format == "rtsp" then
        parse_http_address()
        if data.port == nil then data.port = 554 end
    elseif data.format == "np" then
        parse_http_address()
        if data.port == nil then data.port = 80 end
    else
        data.addr = url
    end

    return data
end

-- ooooo oooo   oooo oooooooooo ooooo  oooo ooooooooooo
--  888   8888o  88   888    888 888    88  88  888  88
--  888   88 888o88   888oooo88  888    88      888
--  888   88   8888   888        888    88      888
-- o888o o88o    88  o888o        888oo88      o888o

init_input_module = {}
kill_input_module = {}

function init_input(conf)
    local instance = { format = conf.format, }

    if not conf.name then
        log.error("[init_input] option 'name' is required")
        astra.abort()
    end

    if not init_input_module[conf.format] then
        log.error("[" .. conf.name .. "] unknown input format")
        astra.abort()
    end
    instance.input = init_input_module[conf.format](conf)
    instance.tail = instance.input

    if conf.pnr == nil then
        local function check_dependent()
            if conf.set_pnr ~= nil then return true end
            if conf.no_sdt == true then return true end
            if conf.no_eit == true then return true end
            if conf.map then return true end
            if conf.filter then return true end
            if conf["filter~"] then return true end
            return false
        end
        if check_dependent() then conf.pnr = 0 end
    end

    if conf.pnr ~= nil then
        if conf.cam and conf.cam ~= true then conf.cas = true end

        instance.channel = channel({
            upstream = instance.tail:stream(),
            name = conf.name,
            pnr = conf.pnr,
            pid = conf.pid,
            no_sdt = conf.no_sdt,
            no_eit = conf.no_eit,
            cas = conf.cas,
            pass_sdt = conf.pass_sdt,
            pass_eit = conf.pass_eit,
            set_pnr = conf.set_pnr,
            map = conf.map,
            filter = string.split(conf.filter, ","),
            ["filter~"] = string.split(conf["filter~"], ","),
            no_reload = conf.no_reload,
        })
        instance.tail = instance.channel
    end

    if conf.biss then
        instance.decrypt = decrypt({
            upstream = instance.tail:stream(),
            name = conf.name,
            biss = conf.biss,
        })
        instance.tail = instance.decrypt
    elseif conf.cam == true then
        -- DVB-CI
    elseif conf.cam then
        local function get_softcam()
            if type(conf.cam) == "table" then
                if conf.cam.cam then
                    return conf.cam
                end
            else
                if type(softcam_list) == "table" then
                    for _, i in ipairs(softcam_list) do
                        if tostring(i.__options.id) == conf.cam then return i end
                    end
                end
                local i = _G[tostring(conf.cam)]
                if type(i) == "table" and i.cam then return i end
            end
            log.error("[" .. conf.name .. "] cam is not found")
            astra.exit()
        end
        local cam = get_softcam()
        local cas_pnr = nil
        if conf.pnr and conf.set_pnr then cas_pnr = conf.pnr end

        instance.decrypt = decrypt({
            upstream = instance.tail:stream(),
            name = conf.name,
            cam = cam:cam(),
            cas_data = conf.cas_data,
            cas_pnr = cas_pnr,
            disable_emm = conf.no_emm,
            ecm_pid = conf.ecm_pid,
            shift = conf.shift,
        })
        instance.tail = instance.decrypt
    end

    return instance
end

function kill_input(instance)
    if not instance then return nil end

    instance.tail = nil

    kill_input_module[instance.format](instance.input)
    instance.input = nil

    instance.channel = nil
    instance.decrypt = nil
end

-- ooooo         ooooo  oooo ooooooooo  oooooooooo
--  888           888    88   888    88o 888    888
--  888 ooooooooo 888    88   888    888 888oooo88
--  888           888    88   888    888 888
-- o888o           888oo88   o888ooo88  o888o

udp_input_instance_list = {}

init_input_module.udp = function(conf)
    local instance_id = tostring(conf.localaddr) .. "@" .. conf.addr .. ":" .. conf.port
    local instance = udp_input_instance_list[instance_id]

    if not instance then
        instance = { clients = 0, }
        udp_input_instance_list[instance_id] = instance

        instance.input = udp_input({
            addr = conf.addr, port = conf.port, localaddr = conf.localaddr,
            socket_size = conf.socket_size,
            renew = conf.renew,
            rtp = conf.rtp,
        })
    end

    instance.clients = instance.clients + 1
    return instance.input
end

kill_input_module.udp = function(module)
    local conf = module.__options
    local instance_id = tostring(conf.localaddr) .. "@" .. conf.addr .. ":" .. conf.port
    local instance = udp_input_instance_list[instance_id]

    instance.clients = instance.clients - 1
    if instance.clients == 0 then
        instance.input = nil
        udp_input_instance_list[instance_id] = nil
    end
end

init_input_module.rtp = function(conf)
    conf.rtp = true
    return init_input_module.udp(conf)
end

kill_input_module.rtp = function(module)
    kill_input_module.udp(module)
end

-- ooooo         ooooooooooo ooooo ooooo       ooooooooooo
--  888           888    88   888   888         888    88
--  888 ooooooooo 888oo8      888   888         888ooo8
--  888           888         888   888      o  888    oo
-- o888o         o888o       o888o o888ooooo88 o888ooo8888

init_input_module.file = function(conf)
    conf.callback = function()
        log.error("[" .. conf.name .. "] end of file")
        if conf.on_error then conf.on_error() end
    end
    return file_input(conf)
end

kill_input_module.file = function(module)
    --
end

-- ooooo         ooooo ooooo ooooooooooo ooooooooooo oooooooooo
--  888           888   888  88  888  88 88  888  88  888    888
--  888 ooooooooo 888ooo888      888         888      888oooo88
--  888           888   888      888         888      888
-- o888o         o888o o888o    o888o       o888o    o888o

http_user_agent = "Astra"
http_input_instance_list = {}

init_input_module.http = function(conf)
    local instance_id = conf.host .. ":" .. conf.port .. conf.path
    local instance = http_input_instance_list[instance_id]

    if not instance then
        instance = { clients = 0, }
        http_input_instance_list[instance_id] = instance

        instance.on_error = function(message)
            log.error("[" .. conf.name .. "] " .. message)
            if conf.on_error then conf.on_error(message) end
        end

        local http_conf = {
            host = conf.host,
            port = conf.port,
            path = conf.path,
            stream = true,
            sync = conf.sync,
            timeout = conf.timeout,
            sctp = conf.sctp,
            headers = {
                "User-Agent: " .. http_user_agent,
                "Host: " .. conf.host .. ":" .. conf.port,
                "Connection: close",
            }
        }

        if conf.login and conf.password then
            local auth = base64.encode(conf.login .. ":" .. conf.password)
            table.insert(http_conf.headers, "Authorization: Basic " .. auth)
        end

        local timer_conf = {
            interval = 5,
            callback = function(self)
                instance.timeout:close()
                instance.timeout = nil

                if instance.request then instance.request:close() end
                instance.request = http_request(http_conf)
            end
        }

        http_conf.callback = function(self, response)
            if not response then
                instance.request:close()
                instance.request = nil
                instance.timeout = timer(timer_conf)

            elseif response.code == 200 then
                if instance.timeout then
                    instance.timeout:close()
                    instance.timeout = nil
                end

                instance.transmit:set_upstream(self:stream())

            elseif response.code == 301 or response.code == 302 then
                if instance.timeout then
                    instance.timeout:close()
                    instance.timeout = nil
                end

                instance.request:close()
                instance.request = nil

                local o = parse_url(response.headers["location"])
                if o then
                    http_conf.host = o.host
                    http_conf.port = o.port
                    http_conf.path = o.path
                    http_conf.headers[2] = "Host: " .. o.host .. ":" .. o.port

                    log.info("[" .. conf.name .. "] Redirect to http://" .. o.host .. ":" .. o.port .. o.path)
                    instance.request = http_request(http_conf)
                else
                    instance.on_error("HTTP Error: Redirect failed")
                    instance.timeout = timer(timer_conf)
                end

            else
                instance.request:close()
                instance.request = nil
                instance.on_error("HTTP Error: " .. response.code .. ":" .. response.message)
                instance.timeout = timer(timer_conf)
            end
        end

        instance.transmit = transmit({ instance_id = instance_id })
        instance.request = http_request(http_conf)
    end

    instance.clients = instance.clients + 1
    return instance.transmit
end

kill_input_module.http = function(module)
    local instance_id = module.__options.instance_id
    local instance = http_input_instance_list[instance_id]

    instance.clients = instance.clients - 1
    if instance.clients == 0 then
        if instance.timeout then
            instance.timeout:close()
            instance.timeout = nil
        end
        if instance.request then
            instance.request:close()
            instance.request = nil
        end
        instance.transmit = nil
        http_input_instance_list[instance_id] = nil
    end
end

-- ooooo         ooooooooo  ooooo  oooo oooooooooo
--  888           888    88o 888    88   888    888
--  888 ooooooooo 888    888  888  88    888oooo88
--  888           888    888   88888     888    888
-- o888o         o888ooo88      888     o888ooo888

dvb_input_instance_list = {}
dvb_list = nil

function dvb_tune(conf)
    if conf.mac then
        conf.adapter = nil
        conf.device = nil

        if dvb_list == nil then
            if dvbls then
                dvb_list = dvbls()
            else
                dvb_list = {}
            end
        end
        local mac = conf.mac:upper()
        for _, a in ipairs(dvb_list) do
            if a.mac == mac then
                log.info("[dvb_tune] adapter: " .. a.adapter .. "." .. a.device .. ". " ..
                         "MAC address: " .. mac)
                conf.adapter = a.adapter
                conf.device = a.device
                break
            end
        end

        if conf.adapter == nil then
            log.error("[dvb_tune] failed to get an adapter. MAC address: " .. mac)
            astra.abort()
        end
    else
        if conf.adapter == nil then
            log.error("[dvb_tune] option 'adapter' or 'mac' is required")
            astra.abort()
        end

        local a = string.split(tostring(conf.adapter), "%.")
        if #a == 1 then
            conf.adapter = tonumber(a[1])
            if conf.device == nil then conf.device = 0 end
        elseif #a == 2 then
            conf.adapter = tonumber(a[1])
            conf.device = tonumber(a[2])
        end
    end

    local instance_id = conf.adapter .. "." .. conf.device
    local instance = dvb_input_instance_list[instance_id]
    if not instance then
        if not conf.type then
            log.error("[dvb_tune " .. instance_id .. "] option 'type' is required")
            astra.abort()
        end

        if conf.tp then
            local a = string.split(conf.tp, ":")
            if #a ~= 3 then
                log.error("[dvb_tune " .. instance_id .. "] option 'tp' has wrong format")
                astra.abort()
            end
            conf.frequency, conf.polarization, conf.symbolrate = a[1], a[2], a[3]
        end

        if conf.lnb then
            local a = string.split(conf.lnb, ":")
            if #a ~= 3 then
                log.error("[dvb_tune " .. instance_id .. "] option 'lnb' has wrong format")
                astra.abort()
            end
            conf.lof1, conf.lof2, conf.slof = a[1], a[2], a[3]
        end

        if conf.unicable then
            local a = string.split(conf.unicable, ":")
            if #a ~= 2 then
                log.error("[dvb_tune " .. instance_id .. "] option 'unicable' has wrong format")
                astra.abort()
            end
            conf.uni_scr, conf.uni_frequency = a[1], a[2]
        end

        if conf.type == "S" and conf.s2 == true then conf.type = "S2" end
        if conf.type == "T" and conf.t2 == true then conf.type = "T2" end

        if conf.type:lower() == "asi" then
            instance = asi_input(conf)
        else
            instance = dvb_input(conf)
        end
        dvb_input_instance_list[instance_id] = instance
    end

    return instance
end

init_input_module.dvb = function(conf)
    local instance = nil

    local adapter_addr = tostring(conf.addr)

    if #adapter_addr == 0 then
        conf.channels = 0
        instance = dvb_tune(conf)
        instance.__options.channels = instance.__options.channels + 1
    else
        local function get_dvb_tune()
            for _, i in pairs(dvb_input_instance_list) do
                if tostring(i.__options.id) == adapter_addr then
                    return i
                end
            end
            local i = _G[adapter_addr]
            local module_name = tostring(i)
            if  module_name == "dvb_input" or
                module_name == "asi_input" or
                module_name == "ddci"
            then
                return i
            end
            log.error("[" .. conf.name .. "] dvb is not found")
            astra.abort()
        end
        instance = get_dvb_tune()
    end

    if conf.cam == true and conf.pnr then
        instance:ca_set_pnr(conf.pnr, true)
    end

    return instance
end

kill_input_module.dvb = function(module)
    local conf = module.__options

    if conf.cam == true and conf.pnr then
        module:ca_set_pnr(conf.pnr, false)
    end

    if conf.channels ~= nil then
        conf.channels = conf.channels - 1
        if conf.channels == 0 then
            module:close()
            local instance_id = conf.adapter .. "." .. conf.device
            dvb_input_instance_list[instance_id] = nil
        end
    end
end

-- ooooo         oooooooooo  ooooooooooo ooooo         ooooooo      o      ooooooooo
--  888           888    888  888    88   888        o888   888o   888      888    88o
--  888 ooooooooo 888oooo88   888ooo8     888        888     888  8  88     888    888
--  888           888  88o    888    oo   888      o 888o   o888 8oooo88    888    888
-- o888o         o888o  88o8 o888ooo8888 o888ooooo88   88ooo88 o88o  o888o o888ooo88

init_input_module.reload = function(conf)
    return transmit({
        timer = timer({
            interval = tonumber(conf.addr),
            callback = function(self)
                self:close()
                astra.reload()
            end,
        })
    })
end

kill_input_module.reload = function(module)
    module.__options.timer:close()
end

-- ooooo          oooooooo8 ooooooooooo   ooooooo  oooooooooo
--  888          888        88  888  88 o888   888o 888    888
--  888 ooooooooo 888oooooo     888     888     888 888oooo88
--  888                  888    888     888o   o888 888
-- o888o         o88oooo888    o888o      88ooo88  o888o

init_input_module.stop = function(conf)
    return transmit({})
end

kill_input_module.stop = function(module)
    --
end

-- ooooo         ooooooo      o      ooooooooo
--  888        o888   888o   888      888    88o
--  888        888     888  8  88     888    888
--  888      o 888o   o888 8oooo88    888    888
-- o888ooooo88   88ooo88 o88o  o888o o888ooo88

function astra_usage()
    log.info("Astra " .. astra.version)
    print([[

Usage: astra APP [OPTIONS]

Available Applications:
    --stream            Astra Stream is a main application for
                        the digital television streaming
    --relay             Astra Relay  is an application for
                        the digital television relaying
                        via the HTTP protocol
    --analyze           Astra Analyze is a MPEG-TS stream analyzer
    --dvbls             DVB Adapters information list
    SCRIPT              launch Astra script

Astra Options:
    -h, --help          command line arguments
    -v, --version       version number
    --pid FILE          create PID-file
    --syslog NAME       send log messages to syslog
    --log FILE          write log to file
    --no-stdout         do not print log messages into console
    --color             colored log messages in console
    --debug             print debug messages
]])

    if _G.options_usage then
        print("Application Options:")
        print(_G.options_usage)
    end
    astra.exit()
end

function astra_version()
    log.info("Astra " .. astra.version)
    astra.exit()
end

astra_options = {
    ["-h"] = function(idx)
        astra_usage()
        return 0
    end,
    ["--help"] = function(idx)
        astra_usage()
        return 0
    end,
    ["-v"] = function(idx)
        astra_version()
        return 0
    end,
    ["--version"] = function(idx)
        astra_version()
        return 0
    end,
    ["--pid"] = function(idx)
        pidfile(argv[idx + 1])
        return 1
    end,
    ["--syslog"] = function(idx)
        log.set({ syslog = argv[idx + 1] })
        return 1
    end,
    ["--log"] = function(idx)
        log.set({ filename = argv[idx + 1] })
        return 1
    end,
    ["--no-stdout"] = function(idx)
        log.set({ stdout = false })
        return 0
    end,
    ["--color"] = function(udx)
        log.set({ color = true })
        return 0
    end,
    ["--debug"] = function(idx)
        log.set({ debug = true })
        return 0
    end,
}

function astra_parse_options(idx)
    function set_option(idx)
        local a = argv[idx]
        local c = nil

        if _G.options then c = _G.options[a] end
        if not c then c = astra_options[a] end
        if not c and _G.options then c = _G.options["*"] end

        if not c then return -1 end
        local ac = c(idx)
        if ac == -1 then return -1 end
        idx = idx + ac + 1
        return idx
    end

    while idx <= #argv do
        local next_idx = set_option(idx)
        if next_idx == -1 then
            print("unknown option: " .. argv[idx])
            astra.exit()
        end
        idx = next_idx
    end
end
