-- _extensions/homepage/shortcodes/kpi-grid.lua
local function find_project_root(start)
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

local function load_kpis()
  local input = pandoc.path.normalize(quarto.doc.input_file or "")
  local root  = find_project_root(pandoc.path.directory(input))
  local path  = pandoc.path.normalize(root .. "/data/kpis.json")
  local f = io.open(path, "r")
  if not f then return {} end
  local txt = f:read("*a"); f:close()
  local ok, data = pcall(quarto.json.decode, txt)
  if not ok or type(data) ~= "table" then return {} end
  return data.kpis or {}
end

return {
  ["kpi-grid"] = function()
    local kpis = load_kpis()
    local buf = { '<div class="kpis grid-3">' }
    for _, k in ipairs(kpis) do
      table.insert(buf, '<div class="kpi">')
      table.insert(buf, '<span class="bi ' .. (k.icon or "") .. ' icon"></span>')
      table.insert(buf, '<div class="num">' .. tostring(k.num or "") .. '</div>')
      table.insert(buf, '<div class="label">' .. (k.label or "") .. '</div>')
      table.insert(buf, '</div>')
    end
    table.insert(buf, '</div>')
    return pandoc.RawBlock("html", table.concat(buf, ""))
  end
}
