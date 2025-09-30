
local utils = require("../../utils")

local MEMBERS_BASE = utils.MEMBERS_BASE
local MEMBERS_EXT  = utils.MEMBERS_EXT
local esc          = utils.esc
local load_members = utils.load_members
local find_project_root = utils.find_project_root

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
