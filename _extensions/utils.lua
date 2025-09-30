-- _extensions/utils.lua

local utils = {}

utils.MEMBERS_BASE = "/membres/"
utils.MEMBERS_EXT  = ".html"

-- Détermine la racine du projet Quarto en remontant les dossiers
function utils.find_project_root(start)
  local dir = start
  while true do
    local q1, q2 = dir .. "/_quarto.yml", dir .. "/_quarto.yaml"
    local f = io.open(q1, "r") or io.open(q2, "r")
    if f then f:close(); return dir end
    local parent = pandoc.path.directory(dir)
    if parent == dir or parent == "" or parent == "." then return "." end
    dir = parent
  end
end

-- Renvoie la racine du projet pour le document en cours
function utils.project_root_for_current_doc()
  local input = pandoc.path.normalize(quarto.doc.input_file or "")
  local start = pandoc.path.directory(input)
  if start == "" then start = "." end
  return utils.find_project_root(start)
end

-- Met en cache et charge data/members.json
local MEMBERS_CACHE = nil
function utils.load_members()
  if MEMBERS_CACHE then return MEMBERS_CACHE end
  local root = utils.project_root_for_current_doc()
  local path = pandoc.path.normalize(root .. "/data/members.json")
  local f = io.open(path, "r")
  if not f then
    MEMBERS_CACHE = { list = {}, byid = {} }
    return MEMBERS_CACHE
  end
  local txt = f:read("*a"); f:close()
  local ok, data = pcall(quarto.json.decode, txt)
  if not ok or type(data) ~= "table" then
    MEMBERS_CACHE = { list = {}, byid = {} }
    return MEMBERS_CACHE
  end
  local list, byid = {}, {}
  for _, m in ipairs(data.members or {}) do
    if m.id and m.name then
      table.insert(list, m)
      byid[m.id] = m
    end
  end
  MEMBERS_CACHE = { list = list, byid = byid }
  return MEMBERS_CACHE
end

-- Fonction d’échappement HTML (utilisée dans les deux shortcodes)
function utils.esc(s)
  s = tostring(s or "")
  return s:gsub("&", "&amp;"):gsub("<", "&lt;")
          :gsub(">", "&gt;"):gsub('"', "&quot;")
end

return utils
