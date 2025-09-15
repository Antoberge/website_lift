function Meta(m)
  -- si la page a déjà des valeurs, on ne touche pas
  local input = quarto.doc and quarto.doc.input_file or nil
  if not input then return m end

  local dir  = pandoc.path.directory(input)
  local base = pandoc.path.filename(dir)   -- ex: ai-exposure

  if not m.slug then
    m.slug = pandoc.MetaString(base)
  end
  if not m.image then
    m.image = pandoc.MetaString("/images/pubs/" .. base .. ".png")
  end
  if not m.pdf then
    m.pdf = pandoc.MetaString("/files/papers/" .. base .. ".pdf")
  end
  return m
end
