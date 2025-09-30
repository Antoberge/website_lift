-- _extensions/homepage/shortcodes/partners.lua
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

local function load_partners()
  local input = pandoc.path.normalize(quarto.doc.input_file or "")
  local root  = find_project_root(pandoc.path.directory(input))
  local path  = pandoc.path.normalize(root .. "/data/partners.json")
  local f = io.open(path, "r")
  if not f then return {} end
  local txt = f:read("*a"); f:close()
  local ok, data = pcall(quarto.json.decode, txt)
  if not ok or type(data) ~= "table" then return {} end
  return data.partners or {}
end

return {
  ["partners"] = function()
    local parts = load_partners()
    local buf = { '<div class="brands">' }
    for _, p in ipairs(parts) do
      local url  = p.url  or "#"
      local logo = p.logo or ""
      local name = p.name or ""
      table.insert(buf, '<a href="'..url..'"><img src="'..logo..'" alt="'..name..'"></a>')
    end
    table.insert(buf, '</div>')
    return pandoc.RawBlock("html", table.concat(buf, ""))
  end
}
