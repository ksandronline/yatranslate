-- free for use, free for modify, free for distribution

local http = minetest.request_http_api()

yatranslate = {
    version                     = '1.00',
    oauth_token                 = minetest.settings:get('yatranslate.oauth_token') or '',
    folder_id                   = minetest.settings:get('yatranslate.folder_id') or '',
    timeout                     = minetest.settings:get('yatranslate.timeout') or 1000,
    startup_on_start_server     = minetest.settings:get('yatranslate.startup_on_start_server') or true,
    startup_after_player_login  = minetest.settings:get('yatranslate.startup_after_player_login') or '',
    need_special_priv           = minetest.settings:get('yatranslate.need_special_priv') or false,
    use_all_support_lang        = minetest.settings:get('yatranslate.use_all_support_lang') or true
    }

token = ''

if yatranslate.oauth_token and yatranslate.folder_id then

    if yatranslate.need_special_priv then
        minetest.register_privilege("translate", {
            description = "You can translate chat message to any languages.",
            give_to_singleplayer = false
        })
        function ch_cmd(code, lang)
            core.register_chatcommand(code, {
                params = "<text>",
                description = lang,
                privs = { translate = true },
                    func = function(name, param)
                        req = yt_req(param, code)
                        http.fetch(req, function(ans)
                            if ans.code == 200 then
                                translate = minetest.parse_json(ans.data).translations[1]
                                minetest.chat_send_all("<"..name .. "> " ..translate["text"])
                            else minetest.chat_send_player(name, "Перевод не работает/Translate worry") end
                        end)
                    end
            })
            
            core.register_chatcommand("pm"..code, {
                params = "<name> <message>",
                description = "Send a direct message to a player",
                privs = { translate = true },
                func = function(name, param)
                    local sendto, message = param:match("^(%S+)%s(.+)$")
                    if not sendto then
                        return false, "Invalid usage, see /help msg."
                    end
                    if not core.get_player_by_name(sendto) then
                        return false, "The player " .. sendto
                                .. " is not online."
                    end
                    core.log("action", "DM from " .. name .. " to " .. sendto
                            .. ": " .. message)
                    req = yt_req(message, code)
                        http.fetch(req, function(ans)
                            if ans.code == 200 then
                                translate = minetest.parse_json(ans.data).translations[1]
                                minetest.chat_send_player(sendto, "PM from "..name .. "> " ..translate["text"])
                            else minetest.chat_send_player(name, "Перевод не работает/Translate worry") end
                        end)                              
                    return true, "Message sent."
                end,
            })
        end
    else
        function ch_cmd(code, lang)
            core.register_chatcommand(code, {
                params = "<text>",
                description = lang,
                privs = { shout = true },
                    func = function(name, param)
                        req = yt_req(param, code)
                        http.fetch(req, function(ans)
                            if ans.code == 200 then
                                translate = minetest.parse_json(ans.data).translations[1]
                                minetest.chat_send_all("<"..name .. "> " ..translate["text"])
                            else minetest.chat_send_player(name, "Перевод не работает/Translate worry") end
                        end)
                    end
            })
        
            core.register_chatcommand("pm"..code, {
                params = "<name> <message>",
                description = "Send a direct message to a player",
                privs = { shout = true },
                func = function(name, param)
                    local sendto, message = param:match("^(%S+)%s(.+)$")
                    if not sendto then
                        return false, "Invalid usage, see /help msg."
                    end
                    if not core.get_player_by_name(sendto) then
                        return false, "The player " .. sendto
                                .. " is not online."
                    end
                    core.log("action", "DM from " .. name .. " to " .. sendto
                            .. ": " .. message)
                    req = yt_req(message, code)
                        http.fetch(req, function(ans)
                            if ans.code == 200 then
                                translate = minetest.parse_json(ans.data).translations[1]
                                minetest.chat_send_player(sendto, "PM from "..name .. "> " ..translate["text"])
                            else minetest.chat_send_player(name, "Перевод не работает/Translate worry") end
                        end)                              
                    return true, "Message sent."
                end,
            })
        end
    end
        
    function start_translate()
        local req_get_token = 
            {
                ["url"]         = "https://iam.api.cloud.yandex.net/iam/v1/tokens",
                ["timeout"]     = yatranslate.timeout,
                ["post_data"]   = minetest.write_json({ yandexPassportOauthToken = yatranslate.oauth_token})
            }
        
        http.fetch(req_get_token, function(ans)
            if ans.code == 200 then              
                token = minetest.parse_json(ans.data)
                minetest.safe_file_write(minetest.get_worldpath().."/iamToken.txt", token["iamToken"])  -- token need update every 12 hors or earlier
                token = token["iamToken"]
                
                local post_data = { folder_id = yatranslate.folder_id }
                local request_support_lang = 
                {
                    ["url"]             = "https://translate.api.cloud.yandex.net/translate/v2/languages",
                    ["timeout"]         = yatranslate.timeout,
                    ["post_data"]       = minetest.write_json(post_data),
                    ["extra_headers"]   = {"Content-Type: application/json", "Authorization: Bearer "..token}
                }
                
                http.fetch(request_support_lang, function(answer)        
                if answer.code == 200 then
                        local languages = minetest.parse_json(answer.data).languages
                        for i = 1, #languages do
                            if languages[i].name then
                                print(i .. " " .. languages[i].code .. " - " .. languages[i].name)
                                if yatranslate.use_all_support_lang then 
                                    ch_cmd(languages[i].code,languages[i].name)
                                end
                            end
                        end
                    end
                end)
                return true
            else return false
            end
        end)       
    end

    function yt_req(text, lang)
        local input = io.open(minetest.get_worldpath().."/iamToken.txt","r")
        for token in input:lines() do end
        io.close(input)
        
        local translate = ""
        local post_data = 
        {
            folder_id = yatranslate.folder_id,
            texts = text,
            targetLanguageCode = lang
        }

        local req = 
        {
            ["url"] = "https://translate.api.cloud.yandex.net/translate/v2/translate",
            ["timeout"] = yatranslate.timeout,
            ["post_data"] = minetest.write_json(post_data),
            ["extra_headers"] = {"Content-Type: application/json", "Authorization: Bearer "..token}
        }
        return req
    end

    init = false
    if yatranslate.startup_on_start_server and not init then
        init = true
        if start_translate() then
            
        end
    elseif yatranslate.startup_after_player_login == player:get_player_name() and not init then
        init = true
        if start_translate() then 
                
        end                 
    end

