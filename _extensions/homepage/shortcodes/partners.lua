local utils = require("../../utils")

local function render_partner(p)
  local url  = utils.esc(p.url  or "#")
  local logo = utils.esc(p.logo or "")
  local name = utils.esc(p.name or "")
  return '<a href="'..url..'"><img src="'..logo..'" alt="'..name..'"></a>'
end

return {
  ["partners"] = function()
    local parts = utils.load_data_array("data/partners.json", "partners")
    local buf = { '<div class="brands">' }
    for _, p in ipairs(parts) do
      table.insert(buf, render_partner(p))
    end
    table.insert(buf, '</div>')
    return pandoc.RawBlock("html", table.concat(buf, ""))
  end
}
