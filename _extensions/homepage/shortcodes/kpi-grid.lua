local utils = require("../../utils")

local function render_kpi(k)
  local icon  = utils.esc(k.icon or "")
  local num   = utils.esc(k.num or "")
  local label = utils.esc(k.label or "")
  return table.concat({
    '<div class="kpi">',
      '<span class="bi ', icon, ' icon"></span>',
      '<div class="num">', num, '</div>',
      '<div class="label">', label, '</div>',
    '</div>'
  })
end

return {
  ["kpi-grid"] = function()
    local kpis = utils.load_data_array("data/kpis.json", "kpis")
    local buf = { '<div class="kpis grid-3">' }
    for _, k in ipairs(kpis) do
      table.insert(buf, render_kpi(k))
    end
    table.insert(buf, '</div>')
    return pandoc.RawBlock("html", table.concat(buf, ""))
  end
}
