-- tabby tests. Run from the repo root: quarto pandoc lua path/to/qtest.lua
local t = require("qtest")

-- Regression: tabby crashed on Quarto 1.10 because quarto.Tabset needs its
-- tabs as a pandoc.List (fixed in the 2026 cleanup). Any render catches it.
t.test("html: a .tabby div becomes one tabset with a tab per language, in order", function()
  local r = t.render("basic.qmd", "html")
  r:succeeded()
  t.count(r.text, '<div class="panel-tabset">', 1)
  t.in_order(r.text, { ">R</a>", ">Python</a>", ">Bash</a>" })
end)

t.test("default-tab: the document setting moves that language first; a div's own setting wins", function()
  local r = t.render("options.qmd", "html")
  r:succeeded()
  t.in_order(r.text, {
    'data-default-tab="python"', ">Python</a>", ">R</a>",
    'data-default-tab="bash"', ">Bash</a>", ">R</a>",
  })
end)

t.test("group: only the tabset that sets it joins the group", function()
  local r = t.render("options.qmd", "html")
  t.count(r.text, '<div class="panel-tabset" data-group="lang"', 1)
  t.count(r.text, '<div class="panel-tabset" data-default-tab="python">', 1)
end)

t.test("?default-tab= URL script: added once per page, however many tabsets", function()
  local r = t.render("options.qmd", "html")
  t.count(r.text, "urlParams.get('default-tab')", 1)
end)

t.test("revealjs: renders the tabset", function()
  local r = t.render("basic.qmd", "revealjs")
  r:succeeded()
  t.count(r.text, '<div class="panel-tabset">', 1)
  t.in_order(r.text, { ">R</a>", ">Python</a>", ">Bash</a>" })
end)

t.test("typst: keeps every code block and drops the HTML script", function()
  local r = t.render("basic.qmd", "typst")
  r:succeeded()
  -- Typst highlights code into tokens, so look for the names alone
  t.contains(r.text, '"getwd"')
  t.contains(r.text, '"pwd"')
  t.not_contains(r.text, "URLSearchParams")
end)

t.test("docx: keeps every code block", function()
  local r = t.render("basic.qmd", "docx")
  r:succeeded()
  t.contains(r.text, "getwd()")
  t.contains(r.text, "pwd")
  t.not_contains(r.text, "URLSearchParams")
end)
