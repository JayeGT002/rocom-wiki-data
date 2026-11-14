-- 旧格式调用方的只读适配器。新增内容始终从独立赛季模块读取。
local p={}
local Visibility=require('Module:ContentVisibility')
local merged,cache,routes,skillRoutes=nil,{},nil,nil
-- 所有公开消费者共用展示策略，避免关联工具绕过图鉴的赛季限制。
-- 原始赛季资料不变；解除策略后恢复原有聚合路径。
local legacyTables={Catalog=true,Skills=true,Learnsets=true,Evolutions=true,Handbooks=true,
    Terms=true,Types=true,SkillStoneTopics=true,Index=true,Config=true,History=true,Overview=true}
local function data()
    if not merged then
        if Visibility.season('S5') then
            merged=setmetatable({Targets={},Links={}}, {__index=function(all,name)
                local value=legacyTables[name] and mw.loadData('Module:Pets/data/'..name) or {}
                value=Visibility.legacy(name,value)
                rawset(all,name,value);return value
            end})
        else
            local config=mw.loadData('Module:Pets/SeasonConfig')
            merged=require('Module:'..config.view_namespace).data
        end
    end
    return merged
end
function p.get(name)
    if cache[name] then return cache[name] end
    local all=data();local value=all[name] or {}
    if name=='Evolutions' then
        local copy={};for key,row in pairs(value) do copy[key]=row end
        for oldKey,newKey in pairs(all.LegacyEvolutionAliases or {}) do
            assert(value[newKey],'缺少新赛季进化资料');copy[oldKey]=value[newKey]
        end
        value=copy
    elseif name=='SkillStoneTopics' then
        local copy={};for key,row in pairs(value) do copy[key]=row end
        for key,rows in pairs(all.LegacyStoneTopics or {}) do
            local combined={};for _,row in ipairs(copy[key] or {}) do combined[#combined+1]=row end
            for _,row in ipairs(rows) do combined[#combined+1]=row end;copy[key]=combined
        end
        value=copy
    end
    cache[name]=value;return value
end
-- 详情只读取当前精灵的学习表，避免为全图鉴建立只读代理和赛季覆盖副本。
function p.learnset(key)
    if cache.Learnsets then return cache.Learnsets[key] end
    if not Visibility.season('S5') then return p.get('Learnsets')[key] end
    local original=mw.loadData('Module:Pets/data/Learnsets')[key]
    local patch=mw.loadData('Module:ContentVisibility/S5Legacy/Learnsets')[key]
    if not original or not patch then return original end
    local row={}
    for field,value in pairs(original) do row[field]=value end
    for field,value in pairs(patch) do row[field]=value end
    return row
end
-- 图鉴课题和历史同样仅投影当前条目；不得展开所有精灵的嵌套只读表。
function p.handbook(key)
    if cache.Handbooks then return cache.Handbooks[key] end
    if not Visibility.season('S5') then return p.get('Handbooks')[key] end
    local original=mw.loadData('Module:Pets/data/Handbooks')[key]
    if not original then return nil end
    return Visibility.legacy('Handbooks',{[key]=original})[key]
end
function p.history(key)
    local history
    if cache.History then history=cache.History
    elseif not Visibility.season('S5') then history=p.get('History')
    else
        local original=mw.loadData('Module:Pets/data/History')
        history=Visibility.legacy('History',{
            versions=original.versions,pets={[key]=(original.pets or {})[key]}
        })
    end
    return (history.pets or {})[key],history.versions
end
function p.title(label)
    if not routes then
        routes={};local all=data()
        for kind,mapping in pairs(all.Targets or {}) do
            for key,title in pairs(mapping) do
                local row=(kind=='pet' and all.Catalog or all.Skills)[key]
                local name=kind=='pet' and row.title or row.name
                if routes[name] and routes[name]~=title then routes[name]=false
                elseif routes[name]==nil then routes[name]=title end
            end
        end
    end
    return routes[label] or label
end
function p.skillTitle(skill)
    if not skillRoutes then
        skillRoutes={};local all=data()
        for _,kind in ipairs({'skill','trait'}) do
            for key,title in pairs((all.Targets or {})[kind] or {}) do
                local row=assert(all.Skills[key],'缺少新赛季技能资料')
                assert(row.game_id,'缺少技能的游戏编号')
                assert(not skillRoutes[row.game_id] or skillRoutes[row.game_id]==title,'技能游戏编号冲突')
                skillRoutes[row.game_id]=title
            end
        end
    end
    return skillRoutes[skill.game_id] or skill.name
end
return p