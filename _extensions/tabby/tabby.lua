---@class TabbyConfig
---@field default_tab? string Document-wide default tab from `tabby: default-tab:`

---@type TabbyConfig
local config = {}

-- The URL handler script only needs to be added once per document
local url_handler_added = false

-- Selects the tab named by `?default-tab=` in the page URL
local URL_HANDLER = [[
<script>
document.addEventListener('DOMContentLoaded', function() {
    // Get default-tab from URL if present
    const urlParams = new URLSearchParams(window.location.search);
    const defaultTab = urlParams.get('default-tab');

    if (defaultTab) {
        const tabName = defaultTab.toLowerCase();
        // Find all tab buttons
        document.querySelectorAll('[role="tab"]').forEach(button => {
            if (button.textContent.toLowerCase() === tabName) {
                button.click();
            }
        });
    }
});
</script>
]]

-- Get the language of a code block, or of the first code block in a cell
---@param block pandoc.CodeBlock|pandoc.Div A code block or a `.cell` div
---@return string language The language class, or "text" when there is none
local function get_language(block)
    if block.t == 'CodeBlock' then
        return block.classes[1] or "text"
    end
    for _, child in ipairs(block.content) do
        if child.t == 'CodeBlock' and child.classes[1] then
            return child.classes[1]
        end
    end
    return "text"
end

-- Move the first block whose language matches `default_lang` to the front,
-- keeping the others in their original order
---@param blocks pandoc.List Code blocks and cells
---@param default_lang? string Language to show first, matched case-insensitively
---@return pandoc.List ordered
local function default_first(blocks, default_lang)
    if not default_lang then
        return blocks
    end
    local wanted = default_lang:lower()
    for i, block in ipairs(blocks) do
        if get_language(block):lower() == wanted then
            local ordered = blocks:clone()
            ordered:insert(1, ordered:remove(i))
            return ordered
        end
    end
    return blocks
end

-- Read the document-wide default tab from `tabby:` metadata
---@param meta pandoc.Meta
local function read_config(meta)
    local options = meta.tabby
    if type(options) == "table" and options["default-tab"] ~= nil then
        config.default_tab = pandoc.utils.stringify(options["default-tab"])
    end
end

-- Turn a `.tabby` div into a tabset with one tab per code block or cell
---@param div pandoc.Div
---@return pandoc.Div|nil
local function make_tabset(div)
    if not div.classes:includes('tabby') then
        return nil
    end

    local code_blocks = pandoc.List()
    local other_content = pandoc.List()
    for _, block in ipairs(div.content) do
        if block.t == 'CodeBlock' or (block.t == 'Div' and block.classes:includes('cell')) then
            code_blocks:insert(block)
        else
            other_content:insert(block)
        end
    end

    if #code_blocks == 0 then
        return nil
    end

    local group = div.attributes["group"]
    local default_lang = div.attributes["default-tab"] or config.default_tab

    -- quarto.Tabset calls :map() on tabs, so this must be a pandoc.List
    local tabs = pandoc.List()
    for _, block in ipairs(default_first(code_blocks, default_lang)) do
        tabs:insert(quarto.Tab({
            title = (get_language(block):gsub("^%l", string.upper)),
            content = pandoc.Blocks({block})
        }))
    end

    -- Pandoc attributes keep insertion order, so assigning one at a time
    -- gives stable output across renders
    local tabset_attr = pandoc.Attr("", {"panel-tabset"})
    if group then
        tabset_attr.attributes["group"] = group
    end
    if default_lang then
        tabset_attr.attributes["default-tab"] = default_lang
    end

    -- quarto.Tabset returns two values; only the first is the block
    local tabset = quarto.Tabset({
        level = 3,
        tabs = tabs,
        attr = tabset_attr
    })

    local result = other_content
    result:insert(tabset)

    if not url_handler_added then
        result:insert(pandoc.RawBlock('html', URL_HANDLER))
        url_handler_added = true
    end

    return pandoc.Div(result)
end

return {
    {Meta = read_config},
    {Div = make_tabset}
}
