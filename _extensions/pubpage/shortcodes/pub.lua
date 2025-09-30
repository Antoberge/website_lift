local utils = require("../../utils")

local MEMBERS_BASE = utils.MEMBERS_BASE
local MEMBERS_EXT  = utils.MEMBERS_EXT


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


-- Construit le bloc meta auteurs + script de "téléportation" dans le header
local function authors_meta_block(authors)
  if #authors == 0 then return pandoc.Null() end

  local label = (#authors > 1) and "Auteurs" or "Auteur"
  local links = {}
  for _, a in ipairs(authors) do
    local name_txt = utils.esc(a.name or a.id or "Anonyme")
    local raw_id   = a.id or ""              -- raw for URL
    local safe_id  = utils.esc(raw_id)       -- only for display if needed
    local href     = MEMBERS_BASE .. raw_id .. MEMBERS_EXT
    table.insert(links, string.format("<a href='%s'>%s</a>", href, name_txt))
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
  if (src && meta) meta.insertBefore(src, meta.firstElementChild || null);
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
    local members_map = utils.load_members().byid
    local ids     = get_author_ids_from_meta(meta, members_map)
    local authors = lookup_authors(ids, members_map)
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
