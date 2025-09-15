-- _extensions/member/members.lua
-- Fournit 2 shortcodes :
--   {{< member name=... role=... img=... bio=... >}}         -- compatibilité (statique)
--   {{< members-grid role="Direction" >}}                    -- AUTO depuis data/members.json

local MEMBERS_BASE = "/membres/"
local MEMBERS_EXT  = ".html"

-- --- utils: trouver la racine du projet + charger JSON --------------------
local function find_project_root(start)
  local dir = start
  while true do
    local q1 = dir .. "/_quarto.yml"
    local q2 = dir .. "/_quarto.yaml"
    local f = io.open(q1, "r") or io.open(q2, "r")
    if f then f:close(); return dir end
    local parent = pandoc.path.directory(dir)
    if parent == dir or parent == "" or parent == "." then return nil end
    dir = parent
  end
end

local function project_root_for_current_doc()
  local input = pandoc.path.normalize(quarto.doc.input_file or "")
  local start = pandoc.path.directory(input)
  if start == "" then start = "." end
  return find_project_root(start) or "."
end

local MEMBERS_CACHE = nil
local function load_members()
  if MEMBERS_CACHE then return MEMBERS_CACHE end
  local root = project_root_for_current_doc()
  local path = pandoc.path.normalize(root .. "/data/members.json")
  local f = io.open(path, "r")
  if not f then
    quarto.log.output("[members] members.json introuvable: " .. path)
    MEMBERS_CACHE = { list = {}, byid = {} }
    return MEMBERS_CACHE
  end
  local txt = f:read("*a"); f:close()
  local ok, data = pcall(quarto.json.decode, txt)
  if not ok or type(data) ~= "table" then
    quarto.log.output("[members] members.json illisible (JSON invalide ?)")
    MEMBERS_CACHE = { list = {}, byid = {} }
    return MEMBERS_CACHE
  end
  local byid, list = {}, {}
  for _, m in ipairs(data.members or {}) do
    if m.id and m.name then
      table.insert(list, m)
      byid[m.id] = m
    end
  end
  quarto.log.output(string.format("[members] %d membres chargés", #list))
  MEMBERS_CACHE = { list = list, byid = byid }
  return MEMBERS_CACHE
end

local function esc(s)
  s = tostring(s or "")
  s = s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
  return s
end

-- --- shortcode existant : member (compat) ---------------------------------
local function Member(args, kwargs, meta)
  local name = pandoc.utils.stringify(kwargs["name"] or "")
  local role = pandoc.utils.stringify(kwargs["role"] or "")
  local img  = pandoc.utils.stringify(kwargs["img"]  or "")
  local bio  = pandoc.utils.stringify(kwargs["bio"]  or "")
  local html = [[
  <div class="member-card">
    <img src="]]..esc(img)..[[" alt="]]..esc(name)..[[" class="member-photo"/>
    <h3 class="member-name">]]..esc(name)..[[</h3>
    <p class="member-role">]]..esc(role)..[[</p>
    <div class="member-bio">]]..esc(bio)..[[</div>
  </div>
  ]]
  return pandoc.RawBlock("html", html)
end

-- --- nouveau shortcode : members-grid (auto) -------------------------------
local function MembersGrid(args, kwargs, meta)
  local role_filter = kwargs["role"] and pandoc.utils.stringify(kwargs["role"]) or nil
  local data = load_members()

  -- filtre + tri (alpha par défaut)
  local rows = {}
  for _, m in ipairs(data.list) do
    if (not role_filter) or (m.role == role_filter) then
      table.insert(rows, m)
    end
  end
  table.sort(rows, function(a,b) return (a.name or "") < (b.name or "") end)

  -- génère la grille complète (avec wrapper .members-grid)
  local buf = { '<div class="members-grid">' }
  for _, m in ipairs(rows) do
    local id   = esc(m.id   or "")
    local name = esc(m.name or "")
    local role = esc(m.role or "")
    local img  = esc(m.photo or "")
    local href = MEMBERS_BASE .. id .. MEMBERS_EXT

    table.insert(buf, '<a class="member-card" href="'..href..'">')
    if img ~= "" then
      table.insert(buf, '<img src="'..img..'" alt="'..name..'" class="member-photo"/>')
    end
    table.insert(buf, '<h3 class="member-name">'..name..'</h3>')
    if role ~= "" then
      table.insert(buf, '<p class="member-role">'..role..'</p>')
    end
    table.insert(buf, '</a>')
  end
  table.insert(buf, '</div>')

  if #rows == 0 then
    return pandoc.RawBlock("html", '<div class="members-grid"><div style="opacity:.7">Aucun membre.</div></div>')
  end
  return pandoc.RawBlock("html", table.concat(buf, ""))
end

return {
  ["member"]       = Member,
  ["members-grid"] = MembersGrid
}