end


-- Example how to do translate all chat message to one players in her natural language
--[[

minetest.register_on_chat_message(function(name, message)
    local player_to_chat_translate  = "ksandr"  -- Change to you name
    local player_natural_lang       = "ru"      -- Change to you lang   
    if core.get_player_by_name(player_to_chat_translate) and name ~= player_to_chat_translate then
        req = yt_req(message, player_natural_lang)
        http.fetch(req, function(ans)
            if ans.code == 200 then
                translate = minetest.parse_json(ans.data).translations[1]
                minetest.chat_send_player(player_to_chat_translate, "<"..name .."> ".. message .."|> ".. translate["text"])
                return true
            else return false end
        end)            
    end
end)

]]

-- If need use translate only some lang use it example form, and change setting "use_all_support_lang" = false
--[[

local lang = 'ru'   -- Change to you lang
core.register_chatcommand(lang, {
    params = "<text>",
    description = translate to lang,
    privs = { translate = true },
        func = function(name, param)
            req = yt_req(param, lang)
            http.fetch(req, function(ans)
                if ans.code == 200 then
                    translate = minetest.parse_json(ans.data).translations[1]
                    minetest.chat_send_all("<"..name .. "> " ..translate["text"])
                else minetest.chat_send_player(name, "Перевод не работает/Translate worry") end
            end)
        end
})

]]
