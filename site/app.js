(() => {
  const $ = (id) => document.getElementById(id);
  const ui = {
    search: $("search"), season: $("season-filter"), source: $("source-filter"), type: $("type-filter"),
    logic: $("logic"), conditions: $("conditions"), add: $("add-condition"), clear: $("clear-query"),
    copy: $("copy-link"), copyStatus: $("copy-status"), columnOptions: $("column-options"),
    columnSearch: $("column-search"), head: $("column-head"), pageSize: $("page-size"),
    rows: $("rows"), status: $("status"), range: $("range"), pageLabel: $("page-label"),
    prev: $("prev"), next: $("next"), export: $("export"),
  };
  const eggGroups = {1:"未发现",2:"巨灵组",3:"两栖组",4:"昆虫组",5:"天空组",6:"动物组",7:"妖精组",8:"植物组",9:"拟人组",10:"软体组",11:"大地组",12:"魔力组",13:"海洋组",14:"飞龙组",15:"机械组"};
  const coreFields = [
    ["number","图鉴编号","number"],["title","精灵名称","text"],["name","Wiki 名称","text"],["id","Pet ID","text"],
    ["season","赛季","text"],["types","属性","array"],["stage","阶段","number"],["egg_group","蛋组","array"],
    ["egg_min","蛋重下限","number"],["egg_max","蛋重上限","number"],["starlight","星光值","number"],
    ["review_gold","洛克贝","number"],["gender_ratio","雌雄比例","object"],["height","身高","text"],
    ["weight","体重","text"],["category","分类","text"],["sources","数据来源","array"],
  ].map(([key,label,type]) => ({key,label,type}));
  const defaultColumns = ["number","title","id","season","types","stage","egg_group","egg_min","egg_max","starlight","review_gold","category","sources"];
  const labels = {
    title:"名称",name:"Wiki 名称",number:"图鉴编号",stage:"阶段",starlight:"星光值",review_gold:"洛克贝",
    egg_group:"蛋组",egg_size:"蛋重范围",min:"下限",max:"上限",types:"属性",class:"分类",height:"身高",
    weight:"体重",gender_ratio:"雌雄比例",description:"描述",release:"上线信息",date:"日期",version:"版本",
    stats:"种族值",atk:"攻击",def:"防御",hp:"生命",spa:"魔攻",spd:"魔防",spe:"速度",
    can_ride:"可骑乘",can_double_ride:"可双人骑乘",has_shiny:"有异色形态",game_id:"游戏 ID",
    relation_key:"关系系别",move_type:"移动类型",ecology:"生态",eggs:"精灵蛋",fruits:"果实",
    affinity:"克制亲和",catch_threshold:"捕捉阈值",
  };
  let records = [];
  let fields = [];
  let fieldByKey = new Map();
  let visibleColumns = new Set(defaultColumns);
  let conditions = [];
  let filtered = [];
  let page = 1;
  let sort = {key:"number",direction:1};

  const isObject = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
  const flatten = (values) => values.flatMap((v) => Array.isArray(v) ? flatten(v) : [v]);

  function resolve(record, path) {
    const parts = path.split(".");
    function descend(value, index) {
      if (Array.isArray(value)) return value.flatMap((item) => descend(item, index));
      if (index >= parts.length) return [value];
      if (!isObject(value) || !(parts[index] in value)) return [];
      return descend(value[parts[index]], index + 1);
    }
    return descend(record, 0);
  }

  function valuesFor(record, key) {
    return flatten(resolve(record, key)).filter((v) => v !== null && v !== undefined && v !== "");
  }

  function collectLeaves(value, path, found, depth) {
    if (depth > 8 || value === null || value === undefined) return;
    if (Array.isArray(value)) {
      if (!value.length) found.add(path);
      else if (value.some((v) => isObject(v) || Array.isArray(v))) value.forEach((v) => collectLeaves(v, path, found, depth + 1));
      else found.add(path);
    } else if (isObject(value)) {
      const entries = Object.entries(value);
      if (!entries.length) found.add(path);
      else entries.forEach(([key, child]) => collectLeaves(child, path + "." + key, found, depth + 1));
    } else found.add(path);
  }

  function inferType(key) {
    for (const record of records) {
      const raw = resolve(record, key).find((v) => v !== null && v !== undefined && v !== "");
      if (raw === undefined) continue;
      if (typeof raw === "number") return "number";
      if (typeof raw === "boolean") return "boolean";
      if (Array.isArray(raw)) return "array";
      if (isObject(raw)) return "object";
      return "text";
    }
    return "text";
  }

  function labelFor(key) {
    const leaf = key.split(".").pop();
    return labels[leaf] ? labels[leaf] + " · " + key : "原始字段 · " + key.replace(/^attributes\./, "");
  }

  function buildFields() {
    const found = new Set();
    records.forEach((record) => collectLeaves(record.attributes, "attributes", found, 0));
    const rawFields = [...found].sort((a,b) => a.localeCompare(b,"zh-CN"))
      .map((key) => ({key,label:labelFor(key),type:inferType(key),raw:true}));
    fields = coreFields.concat(rawFields);
    fieldByKey = new Map(fields.map((field) => [field.key,field]));
    visibleColumns = new Set([...visibleColumns].filter((key) => fieldByKey.has(key)));
    if (!visibleColumns.size) visibleColumns = new Set(defaultColumns);
    renderColumnOptions();
  }

  function option(select, value, label) {
    const el = document.createElement("option");
    el.value = value;
    el.textContent = label;
    select.append(el);
  }

  function populateFilters() {
    const seasons = [...new Set(records.map((r) => r.season).filter(Boolean))].sort((a,b) => a.localeCompare(b,"zh-CN",{numeric:true}));
    const sources = [...new Set(records.flatMap((r) => r.sources || []))].sort((a,b) => a.localeCompare(b,"zh-CN"));
    const types = [...new Set(records.flatMap((r) => r.types || []))].sort((a,b) => a.localeCompare(b,"zh-CN"));
    seasons.forEach((v) => option(ui.season,v,v));
    sources.forEach((v) => option(ui.source,v,v));
    types.forEach((v) => option(ui.type,v,v));
  }

  function loadUrlState() {
    const p = new URLSearchParams(location.search);
    ui.search.value = p.get("q") || "";
    ui.season.value = p.get("season") || "";
    ui.source.value = p.get("source") || "";
    ui.type.value = p.get("type") || "";
    ui.logic.value = p.get("logic") === "or" ? "or" : "and";
    if (p.has("filters")) {
      try {
        const f = JSON.parse(p.get("filters"));
        if (Array.isArray(f)) conditions = f.filter((c) => fieldByKey.has(c.field) && typeof c.op === "string").slice(0,20);
      } catch (_) { /* Ignore malformed query links. */ }
    }
    if (p.has("columns")) {
      const c = p.get("columns").split(",").filter((key) => fieldByKey.has(key));
      if (c.length) visibleColumns = new Set(c);
    }
  }

  function operators(field) {
    const presence = [["present","有值"],["missing","无值"]];
    if (field.type === "number") return [["eq","等于"],["neq","不等于"],["gt","大于"],["gte","大于等于"],["lt","小于"],["lte","小于等于"],["between","介于"],...presence];
    if (field.type === "boolean") return [["eq","是"],["neq","否"],...presence];
    if (field.type === "array") return [["contains","包含值"],["contains_any","包含任一值（逗号分隔）"],...presence];
    return [["contains","包含文字"],["not_contains","不包含文字"],["eq","等于"],["neq","不等于"],["starts","开头为"],...presence];
  }

  function defaultOperator(field) {
    if (field.type === "number") return "eq";
    if (field.type === "boolean") return "eq";
    return "contains";
  }

  function makeSelect(className, choices, selected) {
    const select = document.createElement("select");
    select.className = className;
    choices.forEach(([value,label]) => option(select,value,label));
    if (choices.some(([value]) => value === selected)) select.value = selected;
    return select;
  }

  function makeValueInput(field, key, value) {
    if (field.type === "boolean") {
      const select = makeSelect("",[["true","是"],["false","否"]],value || "true");
      select.dataset.value = key;
      return select;
    }
    const input = document.createElement("input");
    input.type = field.type === "number" ? "number" : "text";
    input.placeholder = field.type === "number" ? "数值" : "输入值";
    input.value = value || "";
    input.dataset.value = key;
    return input;
  }

  function renderConditions() {
    ui.conditions.replaceChildren();
    if (!conditions.length) {
      const note = document.createElement("p");
      note.className = "no-conditions";
      note.textContent = "没有附加条件；可用上方搜索框或常用筛选器查询。";
      ui.conditions.append(note);
      return;
    }
    conditions.forEach((condition,index) => {
      const row = document.createElement("div");
      row.className = "condition-row";
      row.dataset.index = String(index);
      const field = fieldByKey.get(condition.field) || fields[0];
      const fieldSelect = makeSelect("condition-field",fields.map((f) => [f.key,f.label]),condition.field);
      fieldSelect.setAttribute("aria-label","筛选字段");
      const ops = operators(field);
      const opSelect = makeSelect("condition-op",ops,condition.op);
      opSelect.setAttribute("aria-label","比较方式");
      row.append(fieldSelect,opSelect);
      const valueWrap = document.createElement("div");
      valueWrap.className = "condition-values";
      const op = ops.some(([key]) => key === condition.op) ? condition.op : "contains";
      if (op !== "present" && op !== "missing") {
        if (op === "between") {
          const range = document.createElement("div");
          range.className = "range-values";
          range.append(makeValueInput(field,"value",condition.value),makeValueInput(field,"value2",condition.value2));
          valueWrap.append(range);
        } else valueWrap.append(makeValueInput(field,"value",condition.value));
      }
      row.append(valueWrap);
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "remove-condition";
      remove.dataset.remove = "1";
      remove.setAttribute("aria-label","移除筛选条件");
      remove.textContent = "×";
      row.append(remove);
      ui.conditions.append(row);
    });
  }

  function renderColumnOptions() {
    const query = ui.columnSearch ? ui.columnSearch.value.trim().toLocaleLowerCase() : "";
    ui.columnOptions.replaceChildren();
    fields.filter((field) => !query || field.label.toLocaleLowerCase().includes(query) || field.key.toLocaleLowerCase().includes(query))
      .forEach((field) => {
        const label = document.createElement("label");
        label.className = "column-option";
        const input = document.createElement("input");
        input.type = "checkbox";
        input.value = field.key;
        input.checked = visibleColumns.has(field.key);
        input.addEventListener("change",() => {
          if (input.checked) visibleColumns.add(field.key);
          else if (visibleColumns.size > 1) visibleColumns.delete(field.key);
          else input.checked = true;
          renderHead();
          render();
          updateAddress();
        });
        const caption = document.createElement("span");
        caption.textContent = field.label;
        label.append(input,caption);
        ui.columnOptions.append(label);
      });
  }

  function renderHead() {
    ui.head.replaceChildren();
    fields.filter((field) => visibleColumns.has(field.key)).forEach((field) => {
      const th = document.createElement("th");
      const button = document.createElement("button");
      button.type = "button";
      button.dataset.sort = field.key;
      button.textContent = field.label + (sort.key === field.key ? (sort.direction > 0 ? " ↑" : " ↓") : "");
      th.append(button);
      ui.head.append(th);
    });
  }

  function conditionMatches(record,condition) {
    const values = valuesFor(record,condition.field);
    const op = condition.op;
    if (op === "present") return values.length > 0;
    if (op === "missing") return values.length === 0;
    if (!values.length) return false;
    const field = fieldByKey.get(condition.field);
    const expected = condition.value || "";
    const needle = String(expected).toLocaleLowerCase();
    const strings = values.map((v) => String(v).toLocaleLowerCase());
    if (op === "contains") return strings.some((v) => v.includes(needle));
    if (op === "not_contains") return strings.every((v) => !v.includes(needle));
    if (op === "starts") return strings.some((v) => v.startsWith(needle));
    if (op === "contains_any") {
      const choices = needle.split(",").map((v) => v.trim()).filter(Boolean);
      return choices.some((choice) => strings.some((v) => v === choice || v.includes(choice)));
    }
    if (field.type === "boolean") {
      const desired = expected === "true";
      return values.some((v) => op === "neq" ? v !== desired : v === desired);
    }
    if (field.type === "number") {
      const target = Number(expected);
      const upper = Number(condition.value2);
      return values.some((v) => {
        const actual = Number(v);
        if (!Number.isFinite(actual) || !Number.isFinite(target)) return false;
        if (op === "eq") return actual === target;
        if (op === "neq") return actual !== target;
        if (op === "gt") return actual > target;
        if (op === "gte") return actual >= target;
        if (op === "lt") return actual < target;
        if (op === "lte") return actual <= target;
        if (op === "between") return Number.isFinite(upper) && actual >= Math.min(target,upper) && actual <= Math.max(target,upper);
        return false;
      });
    }
    return strings.some((v) => op === "neq" ? v !== needle : v === needle);
  }

  function matches(record) {
    const query = ui.search.value.trim().toLocaleLowerCase();
    if (ui.season.value && record.season !== ui.season.value) return false;
    if (ui.source.value && !(record.sources || []).includes(ui.source.value)) return false;
    if (ui.type.value && !(record.types || []).includes(ui.type.value)) return false;
    if (query && !fields.flatMap((field) => valuesFor(record,field.key)).map(String).join(" ").toLocaleLowerCase().includes(query)) return false;
    if (!conditions.length) return true;
    return ui.logic.value === "or" ? conditions.some((c) => conditionMatches(record,c)) : conditions.every((c) => conditionMatches(record,c));
  }

  function display(value) {
    if (value === null || value === undefined || value === "") return "—";
    if (Array.isArray(value)) return value.map(display).join(" / ") || "—";
    if (isObject(value)) {
      if ("male" in value || "female" in value) return "雄" + (value.male ?? "—") + " / 雌" + (value.female ?? "—");
      return Object.entries(value).map(([key,val]) => key + ": " + display(val)).join(" / ") || "—";
    }
    return String(value);
  }

  function render() {
    filtered = records.filter(matches);
    filtered.sort((a,b) => {
      const av = valuesFor(a,sort.key)[0];
      const bv = valuesFor(b,sort.key)[0];
      if (av === undefined) return bv === undefined ? 0 : 1;
      if (bv === undefined) return -1;
      const an = Number(av), bn = Number(bv);
      const cmp = Number.isFinite(an) && Number.isFinite(bn) ? an - bn : String(av).localeCompare(String(bv),"zh-CN",{numeric:true});
      return cmp * sort.direction;
    });
    const size = Number(ui.pageSize.value);
    const pages = Math.max(1,Math.ceil(filtered.length / size));
    page = Math.min(page,pages);
    const start = (page - 1) * size;
    const shown = filtered.slice(start,start + size);
    const visible = fields.filter((field) => visibleColumns.has(field.key));
    ui.rows.replaceChildren();
    if (!shown.length) {
      const row = document.createElement("tr"), cell = document.createElement("td");
      cell.colSpan = Math.max(visible.length,1);
      cell.className = "empty";
      cell.textContent = records.length ? "没有符合条件的记录" : "数据尚未生成";
      row.append(cell);
      ui.rows.append(row);
    } else shown.forEach((record) => {
      const row = document.createElement("tr");
      visible.forEach((field) => {
        const cell = document.createElement("td");
        if (field.type === "number") cell.classList.add("num");
        let value = field.key === "egg_group"
          ? (record.egg_group || []).map((id) => eggGroups[id] || "未知蛋组(" + id + ")")
          : valuesFor(record,field.key);
        cell.textContent = display(value);
        row.append(cell);
      });
      ui.rows.append(row);
    });
    ui.status.textContent = "共 " + filtered.length.toLocaleString("zh-CN") + " / " + records.length.toLocaleString("zh-CN") + " 条";
    ui.range.textContent = filtered.length ? "显示 " + (start + 1) + "–" + Math.min(start + size,filtered.length) + " 条" : "显示 0 条";
    ui.pageLabel.textContent = page + " / " + pages;
    ui.prev.disabled = page <= 1;
    ui.next.disabled = page >= pages;
  }

  function updateAddress(copy) {
    const p = new URLSearchParams();
    if (ui.search.value) p.set("q",ui.search.value);
    if (ui.season.value) p.set("season",ui.season.value);
    if (ui.source.value) p.set("source",ui.source.value);
    if (ui.type.value) p.set("type",ui.type.value);
    if (conditions.length) {
      p.set("logic",ui.logic.value);
      p.set("filters",JSON.stringify(conditions));
    }
    p.set("columns",[...visibleColumns].join(","));
    const url = new URL(location.href);
    url.search = p.toString();
    history.replaceState(null,"",url);
    if (!copy) return;
    if (!navigator.clipboard?.writeText) {
      ui.copyStatus.textContent = url.toString();
      return;
    }
    navigator.clipboard.writeText(url.toString()).then(
      () => { ui.copyStatus.textContent = "查询链接已复制"; },
      () => { ui.copyStatus.textContent = url.toString(); },
    );
  }

  function apply() {
    page = 1;
    render();
    updateAddress(false);
  }

  ui.conditions.addEventListener("change",(event) => {
    const row = event.target.closest(".condition-row");
    if (!row) return;
    const condition = conditions[Number(row.dataset.index)];
    if (event.target.classList.contains("condition-field")) {
      condition.field = event.target.value;
      condition.op = defaultOperator(fieldByKey.get(condition.field));
      condition.value = "";
      condition.value2 = "";
      renderConditions();
    } else if (event.target.classList.contains("condition-op")) {
      condition.op = event.target.value;
      renderConditions();
    } else if (event.target.dataset.value) condition[event.target.dataset.value] = event.target.value;
    apply();
  });
  ui.conditions.addEventListener("input",(event) => {
    const row = event.target.closest(".condition-row");
    if (!row || !event.target.dataset.value) return;
    conditions[Number(row.dataset.index)][event.target.dataset.value] = event.target.value;
    apply();
  });
  ui.conditions.addEventListener("click",(event) => {
    const button = event.target.closest("[data-remove]");
    if (!button) return;
    conditions.splice(Number(button.closest(".condition-row").dataset.index),1);
    renderConditions();
    apply();
  });
  ui.add.addEventListener("click",() => {
    conditions.push({field:"title",op:"contains",value:""});
    renderConditions();
    apply();
  });
  ui.clear.addEventListener("click",() => {
    conditions = [];
    ui.logic.value = "and";
    renderConditions();
    apply();
  });
  ui.copy.addEventListener("click",() => updateAddress(true));
  ui.logic.addEventListener("change",apply);
  ui.columnSearch?.addEventListener("input",renderColumnOptions);
  ui.pageSize.addEventListener("change",apply);
  ui.prev.addEventListener("click",() => { page -= 1; render(); });
  ui.next.addEventListener("click",() => { page += 1; render(); });
  ui.export.addEventListener("click",() => {
    filtered = records.filter(matches);
    const visible = fields.filter((field) => visibleColumns.has(field.key));
    const safe = (value) => {
      let s = display(value);
      if (/^[=+@-]/.test(s)) s = "'" + s;
      return '"' + s.replaceAll('"','""') + '"';
    };
    const lines = [visible.map((field) => safe(field.label)).join(",")];
    filtered.forEach((record) => lines.push(visible.map((field) => safe(valuesFor(record,field.key))).join(",")));
    const blob = new Blob(["\uFEFF" + lines.join("\r\n")],{type:"text/csv;charset=utf-8"});
    const href = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = href;
    link.download = "rocom-pet-query.csv";
    link.click();
    URL.revokeObjectURL(href);
  });
  ui.search.addEventListener("input",apply);
  [ui.season,ui.source,ui.type].forEach((el) => el.addEventListener("change",apply));
  ui.head.addEventListener("click",(event) => {
    const button = event.target.closest("[data-sort]");
    if (!button) return;
    const key = button.dataset.sort;
    sort = {key,direction:sort.key === key ? -sort.direction : 1};
    renderHead();
    render();
    updateAddress(false);
  });

  fetch("./data/pets.json").then((response) => {
    if (!response.ok) throw new Error("HTTP " + response.status);
    return response.json();
  }).then((data) => {
    if (!Array.isArray(data.records)) throw new Error("数据文件格式不正确");
    records = data.records;
    populateFilters();
    buildFields();
    loadUrlState();
    renderColumnOptions();
    renderConditions();
    renderHead();
    render();
  }).catch((error) => {
    ui.status.textContent = "数据载入失败：" + error.message;
    const row = document.createElement("tr"), cell = document.createElement("td");
    cell.colSpan = 1;
    cell.className = "empty";
    cell.textContent = "请稍后重试，或从仓库生成网页数据。";
    row.append(cell);
    ui.rows.replaceChildren(row);
  });
})();
