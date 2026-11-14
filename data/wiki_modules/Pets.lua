local SeasonData = require("Module:Pets/SeasonData")
local PageIdentity = require("Module:PageIdentity")
local SEO = require("Module:SEO")
local CombatEffects = require("Module:CombatEffects")
-- Module:Pets
-- Detail renderer. Generated data lives under Module:Pets/data/*.

local index = mw.loadData("Module:Pets/data/Index")
local themeData = mw.loadData("Module:Pets/Theme")

local p = {}

local STAT_FIELDS = {
  { key = "hp", label = "生命", rune = "HP", icon = "Stat_HP.png" },
  { key = "atk", label = "攻击", rune = "ATK", icon = "Stat_Atk.png" },
  { key = "spa", label = "魔攻", rune = "MATK", icon = "Stat_Spa.png" },
  { key = "def", label = "物防", rune = "DEF", icon = "Stat_Def.png" },
  { key = "spd", label = "魔防", rune = "MDEF", icon = "Stat_Spd.png" },
  { key = "spe", label = "速度", rune = "SPD", icon = "Stat_Spe.png" },
}

local SKILL_CAT_ICONS = {
  ["物攻"] = "Stat_Atk.png",
  ["魔攻"] = "Stat_Spa.png",
  ["防御"] = "Stat_Def.png",
  ["状态"] = "SkillCat_Status.png",
}

local EGG_GROUP_NAMES = {
  [1] = "未发现", [2] = "巨灵组", [3] = "两栖组", [4] = "昆虫组",
  [5] = "天空组", [6] = "动物组", [7] = "妖精组", [8] = "植物组",
  [9] = "拟人组", [10] = "软体组", [11] = "大地组", [12] = "魔力组",
  [13] = "海洋组", [14] = "飞龙组", [15] = "机械组",
}

local STAGE_NAMES = { [1] = "初阶", [2] = "二阶", [3] = "三阶", [4] = "四阶" }

local ROMANS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }

local NAV = {
  { key = "pInfo", label = "基础信息" },
  { key = "pSkill", label = "技能表" },
  { key = "pReference", label = "培养参考" },
  { key = "pEvo", label = "进化链" },
  { key = "pQuest", label = "图鉴课题" },
  { key = "pEco", label = "生态与获取" },
  { key = "pHistory", label = "历史变动" },
}

local SKILL_TABS = {
  { key = "level", label = "自学" },
  { key = "machine", label = "技能石" },
  { key = "blood", label = "血脉" },
  { key = "legendary", label = "传说" },
}

local SKILL_CATEGORY_ORDER = { "物攻", "魔攻", "防御", "状态" }

local HISTORY_GROUP_LABELS = {
  identity = "身份",
  type = "系别",
  stats = "种族值",
  feature = "特性",
  learnset = "技能来源",
  skill = "技能调整",
  evolution = "进化",
  lord = "首领化",
  breeding = "培育",
  handbook = "图鉴",
}

local function trim(value)
  if value == nil then return nil end
  local text = mw.text.trim(tostring(value))
  return text ~= "" and text or nil
end

local function plain(value)
  if value == nil then return "" end
  return mw.text.nowiki(tostring(value))
end

local function addText(node, value)
  node:wikitext(plain(value))
  return node
end

local function hasItems(value)
  if type(value) ~= "table" then return false end
  if value[1] ~= nil then return true end
  for _ in pairs(value) do return true end
  return false
end

local function arrayCount(value)
  local count = 0
  for _ in ipairs(value or {}) do count = count + 1 end
  return count
end

local function mergeArgs(frame)
  local args = {}
  local parent = frame:getParent()
  if parent and parent.args then
    for key, value in pairs(parent.args) do args[key] = value end
  end
  for key, value in pairs(frame.args) do args[key] = value end
  return args
end

local function resolveId(key)
  if key == nil then return nil end
  key = tostring(key)
  if index.numbers and index.numbers[key] then return key end
  if index.by_title and index.by_title[key] then return index.by_title[key] end
  local matches = index.by_name and index.by_name[key]
  if matches and matches[1] ~= nil and matches[2] == nil then return matches[1] end
  return nil
end

local function wikiFileName(name)
  if not name or name == "" then return nil end
  if name:match("%.[A-Za-z0-9]+$") then return name end
  return name .. ".png"
end

local function addImage(node, name, _size, alt)
  local filename = wikiFileName(name)
  if not filename then return false end
  node:wikitext(string.format(
    "[[File:%s|link=|alt=%s]]",
    filename,
    plain(alt or "")
  ))
  return true
end

local function addPageLink(node, title, label)
  title = SeasonData.title(title)
  if not title then return node end
  node:wikitext(string.format("[[%s|%s]]", title, plain(label or title)))
  return node
end

local function stripType(typeName)
  return trim(typeName) and tostring(typeName):gsub("系$", "") or nil
end

local function typeId(typeName)
  local short = stripType(typeName)
  if not short then return nil end
  return (themeData.ids or {})[short]
end

local function typeTipsFile(typeName)
  local id = typeId(typeName)
  return id and ("TypeTips_" .. id .. ".png") or nil
end

local function typeIconFile(typeName)
  local id = typeId(typeName)
  return id and ("Type_" .. id .. ".png") or nil
end

local function skillCatIcon(category)
  return category and SKILL_CAT_ICONS[category] or nil
end

local function skillIcon(skill)
  if not skill then return nil end
  return trim(skill.icon)
end

local function shinyIllustration(image)
  if image and image.shiny then return image.shiny end
  local file = image and image.illustration
  if not file then return nil end
  return tostring(file):gsub("%.png$", "_yise.png")
end

-- 小头像只切换明确登记的异色资源；没有异色头像时保留原色。
local function renderAppearanceAvatar(parent, image, name, hasShiny, fallback)
  image = image or {}
  local normal = image.head or fallback
  if not normal then return end
  parent:addClass("roco-appearance-avatar")
  local original = parent:tag("span"):addClass("roco-avatar-look is-on"):attr("data-avatar-look", "normal")
  addImage(original, normal, nil, name or "")
  if hasShiny and image.shiny_head and image.shiny_head ~= normal then
    local shiny = parent:tag("span"):addClass("roco-avatar-look"):attr("data-avatar-look", "shiny")
    addImage(shiny, image.shiny_head, nil, (name or "") .. "异色头像")
  end
end

local function firstType(pet)
  local types = pet.types or {}
  return stripType(types[1]) or themeData.fallback
end

local function themeFor(typeName)
  local colors = themeData.colors or {}
  return colors[typeName] or colors[themeData.fallback]
end

local petCatalog
local function loadPet(petId)
  if not petCatalog then
    petCatalog = SeasonData.get("Catalog")
  end
  return petCatalog[petId]
end

local skillCatalog
local function loadSkills()
  if not skillCatalog then
    skillCatalog = SeasonData.get("Skills")
  end
  return skillCatalog
end

local function loadLearnset(referenceId)
  if not referenceId then return nil end
  return SeasonData.learnset(referenceId)
end

local skillStoneTopicCatalog
local function loadSkillStoneTopics(skillId)
  if not skillStoneTopicCatalog then
    skillStoneTopicCatalog = SeasonData.get("SkillStoneTopics")
  end
  return skillStoneTopicCatalog[skillId] or {}
end

local evolutionCatalog
local function loadEvolution(referenceId)
  if not referenceId then return nil end
  if not evolutionCatalog then
    evolutionCatalog = SeasonData.get("Evolutions")
  end
  return evolutionCatalog[referenceId]
end

local function loadHandbook(referenceId)
  if not referenceId then return nil end
  return SeasonData.handbook(referenceId)
end

local descNotesCatalog
local function loadDescNotes()
  if not descNotesCatalog then
    descNotesCatalog = SeasonData.get("Terms")
  end
  return descNotesCatalog
end

local typeRelations
local function loadTypeRelations(relationKey)
  if not typeRelations then
    typeRelations = mw.loadData("Module:Pets/data/Types")
  end
  return typeRelations[relationKey] or {}
end

local function loadHistory(petId)
  if not (index.has_history and index.has_history[petId]) then return nil, nil end
  return SeasonData.history(petId)
end

local configData
local function loadConfig()
  if not configData then
    configData = SeasonData.get("Config")
  end
  return configData
end

local dungeonIndex
local dungeonIndexLoaded = false
local function dungeonTitle(dungeonId)
  if not trim(dungeonId) then return nil end
  if not dungeonIndexLoaded then
    local loaded, data = pcall(mw.loadData, "Module:Dungeons/data/Index")
    dungeonIndex = loaded and data or {}
    dungeonIndexLoaded = true
  end
  return ((dungeonIndex or {}).titles or {})[dungeonId]
end

local function eggGroupText(groups)
  local names = {}
  for _, groupId in ipairs(groups or {}) do
    if EGG_GROUP_NAMES[groupId] then names[#names + 1] = EGG_GROUP_NAMES[groupId] end
  end
  return #names > 0 and table.concat(names, " / ") or nil
end

local function skillCategory(skill)
  if not skill then return nil end
  if skill.category == "攻击" and trim(skill.damage_class) then
    return skill.damage_class
  end
  return skill.category
end

-- 异色蛋共用外观，物品 ID 与获取来源不同不代表多一种蛋图。
local function collectEggFiles(eggFile, eggs)
  local files = { eggFile }
  for _, egg in ipairs(eggs or {}) do
    if egg.is_shiny and trim(egg.icon) then
      if egg.icon ~= eggFile then files[#files + 1] = egg.icon end
      break
    end
  end
  return files
end

local function collectSkillEntries(learnset, skills, petTypes, petStats)
  local entries = {}
  local function append(source, entry, skillId)
    local skill = skills[skillId]
    if skill then
      entries[#entries + 1] = {
        source = source,
        entry = entry or {},
        skill = skill,
        skillId = skillId,
        originalOrder = #entries + 1,
      }
    end
  end
  for _, entry in ipairs(learnset.native_skills or {}) do
    append("level", entry, entry.skill)
  end
  for _, skillId in ipairs(learnset.skill_stones or {}) do
    append("machine", {}, skillId)
  end
  for _, entry in ipairs(learnset.blood_skills or {}) do
    append("blood", entry, entry.skill)
  end
  local legendary = learnset.legendary
  if legendary and legendary.skill then
    append("legendary", legendary, legendary.skill)
  end
  local primaryType = stripType((petTypes or {})[1])
  local secondaryType = stripType((petTypes or {})[2])
  local byType, typeOrder, blood = {}, {}, {}
  for _, item in ipairs(entries) do
    if item.source == "blood" then
      blood[#blood + 1] = item
    else
      local skillType = stripType(item.skill.element) or ""
      if not byType[skillType] then
        byType[skillType] = {}
        typeOrder[#typeOrder + 1] = skillType
      end
      local group = byType[skillType]
      group[#group + 1] = item
    end
  end
  local function typePriority(value)
    if primaryType and value == primaryType then return 1 end
    if secondaryType and value == secondaryType then return 2 end
    return 3
  end
  table.sort(typeOrder, function(left, right)
    local leftPriority, rightPriority = typePriority(left), typePriority(right)
    if leftPriority ~= rightPriority then return leftPriority < rightPriority end
    if #byType[left] ~= #byType[right] then return #byType[left] > #byType[right] end
    return byType[left][1].originalOrder < byType[right][1].originalOrder
  end)
  local grouped = {}
  for _, element in ipairs(typeOrder) do grouped[#grouped + 1] = byType[element] end
  grouped[#grouped + 1] = blood
  -- 先完整聚合同一系别，再按攻击倾向、威力排序；血脉保持独立末组。
  local stats = petStats or {}
  local physicalFirst = (tonumber(stats.atk) or 0) > (tonumber(stats.spa) or 0)
  local categoryOrder = {
    ["物攻"] = physicalFirst and 1 or 2,
    ["魔攻"] = physicalFirst and 2 or 1,
    ["防御"] = 3,
    ["状态"] = 4,
  }
  local sorted = {}
  for _, group in ipairs(grouped) do
    table.sort(group, function(left, right)
      local leftCategory = categoryOrder[skillCategory(left.skill)] or 5
      local rightCategory = categoryOrder[skillCategory(right.skill)] or 5
      if leftCategory ~= rightCategory then return leftCategory < rightCategory end
      local leftPower = tonumber(left.skill.power) or 0
      local rightPower = tonumber(right.skill.power) or 0
      if leftPower ~= rightPower then return leftPower < rightPower end
      return left.originalOrder < right.originalOrder
    end)
    for _, item in ipairs(group) do
      sorted[#sorted + 1] = item
    end
  end
  return sorted
end

local function skillLevelLabel(item)
  if item.source == "level" and item.entry.level ~= nil then
    return "LV" .. tostring(item.entry.level)
  end
  if item.source == "blood" then
    return item.entry.blood and ("血脉·" .. item.entry.blood) or "血脉"
  end
  if item.source == "machine" then return "技能石" end
  if item.source == "legendary" then return "传说" end
  return ""
end

local function powerText(skill)
  if skill.power_text then return skill.power_text end
  if skill.power == nil then return "--" end
  return tostring(skill.power)
end

local function energyText(skill)
  if skill.energy == nil then return "--" end
  return tostring(skill.energy)
end

local function splitMeasure(raw)
  raw = trim(raw)
  if not raw then return nil, nil end
  local num, unit = raw:match("^(.-)%s*([A-Za-z]+)%s*$")
  if not num then return raw, nil end
  return mw.text.trim(num), string.lower(unit)
end

local function rewardFile(icon)
  if not trim(icon) then return nil end
  return tostring(icon)
end

local function romanAt(position)
  return ROMANS[position] or tostring(position)
end

local function formatPoolPercent(weight, total)
  if not tonumber(weight) or not tonumber(total) or total <= 0 then return nil end
  local percent = weight / total * 100
  if percent >= 10 then return string.format("%.0f%%", percent) end
  if percent >= 1 then return string.format("%.1f%%", percent) end
  return string.format("%.2f%%", percent)
end

local function formatHistoryValue(value)
  if value == nil then return "无" end
  if type(value) ~= "table" then return tostring(value) end
  local values = {}
  for _, item in ipairs(value) do values[#values + 1] = tostring(item) end
  return #values > 0 and table.concat(values, "、") or "无"
end

local function renderError(key)
  local root = mw.html.create("div"):addClass("roco-dex-error")
  addText(root:tag("strong"), "无法确定精灵数据")
  addText(root:tag("p"), "查询值：" .. (key or ""))
  local matches = (index.by_name or {})[key or ""] or {}
  if matches[2] ~= nil then
    addText(root:tag("p"), "存在多个同名形态，请使用 id 参数：")
    local list = root:tag("div"):attr("data-nrc-tag", "ul")
    for _, petId in ipairs(matches) do
      addPageLink(list:tag("div"):attr("data-nrc-tag", "li"), index.titles[petId], index.titles[petId])
    end
  end
  return tostring(root)
end

local function addTypeChip(parent, typeName, className, size)
  local short = stripType(typeName)
  local chip = parent:tag("span"):addClass(className or "roco-type-chip")
  if short then
    chip:attr("data-type", short)
    local theme = themeFor(short)
    if theme and theme.tile then chip:attr("data-tile", theme.tile) end
  end
  if short and short ~= "无" and short ~= "无系别" then
    addImage(chip, typeIconFile(short), size or "18x18px", short)
  end
  addText(chip:tag("span"), short or typeName)
  return chip
end

local function renderDash(parent)
  parent:tag("div"):addClass("roco-dash"):attr("aria-hidden", "true")
end

local function renderRichText(parent, description, noteRefs, className)
  local container = parent:tag("div"):addClass(className or "roco-rich")
  local text = tostring(description or "")
  if not hasItems(noteRefs) then
    addText(container, text)
    return container
  end
  local notes = loadDescNotes()
  local cursor = 1
  for _, ref in ipairs(noteRefs) do
    local noteId = type(ref) == "table" and ref[1] or ref
    local note = notes[noteId]
    local label = type(ref) == "table" and ref[2] or (note and note.note)
    if note and trim(label) then
      local startAt, endAt = string.find(text, tostring(label), cursor, true)
      if startAt then
        if startAt > cursor then
          addText(container, string.sub(text, cursor, startAt - 1))
        end
        local mark = container:tag("span")
          :addClass("roco-hl")
          :attr("data-note", tostring(noteId))
          :attr("title", note.desc or "")
        addText(mark, label)
        cursor = endAt + 1
      end
    end
  end
  if cursor <= string.len(text) then
    addText(container, string.sub(text, cursor))
  end
  return container
end

local function descNoteDetails(noteRefs)
  if not hasItems(noteRefs) then return {} end
  local notes = loadDescNotes()
  local details = {}
  local seen = {}
  for _, ref in ipairs(noteRefs) do
    local noteId = type(ref) == "table" and ref[1] or ref
    local note = notes[noteId]
    local label = type(ref) == "table" and ref[2] or (note and note.note)
    if note and trim(label) and trim(note.desc) and not seen[noteId] then
      seen[noteId] = true
      details[#details + 1] = {
        label = label,
        description = note.desc,
      }
    end
  end
  return details
end

local function renderIdentity(parent, pet)
  local bar = parent:tag("div"):addClass("roco-ident")
  local identity = bar:tag("div"):addClass("roco-ident-name")
  addText(identity:tag("span"):addClass("roco-no"), pet.number or "???")
  addText(identity:tag("span"):addClass("roco-name"), pet.name or pet.title or "")
  identity:tag("span"):addClass("roco-glyph")
  bar:tag("span"):addClass("roco-spacer")
  local types = bar:tag("div"):addClass("roco-ident-types")
  for _, raw in ipairs(pet.types or {}) do
    addTypeChip(types, raw, "roco-type", "28x28px")
  end
end

local function renderNav(parent)
  local nav = parent:tag("div"):addClass("roco-nav"):attr("role", "tablist"):attr("aria-label", "图鉴栏目")
  for i, item in ipairs(NAV) do
    local tab = nav:tag("span"):addClass("roco-nav-item")
      :attr("data-panel", item.key)
      :attr("role", "tab")
      :attr("aria-controls", "rocodex-" .. item.key)
      :attr("tabindex", i == 1 and "0" or "-1")
      :attr("aria-selected", i == 1 and "true" or "false")
    if i == 1 then tab:addClass("is-active") end
    addImage(tab:tag("span"):addClass("roco-nav-ico"), "Ui_PetInfo.png", nil, "")
    addText(tab, item.label)
    if i < #NAV then
      nav:tag("span"):addClass("roco-nav-sep"):attr("aria-hidden", "true")
    end
  end
end

local function renderView(parent, key, file, label, selected)
  local btn = parent:tag("div"):addClass("roco-vt")
    :attr("data-view", key)
    :attr("title", label)
    :attr("role", "button")
    :attr("tabindex", "0")
  if selected then btn:addClass("is-on") end
  if key == "model" then btn:attr("aria-label", label) end
  if file then addImage(btn, file, nil, label) end
end

local function renderPetNavigation(parent, pet)
  local index = SeasonData.get("Index")
  local navigation = parent:tag("div"):addClass("roco-pet-navigation")
    :attr("role", "navigation"):attr("aria-label", "精灵图鉴导航")
  local position = (index.handbook_position or {})[tostring(pet.number)]
  local order = index.handbook_order or {}
  local function neighbor(direction, offset, label, arrow)
    local id = position and order[position + offset]
    local slot = navigation:tag("div"):addClass("roco-pet-neighbor is-" .. direction)
    if not id or not index.titles[id] then return end
    local link = slot:tag("div"):addClass("roco-pet-nav-link")
    addPageLink(link:tag("span"):addClass("roco-pet-nav-target"), index.titles[id], label .. "：" .. index.titles[id])
    link:tag("i"):addClass("fa-solid fa-chevron-" .. arrow):attr("aria-hidden", "true")
    addImage(link:tag("div"):addClass("roco-pet-nav-avatar"), (index.avatars or {})[id], nil, "")
    local copy = link:tag("div"):addClass("roco-pet-nav-copy")
    local number = (index.numbers or {})[id] or (loadPet(id) or {}).number
    addText(copy:tag("div"):addClass("roco-pet-nav-direction"), tostring(number or ""))
    addText(copy:tag("div"):addClass("roco-pet-nav-name"), index.titles[id])
  end
  neighbor("previous", -1, "上一只", "left")
  local home = navigation:tag("div"):addClass("roco-pet-nav-home")
  addPageLink(home:tag("span"):addClass("roco-pet-nav-target"), "精灵图鉴", "返回精灵图鉴总览")
  home:tag("i"):addClass("fa-solid fa-table-cells-large"):attr("aria-hidden", "true")
  addText(home:tag("div"), "图鉴总览")
  neighbor("next", 1, "下一只", "right")
end

local function renderLeft(parent, pet)
  local index = SeasonData.get("Index")
  local image = pet.image or {}
  local col = parent:tag("div"):addClass("roco-col-l"):attr("id", "rocodex-pAppear")
  local card = col:tag("div"):addClass("roco-art-card")
  local top = card:tag("div"):addClass("roco-art-top")
  local forms = {}
  for _, siblingId in ipairs(pet.siblings or {}) do
    local sibling = loadPet(siblingId)
    if sibling and siblingId ~= pet.id and (index.titles or {})[siblingId] then
      forms[#forms + 1] = { id = siblingId, pet = sibling }
    end
  end
  if #forms > 0 then
    local allForms = { { id = pet.id, pet = pet } }
    local formCounts, groupedForms = {}, false
    for _, entry in ipairs(forms) do allForms[#allForms + 1] = entry end
    for _, entry in ipairs(allForms) do
      local label = trim(entry.pet.form) or "本来的样子"
      formCounts[label] = (formCounts[label] or 0) + 1
      if formCounts[label] > 1 then groupedForms = true end
    end
    local currentLabel = trim(pet.form) or "本来的样子"
    if groupedForms then currentLabel = (pet.name or "") .. " · " .. currentLabel end
    local form = top:tag("span"):addClass("roco-form-pill")
      :attr("role", "button"):attr("tabindex", "0"):attr("aria-expanded", "false")
    addText(form:tag("span"):addClass("roco-form-label"), currentLabel)
    form:tag("span"):addClass("roco-form-arrow"):tag("i"):addClass("fa-solid fa-chevron-down")
    local menu = top:tag("div"):addClass("roco-form-menu")
    local function option(parentNode, entry, label)
      local row = parentNode:tag("div"):addClass("roco-form-opt")
      if entry.id == pet.id then
        row:addClass("is-current"):attr("aria-current", "page")
        addText(row, label)
      else
        addPageLink(row, index.titles[entry.id], label)
      end
    end
    if groupedForms then
      table.sort(allForms, function(left, right) return left.id < right.id end)
      local groups, groupOrder = {}, {}
      for _, entry in ipairs(allForms) do
        local label = trim(entry.pet.form) or "本来的样子"
        if not groups[label] then
          groups[label] = {}
          groupOrder[#groupOrder + 1] = label
        end
        groups[label][#groups[label] + 1] = entry
      end
      for _, label in ipairs(groupOrder) do
        local group = menu:tag("div"):addClass("roco-form-group")
        addText(group:tag("div"):addClass("roco-form-group-title"), label)
        table.sort(groups[label], function(left, right)
          local leftLord, rightLord = left.pet.is_lord_evolution == true, right.pet.is_lord_evolution == true
          if leftLord ~= rightLord then return not leftLord end
          return left.id < right.id
        end)
        for _, entry in ipairs(groups[label]) do
          local name = entry.pet.name or index.titles[entry.id]
          if entry.pet.is_lord_evolution then name = name .. " · 首领" end
          option(group, entry, name)
        end
      end
    else
      option(menu, allForms[1], trim(pet.form) or "本来的样子")
      for _, entry in ipairs(forms) do
        option(menu, entry, trim(entry.pet.form) or entry.pet.name or index.titles[entry.id])
      end
    end
  elseif not image.head then
    top:addClass("is-empty")
  end
  if image.head then
    renderAppearanceAvatar(top:tag("div"):addClass("roco-art-avatar"), image, pet.name, pet.has_shiny)
  end
  --[[ 暂停生成简要信息图片导出入口，保留代码以便恢复。
  local download = top:tag("span")
    :addClass("roco-art-download")
    :attr("hidden", "hidden")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("title", "生成精灵简要信息图片")
  download:tag("i"):addClass("fa-solid fa-file-image")
  ]]
  local stage = card:tag("div"):addClass("roco-stage-art")
  local acquisitionPet = pet
  local acquisitionPetId = (pet.ecology or {}).acquisition_pet_id
  if acquisitionPetId then acquisitionPet = loadPet(acquisitionPetId) or pet end
  local acquisitionImage = acquisitionPet.image or {}
  local views = {}
  if image.illustration then
    views[#views + 1] = { key = "pet", file = image.illustration, label = "精灵外观" }
  end
  if pet.has_shiny and image.illustration then
    views[#views + 1] = { key = "shiny", file = shinyIllustration(image), label = "异色外观" }
  end
  local eggFile = image.egg or acquisitionImage.egg
  if eggFile then
    local eggFiles = collectEggFiles(eggFile, (acquisitionPet.ecology or {}).eggs)
    views[#views + 1] = {
      key = "egg",
      file = eggFile,
      files = eggFiles,
      label = #eggFiles > 1 and "精灵蛋与异色蛋" or "孵蛋组别",
    }
  end
  local fruitFile = image.fruit or (image.fruits and image.fruits[1])
    or acquisitionImage.fruit or (acquisitionImage.fruits and acquisitionImage.fruits[1])
  if fruitFile then
    views[#views + 1] = { key = "fruit", file = fruitFile, label = "喜好果实" }
  end
  if #views == 0 then
    views[1] = { key = "pet", file = image.head, label = "精灵外观" }
  end
  for i, view in ipairs(views) do
    local art = stage:tag("div"):addClass("roco-art"):attr("data-view", view.key)
    if i == 1 then art:addClass("is-on") end
    local files = view.files or { view.file }
    if #files > 1 then art:addClass("is-multi") end
    for fileIndex, file in ipairs(files) do
      local alt = pet.name or ""
      if view.key == "egg" and fileIndex > 1 then alt = alt .. "异色蛋" end
      addImage(art, file, nil, alt)
    end
  end
  if #views > 1 then
    local tabs = card:tag("div"):addClass("roco-view-tabs")
    for i, view in ipairs(views) do
      local tabFile = ({
        pet = "Ui_Pet.png",
        shiny = "Ui_Shiny.png",
        egg = "Ui_Egg.png",
        fruit = "Ui_Fruit.png",
        model = "Ui_ViewPetOutline.png",
      })[view.key] or view.file
      renderView(tabs, view.key, tabFile, view.label, i == 1)
    end
  end
  if trim(pet.description) then
    local desc = col:tag("div"):addClass("roco-desc")
    desc:tag("span"):addClass("roco-desc-dot"):attr("aria-hidden", "true")
    addText(desc:tag("span"), pet.description)
  end
end

local function renderPowerPill(parent, skill)
  local short = stripType(skill.element) or "普通"
  local pill = parent:tag("span"):addClass("roco-sk-pill"):attr("data-type", short)
  if short ~= "无" and short ~= "无系别" then
    addImage(pill, typeTipsFile(short), "x24px", short)
  end
  addText(pill:tag("span"):addClass("roco-sk-pill-num"), powerText(skill))
  return pill
end

local function topicSkillNames(topics)
  local names = {}
  local seen = {}
  for _, topic in ipairs(topics or {}) do
    for _, reward in ipairs(topic.rewards or {}) do
      local icon = tostring(reward.icon or "")
      local name = trim(reward.name)
      if name and icon:match("^Item_23") and not name:match("^配方") and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  return names
end

local function topicSkillIcon(topics)
  for _, topic in ipairs(topics or {}) do
    for _, reward in ipairs(topic.rewards or {}) do
      local icon = tostring(reward.icon or "")
      local name = trim(reward.name)
      if name and icon:match("^Item_23") and not name:match("^配方") then
        return icon
      end
    end
  end
  return nil
end

local function skillNameIndex(entries)
  local map = {}
  for _, item in ipairs(entries) do
    if item.skill.name then map[item.skill.name] = item.skill end
  end
  return map
end

local function findSkillQuest(topics, skillName)
  if not skillName then return nil end
  for _, topic in ipairs(topics or {}) do
    local text = topic.text or ""
    if text:find(skillName, 1, true) then return text end
  end
  return nil
end

local function renderMeasurePill(parent, raw, extraClass, icon, iconAlt)
  local num, unit = splitMeasure(raw)
  if not num then return end
  local pill = parent:tag("span"):addClass("roco-pill")
  if extraClass then pill:addClass(extraClass) end
  if icon then
    local ico = pill:tag("span"):addClass("roco-pill-ico")
    addImage(ico, icon, "22x22px", iconAlt or "")
  end
  addText(pill, num)
  if unit then addText(pill:tag("span"):addClass("roco-pill-unit"), unit) end
end

local function renderIconPill(parent, extraClass, icon, iconAlt, text)
  if not trim(text) then return end
  local pill = parent:tag("span"):addClass("roco-pill")
  if extraClass then pill:addClass(extraClass) end
  if icon then
    local ico = pill:tag("span"):addClass("roco-pill-ico")
    addImage(ico, icon, "22x22px", iconAlt or "")
  end
  addText(pill, text)
  return pill
end

local function renderStat(parent, pet, field)
  local stats = pet.stats or {}
  local value = tonumber(stats[field.key]) or 0
  local row = parent:tag("div"):addClass("roco-stat")
  local lab = row:tag("span"):addClass("roco-stat-lab")
  if field.icon then
    local ico = lab:tag("span"):addClass("roco-stat-ico")
    addImage(ico, field.icon, "36x36px", field.label)
  end
  local wrap = lab:tag("span"):addClass("roco-stat-txt")
  addText(wrap:tag("span"):addClass("roco-stat-name"), field.label)
  if field.rune then
    wrap:tag("span"):addClass("roco-stat-rune"):attr("data-rune", field.rune)
  end
  local bar = row:tag("span"):addClass("roco-stat-bar")
  bar:tag("span")
    :addClass("roco-stat-fill")
    :attr("data-fill", tostring(math.min(100, math.floor(value / 1.8 + 0.5))))
    :css("width", tostring(math.min(100, math.floor(value / 1.8 + 0.5))) .. "%")
  local val = row:tag("span"):addClass("roco-stat-val"):attr("data-val", tostring(value))
  addText(val, tostring(value))
end

local function renderRelations(parent, relations)
  relations = relations or {}
  if not hasItems(relations.weak) and not hasItems(relations.resist) then return end
  renderDash(parent)
  local head = parent:tag("div"):addClass("roco-subhead")
  addImage(head:tag("span"):addClass("roco-subhead-ico"), "SkillCat_Status.png", "24x24px", "")
  addText(head:tag("span"), "受击关系")
  local grouped = {}
  local function collect(items)
    for _, item in ipairs(items or {}) do
      local multiplier = tonumber(item.multiplier)
      if multiplier and multiplier ~= 0 then
        local key = tostring(multiplier)
        grouped[key] = grouped[key] or { multiplier = multiplier, types = {} }
        grouped[key].types[#grouped[key].types + 1] = item.type
      end
    end
  end
  collect(relations.weak)
  collect(relations.resist)
  local rows = {}
  for _, group in pairs(grouped) do rows[#rows + 1] = group end
  table.sort(rows, function(left, right) return left.multiplier > right.multiplier end)
  local box = parent:tag("div"):addClass("roco-rel-box")
  for _, group in ipairs(rows) do
    local tone = group.multiplier > 1 and "weak" or "resist"
    local row = box:tag("div"):addClass("roco-rel-row roco-rel-row--" .. tone)
    local mult = group.multiplier == math.floor(group.multiplier)
      and tostring(math.floor(group.multiplier))
      or tostring(group.multiplier)
    addText(
      row:tag("span"):addClass("roco-rel-badge"),
      "×" .. mult .. (tone == "weak" and " 弱点" or " 抵抗")
    )
    local chips = row:tag("div"):addClass("roco-rel-chips")
    for _, typeName in ipairs(group.types) do
      addTypeChip(chips, typeName, "roco-rel-chip", "16x16px")
    end
  end
end

local function renderTalents(parent, pet)
  -- S4 同乘资格按当前进化链判断，展示沿用原同乘特长概率表（1002）。
  local poolId = pet.can_double_ride and 1002 or pet.talent_pool_id
  local pool = poolId and (loadConfig().talent_pools or {})[poolId]
  if not pool or not hasItems(pool.entries) then return end
  renderDash(parent)
  local head = parent:tag("div"):addClass("roco-subhead")
  addImage(head:tag("span"):addClass("roco-subhead-ico"), "Ui_Talent.png", "18x18px", "")
  addText(head:tag("span"), "特长概率")
  local list = parent:tag("div"):addClass("roco-talent-list")
  for _, entry in ipairs(pool.entries) do
    local pill = list:tag("span"):addClass("roco-talent")
    if entry.name == "同乘" then pill:addClass("is-ride") end
    addText(pill:tag("span"):addClass("roco-talent-name"), entry.name or "")
    local percent = formatPoolPercent(entry.weight, pool.total)
    if percent then addText(pill:tag("span"):addClass("roco-talent-pct"), percent) end
    if trim(entry.desc) then pill:attr("title", entry.desc) end
  end
  addText(
    parent:tag("p"):addClass("roco-talent-note"),
    "一般般的天分无法获得特长。"
  )
end

local function latestStamp(events, versions, pet)
  local date
  for i = arrayCount(events), 1, -1 do
    local event = events[i]
    local version = (versions or {})[event.version] or {}
    if version.display_date or version.date then
      date = version.display_date or version.date
      break
    end
  end
  if not date then
    date = pet.release and pet.release.date
  end
  return date
end

local function renderInfo(parent, pet, feature, entries, topics, relations, events, versions)
  local box = parent:tag("div"):addClass("roco-block")
  if trim(pet.class) then addText(box:tag("div"):addClass("roco-kicker"), pet.class) end
  if feature then
    local feat = box:tag("div"):addClass("roco-feature")
    if feature.effect_details then feat:addClass("has-combat-details") end
    local emblem = feat:tag("div"):addClass("roco-feature-emblem")
    if skillIcon(feature) then
      local icon = emblem:tag("div"):addClass("roco-feature-icon")
      addImage(icon, skillIcon(feature), "64x64px", feature.name or "")
    end
    local badge = emblem:tag("div"):addClass("roco-feature-badge")
    addText(badge, "特性")
    local copy = feat:tag("div"):addClass("roco-feature-copy")
    local featureHead = copy:tag("div"):addClass("roco-feature-head")
    featureHead:tag("span"):addClass("roco-feature-vline"):attr("aria-hidden", "true")
    addText(featureHead:tag("span"):addClass("roco-feature-name"), feature.name or "特性")
    local noteDetails = descNoteDetails(feature.desc_notes)
    local hasDetails = #noteDetails > 0 or feature.effect_details ~= nil
    if hasDetails then
      local detailButton = featureHead:tag("span")
        :addClass("roco-feature-detail-btn")
        :attr("role", "button")
        :attr("tabindex", "0")
        :attr("aria-expanded", "false")
      addText(detailButton, "特性详解")
      detailButton:tag("i"):addClass("fa-solid fa-chevron-down")
    end
    renderRichText(copy, feature.desc or "", feature.desc_notes, "roco-feature-desc")
    if hasDetails then
      local drawer = copy:tag("div"):addClass("roco-feature-drawer")
      CombatEffects.render(drawer, feature, true)
      for _, detail in ipairs(noteDetails) do
        local row = drawer:tag("div"):addClass("roco-feature-detail-row")
        addText(row:tag("strong"), tostring(detail.label) .. "：")
        addText(row:tag("span"), detail.description)
      end
    end
  end
  renderDash(box)
  local race = box:tag("div"):addClass("roco-race-head")
  addImage(
    race:tag("span"):addClass("roco-race-ico"):attr("aria-hidden", "true"),
    "Ui_Race.png",
    nil,
    ""
  )
  addText(race:tag("span"):addClass("roco-race-title"), "种族资质")
  local total = 0
  for _, field in ipairs(STAT_FIELDS) do
    total = total + (tonumber((pet.stats or {})[field.key]) or 0)
  end
  local totalNode = race:tag("span"):addClass("roco-race-total"):attr("data-val", tostring(total))
  addText(totalNode, tostring(total))
  local list = box:tag("div"):addClass("roco-stat-list")
  for _, field in ipairs(STAT_FIELDS) do
    renderStat(list, pet, field)
  end
  renderDash(box)
  local pills = box:tag("div"):addClass("roco-pills")
  renderMeasurePill(pills, pet.weight, "is-half", "Ui_Weight.png", "体重")
  renderMeasurePill(pills, pet.height, "is-half", "Ui_Height.png", "身高")
  if pet.starlight then
    renderIconPill(pills, "is-half", "Item_6.png", "星光值", tostring(pet.starlight))
  end
  if pet.review_gold then
    local reviewGold = (tonumber(pet.review_gold) or 0) * 1.5
    if reviewGold == math.floor(reviewGold) then reviewGold = math.floor(reviewGold) end
    renderIconPill(pills, "is-half", "Item_1.png", "洛克贝", tostring(reviewGold))
  end
  local stoneNames = topicSkillNames(topics)
  if #stoneNames > 0 then
    local byName = skillNameIndex(entries)
    local stone = pills:tag("span"):addClass("roco-pill is-wide")
    local ico = stone:tag("span"):addClass("roco-pill-ico")
    addImage(ico, topicSkillIcon(topics), "22x22px", "技能石")
    local names = stone:tag("span"):addClass("roco-skill-names")
    for _, name in ipairs(stoneNames) do
      local skill = byName[name]
      local short = skill and stripType(skill.element) or nil
      local node = names:tag("span")
      if short then node:addClass("roco-t-" .. short) end
      addPageLink(node, name, name)
    end
  end
  local eggs = eggGroupText(pet.egg_group)
  if eggs then
    local egg = pills:tag("span"):addClass("roco-pill is-wide")
    addImage(egg:tag("span"):addClass("roco-pill-ico"), "Ui_Egg.png", nil, "蛋组")
    addText(egg, "蛋组：" .. eggs)
  end
  renderRelations(box, relations)
  renderTalents(box, pet)
  local stamp = latestStamp(events, versions, pet)
  if stamp then
    local foot = box:tag("div"):addClass("roco-info-foot")
    local time = foot:tag("span"):addClass("roco-time-pill")
    addText(time:tag("span"):addClass("roco-time-lab"), "数据库更新时间：")
    addText(time:tag("span"):addClass("roco-time-val"), tostring(stamp):gsub("-", "/"))
    local go = foot:tag("span")
      :addClass("roco-go-hist")
      :attr("data-panel", "pHistory")
      :attr("role", "button")
      :attr("tabindex", "0")
      :attr("title", "查看历史变动")
    go:tag("i"):addClass("fa-solid fa-chevron-right")
  end
end

local function renderEmpty(parent, text)
  addText(parent:tag("div"):addClass("roco-empty"), text)
end

local function renderSkillCard(grid, item, topics, reuseDescription)
  local skill = item.skill
  local category = skillCategory(skill) or ""
  local element = stripType(skill.element) or ""
  -- 学院呱呱逐项转为文本，避免同时保留完整技能节点树。
  local card = (reuseDescription and mw.html.create("div") or grid:tag("div"))
    :addClass("roco-sk-card")
    :attr("data-source", item.source)
    :attr("data-skill-id", item.skillId)
    :attr("data-type", element)
    :attr("data-cat", category)
    :attr("data-power", tostring(skill.power or ""))
    :attr("data-energy", tostring(skill.energy or ""))
    :attr("data-name", skill.name or "")
    :attr("role", "button")
    :attr("tabindex", "0")
  if category ~= "" then
    local cat = card:tag("span"):addClass("roco-sk-cat"):attr("title", category)
    addImage(cat, skillCatIcon(category), "24x24px", category)
  end
  local ico = card:tag("div"):addClass("roco-sk-ico")
  if skillIcon(skill) then
    addImage(ico, skillIcon(skill), "64x64px", skill.name or "")
  end
  local cost = ico:tag("span"):addClass("roco-sk-cost")
  addImage(cost, "Stat_Energy.png", "14x14px", "能耗")
  addText(cost, energyText(skill))
  addText(card:tag("div"):addClass("roco-sk-name"), skill.name or "")
  local miniType = card:tag("div"):addClass("roco-sk-mini-type")
    :attr("title", element .. "系"):attr("aria-hidden", "true")
  addImage(miniType, typeIconFile(element), "24x24px", "")
  local meta = card:tag("div"):addClass("roco-sk-meta")
  renderPowerPill(meta, skill)
  addText(card:tag("div"):addClass("roco-sk-lv"), skillLevelLabel(item))
  if trim(skill.desc) then
    if reuseDescription then
      -- 大技能表复用详情中的说明，避免同一内容在嵌套模板中重复计入展开大小。
      card:tag("div"):addClass("roco-sk-card-desc")
    else
      renderRichText(card, skill.desc, skill.desc_notes, "roco-sk-card-desc")
    end
  end
  local quest = findSkillQuest(topics, skill.name)
  if quest then card:attr("data-quest", quest) end
  if reuseDescription then grid:wikitext(tostring(card)) end
end

local function renderSkillStoneSources(parent, skillId)
  local sources = loadSkillStoneTopics(skillId)
  local section = parent:tag("div"):addClass("roco-sk-sources")
  if not hasItems(sources) then
    addText(
      section:tag("div"):addClass("roco-sk-source-empty"),
      "暂未发现对应的图鉴课题"
    )
    return
  end
  local list = section:tag("div"):addClass("roco-sk-source-list")
  for _, source in ipairs(sources) do
    local row = list:tag("div"):addClass("roco-sk-source")
    local avatar = row:tag("div"):addClass("roco-sk-source-avatar")
    addImage(avatar, source.head, "42x42px", source.pet_name or "")
    local copy = row:tag("div"):addClass("roco-sk-source-copy")
    local petName = copy:tag("div"):addClass("roco-sk-source-pet")
    addPageLink(petName, (index.titles or {})[source.pet_id] or source.pet_name, source.pet_name)
    local topic = copy:tag("div"):addClass("roco-sk-source-topic")
    addText(topic:tag("div"):addClass("roco-sk-source-label"), "图鉴课题")
    addText(topic:tag("div"):addClass("roco-sk-source-task"), source.topic or "")
  end
end

local function renderSkillDetail(parent, item, topics, compact)
  local skill = item.skill
  local category = skillCategory(skill) or ""
  -- 仅学院呱呱逐项序列化详情，其他精灵沿用原有节点树。
  local block = (compact and mw.html.create("div") or parent:tag("div"))
    :addClass("roco-sk-ditem")
    :attr("data-skill-id", item.skillId)
    :attr("data-source", item.source)
  local card = block:tag("div"):addClass("roco-sk-dcard")
  local head = card:tag("div"):addClass("roco-sk-dhead")
  local ico = head:tag("div"):addClass("roco-sk-dico")
  if skillIcon(skill) then
    addImage(ico, skillIcon(skill), "72x72px", skill.name or "")
  end
  local info = head:tag("div"):addClass("roco-sk-dinfo")
  if skill.name then
    addPageLink(info:tag("div"):addClass("roco-sk-dtitle"), SeasonData.skillTitle(skill), skill.name)
  end
  local tags = info:tag("div"):addClass("roco-sk-dtags")
  local canvasType = tags:tag("span")
    :addClass("roco-sk-canvas-type-icon")
    :attr("aria-hidden", "true")
  addImage(canvasType, typeIconFile(skill.element), "28x28px", stripType(skill.element) or "")
  if category ~= "" then
    local cat = tags:tag("span"):addClass("roco-sk-dpill")
    addImage(cat, skillCatIcon(category), "16x16px", category)
    addText(cat, category)
  end
  local body = card:tag("div"):addClass("roco-sk-dbody")
  local stats = body:tag("div"):addClass("roco-sk-dstats")
  local energy = stats:tag("div"):addClass("roco-sk-dstat")
  addText(energy:tag("span"):addClass("roco-sk-dstat-lab"), "能耗")
  local energyVal = energy:tag("span"):addClass("roco-sk-dstat-val")
  addImage(energyVal, "Stat_Energy.png", "18x18px", "能耗")
  addText(energyVal, energyText(skill))
  local power = stats:tag("div"):addClass("roco-sk-dstat")
  addText(power:tag("span"):addClass("roco-sk-dstat-lab"), "威力")
  addText(power:tag("span"):addClass("roco-sk-dstat-val"), powerText(skill))
  local source = body:tag("div"):addClass("roco-sk-dlearning")
  addText(source:tag("span"), "学习来源")
  addText(source:tag("span"):addClass("roco-sk-dlearning-value"),
    item.source == "level" and ("自学 · " .. skillLevelLabel(item)) or skillLevelLabel(item))
  local desc = body:tag("div"):addClass("roco-sk-ddesc")
  addText(desc:tag("div"):addClass("roco-sk-section-label"), "技能效果")
  renderRichText(desc, skill.desc or "", skill.desc_notes, "roco-sk-ddesc-text")
  if trim(skill.flavor) then
    addText(desc:tag("div"):addClass("roco-sk-flavor"), skill.flavor)
  end
  desc:tag("div"):addClass("roco-sk-mark")
  CombatEffects.render(body, skill, true)
  if item.source == "machine" then
    renderSkillStoneSources(body, item.skillId)
  else
    local quest = findSkillQuest(topics, skill.name)
    local tip = body:tag("div"):addClass("roco-sk-dquest")
    if not quest then tip:addClass("is-empty") end
    addImage(tip:tag("span"):addClass("roco-sk-dquest-ico"), "Ui_Medal.png", "16x16px", "")
    addText(tip:tag("span"):addClass("roco-sk-dquest-lab"), "课题")
    addText(tip:tag("span"), quest or "暂无专属课题")
  end
  if compact then parent:wikitext(tostring(block)) end
end

local function renderSkillFilters(parent, entries, counts, sourcesOnly)
  local types, cats = {}, {}
  local typeSeen, catSeen = {}, {}
  for _, item in ipairs(entries) do
    local short = stripType(item.skill.element)
    if item.source ~= "blood" and short and not typeSeen[short] then
      typeSeen[short] = true
      types[#types + 1] = short
    end
    local cat = skillCategory(item.skill)
    if cat and not catSeen[cat] then
      catSeen[cat] = true
      cats[#cats + 1] = cat
    end
  end
  -- 筛选项沿用技能列表的系别顺序。
  local function addChip(row, value, label, icon, current, count)
    local chip = row:tag("span")
      :addClass("roco-fchip")
      :attr("data-val", value)
      :attr("role", "button")
      :attr("tabindex", "0")
    if current then chip:addClass("is-on") end
    if icon then addImage(chip, icon, "14x14px", label) end
    addText(chip, label)
    if count ~= nil then
      addText(chip:tag("span"):addClass("roco-sk-tab-count"), tostring(count))
    end
    return chip
  end
  local function section(title, group)
    local sec = parent:tag("div"):addClass("roco-filter-sec"):attr("data-filter-group", group)
    addText(sec:tag("div"):addClass("roco-filter-label"), title)
    return sec:tag("div"):addClass("roco-filter-chips")
  end
  if sourcesOnly then
    local sourceRow = section("学习来源", "source")
    addChip(sourceRow, "all", "全部", nil, true, #entries)
    for _, tab in ipairs(SKILL_TABS) do
      local count = counts[tab.key]
      if count and count > 0 then
        addChip(sourceRow, tab.key, tab.label, nil, false, count)
      end
    end
    return
  end
  local typeRow = section("系别属性", "type")
  addChip(typeRow, "all", "全部", nil, true)
  for _, short in ipairs(types) do
    addChip(typeRow, short, short, typeIconFile(short), false)
  end
  local catRow = section("技能类型", "cat")
  addChip(catRow, "all", "全部", nil, true)
  for _, cat in ipairs(SKILL_CATEGORY_ORDER) do
    if catSeen[cat] then
      addChip(catRow, cat, cat, skillCatIcon(cat), false)
    end
  end
  local powerRow = section("威力范围", "power")
  addChip(powerRow, "all", "不限", nil, true)
  addChip(powerRow, "low", "0~80", nil, false)
  addChip(powerRow, "mid", "80~110", nil, false)
  addChip(powerRow, "high", "110+", nil, false)
end

local function renderSkills(parent, entries, topics, compact)
  if #entries == 0 then
    renderEmpty(parent, "这只精灵暂时没有可展示的技能。")
    return
  end
  local counts = {}
  for _, item in ipairs(entries) do
    counts[item.source] = (counts[item.source] or 0) + 1
  end
  local top = parent:tag("div"):addClass("roco-sk-top")
  local sort = top:tag("div"):addClass("roco-sk-sort")
  addText(sort:tag("span"), "排序")
  local select = sort:tag("div"):addClass("roco-sk-sort-control"):attr("data-skill-sort", "1")
  for _, option in ipairs({
    {"order", "学习来源"}, {"energy", "能耗从低到高"}, {"energy-desc", "能耗从高到低"},
    {"power", "威力从高到低"}, {"power-asc", "威力从低到高"}, {"name", "技能名称"}
  }) do
    addText(select:tag("div"):attr("data-value", option[1]), option[2])
  end
  local miniBtn = top:tag("div")
    :addClass("roco-sk-mini-btn")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("aria-pressed", "false")
    :attr("aria-label", "切换为迷你视图")
    :attr("title", "切换为迷你视图")
  miniBtn:tag("i"):addClass("fa-solid fa-table-cells"):attr("aria-hidden", "true")
  local descBtn = top:tag("span")
    :addClass("roco-sk-desc-btn")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("aria-pressed", "false")
    :attr("aria-label", "显示技能描述")
    :attr("title", "显示技能描述")
  descBtn:tag("i"):addClass("fa-solid fa-eye"):attr("aria-hidden", "true")
  local filterBtn = top:tag("span")
    :addClass("roco-sk-filter-btn")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("aria-expanded", "false")
    :attr("aria-controls", "rocodex-skill-filters")
    :attr("title", "技能筛选")
  filterBtn:tag("i"):addClass("fa-solid fa-filter"):attr("aria-hidden", "true")
  local expandBtn = top:tag("div")
    :addClass("roco-sk-expand-btn")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("aria-pressed", "false")
    :attr("aria-label", "展开技能面板")
    :attr("title", "展开技能面板")
  expandBtn:tag("i"):addClass("fa-solid fa-expand"):attr("aria-hidden", "true")

  local sources = top:tag("div"):addClass("roco-sk-source-choices")
  renderSkillFilters(sources, entries, counts, true)

  local drawer = top:tag("div"):addClass("roco-sk-filter-drawer"):attr("id", "rocodex-skill-filters")
  local drawerInner = drawer:tag("div"):addClass("roco-sk-filter-inner")
  local inner = drawerInner:tag("div"):addClass("roco-sk-filter-body")
  local head = inner:tag("div"):addClass("roco-sk-filter-head")
  local reset = head:tag("span")
    :addClass("roco-freset")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("title", "重置筛选")
  reset:tag("i"):addClass("fa-solid fa-arrows-rotate"):attr("aria-hidden", "true")
  renderSkillFilters(inner, entries, counts)
  local listView = parent:tag("div"):addClass("roco-sk-list-view")
  addText(listView:tag("div"):addClass("roco-sk-status"):attr("role", "status"):attr("aria-live", "polite"),
    "显示 " .. tostring(#entries) .. " / " .. tostring(#entries) .. " 个技能")
  listView:tag("div"):addClass("roco-sk-divider roco-dash")
  local grid = listView:tag("div"):addClass("roco-sk-grid")
  if compact then grid:attr("data-reuse-skill-descriptions", "true") end
  for _, tab in ipairs(SKILL_TABS) do
    if counts[tab.key] then
      local heading = grid:tag("div"):addClass("roco-sk-group")
        :attr("data-skill-group", tab.key):attr("role", "heading"):attr("aria-level", "3")
      addText(heading:tag("span"), tab.label)
      addText(heading:tag("span"):addClass("roco-sk-group-count"), tostring(counts[tab.key]))
      local group = {}
      for _, item in ipairs(entries) do
        if item.source == tab.key then group[#group + 1] = item end
      end
      table.sort(group, function(a, b) return a.originalOrder < b.originalOrder end)
      for _, item in ipairs(group) do renderSkillCard(grid, item, topics, compact) end
    end
  end

  local detail = parent:tag("div"):addClass("roco-sk-detail-page")
  local bar = detail:tag("div"):addClass("roco-sk-dbar")
  local back = bar:tag("span")
    :addClass("roco-sk-back")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("aria-label", "关闭技能详情")
    :attr("title", "关闭")
  back:tag("i"):addClass("fa-solid fa-xmark"):attr("aria-hidden", "true")
  bar:tag("span"):addClass("roco-sk-dbar-spacer")
  --[[ 暂停生成技能详情图片分享入口，保留代码以便恢复。
  local share = bar:tag("span")
    :addClass("roco-sk-share")
    :attr("hidden", "hidden")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("title", "生成技能详情图片")
  addImage(share, "Ui_Share.png", nil, "生成技能详情图片")
  ]]
  local go = bar:tag("div")
    :addClass("roco-sk-dgo")
    :attr("role", "button")
    :attr("tabindex", "0")
    :attr("title", "前往技能页")
  addImage(go, "Ui_SkillGo.png", nil, "前往")
  for _, item in ipairs(entries) do
    renderSkillDetail(detail, item, topics, compact)
  end
end

local function memberSubtitle(member, isLord)
  local stage = nil
  if not isLord then
    stage = STAGE_NAMES[member.stage]
      or (member.stage and ("第" .. tostring(member.stage) .. "阶") or nil)
  end
  local types = {}
  for _, raw in ipairs(member.types or {}) do
    local short = stripType(raw)
    if short then types[#types + 1] = short end
  end
  local typeText = #types > 0 and table.concat(types, " / ") or nil
  if stage and typeText then return stage .. " · " .. typeText end
  return stage or typeText or ""
end

local manualEvolutionConditions
local function manualEvolutionCondition(source, target)
  if not source or not target then return nil end
  if not manualEvolutionConditions then
    manualEvolutionConditions = mw.loadData("Module:Pets/EvolutionConditions")
  end
  local function keys(member)
    local pet = loadPet(member.id) or {}
    local values = {}
    if pet.game_id then
      values[#values + 1] = pet.game_id
      values[#values + 1] = tostring(pet.game_id)
    end
    if member.id then values[#values + 1] = member.id end
    if trim(member.title) then values[#values + 1] = member.title end
    return values
  end
  for _, from in ipairs(keys(source)) do
    local destinations = manualEvolutionConditions[from]
    if type(destinations) == "table" then
      for _, to in ipairs(keys(target)) do
        local value = destinations[to]
        if type(value) == "string" then return mw.text.trim(value) end
      end
    end
  end
  return nil
end

local function memberCondition(member, isLord, source)
  local manual = manualEvolutionCondition(source, member)
  if isLord then
    local base = trim(member.item) and ("通过" .. tostring(member.item) .. "首领化") or "首领化"
    return manual and manual ~= "" and (base .. " " .. manual) or base
  end
  local condition = manual ~= nil and manual or member.cond
  local parts = {}
  if member.level then parts[#parts + 1] = "LV" .. tostring(member.level) end
  if trim(condition) then parts[#parts + 1] = condition end
  if #parts == 0 then return "进化" end
  if member.level and not trim(condition) then return parts[1] .. " 进化" end
  return table.concat(parts, " ")
end

local function renderEvoMember(parent, member, currentId, roman, isLord, isLast)
  local node = parent:tag("div"):addClass("roco-evo-node")
  if isLord then node:addClass("is-lord") end
  if isLast then node:addClass("is-last") end
  if trim(roman) then node:attr("data-roman", roman) end
  local card = node:tag("div"):addClass("roco-evo-card")
  if member.id == currentId then card:addClass("is-cur") end
  local avatar = card:tag("div"):addClass("roco-evo-avatar")
  local memberPet = member.id and loadPet(member.id)
  renderAppearanceAvatar(avatar, memberPet and memberPet.image, member.name,
    memberPet and memberPet.has_shiny, member.head or member.illustration)
  local tag = card:tag("div"):addClass("roco-evo-name")
  if member.title then
    addPageLink(tag:tag("div"):addClass("roco-evo-name-main"), member.title, member.name or member.title)
  else
    addText(tag:tag("div"):addClass("roco-evo-name-main"), member.name or "?")
  end
  addText(tag:tag("div"):addClass("roco-evo-name-sub"), memberSubtitle(member, isLord))
end

local function renderEvolution(parent, evolution, currentId)
  evolution = evolution or {}
  if not hasItems(evolution) then
    renderEmpty(parent, "这只精灵没有进化路径。")
    return
  end
  local wrap = parent:tag("div"):addClass("roco-evo-wrap")
  local groupCount = arrayCount(evolution)
  if groupCount > 1 then
    local bar = wrap:tag("div"):addClass("roco-evo-branch-bar")
    local title = bar:tag("span"):addClass("roco-evo-branch-title")
    addText(title:tag("span"):addClass("roco-evo-mark"), "❙")
    addText(title, "进化分支")
    local btns = bar:tag("div"):addClass("roco-evo-branch-btns")
    for i, group in ipairs(evolution) do
      local btn = btns:tag("span")
        :addClass("roco-evo-branch-btn")
        :attr("data-branch", tostring(i))
        :attr("role", "button")
        :attr("tabindex", "0")
        :attr("title", group.name or ("分支 " .. i))
      if i == 1 then btn:addClass("is-on") end
      addText(btn, tostring(i))
    end
  end
  for i, group in ipairs(evolution) do
    local timeline = wrap:tag("div")
      :addClass("roco-evo-timeline")
      :attr("data-branch", tostring(i))
    if i == 1 then timeline:addClass("is-on") end
    if groupCount > 1 and trim(group.name) then
      addText(timeline:tag("div"):addClass("roco-evo-group-name"), group.name)
    end
    for position, member in ipairs(group.chain or {}) do
      if position > 1 then
        local conn = timeline:tag("div"):addClass("roco-evo-conn")
        local pill = conn:tag("div"):addClass("roco-evo-conn-pill")
        pill:tag("span"):addClass("roco-evo-conn-dot roco-evo-dot-" .. tostring(position))
        addText(pill:tag("span"), memberCondition(member, false, group.chain[position - 1]))
      end
      local isLast = position == arrayCount(group.chain) and not hasItems(group.lord_branches)
      renderEvoMember(timeline, member, currentId, romanAt(position), false, isLast)
    end
    for offset, member in ipairs(group.lord_branches or {}) do
      local position = arrayCount(group.chain) + offset
      local conn = timeline:tag("div"):addClass("roco-evo-conn roco-evo-conn-lord")
      local pill = conn:tag("div"):addClass("roco-evo-conn-pill")
      pill:tag("span"):addClass("roco-evo-conn-dot roco-evo-dot-lord")
      addText(pill:tag("span"), memberCondition(member, true, group.chain[arrayCount(group.chain)]))
      renderEvoMember(
        timeline,
        member,
        currentId,
        romanAt(position),
        true,
        offset == arrayCount(group.lord_branches)
      )
    end
  end
end

local function highlightTopic(parent, text, byName)
  local matches = {}
  for name, skill in pairs(byName) do
    local startAt = string.find(text, name, 1, true)
    if startAt then
      matches[#matches + 1] = { startAt = startAt, stopAt = startAt + #name - 1, name = name, skill = skill }
    end
  end
  table.sort(matches, function(a, b)
    if a.startAt == b.startAt then return #a.name > #b.name end
    return a.startAt < b.startAt
  end)
  local picked = {}
  for _, match in ipairs(matches) do
    local overlap = false
    for _, prev in ipairs(picked) do
      if match.startAt <= prev.stopAt and match.stopAt >= prev.startAt then
        overlap = true
        break
      end
    end
    if not overlap then picked[#picked + 1] = match end
  end
  if #picked == 0 then
    addText(parent, text)
    return
  end
  table.sort(picked, function(a, b) return a.startAt < b.startAt end)
  local cursor = 1
  for _, match in ipairs(picked) do
    if match.startAt > cursor then
      addText(parent, string.sub(text, cursor, match.startAt - 1))
    end
    local short = stripType(match.skill.element)
    local mark = parent:tag("span"):addClass("roco-quest-hl")
    if short then mark:addClass("roco-t-" .. short) end
    addPageLink(mark, match.name, match.name)
    cursor = match.stopAt + 1
  end
  if cursor <= #text then addText(parent, string.sub(text, cursor)) end
end

local function renderTopics(parent, topics, byName)
  if not hasItems(topics) then
    renderEmpty(parent, "这只精灵没有图鉴课题。")
    return
  end
  local list = parent:tag("div"):addClass("roco-quest-list")
  for i, topic in ipairs(topics) do
    local row = list:tag("div"):addClass("roco-quest-row")
    addText(row:tag("span"):addClass("roco-quest-roman"), romanAt(i))
    if trim(topic.progress_id) then
      row:attr("data-topic-progress-id", topic.progress_id)
    end
    local pill = row:tag("div"):addClass("roco-quest-pill")
    local text = pill:tag("div"):addClass("roco-quest-text")
    highlightTopic(text, topic.text or "未命名课题", byName)
    local right = pill:tag("div"):addClass("roco-quest-right")
    if hasItems(topic.rewards) then
      local rewards = right:tag("div"):addClass("roco-quest-rewards")
      for _, reward in ipairs(topic.rewards) do
        if not tostring(reward.name or ""):match("^配方") then
          local unit = rewards:tag("span"):addClass("roco-quest-rew")
          local icon = unit:tag("span"):addClass("roco-quest-rew-ico")
          addImage(icon, rewardFile(reward.icon), "28x28px", reward.name or "")
          if reward.count then
            addText(unit:tag("span"):addClass("roco-quest-rew-num"), "x" .. tostring(reward.count))
          end
        end
      end
    end
    local check = right:tag("span")
      :addClass("roco-quest-check")
      :attr("role", "checkbox")
      :attr("aria-checked", "false")
      :attr("aria-disabled", "true")
      :attr("tabindex", "-1")
      :attr("hidden", "hidden")
      :attr("title", "标记达成")
    check:tag("i"):addClass("fa-solid fa-check")
  end
end

local function renderFixedEggTraits(parent, item)
  if not (
    trim(item.fixed_nature)
    or trim(item.fixed_talent)
    or hasItems(item.fixed_aptitudes)
  ) then
    return
  end
  local grid = parent:tag("div"):addClass("roco-eco-traits")
  local function addTrait(label, value, detail)
    if not trim(value) then return end
    local pill = grid:tag("div"):addClass("roco-eco-trait")
    addText(pill, label .. "：")
    local text = tostring(value)
    if trim(detail) then text = text .. "（" .. tostring(detail) .. "）" end
    addText(pill:tag("strong"), text)
  end
  local natureEffects = {}
  if trim(item.fixed_nature_positive) then
    natureEffects[#natureEffects + 1] = "+" .. tostring(item.fixed_nature_positive)
  end
  if trim(item.fixed_nature_negative) then
    natureEffects[#natureEffects + 1] = "-" .. tostring(item.fixed_nature_negative)
  end
  addTrait("固定性格", item.fixed_nature, table.concat(natureEffects, " "))
  addTrait("固定特长", item.fixed_talent)
  if hasItems(item.fixed_aptitudes) then
    local values = {}
    for _, aptitude in ipairs(item.fixed_aptitudes) do
      if trim(aptitude.stat) and aptitude.value ~= nil then
        values[#values + 1] = tostring(aptitude.stat) .. " " .. tostring(aptitude.value)
      end
    end
    addTrait("固定资质", table.concat(values, "、"))
  end
end

local function renderEcologyItems(parent, title, items, imageFile)
  if not hasItems(items) then return end
  local section = parent:tag("div"):addClass("roco-eco-block")
  if title == "特殊精灵蛋" then section:addClass("is-eggs") end
  addText(section:tag("div"):addClass("roco-subhead"), title)
  for _, item in ipairs(items) do
    local card = section:tag("div"):addClass("roco-eco-card")
    local head = card:tag("div"):addClass("roco-eco-head")
    local itemImage = item.icon or imageFile
    if itemImage then
      local ico = head:tag("div"):addClass("roco-eco-ico")
      addImage(ico, itemImage, nil, item.name or "")
    end
    local meta = head:tag("div"):addClass("roco-eco-meta")
    addText(meta:tag("div"):addClass("roco-eco-item-name"), item.name or "未命名")
    if hasItems(item.sources) then
      local sourceLine = meta:tag("div"):addClass("roco-eco-item-src")
      addText(sourceLine, "来源：")
      local target = #item.sources == 1 and dungeonTitle(item.dungeon) or nil
      for sourceIndex, source in ipairs(item.sources) do
        if sourceIndex > 1 then addText(sourceLine, "；") end
        if target then
          addPageLink(sourceLine, target, source)
        else
          addText(sourceLine, source)
        end
      end
    end
    if trim(item.description) then
      addText(card:tag("div"):addClass("roco-eco-item-desc"), item.description)
    end
    renderFixedEggTraits(card, item)
  end
end

local function renderManual(parent, title, content)
  if not trim(content) then return end
  local section = parent:tag("div"):addClass("roco-eco-block")
  addText(section:tag("div"):addClass("roco-subhead"), title)
  section:tag("div"):addClass("roco-manual"):wikitext(content)
end

local function renderEcology(parent, pet, handbook, args)
  local ecology = pet.ecology or {}
  local acquisitionPet = ecology.acquisition_pet_id and loadPet(ecology.acquisition_pet_id) or pet
  local acquisition = (acquisitionPet or {}).ecology or {}
  local image = (acquisitionPet or {}).image or {}
  -- 有野外分布或对应精灵果实时显示；果实沿用本页的共享获取关系。
  -- 只使用构建结果中确认的比例，不从进化前或其他形态推定缺失值。
  local gender = pet.gender_ratio or {}
  local male = tonumber(gender.male)
  local female = tonumber(gender.female)
  local total = (male or 0) + (female or 0)
  local hasGenderSource = hasItems(ecology.areas) or hasItems(acquisition.fruits)
  if hasGenderSource and male and female and male >= 0 and female >= 0 and total > 0 then
    local block = parent:tag("div"):addClass("roco-eco-block")
    addText(block:tag("div"):addClass("roco-subhead"), "性别比例")
    local ratio = block:tag("div")
      :addClass("roco-gender")
      :attr("aria-label", "性别比例")
    local labels = ratio:tag("div"):addClass("roco-gender-labels")
    local malePercent = male / total * 100
    local femalePercent = female / total * 100
    addText(labels:tag("span"):addClass("is-male"), "雄性 " .. tostring(math.floor(malePercent + 0.5)) .. "%")
    addText(labels:tag("span"):addClass("is-female"), "雌性 " .. tostring(math.floor(femalePercent + 0.5)) .. "%")
    local bar = ratio:tag("div"):addClass("roco-gender-bar")
    bar:tag("span"):addClass("is-male"):css("width", tostring(malePercent) .. "%")
    bar:tag("span"):addClass("is-female"):css("width", tostring(femalePercent) .. "%")
  end
  if hasItems(ecology.areas) then
    local block = parent:tag("div"):addClass("roco-eco-block")
    addText(block:tag("div"):addClass("roco-subhead"), "大世界分布")
    local grid = block:tag("div"):addClass("roco-world-grid")
    for _, areaName in ipairs(ecology.areas) do
      local card = grid:tag("div"):addClass("roco-world-card")
      addText(card:tag("div"):addClass("roco-world-title"), areaName)
    end
  end
  renderEcologyItems(parent, "精灵果实", acquisition.fruits, image.fruit or (image.fruits and image.fruits[1]))
  renderEcologyItems(parent, "特殊精灵蛋", acquisition.eggs, image.egg)
  local validEggGroup = false
  for _, groupId in ipairs(pet.egg_group or {}) do
    if groupId ~= 1 then
      validEggGroup = true
      break
    end
  end
  if image.has_egg and validEggGroup and pet.egg_size then
    local size = pet.egg_size
    local function sizeValue(value)
      local number = tonumber(value)
      if not number then return nil end
      local kilograms = size.unit == "kg" and number or number / 1000
      return string.format("%.3f", kilograms)
    end
    local function sizeRange(low, high)
      local lowText = sizeValue(low)
      local highText = sizeValue(high)
      if not lowText or not highText then return nil end
      return lowText .. "–" .. highText
    end
    local function sizeLimit(value, suffix)
      local text = sizeValue(value)
      return text and (text .. suffix) or nil
    end
    local ranges = {
      { label = "常见范围", value = sizeRange(size.min, size.max), icon = "Ui_Egg.png" },
      { label = "小不点", value = sizeLimit(size.mini_max, "-"), icon = "Ui_SizeMini.png" },
      { label = "大块头", value = sizeLimit(size.huge_min, "+"), icon = "Ui_SizeHuge.png" },
    }
    local block = parent:tag("div"):addClass("roco-eco-block roco-egg-size")
    addText(block:tag("div"):addClass("roco-subhead"), "蛋的重量")
    local grid = block:tag("div"):addClass("roco-egg-size-grid")
    for _, range in ipairs(ranges) do
      if range.value then
        local card = grid:tag("div"):addClass("roco-egg-size-card")
        addImage(card:tag("span"):addClass("roco-egg-size-icon"), range.icon, "36x36px", "")
        local copy = card:tag("span"):addClass("roco-egg-size-copy")
        addText(copy:tag("span"):addClass("roco-egg-size-label"), range.label)
        local measure = copy:tag("span"):addClass("roco-egg-size-measure")
        addText(measure:tag("strong"), range.value)
        addText(measure:tag("span"):addClass("roco-egg-size-unit"), "kg")
      end
    end
    addText(block:tag("p"):addClass("roco-eco-note"), "− 表示不高于，+ 表示不低于。只适用于家园玩法获得的蛋。")
  end
  if hasItems(ecology.activities) then
    local block = parent:tag("div"):addClass("roco-eco-block")
    addText(block:tag("div"):addClass("roco-subhead"), "限时获取")
    addText(block:tag("div"):addClass("roco-eco-note"), "以下为限时获取记录，开放时间以各期活动为准。")
    local list = block:tag("div"):addClass("roco-eco-activity-list")
    for _, activity in ipairs(ecology.activities) do
      local row = list:tag("div"):addClass("roco-eco-activity")
      addText(row:tag("div"):addClass("roco-eco-activity-name"), activity.name or "未命名活动")
      if trim(activity.window) then
        local window = row:tag("div"):addClass("roco-eco-activity-window")
        window:tag("i"):addClass("fa-regular fa-clock"):attr("aria-hidden", "true")
        addText(window:tag("div"), activity.window)
      end
      if trim(activity.note) then addText(row:tag("div"):addClass("roco-eco-activity-note"), activity.note) end
    end
  end
  local likes = {}
  for _, groupId in ipairs(pet.egg_group or {}) do
    local text = (loadConfig().egg_group_likes or {})[groupId]
    local label = EGG_GROUP_NAMES[groupId]
    if text and label then likes[#likes + 1] = label .. "：" .. text end
  end
  if #likes > 0 then
    local block = parent:tag("div"):addClass("roco-eco-block")
    addText(block:tag("div"):addClass("roco-subhead"), "喜好")
    addText(block:tag("p"):addClass("roco-eco-note"), "同蛋组的精灵共享口味与天气偏好，用于喂食和送礼。")
    for _, line in ipairs(likes) do
      addText(block:tag("div"):addClass("roco-eco-like"), line)
    end
  end
  handbook = handbook or {}
  if hasItems(handbook.areas) then
    local block = parent:tag("div"):addClass("roco-eco-block")
    addText(block:tag("div"):addClass("roco-subhead"), "图鉴记录")
    local names = {}
    for _, area in ipairs(handbook.areas) do names[#names + 1] = tostring(area) end
    addText(block:tag("div"), "所属图鉴：" .. table.concat(names, "、"))
  elseif trim(handbook.habitat) and not hasItems(ecology.areas) then
    local block = parent:tag("div"):addClass("roco-eco-block")
    addText(block:tag("div"):addClass("roco-subhead"), "图鉴记录")
    addText(block:tag("div"), "栖息：" .. handbook.habitat)
  end
  renderManual(parent, "分布", args["分布"])
  renderManual(parent, "获取方式", args["获取方式"])
  renderManual(parent, "大世界生态", args["大世界生态"])
  renderManual(parent, "补充", args["补充"])
end

local function renderQuest(parent, topics, byName)
  local quests = parent:tag("div"):addClass("roco-quest-content")
  renderTopics(quests, topics, byName)

end

local HISTORY_SEASON_TITLES = {
  S1 = "暗夜拾光", S2 = "狂欢怪谈", S3 = "铅字幻梦", S4 = "月涌狂想",
}

local function renderHistory(parent, events, versions, manual)
  events = events or {}
  if arrayCount(events) == 0 and not trim(manual) then
    renderEmpty(parent, "目前没有记录到这只精灵的资料变化。")
    return
  end
  addText(parent:tag("p"):addClass("roco-eco-note"), "本页整理不同版本中的资料变化，不等同于官方更新公告。")
  for eventIndex = arrayCount(events), 1, -1 do
    local event = events[eventIndex]
    local version = (versions or {})[event.version] or {}
    local card = parent:tag("div"):addClass("roco-hist-card")
    local heading = card:tag("div"):addClass("roco-hist-head")
    local theme = HISTORY_SEASON_TITLES[version.season]
    addText(heading:tag("div"):addClass("roco-hist-season"), version.display_season and (version.display_season .. " " .. (version.display_name or "")) or theme and (version.season .. " " .. theme) or version.label or event.version)
    if version.display_date or version.date then addText(heading:tag("span"):addClass("roco-hist-date"), version.display_date or version.date) end
    local body = card:tag("div"):addClass("roco-hist-body")
    if event.kind == "introduced" then
      addText(body:tag("div"):addClass("roco-hist-row"), "自该版本起收录。")
    elseif event.kind == "missing" then
      addText(body:tag("div"):addClass("roco-hist-row"), "该版本未收录。")
    end
    local grouped, order = {}, {}
    for _, change in ipairs(event.changes or {}) do
      if not change.action or change.action == "added" or change.action == "removed"
          or change.action == "lord_added" or change.action == "lord_removed" then
        local group = change.group or "identity"
        if not grouped[group] then
          grouped[group] = {}
          order[#order + 1] = group
        end
        grouped[group][#grouped[group] + 1] = change
      end
    end
    for _, group in ipairs(order) do
      for _, change in ipairs(grouped[group]) do
        local row = body:tag("div"):addClass("roco-hist-row")
        addText(row:tag("span"):addClass("roco-hist-tag"), HISTORY_GROUP_LABELS[group] or group)
        local copy = row:tag("div"):addClass("roco-hist-copy")
        if not change.action then
          local field = change.field or ""
          local title = copy:tag("div"):addClass("roco-hist-change-title")
          local skillName, detail
          if group == "skill" then
            for _, suffix in ipairs({ "威力", "能耗", "说明" }) do
              if field:sub(-#suffix) == suffix then
                skillName, detail = field:sub(1, #field - #suffix), suffix
                break
              end
            end
          end
          addText(title:tag("span"):addClass("roco-hist-key"), skillName or field)
          if detail then addText(title:tag("span"):addClass("roco-hist-field"), detail) end
          local values = copy:tag("div"):addClass("roco-hist-values")
          addText(values:tag("span"):addClass("roco-hist-before"), formatHistoryValue(change.before))
          addText(values:tag("span"):addClass("roco-hist-arrow"), " → ")
          addText(values:tag("span"):addClass("roco-hist-after"), formatHistoryValue(change.after))
          if change.delta and change.delta ~= 0 then
            addText(values:tag("span"):addClass(change.delta > 0 and "is-pos" or "is-neg"), string.format(" (%+g)", change.delta))
          end
        elseif change.action == "added" or change.action == "removed" then
          addText(copy, change.action == "added" and "新增技能：" or "移除技能：")
          addText(copy:tag("span"):addClass("roco-hist-key"), change.name or change.value or "")
          local notes = {}
          if trim(change.qualifier) then notes[#notes + 1] = change.qualifier end
          if trim(change.source) then notes[#notes + 1] = change.source end
          if #notes > 0 then
            addText(copy:tag("span"):addClass("roco-hist-field"), "（" .. table.concat(notes, "，") .. "）")
          end
        else
          addText(copy, change.action == "lord_added" and "新增首领化：" or "移除首领化：")
          addText(copy:tag("span"):addClass("roco-hist-key"), change.value or "")
        end
      end
    end
  end
  renderManual(parent, "历史补充", manual)
end

-- Historical build choices use exact source species IDs, never handbook families.
local trainingReferenceData
local function renderTrainingReference(parent, pet)
  if not trainingReferenceData then trainingReferenceData = mw.loadData("Module:Pets/data/TrainingReference") end
  local data = trainingReferenceData
  local record = (data.pets or {})[tonumber(pet.game_id)] or {}
  local box = parent:tag("div"):addClass("roco-reference")
  local choices = box:tag("div"):addClass("roco-reference-modes"):attr("role", "group"):attr("aria-label", "培养场景")
  local groups = {
    {"skill", "常用技能"},
    {"nature", "性格"},
    {"blood", "血脉"},
    {"talent", "天分培养"},
  }
  local categories = box:tag("div"):addClass("roco-reference-categories"):attr("role", "group"):attr("aria-label", "培养项目")
  for _, group in ipairs(groups) do
    addText(categories:tag("div"):attr("data-nrc-tag", "button"):addClass("roco-reference-category" .. (group[1] == "skill" and " is-selected" or "")):attr("data-nrc-type", "button")
      :attr("data-reference-category", group[1]):attr("aria-pressed", group[1] == "skill" and "true" or "false"), group[2])
  end
  for _, mode in ipairs({{"world", "大世界"}, {"pvp", "PVP"}}) do
    local selected = mode[1] == "world"
    addText(choices:tag("div"):attr("data-nrc-tag", "button"):attr("data-nrc-type", "button"):addClass("roco-reference-mode" .. (selected and " is-selected" or ""))
      :attr("data-reference-mode", mode[1]):attr("aria-pressed", selected and "true" or "false"), mode[2])
    local panel = box:tag("div"):addClass("roco-reference-body")
      :attr("data-reference-body", mode[1]):attr("aria-label", mode[2])
    if not selected then panel:addClass("is-reference-hidden"):attr("hidden", "hidden") end
    if not record[mode[1]] then
      addText(panel:tag("div"):addClass("roco-reference-empty"), "本期暂无这只精灵的" .. mode[2] .. "培养数据。")
    else
      local grid = panel:tag("div"):addClass("roco-reference-grid")
      for _, group in ipairs(groups) do
        local card = grid:tag("div"):addClass("roco-reference-card roco-reference-" .. group[1])
        card:attr("data-reference-chart", group[1]):attr("aria-label", group[2])
        if group[1] ~= "skill" then card:addClass("is-reference-hidden"):attr("hidden", "hidden") end
        local rows = record[mode[1]][group[1]] or {}
        local rowCount = 0
        for _ in ipairs(rows) do rowCount = rowCount + 1 end
        if rowCount == 0 then addText(card:tag("div"):addClass("roco-reference-note"), "暂无数据") end
        local list = card:tag("div"):addClass("roco-reference-list")
        local visibleCount = group[1] == "skill" and 6 or 5
        for rank, pair in ipairs(rows) do
          local meta = ((data.labels or {})[group[1]] or {})[pair[1]] or {}
          local row = list:tag("div"):addClass("roco-reference-row")
          if rank == 1 then row:addClass("is-leading") end
          if rank > visibleCount and group[1] ~= "talent" then row:addClass("roco-reference-extra is-reference-hidden"):attr("hidden", "hidden") end
          local identity = row:tag("div"):addClass("roco-reference-identity")
          if meta.icon then addImage(identity:tag("div"):addClass("roco-reference-icon"), meta.icon, 28, meta.name) end
          local text = identity:tag("div"):addClass("roco-reference-label")
          addText(text:tag("div"):addClass("roco-reference-name"), meta.name)
          if meta.detail and meta.detail ~= "" then addText(text:tag("div"):addClass("roco-reference-detail"), meta.detail) end
          addText(row:tag("div"):addClass("roco-reference-value"), string.format("%.2f%%", pair[2] / 100))
          row:tag("div"):addClass("roco-reference-track"):tag("div"):addClass("roco-reference-fill"):css("width", tostring(pair[2] / 100) .. "%")
        end
        if rowCount > visibleCount and group[1] ~= "talent" then
          addText(card:tag("div"):attr("data-nrc-tag", "button"):addClass("roco-reference-more"):attr("data-nrc-type", "button"):attr("aria-expanded", "false"), "展开全部 " .. rowCount .. " 项")
        end
      end
    end
  end
  addText(box:tag("div"):addClass("roco-reference-footer"), "S3 铅字幻梦")
end

local function renderPanels(parent, ctx)
  local column = parent:tag("div"):addClass("roco-col-r")
  column:tag("div"):addClass("roco-stage-surface"):attr("aria-hidden", "true")
  local stage = column:tag("div"):addClass("roco-stage")

  local info = stage:tag("div"):addClass("roco-panel is-on")
    :attr("id", "rocodex-pInfo"):attr("data-panel", "pInfo")
  renderInfo(info, ctx.pet, ctx.feature, ctx.entries, ctx.topics, ctx.relations, ctx.events, ctx.versions)

  local skill = stage:tag("div"):addClass("roco-panel")
    :attr("id", "rocodex-pSkill"):attr("data-panel", "pSkill")
  renderSkills(skill, ctx.entries, ctx.topics, ctx.pet.id == "pet_000485")

  local reference = stage:tag("div"):addClass("roco-panel")
    :attr("id", "rocodex-pReference"):attr("data-panel", "pReference")
  renderTrainingReference(reference, ctx.pet)

  local evo = stage:tag("div"):addClass("roco-panel")
    :attr("id", "rocodex-pEvo"):attr("data-panel", "pEvo")
  renderEvolution(evo, ctx.evolution, ctx.pet.id)

  local quest = stage:tag("div"):addClass("roco-panel")
    :attr("id", "rocodex-pQuest"):attr("data-panel", "pQuest")
  renderQuest(quest, ctx.topics, ctx.byName)

  local eco = stage:tag("div"):addClass("roco-panel")
    :attr("id", "rocodex-pEco"):attr("data-panel", "pEco")
  renderEcology(eco, ctx.pet, ctx.handbook, ctx.args)

  local history = stage:tag("div"):addClass("roco-panel")
    :attr("id", "rocodex-pHistory"):attr("data-panel", "pHistory")
  renderHistory(history, ctx.events, ctx.versions, ctx.args["历史补充"])
end

function p.resolve(key)
  return resolveId(key)
end

function p.get(key)
  local petId = resolveId(key)
  if not petId then
    return nil
  end
  return loadPet(petId)
end

function p.main(frame)
  local args = mergeArgs(frame)
  local key = PageIdentity.current(frame)
  local petId = PageIdentity.resolve(frame, p.pageTitles())
  if not petId then return renderError(key) end
  local pet = loadPet(petId)
  if not pet then return renderError(key) end
  SEO.pet(frame, pet)

  local typeName = firstType(pet)
  local theme = themeFor(typeName)
  local skills = loadSkills()
  local learnset = loadLearnset(pet.learnset_id) or {}
  local evolution = loadEvolution(pet.evolution_id) or {}
  local handbook = loadHandbook(pet.handbook_id) or {}
  local topics = handbook.topics or {}
  local entries = collectSkillEntries(learnset, skills, pet.types, pet.stats)
  local events, versions = loadHistory(petId)
  local root = mw.html.create("div")
    :addClass("nrc-pets")
    :addClass("roco-dex")
    :attr("data-pet-id", petId)
    :attr("data-type", typeName)
    :attr("data-tile", theme.tile or "")

  local bg = root:tag("div"):addClass("roco-bg"):attr("aria-hidden", "true")
  bg:tag("div"):addClass("roco-bg-pattern")
  bg:tag("div"):addClass("roco-bg-fade")

  local wrap = root:tag("div"):addClass("roco-shell")
  renderPetNavigation(wrap, pet)
  local ui = wrap:tag("div"):addClass("roco-ui")
  renderIdentity(ui, pet)
  renderLeft(ui, pet)
  renderNav(ui)
  renderPanels(ui, {
    pet = pet,
    feature = pet.feature_skill_id and skills[pet.feature_skill_id] or nil,
    entries = entries,
    byName = skillNameIndex(entries),
    topics = topics,
    relations = loadTypeRelations(pet.relation_key),
    evolution = evolution,
    handbook = handbook,
    events = events or {},
    versions = versions,
    args = args,
    frame = frame,
  })
  root:wikitext(require("Module:RocopediaLinks").render(frame, true))
  root:tag("div"):addClass("roco-content-end"):attr("aria-hidden", "true")
  return tostring(root)
end

function p.pageTitles(kind)
  return mw.loadData("Module:Pets/data/Index").titles
end

return p