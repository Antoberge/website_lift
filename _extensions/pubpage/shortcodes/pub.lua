-- _extensions/pubpage/shortcodes/pub.lua
-- Auteurs affichés dans le bloc titre (quarto-title-meta), via lookup data/members.json.

local MEMBERS_BASE = "/membres/"
local MEMBERS_EXT  = ".html"

-- ---------- helpers ----------
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
    quarto.log.output("[pub] members.json introuvable: " .. path)
    MEMBERS_CACHE = {}
    return MEMBERS_CACHE
  end
  local txt = f:read("*a"); f:close()
  local ok, data = pcall(quarto.json.decode, txt)
  if not ok or type(data) ~= "table" then
    quarto.log.output("[pub] members.json illisible (JSON invalide ?)")
    MEMBERS_CACHE = {}
    return MEMBERS_CACHE
  end
  local map, n = {}, 0
  for _, m in ipairs(data.members or {}) do
    if m.id and m.name then map[m.id] = m; n = n + 1 end
  end
  quarto.log.output(string.format("[pub] %d membres chargés", n))
  MEMBERS_CACHE = map
  return MEMBERS_CACHE
end

-- Lecture robuste: accepte MetaList OU chaîne "a, b c"
local function get_author_ids_from_meta(meta, members_map)
  -- accepte author-ids / author_ids / authorids / authors
  local field = meta["author-ids"] or meta["author_ids"] or meta["authorids"] or meta["authors"]
  local ids = {}

  if not field then return ids end

  -- Cas 1 : vraie MetaList
  local tag = (type(field) == "table") and (field.t or field.tag) or nil
  if tag == "MetaList" then
    for i = 1, #field do
      local v = field[i]
      if type(v) == "table" and v.t == "MetaMap" and v["id"] then
        table.insert(ids, pandoc.utils.stringify(v["id"]))
      else
        table.insert(ids, pandoc.utils.stringify(v))
      end
    end
  else
    -- Cas 2 : chaîne → on tente des séparateurs classiques
    local s = pandoc.utils.stringify(field or "")
    for id in s:gmatch("[^,%s]+") do table.insert(ids, id) end

    -- Cas 3 (fallback) : si on n’a qu’UN seul “id” très long (concaténé),
    -- on tente de le re-séparer en scannant les ids connus de members.json
    if #ids == 1 then
      local cat = ids[1]
      -- on cherche chaque m.id dans la chaîne et on trie par position
      local found = {}
      for mid, _ in pairs(members_map or {}) do
        local i = string.find(cat, mid, 1, true)
        if i then table.insert(found, {pos = i, id = mid}) end
      end
      table.sort(found, function(a,b) return a.pos < b.pos end)

      -- on reconstruit en évitant les chevauchements
      local rebuilt, cursor = {}, 1
      for _, f in ipairs(found) do
        if f.pos >= cursor then
          table.insert(rebuilt, f.id)
          cursor = f.pos + #f.id
        end
      end

      if #rebuilt >= 2 then
        ids = rebuilt
        quarto.log.output(string.format("[pub] Fallback split appliqué: %s → %s",
          cat, table.concat(ids, ", ")))
      end
    end
  end

  return ids
end

local function lookup_authors(ids, members)
  local out = {}
  for _, id in ipairs(ids) do
    local m = members[id]
    if not m then
      quarto.log.output("[pub] auteur inconnu: " .. id)
      table.insert(out, { id = id, name = id })
    else
      table.insert(out, m)
    end
  end
  return out
end

local function esc(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
  return s
end

-- Construit le bloc meta auteurs + script de "téléportation" dans le header
local function authors_meta_block(authors)
  if #authors == 0 then return pandoc.Null() end

  local label = (#authors > 1) and "Auteurs" or "Auteur"
  local links = {}
  for _, a in ipairs(authors) do
    local name = esc(a.name or a.id or "Anonyme")
    local id   = esc(a.id or "")
    local href = MEMBERS_BASE .. id .. MEMBERS_EXT
    table.insert(links, string.format("<a href='%s'>%s</a>", href, name))
  end

  local html = string.format([[
<div id="title-authors-meta" class="title-authors-meta">
  <div class="quarto-title-meta-heading">%s</div>
  <div class="quarto-title-meta-contents"><p>%s</p></div>
</div>
<script>
document.addEventListener('DOMContentLoaded', function () {
  const src  = document.getElementById('title-authors-meta');
  const meta = document.querySelector('header#title-block-header .quarto-title-meta');
  if (src && meta) {
    meta.insertBefore(src, meta.firstElementChild || null);
  }
});
</script>
]], label, table.concat(links, ", "))

  return pandoc.RawBlock("html", html)
end

local function link(href, txt)
  return pandoc.Link({ pandoc.Str(txt or href) }, href)
end

-- ---------- shortcode ----------
return {
  ["pub"] = function(args, kwargs, meta)
    -- vignette/pdf fallback depuis le dossier
    local image = meta.image and pandoc.utils.stringify(meta.image) or ""
    local pdf   = meta.pdf   and pandoc.utils.stringify(meta.pdf)   or ""
    if image == "" or pdf == "" then
      local input = quarto.doc and quarto.doc.input_file or nil
      if input then
        local dir  = pandoc.path.directory(input)
        local base = pandoc.path.filename(dir)
        if image == "" then image = "/images/pubs/" .. base .. ".png" end
        if pdf   == "" then pdf   = "/files/papers/" .. base .. ".pdf" end
      end
    end

    -- 0) AUTEURS (bloc qui sera déplacé dans le header)
    local members = load_members()
    local ids     = get_author_ids_from_meta(meta, members)  -- <-- passe members ici
    local authors = lookup_authors(ids, members)
    local authors_meta = authors_meta_block(authors)

    -- 1) sidebar (image + partage si tu veux rajouter)
    local sidebar_blocks = {}
    if image ~= "" then
      local img = pandoc.Image("", image); img.attributes["class"] = "pub-cover"
      table.insert(sidebar_blocks, pandoc.Para{ img })
    end
    local sidebar = pandoc.Div(sidebar_blocks); sidebar.attributes["class"] = "pub-sidebar"

    -- 2) body (PAS d’auteurs ici)
    local body_blocks = {}
    if meta.abstract then
      local ab = pandoc.utils.stringify(meta.abstract)
      local ab_div = pandoc.Div({ pandoc.Para(ab) })
      ab_div.attributes["class"] = "abstract"
      table.insert(body_blocks, ab_div)
    end
    local items = {}
    if pdf ~= "" then
      table.insert(items, { pandoc.Para{ pandoc.Str("📄 "), link(pdf, "PDF") } })
    end
    if #items > 0 then
      table.insert(body_blocks, pandoc.Para{ pandoc.Strong("Liens :") })
      table.insert(body_blocks, pandoc.BulletList(items))
    end

    local body = pandoc.Div(body_blocks); body.attributes["class"] = "pub-body"
    local wrap = pandoc.Div({ sidebar, body }); wrap.attributes["class"] = "pub-wrap"

    -- IMPORTANT : on renvoie le bloc auteurs (qui sera déplacé) + la fiche
    return { authors_meta, wrap }
  end
}
