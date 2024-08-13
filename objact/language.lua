
objact_language = { --语言表
    get_languages_number = function() --返回语言数量
        local local_int = 1 --最大语言数
        for i = 1,#language do
            if #language[i] > local_int then
                local_int = #language[i]
            end
        end
        return local_int
    end,
    get_string_in_languages = function(string) --返回语言
        for i = 1, #language do
            if language[i] and language[i][1] == string then --以英语作为基准
                if language[i][settings.language + 1] then
                    return language[i][settings.language + 1]
                end
                return language[i][1]
            end
        end
        return string
    end
}